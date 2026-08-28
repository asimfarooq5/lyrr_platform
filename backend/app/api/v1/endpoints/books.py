"""
Book endpoints
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func
from typing import List, Optional, Dict, Any

from app.core.database import get_db
from app.core.config import settings
from app.api.v1.endpoints.auth import get_current_active_user
from app.core.security import generate_drm_key
from app.models.user import User
from app.models.book import Book, Chapter, BookMedia, UserBook, BookStatus, Language
from app.schemas.book import (
    BookResponse, BookDetailResponse, BookListResponse,
    BookSearchRequest, LicenseResponse, BookContentResponse, BookSyncResponse
)

router = APIRouter()


@router.get("", response_model=BookListResponse)
async def list_books(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    language: Optional[Language] = None,
    search: Optional[str] = None,
    featured_only: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """List published books"""
    query = select(Book).where(Book.status == BookStatus.PUBLISHED)
    
    if language:
        query = query.where(Book.language == language)
    
    if featured_only:
        query = query.where(Book.is_featured == True)
    
    if search:
        # Escape LIKE wildcards so user input is matched literally
        escaped = search.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        search_filter = or_(
            Book.title.ilike(f"%{escaped}%", escape="\\"),
            Book.author.ilike(f"%{escaped}%", escape="\\"),
            Book.description.ilike(f"%{escaped}%", escape="\\")
        )
        query = query.where(search_filter)
    
    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # Paginate
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    books = result.scalars().all()
    
    return {
        "items": books,
        "total": total,
        "page": page,
        "page_size": page_size
    }


@router.get("/{book_id}")
async def get_book(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get book details with chapters"""
    from sqlalchemy.orm import selectinload
    result = await db.execute(
        select(Book)
        .options(selectinload(Book.chapters), selectinload(Book.media))
        .where(and_(Book.id == book_id, Book.status == BookStatus.PUBLISHED))
    )
    book = result.scalar_one_or_none()
    
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    
    return JSONResponse(content=jsonable_encoder({
        "id": book.id,
        "title": book.title,
        "author": book.author,
        "description": book.description,
        "cover_url": book.cover_url,
        "language": book.language.value if hasattr(book.language, 'value') else book.language,
        "duration": book.duration,
        "word_count": book.word_count,
        "status": book.status.value if hasattr(book.status, 'value') else book.status,
        "is_featured": book.is_featured,
        "created_at": str(book.created_at) if book.created_at else None,
        "chapters": [
            {
                "id": ch.id,
                "title": ch.title,
                "order_index": ch.order_index,
                "paragraphs": ch.content or [],
                "sync_data": ch.sync_data,
            }
            for ch in book.chapters
        ],
        "media": [
            {
                "id": m.id,
                "format": m.format,
                "quality": m.quality,
                "duration": m.duration,
                "is_ai_narrated": m.is_ai_narrated,
                "voice_id": m.voice_id,
            }
            for m in book.media
        ],
    }))


@router.get("/{book_id}/content", response_model=BookContentResponse)
async def get_book_content(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get book text content (chapters and words)"""
    # Check if user has access (bypassable for MVP/demo)
    if not settings.BYPASS_LIBRARY_PERMISSIONS:
        user_book_result = await db.execute(
            select(UserBook).where(
                and_(UserBook.user_id == current_user.id, UserBook.book_id == book_id)
            )
        )
        user_book = user_book_result.scalar_one_or_none()
        
        if not user_book and not current_user.is_admin:
            raise HTTPException(status_code=403, detail="Book not purchased")
    
    # Get content
    result = await db.execute(
        select(Chapter).where(Chapter.book_id == book_id).order_by(Chapter.order_index)
    )
    chapters = result.scalars().all()
    
    from fastapi.encoders import jsonable_encoder
    return jsonable_encoder({"chapters": [
        {
            "id": ch.id,
            "book_id": ch.book_id,
            "title": ch.title,
            "order_index": ch.order_index,
            "content": ch.content or [],
            "sync_data": ch.sync_data,
        }
        for ch in chapters
    ]})


@router.get("/{book_id}/sync", response_model=BookSyncResponse)
async def get_book_sync(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get book synchronization data (word timings)"""
    # Check access (bypassable for MVP/demo)
    if not settings.BYPASS_LIBRARY_PERMISSIONS:
        user_book_result = await db.execute(
            select(UserBook).where(
                and_(UserBook.user_id == current_user.id, UserBook.book_id == book_id)
            )
        )
        user_book = user_book_result.scalar_one_or_none()
        
        if not user_book and not current_user.is_admin:
            raise HTTPException(status_code=403, detail="Book not purchased")
    
    # Get sync data from chapters
    result = await db.execute(
        select(Chapter).where(Chapter.book_id == book_id).order_by(Chapter.order_index)
    )
    chapters = result.scalars().all()
    
    # Flatten sync data from all chapters
    all_sync = []
    for chapter in chapters:
        if chapter.sync_data:
            all_sync.extend(chapter.sync_data)
    
    from fastapi.encoders import jsonable_encoder
    return jsonable_encoder({"sync_data": all_sync})


@router.post("/{book_id}/license")
async def get_license(
    book_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get DRM license for book"""
    # Accept device_id from body or query
    import json
    body = await request.body()
    device_id = None
    if body:
        try:
            data = json.loads(body)
            device_id = data.get("device_id")
        except:
            pass
    
    # Verify user has book (bypassable for MVP/demo)
    user_book = None
    if not settings.BYPASS_LIBRARY_PERMISSIONS:
        result = await db.execute(
            select(UserBook).where(
                and_(UserBook.user_id == current_user.id, UserBook.book_id == book_id)
            )
        )
        user_book = result.scalar_one_or_none()
        
        if not user_book:
            raise HTTPException(status_code=403, detail="Book not purchased")
        
        from datetime import datetime, timezone
        if user_book.expires_at and user_book.expires_at < datetime.now(timezone.utc):
            raise HTTPException(status_code=403, detail="License expired")
    
    license_key = generate_drm_key(book_id, current_user.id, device_id or "unknown")
    
    # Get media URL for the first audio file
    media_result = await db.execute(
        select(BookMedia).where(BookMedia.book_id == book_id).limit(1)
    )
    media = media_result.scalar_one_or_none()
    
    audio_url = media.audio_url if media else None
    # If relative URL, make it absolute
    if audio_url and audio_url.startswith("/"):
        base_url = str(request.base_url).rstrip("/")
        audio_url = f"{base_url}{audio_url}"
    
    return {
        "license_key": license_key,
        "expires_at": user_book.expires_at if user_book else None,
        "download_url": audio_url,
        "encryption_key_id": media.encryption_key_id if media else None
    }


@router.post("/{book_id}/purchase")
async def purchase_book(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Purchase a book (records a completed payment and grants a license).

    Equivalent to a card checkout that settles immediately; keeps backward
    compatibility with the mobile app purchase button.
    """
    # Check if already purchased
    result = await db.execute(
        select(UserBook).where(
            and_(UserBook.user_id == current_user.id, UserBook.book_id == book_id)
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Book already purchased")

    # Get book
    book_result = await db.execute(select(Book).where(Book.id == book_id))
    book = book_result.scalar_one_or_none()

    if not book:
        raise HTTPException(status_code=404, detail="Book not found")

    from app.services import payments as payment_service

    payment = await payment_service.create_checkout(
        db,
        user_id=current_user.id,
        method=payment_service.METHOD_CARD,
        item_type="book",
        book_id=book_id,
    )
    payment.status = payment_service.STATUS_COMPLETED
    payment.completed_at = payment_service._utcnow()
    await payment_service._grant_book_access(db, current_user.id, book_id)
    await db.commit()
    await db.refresh(payment)

    return {
        "message": "Book purchased successfully",
        "book_id": book_id,
        "payment_id": payment.id,
        "reference": payment.reference,
    }


@router.post("/{book_id}/download")
async def download_book(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Mark book as downloaded for offline access"""
    result = await db.execute(
        select(UserBook).where(
            and_(UserBook.user_id == current_user.id, UserBook.book_id == book_id)
        )
    )
    user_book = result.scalar_one_or_none()
    
    if not user_book:
        raise HTTPException(status_code=403, detail="Book not purchased")
    
    from datetime import datetime
    
    user_book.is_downloaded = True
    user_book.downloaded_at = datetime.utcnow()
    await db.commit()
    
    return {"message": "Download recorded", "book_id": book_id}


@router.put("/{book_id}")
async def update_book(
    book_id: str,
    book_data: Dict[str, Any],
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Update a book (admin use)"""
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin privileges required")
    
    result = await db.execute(select(Book).where(Book.id == book_id))
    book = result.scalar_one_or_none()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    
    for key, value in book_data.items():
        if hasattr(book, key):
            setattr(book, key, value)
    
    await db.commit()
    return {"message": "Book updated", "book_id": book_id}


@router.delete("/{book_id}")
async def delete_book(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Delete a book (admin use)"""
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Admin privileges required")
    
    result = await db.execute(select(Book).where(Book.id == book_id))
    book = result.scalar_one_or_none()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    
    await db.delete(book)
    await db.commit()
    return {"message": "Book deleted"}
