"""What the books say: the house's figures (`house`), one member's file
(`dossier`) and the standings (`standings`). Everything is counted from the
finished matches only, and kept for a minute: nobody needs it to the second.
"""

from __future__ import annotations

import time

from . import accounts, db

CACHE_SECONDS = 60.0
_cache: dict[str, tuple[float, dict]] = {}


def _cached(key: str, build) -> dict:
    hit = _cache.get(key)
    if hit is not None and time.time() - hit[0] < CACHE_SECONDS:
        return hit[1]
    value = build()
    _cache[key] = (time.time(), value)
    return value


def forget() -> None:
    _cache.clear()


def _ratio(part, whole) -> float | None:
    return round(part / whole, 4) if whole else None


def house() -> dict:
    return _cached("house", _house)


def _house() -> dict:
    with db.connect() as conn:
        totals = conn.execute(
            "SELECT COUNT(*) AS n, AVG(turns) AS turns, AVG(seconds) AS seconds FROM matches WHERE state = 'done'").fetchone()
        members = conn.execute("SELECT COUNT(*) FROM players WHERE matches > 0").fetchone()[0]
        n = totals["n"] or 0
        claim = conn.execute(
            "SELECT COUNT(*) AS n, SUM(1 - truthful) AS bluffs, SUM(CASE WHEN truthful = 0 THEN caught ELSE 0 END) AS caught, "
            "SUM(doubted) AS doubted FROM claims c JOIN matches m ON m.id = c.match_id AND m.state = 'done'").fetchone()
        doubt = conn.execute(
            "SELECT COUNT(*) AS n, SUM(correct) AS right FROM doubts d JOIN matches m ON m.id = d.match_id AND m.state = 'done'").fetchone()

        characters = {}
        for row in conn.execute(
                "SELECT j.value AS id, COUNT(*) AS n FROM matches m, json_each(m.characters) j WHERE m.state = 'done' GROUP BY j.value"):
            characters[row["id"]] = {"id": row["id"], "matches": row["n"], "claims": 0, "bluffs": 0, "caught": 0,
                                     "doubted": 0, "holders": 0, "holder_wins": 0}
        for row in conn.execute(
                "SELECT character AS id, COUNT(*) AS n, SUM(1 - truthful) AS bluffs, "
                "SUM(CASE WHEN truthful = 0 THEN caught ELSE 0 END) AS caught, SUM(doubted) AS doubted "
                "FROM claims c JOIN matches m ON m.id = c.match_id AND m.state = 'done' GROUP BY character"):
            entry = characters.setdefault(row["id"], {"id": row["id"], "matches": 0, "claims": 0, "bluffs": 0, "caught": 0,
                                                      "doubted": 0, "holders": 0, "holder_wins": 0})
            entry.update(claims=row["n"], bluffs=row["bluffs"] or 0, caught=row["caught"] or 0, doubted=row["doubted"] or 0)
        for row in conn.execute(
                "SELECT j.value AS id, COUNT(DISTINCT mp.match_id || ':' || mp.seat) AS n, "
                "COUNT(DISTINCT CASE WHEN mp.place = 1 THEN mp.match_id || ':' || mp.seat END) AS wins "
                "FROM match_players mp JOIN matches m ON m.id = mp.match_id AND m.state = 'done', json_each(mp.start_hand) j "
                "GROUP BY j.value"):
            if row["id"] in characters:
                characters[row["id"]].update(holders=row["n"], holder_wins=row["wins"])
        for entry in characters.values():
            entry["pick_rate"] = _ratio(entry["matches"], n)
            entry["bluff_rate"] = _ratio(entry["bluffs"], entry["claims"])
            entry["caught_rate"] = _ratio(entry["caught"], entry["bluffs"])
            entry["win_rate"] = _ratio(entry["holder_wins"], entry["holders"])

        abilities = []
        for row in conn.execute(
                "SELECT ability AS id, character, COUNT(*) AS n, SUM(1 - truthful) AS bluffs, "
                "SUM(CASE WHEN truthful = 0 THEN caught ELSE 0 END) AS caught, SUM(doubted) AS doubted "
                "FROM claims c JOIN matches m ON m.id = c.match_id AND m.state = 'done' "
                "GROUP BY ability ORDER BY n DESC LIMIT 16"):
            abilities.append({"id": row["id"], "character": row["character"], "claims": row["n"],
                              "bluff_rate": _ratio(row["bluffs"] or 0, row["n"]),
                              "doubted_rate": _ratio(row["doubted"] or 0, row["n"]),
                              "caught_rate": _ratio(row["caught"] or 0, row["bluffs"] or 0)})

        items = []
        for row in conn.execute(
                "SELECT p.item AS id, COUNT(*) AS n, COUNT(DISTINCT p.match_id || ':' || p.player_id) AS buyers, "
                "COUNT(DISTINCT CASE WHEN mp.place = 1 THEN p.match_id || ':' || p.player_id END) AS wins "
                "FROM purchases p JOIN matches m ON m.id = p.match_id AND m.state = 'done' "
                "JOIN match_players mp ON mp.match_id = p.match_id AND mp.player_id = p.player_id "
                "GROUP BY p.item ORDER BY n DESC"):
            items.append({"id": row["id"], "bought": row["n"], "buyers": row["buyers"],
                          "win_rate": _ratio(row["wins"], row["buyers"])})

        sizes = [{"players": row["k"], "matches": row["n"], "turns": round(row["turns"] or 0, 1)} for row in conn.execute(
            "SELECT k, COUNT(*) AS n, AVG(turns) AS turns FROM (SELECT m.id, m.turns, COUNT(*) AS k FROM matches m "
            "JOIN match_players mp ON mp.match_id = m.id WHERE m.state = 'done' GROUP BY m.id) GROUP BY k ORDER BY k")]

    claims = claim["n"] or 0
    bluffs = claim["bluffs"] or 0
    return {
        "matches": n,
        "members": members,
        "avg_turns": round(totals["turns"] or 0, 1),
        "avg_minutes": round((totals["seconds"] or 0) / 60.0, 1),
        "claims": claims,
        "bluff_rate": _ratio(bluffs, claims),
        "caught_rate": _ratio(claim["caught"] or 0, bluffs),
        "doubted_rate": _ratio(claim["doubted"] or 0, claims),
        "doubts": doubt["n"] or 0,
        "doubt_accuracy": _ratio(doubt["right"] or 0, doubt["n"] or 0),
        "characters": sorted(characters.values(), key=lambda c: -(c["claims"] + c["matches"])),
        "abilities": abilities,
        "items": items,
        "sizes": sizes,
        "updated": time.time(),
    }


def standings(limit: int = 50) -> dict:
    return _cached(f"standings:{limit}", lambda: _standings(limit))


def _standings(limit: int) -> dict:
    with db.connect() as conn:
        rows = conn.execute(
            "SELECT id, name, rating, peak, matches, wins FROM players WHERE matches > 0 "
            "ORDER BY rating DESC, matches DESC, id LIMIT ?", (limit,)).fetchall()
        # The last few results of each, latest first: for the marks in the ledger.
        out = []
        for rank, row in enumerate(rows, 1):
            form = [r["place"] for r in conn.execute(
                "SELECT mp.place FROM match_players mp JOIN matches m ON m.id = mp.match_id AND m.state = 'done' "
                "WHERE mp.player_id = ? ORDER BY m.ended_at DESC LIMIT 5", (row["id"],))]
            out.append({"rank": rank, "id": row["id"], "name": row["name"], "rating": round(row["rating"]),
                        "peak": round(row["peak"]), "matches": row["matches"], "wins": row["wins"], "form": form})
        total = conn.execute("SELECT COUNT(*) FROM players WHERE matches > 0").fetchone()[0]
    return {"players": out, "members": total, "updated": time.time()}


def dossier(player_id: int) -> dict:
    with db.connect() as conn:
        me = accounts.profile(conn, player_id)
        history = conn.execute(
            "SELECT m.id, m.ended_at, m.turns, mp.place, mp.rating_before, mp.rating_after, mp.start_hand, "
            "(SELECT COUNT(*) FROM match_players o WHERE o.match_id = m.id) AS seats "
            "FROM match_players mp JOIN matches m ON m.id = mp.match_id AND m.state = 'done' "
            "WHERE mp.player_id = ? ORDER BY m.ended_at", (player_id,)).fetchall()
        series = []
        if history:
            series.append(round(history[0]["rating_before"] or 1000))
            series += [round(h["rating_after"] or 1000) for h in history]
        places: dict[int, int] = {}
        for h in history:
            places[h["place"]] = places.get(h["place"], 0) + 1
        claim = conn.execute(
            "SELECT COUNT(*) AS n, SUM(1 - truthful) AS bluffs, SUM(CASE WHEN truthful = 0 THEN caught ELSE 0 END) AS caught, "
            "SUM(doubted) AS doubted FROM claims WHERE player_id = ?", (player_id,)).fetchone()
        doubt = conn.execute("SELECT COUNT(*) AS n, SUM(correct) AS right FROM doubts WHERE player_id = ?", (player_id,)).fetchone()
        against = conn.execute("SELECT COUNT(*) AS n, SUM(correct) AS right FROM doubts WHERE against_id = ?", (player_id,)).fetchone()
        favourites = [{"id": r["character"], "claims": r["n"], "bluff_rate": _ratio(r["bluffs"] or 0, r["n"]),
                       "caught_rate": _ratio(r["caught"] or 0, r["bluffs"] or 0)} for r in conn.execute(
            "SELECT character, COUNT(*) AS n, SUM(1 - truthful) AS bluffs, SUM(CASE WHEN truthful = 0 THEN caught ELSE 0 END) AS caught "
            "FROM claims WHERE player_id = ? GROUP BY character ORDER BY n DESC LIMIT 5", (player_id,))]
        items = [{"id": r["item"], "bought": r["n"]} for r in conn.execute(
            "SELECT item, COUNT(*) AS n FROM purchases WHERE player_id = ? GROUP BY item ORDER BY n DESC LIMIT 4", (player_id,))]
    bluffs = claim["bluffs"] or 0
    recent = [{"id": h["id"], "ended_at": h["ended_at"], "place": h["place"], "seats": h["seats"], "turns": h["turns"],
               "delta": round(h["rating_after"] or 0) - round(h["rating_before"] or 0)} for h in reversed(history[-8:])]
    return {
        "me": me,
        "series": series[-41:],
        "places": [places.get(p, 0) for p in range(1, 9)],
        "claims": claim["n"] or 0,
        "bluffs": bluffs,
        "bluff_rate": _ratio(bluffs, claim["n"] or 0),
        "caught_rate": _ratio(claim["caught"] or 0, bluffs),
        "doubted_rate": _ratio(claim["doubted"] or 0, claim["n"] or 0),
        "doubts": doubt["n"] or 0,
        "doubt_accuracy": _ratio(doubt["right"] or 0, doubt["n"] or 0),
        "doubted_by_others": against["n"] or 0,
        "survived_doubts": (against["n"] or 0) - (against["right"] or 0),
        "favourites": favourites,
        "items": items,
        "recent": recent,
    }
