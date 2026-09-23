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


class SyncWordSchema(BaseModel):
    id: str
    start: float
    end: float


class ChapterSchema(BaseModel):
    id: str
    title: str
    order_index: int
    paragraphs: List[ParagraphSchema] = Field(default=[], validation_alias="content")
    sync_data: Optional[List[SyncWordSchema]] = None
    
    model_config = {"from_attributes": True}


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


class AdminBookUpdate(BaseModel):
    """Explicit allow-list for admin book edits.

    Replaces the previous unvalidated ``setattr`` loop which allowed a client to
    overwrite any model column (mass assignment). Only the fields below are
    editable; anything else in the request is rejected by Pydantic.
    """

    title: Optional[str] = Field(None, min_length=1, max_length=255)
    subtitle: Optional[str] = Field(None, max_length=255)
    author: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    cover_url: Optional[str] = Field(None, max_length=500)
    book_type: Optional[str] = Field(None, max_length=50)
    language: Optional[Language] = None
    status: Optional[BookStatus] = None
    price: Optional[float] = Field(None, ge=0)
    isbn: Optional[str] = Field(None, max_length=20)
    duration: Optional[int] = Field(None, ge=0)
    word_count: Optional[int] = Field(None, ge=0)
    is_featured: Optional[bool] = None
    publisher: Optional[str] = Field(None, max_length=255)
    published_at: Optional[datetime] = None

    model_config = {"extra": "forbid"}


class BookResponse(BookBase):
    id: str
    cover_url: Optional[str] = None
    book_type: str = "fiction"
    duration: Optional[int] = None
    word_count: Optional[int] = None
    status: BookStatus
    is_featured: bool
    price: Optional[float] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class BookDetailResponse(BookResponse):
    chapters: List[ChapterSchema]
    media: List[BookMediaSchema]


class BookContentResponse(BaseModel):
    chapters: List[ChapterSchema]
    is_preview: bool = False


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
