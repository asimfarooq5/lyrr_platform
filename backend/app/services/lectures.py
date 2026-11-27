"""Selling and spending single listens.

A book is bought on paper. In the app what is sold is the narration: one listen
at a time, per language. Buying adds a listen; playing spends one. When a
reader has none left the recording stops being playable and any offline copy is
withdrawn — the client was explicit that a finished lecture leaves the account.
"""

from __future__ import annotations

import logging
from typing import Optional

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.book import Book, BookMedia
from app.models.content import LectureCredit

logger = logging.getLogger(__name__)


class NoListenAvailable(Exception):
    """Raised when a reader tries to play with no listens left."""

    def __init__(self, language: str, price: Optional[float]):
        self.language = language
        self.price = price
        super().__init__("No listens left for this recording")


async def narration_languages(db: AsyncSession, book_id: str) -> list[dict]:
    """Every language this book is narrated in, with its duration."""
    rows = (await db.execute(
        select(BookMedia.language, BookMedia.audio_url, BookMedia.duration)
        .where(BookMedia.book_id == book_id)
        .order_by(BookMedia.language)
    )).all()

    seen: dict[str, dict] = {}
    for language, _url, duration in rows:
        key = language or "en"
        entry = seen.setdefault(key, {"language": key, "clips": 0, "seconds": 0})
        entry["clips"] += 1
        entry["seconds"] += duration or 0
    return list(seen.values())


async def credits_for(db: AsyncSession, user_id: str, book_id: str) -> dict[str, int]:
    """How many listens this reader still has, per language."""
    rows = (await db.execute(
        select(LectureCredit.language, LectureCredit.listens_left)
        .where(and_(LectureCredit.user_id == user_id, LectureCredit.book_id == book_id))
    )).all()
    return {language: left for language, left in rows}


async def grant(
    db: AsyncSession,
    user_id: str,
    book_id: str,
    language: str,
    listens: int = 1,
    price: Optional[float] = None,
) -> LectureCredit:
    """Add paid listens for one recording. Caller commits."""
    credit = (await db.execute(
        select(LectureCredit).where(and_(
            LectureCredit.user_id == user_id,
            LectureCredit.book_id == book_id,
            LectureCredit.language == language,
        ))
    )).scalar_one_or_none()

    if credit is None:
        credit = LectureCredit(
            user_id=user_id,
            book_id=book_id,
            language=language,
            listens_left=listens,
            listens_bought=listens,
            last_price=price,
        )
        db.add(credit)
    else:
        credit.listens_left += listens
        credit.listens_bought += listens
        if price is not None:
            credit.last_price = price
    return credit


async def spend(
    db: AsyncSession,
    user_id: str,
    book_id: str,
    language: str,
) -> int:
    """Spend one listen and return how many remain.

    Raises [NoListenAvailable] when the reader has none, which is the signal
    the app uses to offer a purchase instead of playing.
    """
    credit = (await db.execute(
        select(LectureCredit).where(and_(
            LectureCredit.user_id == user_id,
            LectureCredit.book_id == book_id,
            LectureCredit.language == language,
        ))
    )).scalar_one_or_none()

    if credit is None or credit.listens_left <= 0:
        book = (await db.execute(select(Book).where(Book.id == book_id))).scalar_one_or_none()
        raise NoListenAvailable(language, book.lecture_price if book else None)

    credit.listens_left -= 1
    return credit.listens_left


async def audio_for_language(
    db: AsyncSession,
    book_id: str,
    language: str,
    chapter_id: Optional[str] = None,
) -> Optional[BookMedia]:
    """The clip to play: this chapter's, or the book's first in that language."""
    query = select(BookMedia).where(and_(
        BookMedia.book_id == book_id,
        BookMedia.language == language,
    ))
    if chapter_id:
        query = query.where(BookMedia.chapter_id == chapter_id)
    query = query.order_by(BookMedia.chapter_id.is_(None), BookMedia.created_at)
    return (await db.execute(query)).scalars().first()
