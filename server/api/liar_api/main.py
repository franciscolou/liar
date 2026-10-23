"""The house: the HTTP API the game's ranked screens talk to, and the one the
match servers report to (under /internal, each with its match's secret).

Run with `uvicorn liar_api.main:app --host 0.0.0.0 --port 8080`.
"""

from __future__ import annotations

import asyncio
import contextlib
import logging

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from . import accounts, analytics, db, results, rooms
from .config import RANKED_RULES, settings
from .matchmaker import matchmaker

VERSION = 1
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")


@contextlib.asynccontextmanager
async def lifespan(_app: FastAPI):
    db.init()
    task = asyncio.create_task(matchmaker.run())
    yield
    task.cancel()


app = FastAPI(title="LIAR! house", version=str(VERSION), lifespan=lifespan)
if settings.cors:
    app.add_middleware(CORSMiddleware, allow_origins=settings.cors, allow_methods=["*"], allow_headers=["*"])


@app.exception_handler(accounts.Refused)
async def _refused(_request: Request, error: accounts.Refused):
    # What the player reads: the game translates it by the English text.
    return JSONResponse(status_code=400, content={"error": str(error)})


def member(authorization: str = Header(default="")) -> int:
    token = authorization.removeprefix("Bearer ").strip()
    player = accounts.player_of(token)
    if player is None:
        raise HTTPException(status_code=401, detail="Sign in again.")
    return player


class Credentials(BaseModel):
    name: str = Field(max_length=64)
    password: str = Field(max_length=256)


class QueueIn(BaseModel):
    build: int = 0


# --- for the game -------------------------------------------------------------

@app.get("/v1/status")
def status() -> dict:
    return {"ok": True, "version": VERSION, "rules": RANKED_RULES, "min_players": settings.min_players,
            "max_players": settings.max_players, **matchmaker.counts()}


@app.post("/v1/accounts")
def register(body: Credentials) -> dict:
    token, me = accounts.register(body.name, body.password)
    return {"token": token, "me": me}


@app.post("/v1/sessions")
def sign_in(body: Credentials) -> dict:
    token, me = accounts.sign_in(body.name, body.password)
    return {"token": token, "me": me}


@app.delete("/v1/sessions")
def sign_out(authorization: str = Header(default="")) -> dict:
    accounts.sign_out(authorization.removeprefix("Bearer ").strip())
    return {"ok": True}


@app.get("/v1/me")
def me(player: int = Depends(member)) -> dict:
    with db.connect() as conn:
        return {"me": accounts.profile(conn, player), "queue": matchmaker.status(player)}


@app.get("/v1/me/dossier")
def my_dossier(player: int = Depends(member)) -> dict:
    return analytics.dossier(player)


@app.get("/v1/standings")
def standings(limit: int = 50) -> dict:
    return analytics.standings(max(1, min(limit, 200)))


@app.get("/v1/analytics")
def house() -> dict:
    return analytics.house()


@app.post("/v1/queue")
def queue_up(body: QueueIn, player: int = Depends(member)) -> dict:
    with db.connect() as conn:
        me = accounts.profile(conn, player)
    return matchmaker.join(player, me["name"], me["rating"], body.build)


@app.get("/v1/queue")
def queue_status(player: int = Depends(member)) -> dict:
    return matchmaker.status(player)


@app.delete("/v1/queue")
def queue_leave(player: int = Depends(member)) -> dict:
    matchmaker.leave(player)
    return matchmaker.status(player)


# --- ranked rooms (see rooms.py) -------------------------------------------------

class RoomIn(BaseModel):
    build: int = 0
    seats: list[str] = []
    config: dict = {}


@app.post("/v1/rooms")
def room_open(body: RoomIn, player: int = Depends(member)) -> dict:
    return rooms.open_room(player, body.build, body.seats, body.config)


@app.post("/v1/rooms/{match_id}/join")
def room_join(match_id: str, player: int = Depends(member)) -> dict:
    return rooms.join(match_id, player)


@app.post("/v1/rooms/{match_id}/report")
async def room_report(match_id: str, request: Request, player: int = Depends(member)) -> dict:
    body = await request.json()
    if not isinstance(body, dict):
        raise HTTPException(status_code=400, detail="That report is not right.")
    out = await asyncio.to_thread(rooms.report, match_id, player, body)
    analytics.forget()
    return out


@app.get("/v1/rooms/{match_id}")
def room_state(match_id: str, player: int = Depends(member)) -> dict:
    return rooms.state(match_id, player)


# --- for the match servers ------------------------------------------------------

class Started(BaseModel):
    characters: list[str] = []


def _secret(x_match_secret: str = Header(default="")) -> str:
    return x_match_secret


@app.post("/internal/matches/{match_id}/started")
def match_started(match_id: str, body: Started, secret: str = Depends(_secret)) -> dict:
    try:
        results.started(match_id, secret, body.characters)
    except results.Rejected as error:
        raise HTTPException(status_code=403, detail=str(error)) from None
    return {"ok": True}


@app.post("/internal/matches/{match_id}/result")
async def match_result(match_id: str, request: Request, secret: str = Depends(_secret)) -> dict:
    report = await request.json()
    try:
        seats = results.record(match_id, secret, report)
    except results.Rejected as error:
        raise HTTPException(status_code=409, detail=str(error)) from None
    matchmaker.finished(match_id)
    analytics.forget()
    return {"ok": True, "seats": seats}


@app.post("/internal/matches/{match_id}/aborted")
def match_aborted(match_id: str, secret: str = Depends(_secret)) -> dict:
    try:
        results.aborted(match_id, secret)
    except results.Rejected as error:
        raise HTTPException(status_code=403, detail=str(error)) from None
    matchmaker.finished(match_id)
    return {"ok": True}
