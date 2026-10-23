"""The house's files: one JSON per match played, with everything that happened
in it (scripts/net/match_log.gd writes it; server/LOGS.md has the format), in
`LIAR_DATA/logs/<match id>.json`. They are not in the database: they are for
whatever questions are asked of them later."""

from __future__ import annotations

import json
import os
from pathlib import Path

from .config import settings


def folder() -> Path:
    return settings.data_dir / "logs"


def path(match_id: str) -> Path:
    return folder() / f"{match_id}.json"


def save(match_id: str, log: dict, house: dict) -> Path | None:
    """Writes the log of `match_id`, with what the house made of the match
    (`house`: mode, seats with accounts and ratings) at the top of it."""
    if not isinstance(log, dict) or not log:
        return None
    folder().mkdir(parents=True, exist_ok=True)
    out = {"match": match_id, "house": house, **log}
    target = path(match_id)
    temporary = target.with_suffix(".tmp")
    temporary.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    os.replace(temporary, target)
    return target
