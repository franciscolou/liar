"""Reads the file of a match (LIAR_DATA/logs/<id>.json, see server/LOGS.md).

    python match_log.py logs/<id>.json                 the match in short
    python match_log.py logs/<id>.json --turn 12       the table as turn 12 began, and what happened in it
    python match_log.py logs/<id>.json --type claim_declared
                                                       every event of a type
    python match_log.py logs/            --summary     one line per match in a folder

It is only a start: the files are plain JSON, for jq, pandas or anything else.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def names(log: dict) -> dict[int, str]:
    return {p["seat"]: p["name"] for p in log.get("players", [])}


def state_at(log: dict, turn: int) -> dict | None:
    """The snapshot taken as `turn` began (turn 0: as the match was dealt)."""
    found = None
    for snap in log.get("snapshots", []):
        if snap["turn"] <= turn:
            found = snap
    return found


def describe(event: dict, who: dict[int, str]) -> str:
    d = event.get("data", {})
    name = lambda seat: who.get(seat, "-") if isinstance(seat, int) else "-"
    t = event["type"]
    play = d.get("play") if isinstance(d.get("play"), dict) and "source" in d.get("play", {}) else None
    if t == "claim_declared" and play:
        lie = "" if play["truthful"] else "  (BLUFF)"
        aim = f" on {name(play['target'])}" if play.get("target") is not None else ""
        return f"{name(play['actor'])} claims {play['source']}{aim}{lie}"
    if t == "doubt_revealed":
        return f"{name(d['doubter'])} called LIAR! on {name(play['actor'])}: " + ("it was the truth" if d["truthful"] else "caught a lie")
    if t == "player_eliminated":
        return f"{name(d['player'])} is out" + (f", by {name(d['killer'])}" if d.get("killer") is not None else "")
    if t in ("item_bought", "item_used", "item_broken", "item_gained", "item_discarded", "item_sold"):
        return f"{name(d.get('player'))} {t.split('_')[1]} {d['item']['item'] if isinstance(d.get('item'), dict) else d.get('item')}"
    if t == "coins":
        return f"{name(d['player'])} {d['delta']:+d} coins ({d.get('reason')})"
    if t in ("morale_lost", "morale_gained"):
        return f"{name(d.get('target', d.get('player')))} {'-' if t == 'morale_lost' else '+'}{d['amount']} Morale"
    return t


def summary(log: dict) -> str:
    who = names(log)
    house = log.get("house", {})
    winner = who.get(log.get("winner"), "nobody")
    seats = ", ".join(f"{s['name']} {s['place']}º {s['delta']:+d}" for s in house.get("seats", []))
    return f"{log.get('match')}  {house.get('mode')}/{house.get('state')}  {log.get('turns')} turns  {winner} won  [{seats}]"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--turn", type=int)
    parser.add_argument("--type")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()
    if args.path.is_dir():
        for file in sorted(args.path.glob("*.json")):
            print(summary(load(file)))
        return
    log = load(args.path)
    who = names(log)
    if args.turn is not None:
        print(json.dumps(state_at(log, args.turn), indent=1, ensure_ascii=False))
        for event in log["events"]:
            if event["turn"] == args.turn:
                print(f"  #{event['n']:>4}  {describe(event, who)}")
        return
    if args.type:
        for event in log["events"]:
            if event["type"] == args.type:
                print(f"turn {event['turn']:>3}  #{event['n']:>4}  {describe(event, who)}")
        return
    print(summary(log))
    for event in log["events"]:
        if event["type"] in ("claim_declared", "doubt_revealed", "player_eliminated", "item_bought", "item_used"):
            print(f"turn {event['turn']:>3}  {describe(event, who)}")


if __name__ == "__main__":
    sys.exit(main())
