"""
Media endpoints - book-scoped audio streaming and DRM verification.

The low-level byte serving lives in ``/media/audio/{filename}`` (media_stream
router). This module exposes the book-scoped API the mobile client prefers:
ask for a book, not a filename.
"""

import os

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import verify_drm_key
from app.services import media as media_service

router = APIRouter()


async def _media_identity(request: Request, db: AsyncSession = Depends(get_db)):
    """FastAPI dependency wrapper around the shared identity resolver."""
    return await media_service.resolve_media_identity(request, db)


@router.get("/stream/{book_id}")
async def stream_book_audio(
    book_id: str,
    request: Request,
    quality: str = "high",
    db: AsyncSession = Depends(get_db),
    identity=Depends(_media_identity),
):
    """Stream a book's audio track with Range support for seeking.

    Content protection (FRS §14): only callers with a purchase/subscription
    (or admins, or open-access deployments) receive bytes.
    """
    media = await media_service.find_media_for_book(db, book_id)
    if media is None or not media.audio_url:
        raise HTTPException(status_code=404, detail="No audio available for this book")

    media_service.verify_media_token_scope(request, book_id)

    if not await media_service.has_book_access(identity, book_id, db):
        raise HTTPException(
            status_code=403,
            detail="You do not have access to this content. "
                   "Purchase the book or start a subscription.",
        )

    filename = media.audio_url.split("/")[-1]
    filepath = media_service.safe_path(media_service.AUDIO_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Audio file missing")

    return media_service.file_response(filepath, filename, request.headers.get("range"))


@router.post("/drm/verify")
async def verify_drm(
    request: Request,
    db: AsyncSession = Depends(get_db),
    identity=Depends(_media_identity),
):
    """Verify a DRM license key for a book.

    Body: ``{"book_id": str, "device_id": str, "license_key": str}``.
    Returns ``{"valid": bool}``. Key issuance happens at
    ``POST /api/v1/books/{book_id}/license``.
    """
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON body")

    book_id = body.get("book_id")
    device_id = body.get("device_id")
    license_key = body.get("license_key")
    if not book_id or not device_id or not license_key:
        raise HTTPException(
            status_code=400,
            detail="book_id, device_id and license_key are required",
        )

    if identity is media_service.OPEN_ACCESS:
        raise HTTPException(status_code=401, detail="Authentication required")

    if identity == media_service.ADMIN:
        return {"valid": True}

    if not await media_service.has_book_access(identity, book_id, db):
        raise HTTPException(status_code=403, detail="Access denied for this book")

    valid = verify_drm_key(license_key, book_id, identity.id, device_id)
    return {"valid": valid}
