"""
Reading session model for streak tracking
"""

from sqlalchemy import Column, String, Integer, Date, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.sql import func
import uuid

from app.core.database import Base


class ReadingSession(Base):
    """Daily reading session aggregation for streak tracking"""
    __tablename__ = "reading_sessions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    book_id = Column(String(36), ForeignKey("books.id", ondelete="CASCADE"), nullable=True)
    date = Column(Date, nullable=False)
    duration_seconds = Column(Integer, default=0, nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("user_id", "date", name="uq_reading_session_user_date"),
    )
