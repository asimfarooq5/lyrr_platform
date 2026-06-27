"""
User data schemas - bookmarks, notes, progress
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


class Color(str, Enum):
    YELLOW = "#FFD700"
    GREEN = "#90EE90"
    BLUE = "#87CEEB"
    PINK = "#FFB6C1"
    PURPLE = "#DDA0DD"


class BookmarkBase(BaseModel):
    book_id: str
    chapter_id: Optional[str] = None
    word_id: str
    position_seconds: Optional[float] = None
    note: Optional[str] = None
    color: Color = Color.YELLOW


class BookmarkCreate(BookmarkBase):
    client_id: Optional[str] = None  # For offline sync


class BookmarkUpdate(BaseModel):
    note: Optional[str] = None
    color: Optional[Color] = None


class BookmarkResponse(BookmarkBase):
    id: str
    created_at: datetime
    updated_at: Optional[datetime] = None
    is_synced: bool = True
    
    class Config:
        from_attributes = True


class NoteBase(BaseModel):
    book_id: str
    chapter_id: Optional[str] = None
    word_id: str
    content: str


class NoteCreate(NoteBase):
    client_id: Optional[str] = None


class NoteUpdate(BaseModel):
    content: str


class NoteResponse(NoteBase):
    id: str
    created_at: datetime
    updated_at: Optional[datetime] = None
    is_synced: bool = True
    
    class Config:
        from_attributes = True


class ReadingProgressBase(BaseModel):
    book_id: str
    chapter_id: Optional[str] = None
    word_id: Optional[str] = None
    position_seconds: float = 0.0
    progress_percent: float = Field(..., ge=0.0, le=100.0)


class ReadingProgressCreate(ReadingProgressBase):
    device_id: Optional[str] = None


class ReadingProgressUpdate(BaseModel):
    chapter_id: Optional[str] = None
    word_id: Optional[str] = None
    position_seconds: float
    progress_percent: float = Field(..., ge=0.0, le=100.0)


class ReadingProgressResponse(ReadingProgressBase):
    id: str
    total_reading_time_seconds: int = 0
    sessions_count: int = 0
    last_read_at: datetime
    last_synced_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class ReadingStats(BaseModel):
    total_books: int
    total_reading_time_hours: float
    total_sessions: int
    average_session_minutes: float
    books_completed: int
    books_in_progress: int
    favorite_genres: List[str]
    reading_streak_days: int


class UserLibraryBook(BaseModel):
    book_id: str
    title: str
    author: str
    cover_url: Optional[str] = None
    progress_percent: float
    last_read_at: Optional[datetime] = None
    is_downloaded: bool = False


class UserLibraryResponse(BaseModel):
    items: List[UserLibraryBook]
    total: int
