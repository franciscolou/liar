"""Members of the house: a name and a password, and the tokens the game keeps
instead of the password (only their hashes are stored)."""

from __future__ import annotations

import hashlib
import hmac
import re
import secrets
import sqlite3

from . import db

# The same length a seat's name has in the game (Room.NAME_LENGTH).
NAME_LENGTH = 12
NAME = re.compile(r"^[\w][\w .'-]*$", re.UNICODE)
PASSWORD_MIN = 6
ITERATIONS = 200_000


class Refused(Exception):
    """What the player is told, in English (the game translates it)."""


def clean_name(text: str) -> str:
    return " ".join(str(text).split())[:NAME_LENGTH]


def _hash_password(password: str, salt: str) -> str:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), ITERATIONS).hex()


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _issue(conn: sqlite3.Connection, player_id: int) -> str:
    token = secrets.token_urlsafe(32)
    t = db.now()
    conn.execute("INSERT INTO tokens (token_hash, player_id, created_at, last_used) VALUES (?, ?, ?, ?)",
                 (token_hash(token), player_id, t, t))
    return token


def register(name: str, password: str) -> tuple[str, dict]:
    name = clean_name(name)
    if not name or not NAME.match(name):
        raise Refused("Pick a name of letters and numbers.")
    if len(password) < PASSWORD_MIN:
        raise Refused("The password needs at least 6 characters.")
    salt = secrets.token_hex(16)
    t = db.now()
    with db.connect() as conn:
        try:
            cur = conn.execute(
                "INSERT INTO players (name, pass_hash, salt, created_at, last_seen) VALUES (?, ?, ?, ?, ?)",
                (name, _hash_password(password, salt), salt, t, t))
        except sqlite3.IntegrityError:
            raise Refused("That name is already a member of the house.") from None
        token = _issue(conn, cur.lastrowid)
        return token, profile(conn, cur.lastrowid)


def sign_in(name: str, password: str) -> tuple[str, dict]:
    with db.connect() as conn:
        row = conn.execute("SELECT id, pass_hash, salt FROM players WHERE name = ?", (clean_name(name),)).fetchone()
        if row is None or not hmac.compare_digest(row["pass_hash"], _hash_password(password, row["salt"])):
            raise Refused("Wrong name or password.")
        token = _issue(conn, row["id"])
        return token, profile(conn, row["id"])


def sign_out(token: str) -> None:
    with db.connect() as conn:
        conn.execute("DELETE FROM tokens WHERE token_hash = ?", (token_hash(token),))


def player_of(token: str) -> int | None:
    """The member a token belongs to, or None."""
    if not token:
        return None
    with db.connect() as conn:
        row = conn.execute("SELECT player_id FROM tokens WHERE token_hash = ?", (token_hash(token),)).fetchone()
        if row is None:
            return None
        t = db.now()
        conn.execute("UPDATE tokens SET last_used = ? WHERE token_hash = ?", (t, token_hash(token)))
        conn.execute("UPDATE players SET last_seen = ? WHERE id = ?", (t, row["player_id"]))
        return row["player_id"]


def profile(conn: sqlite3.Connection, player_id: int) -> dict:
    row = conn.execute("SELECT id, name, rating, peak, matches, wins FROM players WHERE id = ?", (player_id,)).fetchone()
    if row is None:
        return {}
    rank = None
    if row["matches"] > 0:
        rank = conn.execute("SELECT COUNT(*) + 1 FROM players WHERE matches > 0 AND rating > ?",
                            (row["rating"],)).fetchone()[0]
    return {"id": row["id"], "name": row["name"], "rating": round(row["rating"]), "peak": round(row["peak"]),
            "matches": row["matches"], "wins": row["wins"], "rank": rank}
