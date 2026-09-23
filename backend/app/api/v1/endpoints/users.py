"""
User data endpoints - library, bookmarks, notes, progress, streaks
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc, func as sa_func
from sqlalchemy.exc import IntegrityError
from typing import List, Optional
from datetime import datetime, date, timedelta

from app.core.database import get_db
from app.api.v1.endpoints.auth import get_current_active_user
from app.models.user import User
from app.models.book import Book, UserBook
from app.models.user_data import Bookmark, Note, ReadingProgress, Collection, CollectionBook
from app.models.reading_session import ReadingSession
from app.schemas.user_data import (
    BookmarkCreate, BookmarkUpdate, BookmarkResponse,
    NoteCreate, NoteUpdate, NoteResponse,
    ReadingProgressCreate, ReadingProgressUpdate, ReadingProgressResponse,
    UserLibraryResponse, UserLibraryBook, ReadingStats,
    CollectionCreate, CollectionResponse, CollectionBookSummary,
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
    book_id: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get user's bookmarks"""
    query = select(Bookmark).where(Bookmark.user_id == current_user.id)
    
    if book_id:
        query = query.where(Bookmark.book_id == book_id)
    
    query = query.order_by(desc(Bookmark.created_at)).offset(skip).limit(limit)
    
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
    book_id: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get user's notes"""
    query = select(Note).where(Note.user_id == current_user.id)
    
    if book_id:
        query = query.where(Note.book_id == book_id)
    
    query = query.order_by(desc(Note.created_at)).offset(skip).limit(limit)
    
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
    skip: int = Query(0, ge=0),
    limit: int = Query(200, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get reading progress for all books"""
    result = await db.execute(
        select(ReadingProgress)
        .where(ReadingProgress.user_id == current_user.id)
        .order_by(desc(ReadingProgress.last_read_at))
        .offset(skip)
        .limit(limit)
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


async def _touch_reading_session(
    db: AsyncSession, user_id: str, book_id: Optional[str], seconds: int = 10
) -> None:
    """Add `seconds` to today's reading session for the user (upsert-safe)."""
    today = date.today()
    session = (await db.execute(
        select(ReadingSession).where(
            and_(
                ReadingSession.user_id == user_id,
                ReadingSession.date == today,
            )
        )
    )).scalar_one_or_none()
    if session:
        session.duration_seconds += seconds
    else:
        db.add(ReadingSession(
            user_id=user_id,
            book_id=book_id,
            date=today,
            duration_seconds=seconds,
        ))


@router.post("/progress", response_model=ReadingProgressResponse)
async def update_progress(
    progress: ReadingProgressCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update reading progress and track the daily reading session.

    Race-safe: (user_id, book_id) is unique, so a concurrent insert is caught
    and retried as an update instead of raising.
    """
    def _apply(target: ReadingProgress) -> None:
        target.chapter_id = progress.chapter_id
        target.word_id = progress.word_id
        target.position_seconds = progress.position_seconds
        target.progress_percent = progress.progress_percent
        target.last_read_at = datetime.utcnow()
        target.last_synced_at = datetime.utcnow()

    existing = (await db.execute(
        select(ReadingProgress).where(
            and_(
                ReadingProgress.user_id == current_user.id,
                ReadingProgress.book_id == progress.book_id,
            )
        )
    )).scalar_one_or_none()

    if existing:
        _apply(existing)
        existing.total_reading_time_seconds += 10  # called every ~10s
        existing.sessions_count += 1
        await _touch_reading_session(db, current_user.id, progress.book_id)
        await db.commit()
        await db.refresh(existing)
        return existing

    new_progress = ReadingProgress(
        user_id=current_user.id,
        book_id=progress.book_id,
        chapter_id=progress.chapter_id,
        word_id=progress.word_id,
        position_seconds=progress.position_seconds,
        progress_percent=progress.progress_percent,
        device_id=progress.device_id,
        last_synced_at=datetime.utcnow(),
    )
    db.add(new_progress)
    await _touch_reading_session(db, current_user.id, progress.book_id)

    try:
        await db.commit()
    except IntegrityError:
        # Another request inserted this (user, book) between our SELECT and
        # INSERT — fall back to updating the row that won the race.
        await db.rollback()
        existing = (await db.execute(
            select(ReadingProgress).where(
                and_(
                    ReadingProgress.user_id == current_user.id,
                    ReadingProgress.book_id == progress.book_id,
                )
            )
        )).scalar_one()
        _apply(existing)
        await db.commit()
        await db.refresh(existing)
        return existing

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


@router.get("/stats/streaks")
async def get_reading_streaks(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get daily reading streak data for the last 60 days"""
    sixty_days_ago = date.today() - timedelta(days=60)
    
    result = await db.execute(
        select(ReadingSession)
        .where(
            and_(
                ReadingSession.user_id == current_user.id,
                ReadingSession.date >= sixty_days_ago
            )
        )
        .order_by(ReadingSession.date)
    )
    sessions = result.scalars().all()
    
    # Build daily map
    daily_log = {}
    for s in sessions:
        daily_log[str(s.date)] = {
            "duration_seconds": s.duration_seconds,
            "book_id": s.book_id,
        }
    
    # Calculate current streak
    current_streak = 0
    check_date = date.today()
    while str(check_date) in daily_log:
        current_streak += 1
        check_date -= timedelta(days=1)
    
    # Calculate longest streak
    dates = sorted(daily_log.keys())
    longest_streak = 0
    streak = 0
    prev_date = None
    for d in dates:
        d_date = date.fromisoformat(d)
        if prev_date and (d_date - prev_date).days == 1:
            streak += 1
        else:
            streak = 1
        longest_streak = max(longest_streak, streak)
        prev_date = d_date
    
    # Generate last 60 days calendar
    calendar = []
    for i in range(60):
        d = sixty_days_ago + timedelta(days=i)
        d_str = str(d)
        calendar.append({
            "date": d_str,
            "has_read": d_str in daily_log,
            "duration_seconds": daily_log.get(d_str, {}).get("duration_seconds", 0),
        })
    
    return {
        "current_streak": current_streak,
        "longest_streak": longest_streak,
        "total_days_read": len(daily_log),
        "daily_goal_minutes": 30,
        "calendar": calendar,
    }


# ---- Collections (Kindle-style shelves) ----

async def _collection_response(db: AsyncSession, collection: Collection) -> CollectionResponse:
    rows = await db.execute(
        select(Book.id, Book.title, Book.author, Book.cover_url)
        .join(CollectionBook, CollectionBook.book_id == Book.id)
        .where(CollectionBook.collection_id == collection.id)
        .order_by(CollectionBook.added_at.desc())
    )
    books = [
        CollectionBookSummary(book_id=r.id, title=r.title, author=r.author, cover_url=r.cover_url)
        for r in rows.all()
    ]
    return CollectionResponse(
        id=collection.id, name=collection.name, created_at=collection.created_at, books=books,
    )


@router.get("/collections", response_model=List[CollectionResponse])
async def list_collections(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """List the user's custom collections/shelves."""
    result = await db.execute(
        select(Collection).where(Collection.user_id == current_user.id)
        .order_by(Collection.created_at)
    )
    collections = result.scalars().all()
    return [await _collection_response(db, c) for c in collections]


@router.post("/collections", response_model=CollectionResponse, status_code=status.HTTP_201_CREATED)
async def create_collection(
    data: CollectionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    collection = Collection(user_id=current_user.id, name=data.name.strip())
    db.add(collection)
    await db.commit()
    await db.refresh(collection)
    return await _collection_response(db, collection)


@router.delete("/collections/{collection_id}")
async def delete_collection(
    collection_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    result = await db.execute(
        select(Collection).where(
            Collection.id == collection_id, Collection.user_id == current_user.id
        )
    )
    collection = result.scalar_one_or_none()
    if not collection:
        raise HTTPException(status_code=404, detail="Collection not found")
    await db.delete(collection)
    await db.commit()
    return {"message": "Collection deleted"}


@router.post("/collections/{collection_id}/books/{book_id}", response_model=CollectionResponse)
async def add_book_to_collection(
    collection_id: str,
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    result = await db.execute(
        select(Collection).where(
            Collection.id == collection_id, Collection.user_id == current_user.id
        )
    )
    collection = result.scalar_one_or_none()
    if not collection:
        raise HTTPException(status_code=404, detail="Collection not found")

    existing = await db.execute(
        select(CollectionBook).where(
            CollectionBook.collection_id == collection_id, CollectionBook.book_id == book_id
        )
    )
    if not existing.scalar_one_or_none():
        db.add(CollectionBook(collection_id=collection_id, book_id=book_id))
        await db.commit()

    return await _collection_response(db, collection)


@router.delete("/collections/{collection_id}/books/{book_id}", response_model=CollectionResponse)
async def remove_book_from_collection(
    collection_id: str,
    book_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    result = await db.execute(
        select(Collection).where(
            Collection.id == collection_id, Collection.user_id == current_user.id
        )
    )
    collection = result.scalar_one_or_none()
    if not collection:
        raise HTTPException(status_code=404, detail="Collection not found")

    await db.execute(
        CollectionBook.__table__.delete().where(
            CollectionBook.collection_id == collection_id, CollectionBook.book_id == book_id
        )
    )
    await db.commit()
    return await _collection_response(db, collection)
