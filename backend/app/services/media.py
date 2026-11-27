"""
Media service - shared helpers for audio/cover serving and access control.

Both the public media router (``/media/audio/{filename}``) and the API media
router (``/api/v1/media/...``) use these helpers so the range-streaming logic,
directory-traversal guard, and entitlement checks live in exactly one place.
"""

from __future__ import annotations

import mimetypes
import os
from datetime import datetime, timezone
from typing import Optional, Union

from fastapi import HTTPException
from fastapi.responses import FileResponse, StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import decode_token
from app.models.book import BookMedia, UserBook
from app.models.content import UserSubscription
from app.models.user import User

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
AUDIO_DIR = os.path.normpath(os.path.join(BASE_DIR, "storage", "audio"))
COVERS_DIR = os.path.normpath(os.path.join(BASE_DIR, "storage", "covers"))

# Sentinel identity constants.
OPEN_ACCESS = object()
ADMIN = "admin"


def safe_path(directory: str, filename: str) -> str:
    """Resolve a filename inside ``directory``, rejecting traversal attempts."""
    directory_real = os.path.realpath(directory)
    safe_name = os.path.basename(os.path.normpath(filename))
    resolved = os.path.realpath(os.path.join(directory_real, safe_name))
    if not (resolved == directory_real or resolved.startswith(directory_real + os.sep)):
        raise HTTPException(status_code=400, detail="Invalid file path")
    return resolved


def is_open_access() -> bool:
    """True when the deployment deliberately serves media without auth."""
    return (
        not settings.MEDIA_AUTH_ENABLED
        and getattr(settings, "BYPASS_LIBRARY_PERMISSIONS", False)
    )


async def has_book_access(identity, book_id: str, db: AsyncSession) -> bool:
    """Entitlement check for a book's protected content (FRS §14).

    Granted to: open-access mode, administrators, active subscription holders,
    or users who purchased the specific book.
    """
    if identity is OPEN_ACCESS:
        return True
    if identity == ADMIN:
        return True
    if identity is None:
        return False

    now = datetime.now(timezone.utc)
    sub = await db.execute(
        select(UserSubscription.id)
        .where(
            UserSubscription.user_id == identity.id,
            UserSubscription.status == "active",
            UserSubscription.expires_at > now,
        )
        .limit(1)
    )
    if sub.scalars().first() is not None:
        return True

    purchase = await db.execute(
        select(UserBook.id)
        .where(
            UserBook.user_id == identity.id,
            UserBook.book_id == book_id,
        )
        .limit(1)
    )
    return purchase.scalars().first() is not None


async def find_media_by_filename(db: AsyncSession, filename: str) -> Optional[BookMedia]:
    """Resolve a stored audio filename to its BookMedia row."""
    result = await db.execute(
        select(BookMedia).where(BookMedia.audio_url.endswith(f"/{filename}")).limit(1)
    )
    media = result.scalars().first()
    if media is not None:
        return media
    # Fall back to path-based matching for legacy records.
    all_media = (await db.execute(select(BookMedia))).scalars().all()
    return next(
        (m for m in all_media if m.audio_url and m.audio_url.split("/")[-1] == filename),
        None,
    )


async def find_media_for_book(db: AsyncSession, book_id: str) -> Optional[BookMedia]:
    """Return the primary audio track for a book (highest quality first)."""
    result = await db.execute(
        select(BookMedia)
        .where(BookMedia.book_id == book_id)
        .order_by(BookMedia.created_at.asc())
    )
    return result.scalars().first()


async def _user_from_token(db: AsyncSession, payload: dict) -> Optional[User]:
    user_id = payload.get("sub")
    if not user_id:
        return None
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    return user if user and user.is_active else None


async def resolve_media_identity(request, db: AsyncSession):
    """Resolve the caller of a media request.

    Returns ``OPEN_ACCESS``, ``ADMIN``, a ``User``, or raises 401.

    `just_audio` and the offline downloader cannot attach an `Authorization`
    header, so a short-lived book-scoped media token may arrive in the ``token``
    query parameter instead.
    """
    if is_open_access():
        return OPEN_ACCESS

    # Admin portal cookie.
    cookie = request.cookies.get("admin_token")
    if cookie:
        payload = decode_token(cookie)
        if payload and payload.get("type") == "admin":
            return ADMIN

    # Mobile / web app bearer token.
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        payload = decode_token(auth_header[7:])
        if payload and payload.get("type") in ("access", "admin"):
            user = await _user_from_token(db, payload)
            if user:
                return user

    # Book-scoped media token carried in the URL (players, downloader).
    query_token = request.query_params.get("token")
    if query_token:
        payload = decode_token(query_token)
        if payload and payload.get("type") == "media":
            user = await _user_from_token(db, payload)
            if user:
                return user

    raise HTTPException(status_code=401, detail="Authentication required to access media")


def verify_media_token_scope(request, book_id: str) -> None:
    """Pin a URL-borne media token to the book it was minted for."""
    query_token = request.query_params.get("token")
    if not query_token:
        return
    payload = decode_token(query_token)
    if not payload or payload.get("type") != "media":
        raise HTTPException(status_code=401, detail="Invalid media token")
    if payload.get("book_id") != book_id:
        raise HTTPException(
            status_code=403, detail="Media token is not valid for this book"
        )


def file_response(
    filepath: str,
    filename: str,
    range_header: Optional[str] = None,
) -> Union[FileResponse, StreamingResponse]:
    """Serve a file with HTTP Range support (seeking).

    Returns a 206 partial response for a valid single range, otherwise a plain
    FileResponse advertising ``Accept-Ranges``.
    """
    file_size = os.path.getsize(filepath)
    content_type, _ = mimetypes.guess_type(filename)
    content_type = content_type or "application/octet-stream"

    if not range_header:
        return FileResponse(
            filepath,
            media_type=content_type,
            filename=filename,
            headers={"Accept-Ranges": "bytes"},
        )

    if not range_header.startswith("bytes="):
        raise HTTPException(status_code=416, detail="Invalid Range header")
    spec = range_header[len("bytes="):].strip()
    if not spec or "," in spec:
        raise HTTPException(status_code=416, detail="Multiple ranges not supported")
    parts = spec.split("-", 1)
    if len(parts) != 2:
        raise HTTPException(status_code=416, detail="Invalid Range header")

    start_str, end_str = parts
    try:
        start = int(start_str) if start_str else 0
        end = int(end_str) if end_str else file_size - 1
    except ValueError:
        raise HTTPException(status_code=416, detail="Invalid Range header")

    if start >= file_size:
        raise HTTPException(
            status_code=416,
            detail="Range not satisfiable",
            headers={"Content-Range": f"bytes */{file_size}"},
        )
    if end >= file_size:
        end = file_size - 1
    if end < start:
        raise HTTPException(status_code=416, detail="Invalid Range header")

    content_length = end - start + 1

    async def stream_chunks():
        with open(filepath, "rb") as f:
            f.seek(start)
            remaining = content_length
            while remaining > 0:
                chunk_size = min(8192, remaining)
                data = f.read(chunk_size)
                if not data:
                    break
                yield data
                remaining -= len(data)

    return StreamingResponse(
        stream_chunks(),
        media_type=content_type,
        status_code=206,
        headers={
            "Content-Range": f"bytes {start}-{end}/{file_size}",
            "Content-Length": str(content_length),
            "Accept-Ranges": "bytes",
        },
    )
