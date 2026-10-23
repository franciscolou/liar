"""Ratings for a table of many: every pair at the table is an Elo game.

Whoever went out later beat whoever went out earlier; the winner beat
everybody. Each player's change is the sum over the others, scaled so that a
table of five moves a rating about as much as a game between two would. The
first matches of a player count more (`PROVISIONAL`), to find their level
sooner.
"""

from __future__ import annotations

START = 1000.0
K = 32.0
K_PROVISIONAL = 48.0
PROVISIONAL = 10
FLOOR = 100.0


def expected(mine: float, theirs: float) -> float:
    return 1.0 / (1.0 + 10.0 ** ((theirs - mine) / 400.0))


def table(entries: list[dict]) -> dict[int, float]:
    """`entries`: [{id, rating, place, matches}], place 1 the winner. Ties
    (two forfeits) share a place. Returns id -> change."""
    n = len(entries)
    if n < 2:
        return {e["id"]: 0.0 for e in entries}
    out: dict[int, float] = {}
    for me in entries:
        score = 0.0
        for other in entries:
            if other is me:
                continue
            if me["place"] < other["place"]:
                won = 1.0
            elif me["place"] > other["place"]:
                won = 0.0
            else:
                won = 0.5
            score += won - expected(me["rating"], other["rating"])
        k = K_PROVISIONAL if me.get("matches", 0) < PROVISIONAL else K
        change = k * score / (n - 1)
        # Nobody falls through the floor of the ledger.
        out[me["id"]] = max(change, FLOOR - me["rating"])
    return out
