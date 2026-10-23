"""What a match server reports, written into the books: the places, the new
ratings, and the claims, doubts and purchases the analytics are made of."""

from __future__ import annotations

import hashlib
import hmac

from . import db, logs, rating


class Rejected(Exception):
    pass


def check_secret(conn, match_id: str, secret: str) -> dict:
    row = conn.execute("SELECT * FROM matches WHERE id = ?", (match_id,)).fetchone()
    if row is None or not hmac.compare_digest(row["secret_hash"], hashlib.sha256(secret.encode()).hexdigest()):
        raise Rejected("unknown match or wrong secret")
    return dict(row)


def started(match_id: str, secret: str, characters: list[str]) -> None:
    with db.connect() as conn:
        match = check_secret(conn, match_id, secret)
        if match["state"] == "starting":
            conn.execute("UPDATE matches SET state = 'playing', started_at = ?, characters = ? WHERE id = ?",
                         (db.now(), db.dumps(characters), match_id))


def aborted(match_id: str, secret: str) -> None:
    with db.connect() as conn:
        check_secret(conn, match_id, secret)
        conn.execute("UPDATE matches SET state = 'aborted', ended_at = ? WHERE id = ? AND state IN ('starting', 'playing')",
                     (db.now(), match_id))


def record(match_id: str, secret: str, report: dict) -> list[dict]:
    """A match server's report: writes the result down and returns, per seat,
    the rating change."""
    with db.connect() as conn:
        match = check_secret(conn, match_id, secret)
        if match["state"] not in ("starting", "playing"):
            raise Rejected(f"the match is {match['state']} already")
        seats = {row["seat"]: dict(row) for row in conn.execute("SELECT * FROM match_players WHERE match_id = ?", (match_id,))}
        reported = {int(p["seat"]): p for p in report.get("players", [])}
        if set(reported) != set(seats):
            raise Rejected("the seats reported are not the seats of the match")
        places = {seat: int(reported[seat].get("place", len(seats))) for seat in seats}
        forfeits = {seat for seat in seats if reported[seat].get("forfeit")}
        out = write(conn, match_id, report, seats, places, forfeits)
    save_log(match_id, report, "house", out)
    return out


def places_of(order: list, seats, forfeits: set) -> dict[int, int]:
    """The places at a table, from the order the engine has the seats in (the
    winner first, then whoever went out last): a seat left to a bot comes
    after all the others, tied with any other such seat. A seat missing from
    the order comes last too."""
    played = [s for s in order if s in seats and s not in forfeits]
    out = {s: i + 1 for i, s in enumerate(played)}
    for s in seats:
        out.setdefault(s, len(played) + 1)
    return out


def write(conn, match_id: str, report: dict, seats: dict, places: dict, forfeits: set) -> list[dict]:
    """Writes the result of `match_id` down for `seats` ({seat: match_players
    row}, the ones rated): the new ratings, the places, and the claims, doubts
    and purchases the analytics are made of."""
    reported = {int(p["seat"]): p for p in report.get("players", []) if "seat" in p}
    accounts = {seat: s["player_id"] for seat, s in seats.items()}
    entries = []
    for seat, s in seats.items():
        player = conn.execute("SELECT rating, matches FROM players WHERE id = ?", (s["player_id"],)).fetchone()
        entries.append({"id": s["player_id"], "rating": player["rating"], "matches": player["matches"],
                        "place": int(places.get(seat, len(seats)))})
    changes = rating.table(entries)
    out = []
    winner = None
    t = db.now()
    for entry in entries:
        seat = next(k for k, v in accounts.items() if v == entry["id"])
        p = reported.get(seat, {})
        after = entry["rating"] + changes[entry["id"]]
        won = entry["place"] == 1
        if won:
            winner = entry["id"]
        conn.execute("UPDATE players SET rating = ?, peak = MAX(peak, ?), matches = matches + 1, wins = wins + ? WHERE id = ?",
                     (after, after, 1 if won else 0, entry["id"]))
        conn.execute(
            "UPDATE match_players SET place = ?, forfeit = ?, eliminated_turn = ?, rating_before = ?, rating_after = ?, "
            "start_hand = ?, stats = ? WHERE match_id = ? AND seat = ?",
            (entry["place"], 1 if seat in forfeits else 0, int(p.get("eliminated_turn", -1)), entry["rating"], after,
             db.dumps([str(c) for c in p.get("start_hand", [])]), db.dumps(p.get("stats", {})), match_id, seat))
        out.append({"seat": seat, "account": entry["id"], "name": seats[seat]["name"], "place": entry["place"],
                    "forfeit": seat in forfeits, "before": round(entry["rating"]), "after": round(after),
                    "delta": round(after) - round(entry["rating"])})
    for c in report.get("claims", []):
        if int(c.get("seat", -1)) not in accounts:
            continue
        conn.execute("INSERT INTO claims VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                     (match_id, int(c.get("turn", 0)), accounts[int(c["seat"])], str(c.get("character", "")),
                      str(c.get("ability", "")), 1 if c.get("truthful") else 0, 1 if c.get("doubted") else 0,
                      1 if c.get("caught") else 0, 1 if c.get("reaction") else 0))
    for d in report.get("doubts", []):
        if int(d.get("seat", -1)) not in accounts or int(d.get("against", -1)) not in accounts:
            continue
        conn.execute("INSERT INTO doubts VALUES (?, ?, ?, ?, ?, ?)",
                     (match_id, int(d.get("turn", 0)), accounts[int(d["seat"])], accounts[int(d["against"])],
                      str(d.get("ability", "")), 1 if d.get("correct") else 0))
    for b in report.get("purchases", []):
        if int(b.get("seat", -1)) not in accounts:
            continue
        conn.execute("INSERT INTO purchases VALUES (?, ?, ?, ?)",
                     (match_id, int(b.get("turn", 0)), accounts[int(b["seat"])], str(b.get("item", ""))))
    conn.execute(
        "UPDATE matches SET state = 'done', ended_at = ?, turns = ?, seconds = ?, winner_id = ?, "
        "characters = CASE WHEN ? = '[]' THEN characters ELSE ? END, started_at = COALESCE(started_at, ?) WHERE id = ?",
        (t, int(report.get("turns", 0)), float(report.get("seconds", 0)), winner,
         db.dumps(report.get("characters", [])), db.dumps(report.get("characters", [])), t, match_id))
    return sorted(out, key=lambda o: o["seat"])


def save_log(match_id: str, report: dict, mode: str, seats: list[dict], state: str = "done", why: str = "") -> None:
    """The match's file (logs.py), with what the house made of it on top."""
    house = {"mode": mode, "state": state, "build": report.get("build", 0), "seats": seats,
             "recorded_at": db.now(), "summary": {k: report.get(k) for k in ("turns", "seconds", "characters", "order")}}
    if why:
        house["why"] = why
    logs.save(match_id, report.get("log") or {}, house)
