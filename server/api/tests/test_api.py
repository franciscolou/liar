"""The house end to end, without a match server: members queue, a table is
dealt, and its result is reported the way scripts/net/match_server.gd does."""

from __future__ import annotations

import importlib
import json
import os
import time

import pytest
from fastapi.testclient import TestClient


@pytest.fixture()
def house(tmp_path, monkeypatch):
    monkeypatch.setenv("LIAR_DATA", str(tmp_path))
    monkeypatch.setenv("LIAR_SERVER_CMD", "")
    monkeypatch.setenv("LIAR_MIN_PLAYERS", "3")
    monkeypatch.setenv("LIAR_MAX_PLAYERS", "4")
    monkeypatch.setenv("LIAR_FILL_AFTER", "1")
    # Settings are read once, on import: read them again for this house.
    from liar_api import config
    importlib.reload(config)
    import liar_api.db, liar_api.logs, liar_api.accounts, liar_api.results, liar_api.rooms, liar_api.analytics, liar_api.matchmaker, liar_api.main
    for module in (liar_api.db, liar_api.logs, liar_api.accounts, liar_api.results, liar_api.rooms, liar_api.analytics,
                   liar_api.matchmaker, liar_api.main):
        importlib.reload(module)
    with TestClient(liar_api.main.app) as client:
        yield client, tmp_path


def _member(client, name):
    r = client.post("/v1/accounts", json={"name": name, "password": "secret123"})
    assert r.status_code == 200, r.text
    return {"Authorization": "Bearer " + r.json()["token"]}


def _until(condition, seconds=6.0):
    end = time.time() + seconds
    while time.time() < end:
        value = condition()
        if value:
            return value
        time.sleep(0.1)
    raise AssertionError("it never happened")


def test_accounts(house):
    client, _ = house
    auth = _member(client, "Fran")
    assert client.post("/v1/accounts", json={"name": "fran", "password": "secret123"}).status_code == 400
    assert client.post("/v1/sessions", json={"name": "FRAN", "password": "nope"}).status_code == 400
    assert client.post("/v1/sessions", json={"name": "FRAN", "password": "secret123"}).status_code == 200
    me = client.get("/v1/me", headers=auth).json()
    assert me["me"]["name"] == "Fran" and me["me"]["rating"] == 1000 and me["queue"]["state"] == "idle"
    assert client.get("/v1/me", headers={"Authorization": "Bearer nope"}).status_code == 401


def test_table_and_result(house):
    client, data = house
    names = ["Ana", "Bia", "Caio"]
    auths = {name: _member(client, name) for name in names}
    for name in names:
        assert client.post("/v1/queue", json={"build": 7}, headers=auths[name]).json()["state"] == "waiting"
    # Another build never sits with them.
    other = _member(client, "Dora")
    client.post("/v1/queue", json={"build": 8}, headers=other)
    seated = {name: _until(lambda n=name: (s := client.get("/v1/queue", headers=auths[n]).json())["state"] == "matched" and s)
              for name in names}
    match = seated["Ana"]["match"]
    assert all(s["match"]["id"] == match["id"] for s in seated.values())
    assert client.get("/v1/queue", headers=other).json()["state"] == "waiting"

    spec = json.loads((data / "matches" / f"{match['id']}.json").read_text())
    assert len(spec["players"]) == 3 and spec["config"]["turn_seconds"] > 0
    secret = {"X-Match-Secret": spec["secret"]}
    assert client.post(f"/internal/matches/{match['id']}/started", json={"characters": ["bard"]},
                       headers={"X-Match-Secret": "wrong"}).status_code == 403
    assert client.post(f"/internal/matches/{match['id']}/started", json={"characters": ["bard", "judge"]}, headers=secret).status_code == 200

    by_name = {p["name"]: seat for seat, p in enumerate(spec["players"])}
    report = {
        "turns": 30, "seconds": 600, "characters": ["bard", "judge", "spy"],
        "players": [
            {"seat": by_name["Ana"], "place": 1, "start_hand": ["bard", "spy"], "stats": {"claims": 4}},
            {"seat": by_name["Bia"], "place": 2, "start_hand": ["judge", "bard"]},
            {"seat": by_name["Caio"], "place": 3, "start_hand": ["spy", "judge"], "eliminated_turn": 12},
        ],
        "claims": [
            {"turn": 1, "seat": by_name["Ana"], "character": "bard", "ability": "bard.swindle", "truthful": True, "doubted": True},
            {"turn": 2, "seat": by_name["Caio"], "character": "judge", "ability": "judge.oath", "truthful": False, "doubted": True, "caught": True},
            {"turn": 3, "seat": by_name["Bia"], "character": "spy", "ability": "spy.sneak_peek", "truthful": False},
        ],
        "doubts": [
            {"turn": 1, "seat": by_name["Bia"], "against": by_name["Ana"], "ability": "bard.swindle", "correct": False},
            {"turn": 2, "seat": by_name["Ana"], "against": by_name["Caio"], "ability": "judge.oath", "correct": True},
        ],
        "purchases": [{"turn": 2, "seat": by_name["Ana"], "item": "shield"}],
        "log": {"format": 1, "events": [{"n": 0, "turn": 0, "type": "game_started", "data": {}}], "snapshots": []},
    }
    r = client.post(f"/internal/matches/{match['id']}/result", json=report, headers=secret)
    assert r.status_code == 200, r.text
    seats = {s["seat"]: s for s in r.json()["seats"]}
    assert seats[by_name["Ana"]]["delta"] > 0 > seats[by_name["Caio"]]["delta"]
    # Reported once only.
    assert client.post(f"/internal/matches/{match['id']}/result", json=report, headers=secret).status_code == 409
    assert client.get("/v1/queue", headers=auths["Ana"]).json()["state"] == "idle"

    board = client.get("/v1/standings").json()
    assert [p["name"] for p in board["players"]] == ["Ana", "Bia", "Caio"]
    assert board["players"][0]["form"] == [1]
    figures = client.get("/v1/analytics").json()
    assert figures["matches"] == 1 and figures["claims"] == 3
    assert figures["bluff_rate"] == pytest.approx(2 / 3, abs=1e-3) and figures["doubt_accuracy"] == 0.5
    bard = next(c for c in figures["characters"] if c["id"] == "bard")
    assert bard["holders"] == 2 and bard["win_rate"] == 0.5
    assert figures["items"][0]["id"] == "shield" and figures["items"][0]["win_rate"] == 1.0
    # The match's file, with the house's own account of it on top.
    kept = json.loads((data / "logs" / f"{match['id']}.json").read_text())
    assert kept["house"]["mode"] == "house" and kept["events"][0]["type"] == "game_started"
    assert {s["name"] for s in kept["house"]["seats"]} == {"Ana", "Bia", "Caio"}
    mine = client.get("/v1/me/dossier", headers=auths["Ana"]).json()
    assert mine["me"]["rank"] == 1 and mine["places"][0] == 1 and len(mine["series"]) == 2
    assert mine["doubt_accuracy"] == 1.0 and mine["recent"][0]["place"] == 1


def test_leaving_the_queue(house):
    client, _ = house
    auth = _member(client, "Solo")
    client.post("/v1/queue", json={"build": 1}, headers=auth)
    assert client.delete("/v1/queue", headers=auth).json()["state"] == "idle"


def _room_report(order, forfeits=(), digest="same", turns=20):
    return {"digest": digest, "report": {
        "turns": turns, "seconds": 300, "characters": ["bard", "judge"], "order": list(order),
        "players": [{"seat": s, "place": 0, "forfeit": s in forfeits, "start_hand": ["bard"]} for s in order],
        "claims": [{"turn": 1, "seat": order[0], "character": "bard", "ability": "bard.swindle", "truthful": False}],
        "doubts": [], "purchases": [],
        "log": {"format": 1, "events": [{"n": 0, "type": "game_started"}], "snapshots": [{"turn": 0}]},
    }}


def test_ranked_room(house):
    client, data = house
    from liar_api.config import RANKED_RULES
    auths = {n: _member(client, n) for n in ["Ana", "Bia", "Caio", "Dora"]}
    seats = ["Ana", "Bia", "Caio"]
    # Only members, by the house's rules, with the host at the table.
    assert client.post("/v1/rooms", json={"build": 3, "seats": ["Ana", "Zed"], "config": RANKED_RULES}, headers=auths["Ana"]).status_code == 400
    assert client.post("/v1/rooms", json={"build": 3, "seats": seats, "config": {**RANKED_RULES, "start_coins": 50}}, headers=auths["Ana"]).status_code == 400
    assert client.post("/v1/rooms", json={"build": 3, "seats": ["Bia", "Caio"], "config": RANKED_RULES}, headers=auths["Ana"]).status_code == 400
    r = client.post("/v1/rooms", json={"build": 3, "seats": seats, "config": RANKED_RULES}, headers=auths["Ana"])
    assert r.status_code == 200, r.text
    match = r.json()["match"]
    assert client.post(f"/v1/rooms/{match}/join", headers=auths["Dora"]).status_code == 400
    assert client.post(f"/v1/rooms/{match}/join", headers=auths["Bia"]).status_code == 200
    # Caio never shows up: Ana and Bia report the same end, Caio's seat is not rated.
    assert client.post(f"/v1/rooms/{match}/report", json=_room_report([1, 0, 2]), headers=auths["Caio"]).status_code == 400
    assert client.post(f"/v1/rooms/{match}/report", json=_room_report([1, 0, 2]), headers=auths["Ana"]).json()["state"] == "playing"
    done = client.post(f"/v1/rooms/{match}/report", json=_room_report([1, 0, 2]), headers=auths["Bia"]).json()
    assert done["state"] == "done"
    places = {s["name"]: s for s in done["seats"]}
    assert set(places) == {"Ana", "Bia"} and places["Bia"]["place"] == 1 and places["Bia"]["delta"] > 0
    assert client.get(f"/v1/rooms/{match}", headers=auths["Ana"]).json()["state"] == "done"
    kept = json.loads((data / "logs" / f"{match}.json").read_text())
    assert kept["house"]["mode"] == "room" and kept["house"]["state"] == "done" and kept["snapshots"] == [{"turn": 0}]
    assert not (data / "reports" / match).exists()
    board = {p["name"]: p for p in client.get("/v1/standings").json()["players"]}
    assert board["Bia"]["matches"] == 1 and "Caio" not in board


def test_ranked_room_disputes(house):
    client, data = house
    from liar_api import rooms
    from liar_api.config import RANKED_RULES
    auths = {n: _member(client, n) for n in ["Ana", "Bia", "Caio"]}
    match = client.post("/v1/rooms", json={"build": 3, "seats": ["Ana", "Bia"], "config": RANKED_RULES}, headers=auths["Ana"]).json()["match"]
    client.post(f"/v1/rooms/{match}/join", headers=auths["Bia"])
    client.post(f"/v1/rooms/{match}/report", json=_room_report([0, 1], digest="a"), headers=auths["Ana"])
    assert client.post(f"/v1/rooms/{match}/report", json=_room_report([1, 0], digest="b"), headers=auths["Bia"]).json()["state"] == "void"
    assert json.loads((data / "logs" / f"{match}.json").read_text())["house"]["why"] == "the reports do not agree"
    # One member left, and only the other reports: settled once its time is up,
    # the one who left a forfeit.
    match = client.post("/v1/rooms", json={"build": 3, "seats": ["Ana", "Bia", "Caio"], "config": RANKED_RULES}, headers=auths["Ana"]).json()["match"]
    for name in ["Bia", "Caio"]:
        client.post(f"/v1/rooms/{match}/join", headers=auths[name])
    client.post(f"/v1/rooms/{match}/report", json=_room_report([2, 0, 1], forfeits=[2]), headers=auths["Ana"])
    client.post(f"/v1/rooms/{match}/report", json=_room_report([2, 0, 1], forfeits=[2]), headers=auths["Bia"])
    assert client.get(f"/v1/rooms/{match}", headers=auths["Ana"]).json()["state"] == "playing"
    rooms.settle(match, force=True)
    seats = {s["name"]: s for s in client.get(f"/v1/rooms/{match}", headers=auths["Caio"]).json()["seats"]}
    assert seats["Caio"]["place"] == 3 and seats["Caio"]["forfeit"] and seats["Ana"]["place"] == 1
