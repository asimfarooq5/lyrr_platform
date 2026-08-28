"""
Media streaming endpoints - serves uploaded audio and cover images with access control
"""

from fastapi import APIRouter, Request, HTTPException, Depends
from fastapi.responses import FileResponse, StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timezone
from app.core.config import settings
from app.core.database import get_db
from app.core.security import decode_token
from app.models.book import BookMedia, UserBook
from app.models.content import UserSubscription
from app.models.user import User
import os
import mimetypes

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
AUDIO_DIR = os.path.normpath(os.path.join(BASE_DIR, "storage", "audio"))
COVERS_DIR = os.path.normpath(os.path.join(BASE_DIR, "storage", "covers"))

router = APIRouter()


async def _optional_auth(request: Request) -> bool:
    """Optional authentication check for media access, gated by MEDIA_AUTH_ENABLED"""
    if not settings.MEDIA_AUTH_ENABLED:
        return True
    # Check admin cookie
    token = request.cookies.get("admin_token")
    if token:
        payload = decode_token(token)
        if payload and payload.get("type") == "admin":
            return True
    # Check Bearer token (for mobile app)
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        payload = decode_token(auth_header[7:])
        if payload and payload.get("type") in ("access", "admin"):
            return True
    raise HTTPException(status_code=403, detail="Authentication required to access media")


# Sentinel returned by _resolve_media_user when open-access mode is active.
_OPEN_ACCESS = object()


async def _resolve_media_user(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Resolve the identity of a media request.

    Returns:
      * ``_OPEN_ACCESS`` — when the deployment deliberately exposes media
        without restrictions (demo/MVP mode, controlled by MEDIA_AUTH_ENABLED
        and BYPASS_LIBRARY_PERMISSIONS).
      * ``"admin"`` — when a valid admin portal cookie is presented.
      * a ``User`` instance — when a valid bearer access token is presented.
      * raises 401 otherwise.
    """
    open_access = (
        not settings.MEDIA_AUTH_ENABLED
        and getattr(settings, "BYPASS_LIBRARY_PERMISSIONS", False)
    )
    if open_access:
        return _OPEN_ACCESS

    # Admin portal cookie.
    token = request.cookies.get("admin_token")
    if token:
        payload = decode_token(token)
        if payload and payload.get("type") == "admin":
            return "admin"

    # Mobile / web app bearer token.
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        payload = decode_token(auth_header[7:])
        if payload and payload.get("type") in ("access", "admin"):
            user_id = payload.get("sub")
            if user_id:
                result = await db.execute(select(User).where(User.id == user_id))
                user = result.scalar_one_or_none()
                if user and user.is_active:
                    return user

    raise HTTPException(status_code=401, detail="Authentication required to access media")


async def _has_audio_access(identity, book_id: str, db: AsyncSession) -> bool:
    """Content protection check (FRS §14).

    Access is granted to: open-access mode, administrators, subscription
    holders (whole library), or users who purchased the specific book.
    """
    if identity is _OPEN_ACCESS:
        return True

    if identity == "admin":
        return True

    if identity is None:
        return False

    # Subscription holders get access to the whole library.
    now = datetime.now(timezone.utc)
    sub_result = await db.execute(
        select(UserSubscription.id)
        .where(
            UserSubscription.user_id == identity.id,
            UserSubscription.status == "active",
            UserSubscription.expires_at > now,
        )
        .limit(1)
    )
    if sub_result.scalars().first() is not None:
        return True

    # Per-book purchase / license.
    book_result = await db.execute(
        select(UserBook.id).where(
            UserBook.user_id == identity.id,
            UserBook.book_id == book_id,
        ).limit(1)
    )
    return book_result.scalars().first() is not None


def _safe_path(directory: str, filename: str) -> str:
    """Sanitize and resolve a file path to prevent directory traversal"""
    directory_real = os.path.realpath(directory)
    # Remove any path separators from filename
    safe_name = os.path.basename(os.path.normpath(filename))
    resolved = os.path.realpath(os.path.join(directory_real, safe_name))
    # Ensure resolved path is within the intended directory
    if not (resolved == directory_real or resolved.startswith(directory_real + os.sep)):
        raise HTTPException(status_code=400, detail="Invalid file path")
    return resolved


@router.get("/audio/{filename}")
async def stream_audio(
    filename: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user = Depends(_resolve_media_user),
):
    """Stream audio file with range support for seeking.

    Content protection (FRS §14): audio is only streamed to authenticated users
    who hold a license for the book (purchase or active subscription), or to
    admins. Range requests are honoured so clients can seek.
    """
    # Resolve the audio file to its book to enforce access control.
    result = await db.execute(
        select(BookMedia).where(BookMedia.audio_url.endswith(f"/{filename}"))
        .limit(1)
    )
    media = result.scalars().first()
    if media is None:
        # Fall back to path-based matching for legacy records.
        media_list = (await db.execute(select(BookMedia))).scalars().all()
        media = next((m for m in media_list if m.audio_url and m.audio_url.split("/")[-1] == filename), None)

    if media is None:
        raise HTTPException(status_code=404, detail="Audio not found")

    if not await _has_audio_access(current_user, media.book_id, db):
        raise HTTPException(
            status_code=403,
            detail="You do not have access to this content. Purchase the book or start a subscription.",
        )

    filepath = _safe_path(AUDIO_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Audio not found")

    file_size = os.path.getsize(filepath)
    content_type, _ = mimetypes.guess_type(filename)
    content_type = content_type or "audio/mpeg"

    range_header = request.headers.get("range")
    if range_header:
        # Only support single, well-formed byte ranges: "bytes=start-end" or "bytes=start-"
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

    return FileResponse(filepath, media_type=content_type, filename=filename,
                        headers={"Accept-Ranges": "bytes"})


@router.get("/covers/{filename}")
async def serve_cover(filename: str, auth: bool = Depends(_optional_auth)):
    """Serve cover images"""
    filepath = _safe_path(COVERS_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="Cover not found")
    content_type, _ = mimetypes.guess_type(filename)
    return FileResponse(filepath, media_type=content_type or "image/jpeg")
