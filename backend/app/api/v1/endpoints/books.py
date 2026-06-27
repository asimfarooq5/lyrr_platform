"""
Book endpoints
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func
from typing import List, Optional

from app.core.database import get_db
from app.core.config import settings
from app.core.security import get_current_active_user, generate_drm_key
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
        search_filter = or_(
            Book.title.ilike(f"%{search}%"),
            Book.author.ilike(f"%{search}%"),
            Book.description.ilike(f"%{search}%")
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


@router.get("/{book_id}", response_model=BookDetailResponse)
async def get_book(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get book details with chapters"""
    result = await db.execute(
        select(Book).where(and_(Book.id == book_id, Book.status == BookStatus.PUBLISHED))
    )
    book = result.scalar_one_or_none()
    
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    
    return book


@router.get("/{book_id}/content", response_model=BookContentResponse)
async def get_book_content(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get book text content (chapters and words)"""
    # Check if user has access
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
    
    return {"chapters": chapters}


@router.get("/{book_id}/sync", response_model=BookSyncResponse)
async def get_book_sync(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get book synchronization data (word timings)"""
    # Check access
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
    
    return {"sync_data": all_sync}


@router.post("/{book_id}/license", response_model=LicenseResponse)
async def get_license(
    book_id: str,
    device_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get DRM license for book"""
    # Verify user has book
    result = await db.execute(
        select(UserBook).where(
            and_(UserBook.user_id == current_user.id, UserBook.book_id == book_id)
        )
    )
    user_book = result.scalar_one_or_none()
    
    if not user_book:
        raise HTTPException(status_code=403, detail="Book not purchased")
    
    # Check if expired
    if user_book.expires_at and user_book.expires_at < datetime.utcnow():
        raise HTTPException(status_code=403, detail="License expired")
    
    # Generate license key
    license_key = generate_drm_key(book_id, current_user.id, device_id)
    
    # Get media URL
    media_result = await db.execute(
        select(BookMedia).where(BookMedia.book_id == book_id).limit(1)
    )
    media = media_result.scalar_one_or_none()
    
    return {
        "license_key": license_key,
        "expires_at": user_book.expires_at,
        "download_url": media.audio_url if media else None,
        "encryption_key_id": media.encryption_key_id if media else None
    }


@router.post("/{book_id}/purchase")
async def purchase_book(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Purchase a book (mock implementation)"""
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
    
    # Create user book (mock purchase)
    from datetime import datetime, timedelta
    
    user_book = UserBook(
        user_id=current_user.id,
        book_id=book_id,
        license_key=generate_drm_key(book_id, current_user.id, "purchase"),
        license_type="purchase"
    )
    
    db.add(user_book)
    await db.commit()
    
    return {"message": "Book purchased successfully", "book_id": book_id}


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
