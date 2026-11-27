"""
Media streaming endpoints - serves uploaded audio and cover images.

All entitlement logic and byte-serving lives in ``app.services.media``; this
module only wires HTTP concerns (routing, dependency injection).
"""

import os

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.services import media as media_service

router = APIRouter()


async def _media_identity(request: Request, db: AsyncSession = Depends(get_db)):
    """FastAPI dependency wrapper around the shared identity resolver."""
    return await media_service.resolve_media_identity(request, db)


@router.get("/audio/{filename}")
async def stream_audio(
    filename: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
    identity=Depends(_media_identity),
):
    """Stream an audio file with Range support for seeking.

    Content protection (FRS §14): a book's audio is only served to callers who
    hold a license (purchase or active subscription), or to admins.
    """
    media = await media_service.find_media_by_filename(db, filename)
    if media is None:
        raise HTTPException(status_code=404, detail="Audio not found")

    # A URL-borne media token may only fetch the book it was minted for.
    media_service.verify_media_token_scope(request, media.book_id)

    if not await media_service.has_book_access(identity, media.book_id, db):
        raise HTTPException(
            status_code=403,
            detail="You do not have access to this content. "
                   "Purchase the book or start a subscription.",
        )

    filepath = media_service.safe_path(media_service.AUDIO_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Audio not found")

    return media_service.file_response(filepath, filename, request.headers.get("range"))


@router.get("/covers/{filename}")
async def serve_cover(filename: str):
    """Serve cover images.

    DELIBERATELY UNAUTHENTICATED. Cover art is catalog material — it is shown
    while browsing the store, on library shelves and in search results, none of
    which can attach credentials through `Image.network`. FRS §14's content
    protection is about the book's text and audio, which remain gated; gating
    the artwork as well would only break the storefront for no security gain.
    """
    filepath = media_service.safe_path(media_service.COVERS_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Cover not found")
    return media_service.file_response(filepath, filename)
