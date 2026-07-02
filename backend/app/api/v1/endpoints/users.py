"""
User data endpoints - library, bookmarks, notes, progress
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc
from typing import List
from datetime import datetime

from app.core.database import get_db
from app.api.v1.endpoints.auth import get_current_active_user
from app.models.user import User
from app.models.book import Book, UserBook
from app.models.user_data import Bookmark, Note, ReadingProgress
from app.schemas.user_data import (
    BookmarkCreate, BookmarkUpdate, BookmarkResponse,
    NoteCreate, NoteUpdate, NoteResponse,
    ReadingProgressCreate, ReadingProgressUpdate, ReadingProgressResponse,
    UserLibraryResponse, UserLibraryBook, ReadingStats
)

router = APIRouter()


@router.get("/library", response_model=UserLibraryResponse)
async def get_library(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get user's book library"""
    result = await db.execute(
        select(UserBook, Book)
        .join(Book, UserBook.book_id == Book.id)
        .where(UserBook.user_id == current_user.id)
        .order_by(desc(UserBook.purchased_at))
    )
    
    items = []
    for user_book, book in result.all():
        # Get progress
        progress_result = await db.execute(
            select(ReadingProgress)
            .where(
                and_(
                    ReadingProgress.user_id == current_user.id,
                    ReadingProgress.book_id == book.id
                )
            )
        )
        progress = progress_result.scalar_one_or_none()
        
        items.append(UserLibraryBook(
            book_id=book.id,
            title=book.title,
            author=book.author,
            cover_url=book.cover_url,
            book_type=book.book_type or "fiction",
            language=book.language.value if hasattr(book.language, 'value') else str(book.language),
            progress_percent=progress.progress_percent if progress else 0.0,
            last_read_at=progress.last_read_at if progress else None,
            is_downloaded=user_book.is_downloaded
        ))
    
    # Group by type, author, language
    from collections import defaultdict
    by_type = defaultdict(list)
    by_author = defaultdict(list)
    by_language = defaultdict(list)
    
    for item in items:
        by_type[item.book_type].append(item)
        by_author[item.author].append(item)
        by_language[item.language].append(item)
    
    return {
        "items": items,
        "by_type": [{"group": k, "books": v} for k, v in by_type.items()],
        "by_author": [{"group": k, "books": v} for k, v in by_author.items()],
        "by_language": [{"group": k, "books": v} for k, v in by_language.items()],
        "total": len(items),
    }


# Bookmarks
@router.get("/bookmarks", response_model=List[BookmarkResponse])
async def get_bookmarks(
    book_id: str = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get user's bookmarks"""
    query = select(Bookmark).where(Bookmark.user_id == current_user.id)
    
    if book_id:
        query = query.where(Bookmark.book_id == book_id)
    
    query = query.order_by(desc(Bookmark.created_at))
    
    result = await db.execute(query)
    return result.scalars().all()


@router.post("/bookmarks", response_model=BookmarkResponse, status_code=status.HTTP_201_CREATED)
async def create_bookmark(
    bookmark: BookmarkCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Create a bookmark"""
    # Check if bookmark already exists at this location
    result = await db.execute(
        select(Bookmark).where(
            and_(
                Bookmark.user_id == current_user.id,
                Bookmark.book_id == bookmark.book_id,
                Bookmark.word_id == bookmark.word_id
            )
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Bookmark already exists at this location")
    
    new_bookmark = Bookmark(
        user_id=current_user.id,
        book_id=bookmark.book_id,
        chapter_id=bookmark.chapter_id,
        word_id=bookmark.word_id,
        position_seconds=bookmark.position_seconds,
        note=bookmark.note,
        color=bookmark.color.value,
        client_id=bookmark.client_id,
        is_synced=True
    )
    
    db.add(new_bookmark)
    await db.commit()
    await db.refresh(new_bookmark)
    
    return new_bookmark


@router.put("/bookmarks/{bookmark_id}", response_model=BookmarkResponse)
async def update_bookmark(
    bookmark_id: str,
    update: BookmarkUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update a bookmark"""
    result = await db.execute(
        select(Bookmark).where(
            and_(Bookmark.id == bookmark_id, Bookmark.user_id == current_user.id)
        )
    )
    bookmark = result.scalar_one_or_none()
    
    if not bookmark:
        raise HTTPException(status_code=404, detail="Bookmark not found")
    
    if update.note is not None:
        bookmark.note = update.note
    if update.color is not None:
        bookmark.color = update.color.value
    
    bookmark.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(bookmark)
    
    return bookmark


@router.delete("/bookmarks/{bookmark_id}")
async def delete_bookmark(
    bookmark_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Delete a bookmark"""
    result = await db.execute(
        select(Bookmark).where(
            and_(Bookmark.id == bookmark_id, Bookmark.user_id == current_user.id)
        )
    )
    bookmark = result.scalar_one_or_none()
    
    if not bookmark:
        raise HTTPException(status_code=404, detail="Bookmark not found")
    
    await db.delete(bookmark)
    await db.commit()
    
    return {"message": "Bookmark deleted"}


# Notes
@router.get("/notes", response_model=List[NoteResponse])
async def get_notes(
    book_id: str = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get user's notes"""
    query = select(Note).where(Note.user_id == current_user.id)
    
    if book_id:
        query = query.where(Note.book_id == book_id)
    
    query = query.order_by(desc(Note.created_at))
    
    result = await db.execute(query)
    return result.scalars().all()


@router.post("/notes", response_model=NoteResponse, status_code=status.HTTP_201_CREATED)
async def create_note(
    note: NoteCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Create a note"""
    new_note = Note(
        user_id=current_user.id,
        book_id=note.book_id,
        chapter_id=note.chapter_id,
        word_id=note.word_id,
        content=note.content,
        client_id=note.client_id,
        is_synced=True
    )
    
    db.add(new_note)
    await db.commit()
    await db.refresh(new_note)
    
    return new_note


@router.put("/notes/{note_id}", response_model=NoteResponse)
async def update_note(
    note_id: str,
    update: NoteUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update a note"""
    result = await db.execute(
        select(Note).where(
            and_(Note.id == note_id, Note.user_id == current_user.id)
        )
    )
    note = result.scalar_one_or_none()
    
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    note.content = update.content
    note.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(note)
    
    return note


@router.delete("/notes/{note_id}")
async def delete_note(
    note_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Delete a note"""
    result = await db.execute(
        select(Note).where(
            and_(Note.id == note_id, Note.user_id == current_user.id)
        )
    )
    note = result.scalar_one_or_none()
    
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    await db.delete(note)
    await db.commit()
    
    return {"message": "Note deleted"}


# Reading Progress
@router.get("/progress", response_model=List[ReadingProgressResponse])
async def get_progress(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get reading progress for all books"""
    result = await db.execute(
        select(ReadingProgress)
        .where(ReadingProgress.user_id == current_user.id)
        .order_by(desc(ReadingProgress.last_read_at))
    )
    return result.scalars().all()


@router.get("/progress/{book_id}")
async def get_book_progress(
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get reading progress for a specific book"""
    result = await db.execute(
        select(ReadingProgress).where(
            and_(
                ReadingProgress.user_id == current_user.id,
                ReadingProgress.book_id == book_id
            )
        )
    )
    progress = result.scalar_one_or_none()
    
    if not progress:
        return {}
    
    return progress


@router.post("/progress", response_model=ReadingProgressResponse)
async def update_progress(
    progress: ReadingProgressCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update reading progress"""
    # Check if progress exists
    result = await db.execute(
        select(ReadingProgress).where(
            and_(
                ReadingProgress.user_id == current_user.id,
                ReadingProgress.book_id == progress.book_id
            )
        )
    )
    existing = result.scalar_one_or_none()
    
    if existing:
        # Update existing
        existing.chapter_id = progress.chapter_id
        existing.word_id = progress.word_id
        existing.position_seconds = progress.position_seconds
        existing.progress_percent = progress.progress_percent
        existing.last_read_at = datetime.utcnow()
        existing.total_reading_time_seconds += 1  # Increment by 1 second (called periodically)
        existing.sessions_count += 1
        existing.last_synced_at = datetime.utcnow()
        
        await db.commit()
        await db.refresh(existing)
        return existing
    else:
        # Create new
        new_progress = ReadingProgress(
            user_id=current_user.id,
            book_id=progress.book_id,
            chapter_id=progress.chapter_id,
            word_id=progress.word_id,
            position_seconds=progress.position_seconds,
            progress_percent=progress.progress_percent,
            device_id=progress.device_id,
            last_synced_at=datetime.utcnow()
        )
        
        db.add(new_progress)
        await db.commit()
        await db.refresh(new_progress)
        return new_progress


@router.get("/stats", response_model=ReadingStats)
async def get_reading_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get reading statistics"""
    # Get all progress
    result = await db.execute(
        select(ReadingProgress).where(ReadingProgress.user_id == current_user.id)
    )
    progress_list = result.scalars().all()
    
    total_books = len(progress_list)
    total_reading_time = sum(p.total_reading_time_seconds for p in progress_list)
    total_sessions = sum(p.sessions_count for p in progress_list)
    books_completed = sum(1 for p in progress_list if p.progress_percent >= 95)
    books_in_progress = sum(1 for p in progress_list if 0 < p.progress_percent < 95)
    
    # Calculate average session
    avg_session = (total_reading_time / total_sessions / 60) if total_sessions > 0 else 0
    
    # TODO: Calculate reading streak and favorite genres
    
    return ReadingStats(
        total_books=total_books,
        total_reading_time_hours=total_reading_time / 3600,
        total_sessions=total_sessions,
        average_session_minutes=avg_session,
        books_completed=books_completed,
        books_in_progress=books_in_progress,
        favorite_genres=[],
        reading_streak_days=0
    )
