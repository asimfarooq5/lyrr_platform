"""
Dictionary lookup - Kindle-style tap-to-define.

Proxies a free public dictionary API server-side so the mobile app has one
simple authenticated endpoint, and so responses can be cached in-process to
avoid hammering the upstream provider for common words.
"""

from __future__ import annotations

import logging
import re
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.v1.endpoints.auth import get_current_active_user
from app.models.user import User

router = APIRouter()
logger = logging.getLogger(__name__)

# Small in-process cache: {"en:word": DefinitionResponse}. Definitions never
# change, so entries live for the process lifetime.
_cache: dict = {}

_WORD_RE = re.compile(r"^[A-Za-zÀ-ÿ'-]{1,64}$")

# Free-dictionary API only publishes a handful of languages; others fail
# gracefully with "not available" rather than a broken lookup.
_SUPPORTED_LANGS = {"en", "es", "fr", "de", "it", "pt", "ar"}


class Meaning(BaseModel):
    part_of_speech: str
    definitions: list[str]


class DefinitionResponse(BaseModel):
    word: str
    phonetic: Optional[str] = None
    meanings: list[Meaning]


@router.get("/{word}", response_model=DefinitionResponse)
async def define_word(
    word: str,
    lang: str = "en",
    current_user: User = Depends(get_current_active_user),
):
    """Look up a word's definition (FRS-adjacent: Kindle-style dictionary)."""
    word = word.strip().lower()
    if not _WORD_RE.match(word):
        raise HTTPException(status_code=400, detail="Invalid word")

    lang = (lang or "en").lower()
    if lang not in _SUPPORTED_LANGS:
        raise HTTPException(status_code=404, detail=f"Dictionary not available for '{lang}'")

    cache_key = f"{lang}:{word}"
    if cache_key in _cache:
        return _cache[cache_key]

    import httpx

    url = f"https://api.dictionaryapi.dev/api/v2/entries/{lang}/{word}"
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(url)
    except httpx.HTTPError as exc:
        logger.warning("Dictionary lookup failed for %s: %s", word, exc)
        raise HTTPException(status_code=502, detail="Dictionary service unavailable")

    if resp.status_code == 404:
        raise HTTPException(status_code=404, detail=f"No definition found for '{word}'")
    if resp.status_code != 200:
        raise HTTPException(status_code=502, detail="Dictionary service error")

    entries = resp.json()
    entry = entries[0] if entries else {}
    phonetic = entry.get("phonetic") or next(
        (p.get("text") for p in entry.get("phonetics", []) if p.get("text")), None
    )
    meanings = [
        Meaning(
            part_of_speech=m.get("partOfSpeech", ""),
            definitions=[d.get("definition", "") for d in m.get("definitions", [])[:3]],
        )
        for m in entry.get("meanings", [])[:3]
    ]

    result = DefinitionResponse(word=word, phonetic=phonetic, meanings=meanings)
    _cache[cache_key] = result
    return result
