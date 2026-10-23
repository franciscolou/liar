"""Fills a house with made-up members and matches, for looking at the ranked
screens of the game before any real match has been played there.

    LIAR_DATA=./demo python seed_demo.py [matches] [--me NAME]

Every member's password is "demo1234". With --me, that member exists too and
sits at a good share of the tables, so that their file has something in it.
Never point it at the books of a real house.
"""

from __future__ import annotations

import argparse
import random
import secrets
import hashlib

from liar_api import accounts, db, results

CHARACTERS = {
    "assassin": ["assassin.blood_count", "assassin.streak_thirst"],
    "bard": ["bard.swindle", "bard.silver_tongue"],
    "bartender": ["bartender.mickey_finn", "bartender.last_call"],
    "bomber": ["bomber.time_bomb", "bomber.demolition"],
    "clown": ["clown.bang", "clown.laughter"],
    "doctor": ["doctor.patch_up", "doctor.antidote"],
    "duelist": ["duelist.dilemma", "duelist.berserk"],
    "entity": ["entity.entropy", "entity.materialize"],
    "gambler": ["gambler.double_down", "gambler.side_bet"],
    "gravedigger": ["gravedigger.exhume", "gravedigger.last_rites"],
    "heir": ["heir.sold_out", "heir.party"],
    "impostor": ["impostor.cover_story", "impostor.perfect_disguise"],
    "judge": ["judge.under_oath", "judge.contempt"],
    "magician": ["magician.hat_trick", "magician.counterfeit"],
    "mercenary": ["mercenary.bounty", "mercenary.collateral"],
    "mythomaniac": ["mythomaniac.tall_tale", "mythomaniac.cash_out"],
    "necromancer": ["necromancer.retaliation", "necromancer.drain"],
    "painter": ["painter.all_is_color", "painter.monochrome"],
    "sheriff": ["sheriff.shakedown", "sheriff.confiscate"],
    "spy": ["spy.sneak_peek", "spy.untraceable"],
    "vagabond": ["vagabond.street_bargain", "vagabond.on_the_cuff"],
    "voodooist": ["voodooist.hex", "voodooist.puppet_strings"],
}
ITEMS = ["death", "fresh_card", "mirror", "money_bag", "potion", "roulette", "shield", "silencer", "soul_swap"]
NAMES = ["Rosalind", "Hank", "Duchess", "Silas", "Marlowe", "Juniper", "Cassius", "Ottoline", "Waylon", "Bram",
         "Clementine", "Ezra", "Florence", "Gideon", "Hattie", "Ignatius", "Josephine", "Lazarus", "Mabel", "Nash",
         "Opal", "Percival", "Quincy", "Ruby", "Thaddeus", "Vera", "Wilhelmina", "Zeke"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("matches", type=int, nargs="?", default=160)
    parser.add_argument("--me", default="")
    args = parser.parse_args()
    db.init()
    rng = random.Random(7)
    # Each member has a way of playing: how often they bluff and how sharp they are.
    members = {}
    for name in NAMES + ([args.me] if args.me else []):
        try:
            accounts.register(name, "demo1234")
        except accounts.Refused:
            pass
        with db.connect() as conn:
            pid = conn.execute("SELECT id FROM players WHERE name = ?", (name,)).fetchone()[0]
        members[pid] = {"name": name, "skill": rng.gauss(0, 1), "bluff": rng.uniform(0.15, 0.6), "eye": rng.uniform(0.3, 0.75)}
    me = next((pid for pid, m in members.items() if m["name"] == args.me), None)
    t0 = db.now() - args.matches * 1800
    for n in range(args.matches):
        size = rng.choice([3, 4, 4, 5, 5, 5])
        pool = [p for p in members if p != me]
        seated = rng.sample(pool, size - (1 if me and rng.random() < 0.35 else 0))
        if len(seated) < size:
            seated.append(me)
        rng.shuffle(seated)
        cast = rng.sample(sorted(CHARACTERS), 5)
        match_id = "demo" + secrets.token_hex(5)
        secret = secrets.token_hex(8)
        with db.connect() as conn:
            conn.execute("INSERT INTO matches (id, state, port, secret_hash, characters, created_at, started_at) VALUES (?, 'playing', 0, ?, ?, ?, ?)",
                         (match_id, hashlib.sha256(secret.encode()).hexdigest(), db.dumps(cast), t0 + n * 1800, t0 + n * 1800))
            for seat, pid in enumerate(seated):
                conn.execute("INSERT INTO match_players (match_id, player_id, seat, name) VALUES (?, ?, ?, ?)",
                             (match_id, pid, seat, members[pid]["name"]))
        hands = {seat: rng.sample(cast, 2) for seat in range(size)}
        # Strength this match: skill, luck, and a little from the hand dealt.
        strength = {seat: members[pid]["skill"] + rng.gauss(0, 1.1) + (0.4 if "assassin" in hands[seat] else 0)
                    + (0.25 if "judge" in hands[seat] else 0) - (0.2 if "clown" in hands[seat] else 0)
                    for seat, pid in enumerate(seated)}
        order = sorted(range(size), key=lambda s: -strength[s])
        turns = rng.randint(18, 60)
        claims, doubts, buys = [], [], []
        for turn in range(1, turns + 1):
            seat = (turn - 1) % size
            m = members[seated[seat]]
            character = rng.choice(cast)
            truthful = character in hands[seat] or rng.random() > m["bluff"]
            doubter = rng.choice([s for s in range(size) if s != seat])
            doubted = rng.random() < (0.45 if not truthful else 0.2) * (members[seated[doubter]]["eye"] + 0.3)
            caught = doubted and not truthful
            claims.append({"turn": turn, "seat": seat, "character": character, "ability": rng.choice(CHARACTERS[character]),
                           "truthful": truthful, "doubted": doubted, "caught": caught, "reaction": rng.random() < 0.2})
            if doubted:
                doubts.append({"turn": turn, "seat": doubter, "against": seat, "ability": claims[-1]["ability"], "correct": caught})
            if rng.random() < 0.3:
                buys.append({"turn": turn, "seat": seat, "item": rng.choice(ITEMS)})
        players = []
        for place, seat in enumerate(order, 1):
            players.append({"seat": seat, "place": place, "start_hand": hands[seat],
                            "eliminated_turn": -1 if place == 1 else turns - (place - 1) * rng.randint(2, 6)})
        report = {"turns": turns, "seconds": turns * rng.uniform(18, 32), "characters": cast,
                  "players": players, "claims": claims, "doubts": doubts, "purchases": buys}
        results.record(match_id, secret, report)
        with db.connect() as conn:
            conn.execute("UPDATE matches SET ended_at = ? WHERE id = ?", (t0 + n * 1800 + report["seconds"], match_id))
    print(f"{args.matches} matches among {len(members)} members in {db.path()}")


if __name__ == "__main__":
    main()
