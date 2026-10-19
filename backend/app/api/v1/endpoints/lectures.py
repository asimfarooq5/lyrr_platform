"""Buying and playing narration.

The app sells listening, not books. These routes answer the three questions the
reader has: which recordings exist for this book, how many listens do I have
left, and how do I buy one.
"""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import create_media_token
from app.models.book import Book
from app.models.user import User
from app.api.v1.endpoints.auth import get_current_active_user
from app.services import lectures as lecture_service
from app.services import payments as payment_service

router = APIRouter()


class PurchaseListenRequest(BaseModel):
    language: str = "en"
    method: str = "orange_money"
    phone: Optional[str] = None


class StartListenRequest(BaseModel):
    language: str = "en"
    chapter_id: Optional[str] = None


@router.get("/{book_id}/lectures")
async def list_lectures(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """The recordings available for this book, the price, and what I hold."""
    book = (await db.execute(select(Book).where(Book.id == book_id))).scalar_one_or_none()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")

    languages = await lecture_service.narration_languages(db, book_id)
    credits = await lecture_service.credits_for(db, current_user.id, book_id)

    return {
        "book_id": book_id,
        "price_per_listen": book.lecture_price,
        "recordings": [
            {
                **entry,
                "listens_left": credits.get(entry["language"], 0),
                "purchasable": book.lecture_price is not None,
            }
            for entry in languages
        ],
    }


@router.post("/{book_id}/lectures/purchase", status_code=status.HTTP_201_CREATED)
async def purchase_listen(
    book_id: str,
    data: PurchaseListenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Buy one listen of one recording."""
    book = (await db.execute(select(Book).where(Book.id == book_id))).scalar_one_or_none()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    if not book.lecture_price:
        raise HTTPException(status_code=400, detail="This book is not sold as a listen")

    languages = {e["language"] for e in await lecture_service.narration_languages(db, book_id)}
    if data.language not in languages:
        raise HTTPException(status_code=400, detail="No narration in that language")

    try:
        payment = await payment_service.initiate_payment(
            db,
            user_id=current_user.id,
            method=data.method,
            item_type="lecture",
            book_id=book_id,
            phone=data.phone,
        )
    except payment_service.PaymentError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    # Which recording the purchase is for; read back when it settles.
    payment.payment_metadata = {
        **(payment.payment_metadata or {}),
        "language": data.language,
        "kind": "lecture",
    }
    await db.commit()
    await db.refresh(payment)
    return payment


@router.post("/{book_id}/lectures/start")
async def start_listen(
    book_id: str,
    data: StartListenRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Spend one listen and hand back the clip to play.

    The reader is told how many listens remain so the app can show it, and so it
    knows to withdraw the offline copy once the last one is spent.
    """
    try:
        remaining = await lecture_service.spend(db, current_user.id, book_id, data.language)
    except lecture_service.NoListenAvailable as exc:
        await db.rollback()
        raise HTTPException(
            status_code=402,
            detail={
                "message": "No listens left for this recording",
                "language": exc.language,
                "price": exc.price,
                "needs_purchase": True,
            },
        )

    media = await lecture_service.audio_for_language(
        db, book_id, data.language, data.chapter_id
    )
    if media is None:
        await db.rollback()
        raise HTTPException(status_code=404, detail="No narration in that language")

    await db.commit()

    token = create_media_token(book_id, current_user.id)
    separator = "&" if "?" in media.audio_url else "?"
    return {
        "audio_url": f"{media.audio_url}{separator}token={token}",
        "language": data.language,
        "listens_left": remaining,
        # When this hits zero the app must delete its downloaded copy.
        "withdraw_download": remaining <= 0,
    }
