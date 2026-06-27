"""
Book models with content, media, and DRM
"""

from sqlalchemy import Column, String, Boolean, DateTime, Integer, Float, ForeignKey, Text, JSON, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
import uuid

from app.core.database import Base


class BookStatus(str, enum.Enum):
    DRAFT = "draft"
    PUBLISHED = "published"
    ARCHIVED = "archived"


class Language(str, enum.Enum):
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


class Book(Base):
    __tablename__ = "books"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Basic info
    title = Column(String(255), nullable=False)
    subtitle = Column(String(255), nullable=True)
    author = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    cover_url = Column(String(500), nullable=True)
    
    # Metadata
    language = Column(Enum(Language), default=Language.EN)
    duration = Column(Integer, nullable=True)  # in seconds
    word_count = Column(Integer, nullable=True)
    isbn = Column(String(20), nullable=True, unique=True)
    
    # Status
    status = Column(Enum(BookStatus), default=BookStatus.DRAFT)
    is_featured = Column(Boolean, default=False)
    
    # DRM
    drm_enabled = Column(Boolean, default=True)
    encryption_key_id = Column(String(64), nullable=True)
    
    # Timestamps
    published_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    chapters = relationship("Chapter", back_populates="book", order_by="Chapter.order_index")
    media = relationship("BookMedia", back_populates="book")
    user_books = relationship("UserBook", back_populates="book")
    bookmarks = relationship("Bookmark", back_populates="book")
    notes = relationship("Note", back_populates="book")
    progress = relationship("ReadingProgress", back_populates="book")
    
    def __repr__(self):
        return f"<Book {self.title}>"


class Chapter(Base):
    __tablename__ = "chapters"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    book_id = Column(String(36), ForeignKey("books.id", ondelete="CASCADE"))
    
    # Content
    title = Column(String(255), nullable=False)
    order_index = Column(Integer, nullable=False)
    
    # Word content (JSON array of words with IDs)
    content = Column(JSON, nullable=False)  # [{"id": "w1", "text": "Hello"}, ...]
    
    # Sync data (JSON array of word timings)
    sync_data = Column(JSON, nullable=True)  # [{"id": "w1", "start": 0.0, "end": 0.5}, ...]
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    book = relationship("Book", back_populates="chapters")


class BookMedia(Base):
    __tablename__ = "book_media"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    book_id = Column(String(36), ForeignKey("books.id", ondelete="CASCADE"))
    
    # Media info
    audio_url = Column(String(500), nullable=False)
    format = Column(String(10), default="mp3")  # mp3, m4a, wav
    quality = Column(String(10), default="high")  # low, medium, high
    size_bytes = Column(Integer, nullable=True)
    duration = Column(Integer, nullable=True)  # in seconds
    
    # AI narration
    is_ai_narrated = Column(Boolean, default=False)
    voice_id = Column(String(50), nullable=True)  # ElevenLabs voice ID
    
    # Encryption
    is_encrypted = Column(Boolean, default=True)
    encryption_key_id = Column(String(64), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    book = relationship("Book", back_populates="media")


class UserBook(Base):
    """User's library - purchased or accessed books"""
    __tablename__ = "user_books"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
    book_id = Column(String(36), ForeignKey("books.id", ondelete="CASCADE"))
    
    # License
    license_key = Column(String(64), nullable=True)
    license_type = Column(String(20), default="purchase")  # purchase, subscription, trial
    
    # Download status
    is_downloaded = Column(Boolean, default=False)
    downloaded_at = Column(DateTime(timezone=True), nullable=True)
    
    # Timestamps
    purchased_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="books")
    book = relationship("Book", back_populates="user_books")
