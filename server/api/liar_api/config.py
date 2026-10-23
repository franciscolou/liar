"""Everything the house can be told from its environment (see .env.example).

Nothing here is a secret by default: a fresh checkout runs on a laptop with no
setup at all, matching players but starting no match server (`server_cmd`
empty), which is enough to try the screens of the game against it.
"""

from __future__ import annotations

import os
import shlex
from dataclasses import dataclass, field
from pathlib import Path


def _int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, default))
    except ValueError:
        return default


@dataclass(frozen=True)
class Settings:
    # Where the database and the files handed to each match server live.
    data_dir: Path = field(default_factory=lambda: Path(os.environ.get("LIAR_DATA", "./data")).resolve())
    # How the players reach the match servers (the VPS's public address or
    # domain): it goes to the game as is, next to the port.
    public_host: str = os.environ.get("LIAR_PUBLIC_HOST", "127.0.0.1")
    # How a match server reaches this API back, from the same machine.
    internal_url: str = os.environ.get("LIAR_INTERNAL_URL", "http://127.0.0.1:8080")
    # The command that starts one match server, without the spec file: the
    # API adds `--ranked-server=<spec.json>` at the end. Empty: no process is
    # started (the queue still matches people, for trying the screens).
    server_cmd: list[str] = field(default_factory=lambda: shlex.split(os.environ.get("LIAR_SERVER_CMD", "")))
    # The UDP ports the match servers take, one each: first and how many.
    # Open exactly these on the VPS's firewall.
    port_first: int = _int("LIAR_PORT_FIRST", 24600)
    port_count: int = _int("LIAR_PORT_COUNT", 32)
    # How many sit at a ranked table, and how long the first one in the queue
    # waits for a full table before a smaller one is dealt.
    min_players: int = _int("LIAR_MIN_PLAYERS", 3)
    max_players: int = _int("LIAR_MAX_PLAYERS", 5)
    fill_after: int = _int("LIAR_FILL_AFTER", 45)
    # How long a match server waits for everyone to sit down, and how long a
    # seat whose player dropped out waits before a bot plays it.
    arrive_seconds: int = _int("LIAR_ARRIVE_SECONDS", 60)
    away_seconds: int = _int("LIAR_AWAY_SECONDS", 60)
    # A ranked room: once the first member's machine reports the end of the
    # match, how long the others get to report theirs before it is settled.
    room_settle: int = _int("LIAR_ROOM_SETTLE", 90)
    # A match nobody reported on after this long is given up for lost.
    match_hours: int = _int("LIAR_MATCH_HOURS", 3)
    # Comma separated origins allowed to call the API from a browser (the web
    # export of the game); empty: none needed by the desktop and mobile games.
    cors: list[str] = field(default_factory=lambda: [o for o in os.environ.get("LIAR_CORS", "").split(",") if o])


settings = Settings()

# The rules every ranked table is played by (GameConfig.to_wire fields). The
# characters are drawn at random, `character_count` of them; a turn has a clock.
RANKED_RULES: dict = {
    "character_ids": [],
    "item_ids": [],
    "character_count": 5,
    "copies_per_character": 3,
    "hand_size": 2,
    "start_morale": 3,
    "start_coins": 2,
    "income": 2,
    "doubt_cost": 4,
    "doubt_reward": 3,
    "shop_slots": 3,
    "reroll_cost": 2,
    "inventory_limit": 3,
    "anim_speed": 1.0,
    "max_turns": 0,
    "suspect_book": True,
    "pool_draw": 0,
    "turn_seconds": 45,
}
