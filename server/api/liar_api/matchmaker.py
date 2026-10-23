"""The queue, and the match servers it starts.

Players wait in the queue of their game build (machines of different builds
cannot play together). A table is dealt when the queue of a build holds
`max_players`, or once the first one in it has waited `fill_after` seconds
and at least `min_players` are there. The first in line sits with those
closest to their rating.

Each table is a Godot process of its own, the game run headless as a match
server (scripts/net/match_server.gd), on a UDP port of the range. It is told
everything in a spec file: the seats, the hash of each seat's ticket, the
rules, and how to report back here. Each player gets their ticket (the key to
their seat, as the game calls it) from the queue, and joins the process at
`public_host:port` with it. Tickets live only in memory: they are good for
one match, and a player who drops out gets theirs again from the queue to
go back to their seat.
"""

from __future__ import annotations

import asyncio
import hashlib
import logging
import random
import secrets
import threading
import time
from dataclasses import dataclass, field

from . import db, rooms
from .config import RANKED_RULES, settings

log = logging.getLogger("liar.matchmaker")


@dataclass
class Waiting:
    player_id: int
    name: str
    rating: float
    build: int
    since: float = field(default_factory=time.time)


@dataclass
class Table:
    match_id: str
    port: int
    players: list[int]
    tickets: dict[int, str]
    created: float = field(default_factory=time.time)
    process: asyncio.subprocess.Process | None = None


class Matchmaker:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.waiting: dict[int, Waiting] = {}
        self.tables: dict[str, Table] = {}
        self._seated: dict[int, str] = {}  # player -> match id
        self._loop: asyncio.AbstractEventLoop | None = None

    # --- what the endpoints ask ------------------------------------------------

    def join(self, player_id: int, name: str, rating: float, build: int) -> dict:
        with self._lock:
            if player_id not in self._seated and player_id not in self.waiting:
                self.waiting[player_id] = Waiting(player_id, name, rating, build)
        return self.status(player_id)

    def leave(self, player_id: int) -> None:
        with self._lock:
            self.waiting.pop(player_id, None)

    def status(self, player_id: int) -> dict:
        with self._lock:
            match_id = self._seated.get(player_id)
            if match_id is not None and match_id in self.tables:
                table = self.tables[match_id]
                return {"state": "matched", "match": {
                    "id": match_id, "address": settings.public_host, "port": table.port,
                    "ticket": table.tickets[player_id], "players": len(table.players)}}
            entry = self.waiting.get(player_id)
            if entry is None:
                return {"state": "idle"}
            same = [w for w in self.waiting.values() if w.build == entry.build]
            return {"state": "waiting", "since": entry.since, "waited": round(time.time() - entry.since),
                    "waiting": len(same), "needed": settings.min_players, "table": settings.max_players}

    def counts(self) -> dict:
        with self._lock:
            return {"queue": len(self.waiting), "matches": len(self.tables),
                    "playing": sum(len(t.players) for t in self.tables.values())}

    def finished(self, match_id: str) -> None:
        """The match is over (reported, or given up): its seats are free."""
        with self._lock:
            table = self.tables.pop(match_id, None)
            if table is None:
                return
            for player_id in table.players:
                if self._seated.get(player_id) == match_id:
                    del self._seated[player_id]

    # --- the loop --------------------------------------------------------------

    async def run(self) -> None:
        self._loop = asyncio.get_running_loop()
        self._recover()
        while True:
            try:
                for spec in self._deal():
                    await self._start(spec)
                self._reap()
                await asyncio.to_thread(rooms.settle_due)
            except Exception:  # a bad tick must not stop the house
                log.exception("matchmaker tick")
            await asyncio.sleep(1.0)

    def _recover(self) -> None:
        """Matches left open by a house that went down cannot be finished."""
        with db.connect() as conn:
            conn.execute("UPDATE matches SET state = 'aborted', ended_at = ? WHERE state IN ('starting', 'playing')",
                         (db.now(),))

    def _deal(self) -> list[dict]:
        out = []
        with self._lock:
            builds: dict[int, list[Waiting]] = {}
            for w in self.waiting.values():
                builds.setdefault(w.build, []).append(w)
            now = time.time()
            for build, queue in builds.items():
                queue.sort(key=lambda w: w.since)
                while queue:
                    first = queue[0]
                    full = len(queue) >= settings.max_players
                    due = now - first.since >= settings.fill_after and len(queue) >= settings.min_players
                    if not (full or due):
                        break
                    port = self._free_port()
                    if port is None:
                        log.warning("no free port for a table: every one of the range is taken")
                        return out
                    # The first in line, and those nearest to their rating.
                    rest = sorted(queue[1:], key=lambda w: abs(w.rating - first.rating))
                    seated = [first] + rest[: settings.max_players - 1]
                    for w in seated:
                        queue.remove(w)
                        del self.waiting[w.player_id]
                    out.append(self._table(seated, build, port))
        return out

    def _free_port(self) -> int | None:
        taken = {t.port for t in self.tables.values()}
        for port in range(settings.port_first, settings.port_first + settings.port_count):
            if port not in taken:
                return port
        return None

    def _table(self, seated: list[Waiting], build: int, port: int) -> dict:
        """Books a table for `seated` (called under the lock)."""
        match_id = "m" + secrets.token_hex(6)
        secret = secrets.token_urlsafe(24)
        random.shuffle(seated)
        tickets = {w.player_id: secrets.token_hex(16) for w in seated}
        table = Table(match_id, port, [w.player_id for w in seated], tickets)
        self.tables[match_id] = table
        for w in seated:
            self._seated[w.player_id] = match_id
        players = [{"account": w.player_id, "name": w.name, "ticket_hash": hashlib.sha256(tickets[w.player_id].encode()).hexdigest()}
                   for w in seated]
        rules = dict(RANKED_RULES)
        with db.connect() as conn:
            conn.execute("INSERT INTO matches (id, state, port, secret_hash, build, config, created_at) VALUES (?, 'starting', ?, ?, ?, ?, ?)",
                         (match_id, port, hashlib.sha256(secret.encode()).hexdigest(), build, db.dumps(rules), db.now()))
            for seat, w in enumerate(seated):
                conn.execute("INSERT INTO match_players (match_id, player_id, seat, name) VALUES (?, ?, ?, ?)",
                             (match_id, w.player_id, seat, w.name))
        log.info("table %s on port %d: %s", match_id, port, ", ".join(w.name for w in seated))
        return {"match": match_id, "port": port, "api": settings.internal_url, "secret": secret,
                "build": build, "config": rules, "players": players,
                "arrive_seconds": settings.arrive_seconds, "away_seconds": settings.away_seconds}

    async def _start(self, spec: dict) -> None:
        folder = settings.data_dir / "matches"
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / f"{spec['match']}.json"
        path.write_text(db.dumps(spec))
        if not settings.server_cmd:
            log.info("no LIAR_SERVER_CMD: table %s is matched but no server is started", spec["match"])
            return
        command = settings.server_cmd + [f"--ranked-server={path}"]
        logs = (folder / f"{spec['match']}.log").open("wb")
        try:
            process = await asyncio.create_subprocess_exec(*command, stdout=logs, stderr=asyncio.subprocess.STDOUT)
        except OSError:
            log.exception("could not start the match server for %s", spec["match"])
            self._abort(spec["match"])
            return
        finally:
            logs.close()
        table = self.tables.get(spec["match"])
        if table is not None:
            table.process = process
        asyncio.create_task(self._watch(spec["match"], process))

    async def _watch(self, match_id: str, process: asyncio.subprocess.Process) -> None:
        code = await process.wait()
        log.info("match server %s exited with %s", match_id, code)
        # Whatever it did not report, it never will.
        self._abort(match_id)

    def _abort(self, match_id: str) -> None:
        with db.connect() as conn:
            conn.execute("UPDATE matches SET state = 'aborted', ended_at = ? WHERE id = ? AND state IN ('starting', 'playing')",
                         (db.now(), match_id))
        self.finished(match_id)

    def _reap(self) -> None:
        """Tables nobody will report on: no server was started for them, or it
        has been at it for far too long."""
        now = time.time()
        with self._lock:
            stale = []
            for t in self.tables.values():
                if t.process is None and not settings.server_cmd and now - t.created > settings.arrive_seconds + 30:
                    stale.append(t)
                elif now - t.created > settings.match_hours * 3600:
                    stale.append(t)
        for t in stale:
            if t.process is not None and t.process.returncode is None:
                t.process.kill()
            self._abort(t.match_id)


matchmaker = Matchmaker()
