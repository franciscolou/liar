"""The house's books: one SQLite file (WAL), a connection per call.

The schema is created on start and only ever grows: a column or table added
later goes at the end of SCHEMA with IF NOT EXISTS, never by editing a line.
"""

from __future__ import annotations

import json
import sqlite3
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from .config import settings

SCHEMA = """
CREATE TABLE IF NOT EXISTS players (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE COLLATE NOCASE,
    pass_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    rating REAL NOT NULL DEFAULT 1000,
    peak REAL NOT NULL DEFAULT 1000,
    matches INTEGER NOT NULL DEFAULT 0,
    wins INTEGER NOT NULL DEFAULT 0,
    created_at REAL NOT NULL,
    last_seen REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS tokens (
    token_hash TEXT PRIMARY KEY,
    player_id INTEGER NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    created_at REAL NOT NULL,
    last_used REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS matches (
    id TEXT PRIMARY KEY,
    state TEXT NOT NULL,              -- starting, playing, done, aborted
    port INTEGER NOT NULL,
    secret_hash TEXT NOT NULL,
    build INTEGER NOT NULL DEFAULT 0,
    config TEXT NOT NULL DEFAULT '{}',
    characters TEXT NOT NULL DEFAULT '[]',
    turns INTEGER NOT NULL DEFAULT 0,
    seconds REAL NOT NULL DEFAULT 0,
    winner_id INTEGER,
    created_at REAL NOT NULL,
    started_at REAL,
    ended_at REAL
);
CREATE INDEX IF NOT EXISTS matches_ended ON matches(state, ended_at);
CREATE TABLE IF NOT EXISTS match_players (
    match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    player_id INTEGER NOT NULL REFERENCES players(id),
    seat INTEGER NOT NULL,
    name TEXT NOT NULL,
    place INTEGER,
    forfeit INTEGER NOT NULL DEFAULT 0,
    eliminated_turn INTEGER NOT NULL DEFAULT -1,
    rating_before REAL,
    rating_after REAL,
    start_hand TEXT NOT NULL DEFAULT '[]',
    stats TEXT NOT NULL DEFAULT '{}',
    PRIMARY KEY (match_id, seat)
);
CREATE INDEX IF NOT EXISTS match_players_player ON match_players(player_id);
CREATE TABLE IF NOT EXISTS claims (
    match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    turn INTEGER NOT NULL,
    player_id INTEGER NOT NULL,
    character TEXT NOT NULL,
    ability TEXT NOT NULL,
    truthful INTEGER NOT NULL,
    doubted INTEGER NOT NULL,
    caught INTEGER NOT NULL,
    reaction INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS claims_player ON claims(player_id);
CREATE TABLE IF NOT EXISTS doubts (
    match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    turn INTEGER NOT NULL,
    player_id INTEGER NOT NULL,       -- who called LIAR!
    against_id INTEGER NOT NULL,
    ability TEXT NOT NULL,
    correct INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS doubts_player ON doubts(player_id);
CREATE TABLE IF NOT EXISTS purchases (
    match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    turn INTEGER NOT NULL,
    player_id INTEGER NOT NULL,
    item TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS room_reports (
    match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    player_id INTEGER NOT NULL,
    digest TEXT NOT NULL,
    at REAL NOT NULL,
    PRIMARY KEY (match_id, player_id)
);
"""

# Columns added to tables that exist already (SQLite has no ADD COLUMN IF NOT
# EXISTS): tried on every start, the error of one that is there is dropped.
COLUMNS = [
    # 'house': a table of the queue, on a match server; 'room': a ranked
    # room someone hosted, reported by the members' own machines.
    "ALTER TABLE matches ADD COLUMN mode TEXT NOT NULL DEFAULT 'house'",
    "ALTER TABLE matches ADD COLUMN host_id INTEGER",
    # Room matches: whether the member's machine showed up at the house.
    "ALTER TABLE match_players ADD COLUMN joined INTEGER NOT NULL DEFAULT 0",
]


def path() -> Path:
    return settings.data_dir / "liar.db"


def init() -> None:
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    with connect() as db:
        db.execute("PRAGMA journal_mode=WAL")
        db.executescript(SCHEMA)
        for statement in COLUMNS:
            try:
                db.execute(statement)
            except sqlite3.OperationalError as error:
                if "duplicate column" not in str(error):
                    raise


@contextmanager
def connect() -> Iterator[sqlite3.Connection]:
    db = sqlite3.connect(path(), timeout=10)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys=ON")
    try:
        yield db
        db.commit()
    except BaseException:
        db.rollback()
        raise
    finally:
        db.close()


def now() -> float:
    return time.time()


def dumps(value) -> str:
    return json.dumps(value, separators=(",", ":"))


def loads(text: str | None, default=None):
    if not text:
        return default
    try:
        return json.loads(text)
    except ValueError:
        return default
