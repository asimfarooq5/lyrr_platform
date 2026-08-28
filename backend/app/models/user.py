"""
User models with authentication and profile
"""

from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, Text, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base
import uuid


class User(Base):
    __tablename__ = "users"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=True)  # Nullable for OAuth users
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    is_admin = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Phone registration & verification (FRS §4)
    phone = Column(String(20), unique=True, index=True, nullable=True)
    phone_verified = Column(Boolean, default=False)
    
    # OAuth fields
    google_id = Column(String(255), unique=True, nullable=True)
    apple_id = Column(String(255), unique=True, nullable=True)
    
    # Relationships
    profile = relationship("UserProfile", back_populates="user", uselist=False)
    devices = relationship("UserDevice", back_populates="user")
    books = relationship("UserBook", back_populates="user")
    bookmarks = relationship("Bookmark", back_populates="user")
    notes = relationship("Note", back_populates="user")
    progress = relationship("ReadingProgress", back_populates="user")
    
    def __repr__(self):
        return f"<User {self.email}>"


class UserProfile(Base):
    __tablename__ = "user_profiles"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    
    # Profile info
    first_name = Column(String(100), nullable=True)
    last_name = Column(String(100), nullable=True)
    avatar_url = Column(String(500), nullable=True)
    bio = Column(Text, nullable=True)
    
    # Preferences (encrypted)
    preferences = Column(JSON, default=dict)  # font_size, theme, language, etc.
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="profile")


class UserDevice(Base):
    __tablename__ = "user_devices"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
    
    # Device info
    device_fingerprint = Column(String(64), nullable=False)
    device_name = Column(String(100), nullable=True)
    device_type = Column(String(50), nullable=True)  # ios, android, web, desktop
    os_version = Column(String(50), nullable=True)
    app_version = Column(String(50), nullable=True)
    
    # Security
    is_trusted = Column(Boolean, default=False)
    last_ip = Column(String(45), nullable=True)
    
    # Timestamps
    last_active_at = Column(DateTime(timezone=True), server_default=func.now())
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="devices")
    
    __table_args__ = (
        # Unique constraint on user + fingerprint
        # This is handled in code for flexibility
    )
