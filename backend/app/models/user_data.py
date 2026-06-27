"""
User data models - bookmarks, notes, progress
"""

from sqlalchemy import Column, String, Boolean, DateTime, Integer, Float, ForeignKey, Text, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid

from app.core.database import Base


class Bookmark(Base):
    __tablename__ = "bookmarks"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
    book_id = Column(String(36), ForeignKey("books.id", ondelete="CASCADE"))
    
    # Location
    chapter_id = Column(String(36), ForeignKey("chapters.id", ondelete="CASCADE"), nullable=True)
    word_id = Column(String(50), nullable=False)  # e.g., "w1234"
    position_seconds = Column(Float, nullable=True)
    
    # Content
    note = Column(Text, nullable=True)
    color = Column(String(7), default="#FFD700")  # Hex color
    
    # Sync
    client_id = Column(String(36), nullable=True)  # For offline sync
    is_synced = Column(Boolean, default=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="bookmarks")
    book = relationship("Book", back_populates="bookmarks")


class Note(Base):
    __tablename__ = "notes"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
    book_id = Column(String(36), ForeignKey("books.id", ondelete="CASCADE"))
    
    # Location
    chapter_id = Column(String(36), ForeignKey("chapters.id", ondelete="CASCADE"), nullable=True)
    word_id = Column(String(50), nullable=False)
    
    # Content
    content = Column(Text, nullable=False)
    
    # Sync
    client_id = Column(String(36), nullable=True)
    is_synced = Column(Boolean, default=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="notes")
    book = relationship("Book", back_populates="notes")


class ReadingProgress(Base):
    __tablename__ = "reading_progress"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
    book_id = Column(String(36), ForeignKey("books.id", ondelete="CASCADE"))
    
    # Position
    chapter_id = Column(String(36), ForeignKey("chapters.id", ondelete="CASCADE"), nullable=True)
    word_id = Column(String(50), nullable=True)
    position_seconds = Column(Float, default=0.0)
    progress_percent = Column(Float, default=0.0)  # 0.0 to 100.0
    
    # Stats
    total_reading_time_seconds = Column(Integer, default=0)
    sessions_count = Column(Integer, default=0)
    
    # Sync
    last_synced_at = Column(DateTime(timezone=True), nullable=True)
    device_id = Column(String(36), nullable=True)
    
    # Timestamps
    last_read_at = Column(DateTime(timezone=True), server_default=func.now())
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="progress")
    book = relationship("Book", back_populates="progress")
    
    __table_args__ = (
        # Unique constraint on user + book
        # This is handled in code for flexibility
    )


class UserSettings(Base):
    """User preferences and settings"""
    __tablename__ = "user_settings"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    
    # Reader settings
    font_size = Column(Integer, default=18)
    line_height = Column(Float, default=1.6)
    theme = Column(String(20), default="system")  # light, dark, system
    
    # Audio settings
    playback_speed = Column(Float, default=1.0)
    auto_scroll = Column(Boolean, default=True)
    highlight_color = Column(String(7), default="#6B4EFF")
    
    # Sync settings
    auto_sync = Column(Boolean, default=True)
    sync_over_wifi_only = Column(Boolean, default=False)
    
    # Language
    interface_language = Column(String(10), default="en")
    content_language = Column(String(10), nullable=True)
    
    # JSON for extensibility
    custom_settings = Column(JSON, default=dict)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User")


class SearchHistory(Base):
    """User search history for personalization"""
    __tablename__ = "search_history"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
    
    query = Column(String(255), nullable=False)
    results_count = Column(Integer, nullable=True)
    clicked_book_id = Column(String(36), nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
