"""
Book schemas
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum


class Language(str, Enum):
    EN = "en"
    ES = "es"
    FR = "fr"
    DE = "de"
    IT = "it"
    PT = "pt"
    ZH = "zh"
    JA = "ja"
    KO = "ko"
    AR = "ar"


class BookStatus(str, Enum):
    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


class WordSchema(BaseModel):
    id: str
    text: str


class ParagraphSchema(BaseModel):
    words: List[WordSchema]


class ChapterSchema(BaseModel):
    id: str
    title: str
    order_index: int
    paragraphs: List[ParagraphSchema]


class SyncWordSchema(BaseModel):
    id: str
    start: float
    end: float


class BookMediaSchema(BaseModel):
    id: str
    format: str
    quality: str
    duration: Optional[int] = None
    is_ai_narrated: bool = False
    voice_id: Optional[str] = None


class BookBase(BaseModel):
    title: str
    subtitle: Optional[str] = None
    author: str
    description: Optional[str] = None
    language: Language = Language.EN
    isbn: Optional[str] = None


class BookCreate(BookBase):
    pass


class BookUpdate(BaseModel):
    title: Optional[str] = None
    subtitle: Optional[str] = None
    author: Optional[str] = None
    description: Optional[str] = None
    status: Optional[BookStatus] = None


class BookResponse(BookBase):
    id: str
    cover_url: Optional[str] = None
    duration: Optional[int] = None
    word_count: Optional[int] = None
    status: BookStatus
    is_featured: bool
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class BookDetailResponse(BookResponse):
    chapters: List[ChapterSchema]
    media: List[BookMediaSchema]


class BookContentResponse(BaseModel):
    chapters: List[ChapterSchema]


class BookSyncResponse(BaseModel):
    sync_data: List[SyncWordSchema]


class BookListResponse(BaseModel):
    items: List[BookResponse]
    total: int
    page: int
    page_size: int


class BookSearchRequest(BaseModel):
    query: str
    language: Optional[Language] = None
    page: int = 1
    page_size: int = 20


class LicenseResponse(BaseModel):
    license_key: str
    expires_at: Optional[datetime] = None
    download_url: Optional[str] = None
    encryption_key_id: Optional[str] = None
