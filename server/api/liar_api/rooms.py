"""Ranked rooms: a ranked match played the way every room of the game is
(one of the players hosts it, the others join by address: a LAN, Radmin VPN),
not on a match server of the house.

Nobody's machine is the authority there, and the house trusts none of them
alone: every member at the table plays the whole match (the game runs in
lockstep), and every one of them reports how it ended.

1. The host asks for the match (`open_room`): the seats, by member name,
   played by the ranked rules. Everyone in it has to be a member.
2. Each member's machine shows up (`join`) with its own token, as the deal
   reaches it: that is how the house knows the member is at that table.
3. At the end each of them reports (`report`): the result, the record of the
   match and a digest of how it ended. Once every member who showed up has
   reported, or `room_settle` seconds after the first report, the house goes
   with the digest most of them agree on (a tie between two: the match is
   void). Only the members who showed up are rated; a seat is a forfeit (put
   last) if most of the agreeing reports say so.
"""

from __future__ import annotations

import json
import secrets
import shutil
import threading
from collections import Counter

from . import accounts, db, results
from .config import RANKED_RULES, settings

_lock = threading.Lock()


def _reports_dir(match_id: str):
    return settings.data_dir / "reports" / match_id


def _same_rules(config: dict) -> bool:
    for key, value in RANKED_RULES.items():
        given = config.get(key)
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            if not isinstance(given, (int, float)) or isinstance(given, bool) or abs(float(given) - float(value)) > 1e-6:
                return False
        elif given != value:
            return False
    return True


def open_room(host_id: int, build: int, names: list[str], config: dict) -> dict:
    names = [str(n).strip() for n in names]
    if len(names) < 2:
        raise accounts.Refused("A ranked table needs at least 2 members.")
    if len({n.casefold() for n in names}) != len(names) or len(names) > 8:
        raise accounts.Refused("The seats of that table are not right.")
    if not _same_rules(config):
        raise accounts.Refused("A ranked table is played by the house's rules.")
    with db.connect() as conn:
        ids = []
        for name in names:
            row = conn.execute("SELECT id, name FROM players WHERE name = ?", (name,)).fetchone()
            if row is None:
                raise accounts.Refused("Everyone at a ranked table has to be a member of the house.")
            ids.append((row["id"], row["name"]))
        if host_id not in [i for i, _ in ids]:
            raise accounts.Refused("The host has to be at the table.")
        # A host has one ranked room open at a time: the one they left
        # behind (nobody reported on it) is called off.
        stale = [r["id"] for r in conn.execute(
            "SELECT id FROM matches WHERE mode = 'room' AND host_id = ? AND state = 'playing' "
            "AND NOT EXISTS (SELECT 1 FROM room_reports WHERE match_id = matches.id)", (host_id,))]
        for old in stale:
            conn.execute("UPDATE matches SET state = 'aborted', ended_at = ? WHERE id = ?", (db.now(), old))
        match_id = "r" + secrets.token_hex(7)
        t = db.now()
        conn.execute(
            "INSERT INTO matches (id, state, port, secret_hash, build, config, created_at, started_at, mode, host_id) "
            "VALUES (?, 'playing', 0, '', ?, ?, ?, ?, 'room', ?)",
            (match_id, int(build), db.dumps(config), t, t, host_id))
        for seat, (player_id, name) in enumerate(ids):
            conn.execute("INSERT INTO match_players (match_id, player_id, seat, name, joined) VALUES (?, ?, ?, ?, ?)",
                         (match_id, player_id, seat, name, 1 if player_id == host_id else 0))
    return {"match": match_id, "seats": [name for _, name in ids]}


def _seat(conn, match_id: str, player_id: int) -> dict:
    match = conn.execute("SELECT * FROM matches WHERE id = ? AND mode = 'room'", (match_id,)).fetchone()
    row = conn.execute("SELECT * FROM match_players WHERE match_id = ? AND player_id = ?", (match_id, player_id)).fetchone()
    if match is None or row is None:
        raise accounts.Refused("You have no seat at that table.")
    return {"match": dict(match), "seat": dict(row)}


def join(match_id: str, player_id: int) -> dict:
    with db.connect() as conn:
        found = _seat(conn, match_id, player_id)
        if found["match"]["state"] != "playing":
            raise accounts.Refused("That match is over.")
        conn.execute("UPDATE match_players SET joined = 1 WHERE match_id = ? AND player_id = ?", (match_id, player_id))
        return {"ok": True, "seat": found["seat"]["seat"]}


def report(match_id: str, player_id: int, body: dict) -> dict:
    digest = str(body.get("digest", ""))[:128]
    if not digest or not isinstance(body.get("report"), dict):
        raise accounts.Refused("That report is not right.")
    with db.connect() as conn:
        found = _seat(conn, match_id, player_id)
        if found["match"]["state"] == "playing":
            if not found["seat"]["joined"]:
                raise accounts.Refused("You have no seat at that table.")
            folder = _reports_dir(match_id)
            folder.mkdir(parents=True, exist_ok=True)
            (folder / f"{player_id}.json").write_text(json.dumps(body["report"], separators=(",", ":")), encoding="utf-8")
            conn.execute("INSERT OR REPLACE INTO room_reports VALUES (?, ?, ?, ?)", (match_id, player_id, digest, db.now()))
    settle(match_id)
    return state(match_id, player_id)


def state(match_id: str, player_id: int) -> dict:
    with db.connect() as conn:
        found = _seat(conn, match_id, player_id)
        match = found["match"]
        out = {"state": {"playing": "playing", "done": "done"}.get(match["state"], "void"), "match": match_id}
        if match["state"] == "done":
            out["seats"] = [
                {"seat": r["seat"], "name": r["name"], "place": r["place"], "forfeit": bool(r["forfeit"]),
                 "before": round(r["rating_before"]), "after": round(r["rating_after"]),
                 "delta": round(r["rating_after"]) - round(r["rating_before"])}
                for r in conn.execute("SELECT * FROM match_players WHERE match_id = ? ORDER BY seat", (match_id,))]
        return out


def settle_due() -> None:
    """The room matches whose time is up: settled if anyone reported, called
    off if nobody did for `match_hours`."""
    now = db.now()
    with db.connect() as conn:
        rows = conn.execute(
            "SELECT m.id, m.created_at, MIN(r.at) AS first, COUNT(r.player_id) AS reports "
            "FROM matches m LEFT JOIN room_reports r ON r.match_id = m.id "
            "WHERE m.mode = 'room' AND m.state = 'playing' GROUP BY m.id").fetchall()
        for row in rows:
            if not row["reports"] and now - row["created_at"] > settings.match_hours * 3600:
                conn.execute("UPDATE matches SET state = 'aborted', ended_at = ? WHERE id = ?", (now, row["id"]))
    for row in rows:
        if row["reports"] and now - row["first"] > settings.room_settle:
            settle(row["id"], force=True)


def settle(match_id: str, force: bool = False) -> None:
    with _lock:
        with db.connect() as conn:
            match = conn.execute("SELECT * FROM matches WHERE id = ?", (match_id,)).fetchone()
            if match is None or match["state"] != "playing":
                return
            seats = {r["seat"]: dict(r) for r in conn.execute("SELECT * FROM match_players WHERE match_id = ?", (match_id,))}
            joined = {s for s, r in seats.items() if r["joined"]}
            reports = [dict(r) for r in conn.execute("SELECT * FROM room_reports WHERE match_id = ?", (match_id,))]
            if not reports or (not force and len(reports) < len(joined)):
                return
            bodies = {}
            for r in reports:
                try:
                    bodies[r["player_id"]] = json.loads((_reports_dir(match_id) / f"{r['player_id']}.json").read_text(encoding="utf-8"))
                except (OSError, ValueError):
                    pass
            counts = Counter(r["digest"] for r in reports if r["player_id"] in bodies).most_common()
            why = ""
            if not counts:
                why = "no report could be read"
            elif len(counts) > 1 and counts[0][1] == counts[1][1]:
                why = "the reports do not agree"
            elif len(joined) < 2:
                why = "fewer than 2 members showed up"
            if why:
                conn.execute("UPDATE matches SET state = 'aborted', ended_at = ? WHERE id = ?", (db.now(), match_id))
                report = next(iter(bodies.values()), {})
                out = []
            else:
                agreed = [bodies[r["player_id"]] for r in reports if r["digest"] == counts[0][0] and r["player_id"] in bodies]
                report = agreed[0]
                # A seat is a forfeit if most of the agreeing reports say so: the
                # machines may see a player leave at different moments.
                said = Counter()
                for body in agreed:
                    for p in body.get("players", []):
                        if p.get("forfeit"):
                            said[int(p.get("seat", -1))] += 1
                forfeits = {s for s in seats if said[s] * 2 > len(agreed)}
                places = results.places_of([int(s) for s in report.get("order", [])], seats, forfeits)
                rated = {s: seats[s] for s in joined}
                # Whoever never showed up at the house is not rated, nor counted.
                for s in seats:
                    if s not in joined:
                        conn.execute("DELETE FROM match_players WHERE match_id = ? AND seat = ?", (match_id, s))
                out = results.write(conn, match_id, report, rated, places, forfeits)
            conn.execute("DELETE FROM room_reports WHERE match_id = ?", (match_id,))
        results.save_log(match_id, report, "room", out, "void" if why else "done", why)
        shutil.rmtree(_reports_dir(match_id), ignore_errors=True)
