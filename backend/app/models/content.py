"""
Category, Author, Subscription, and Payment models
"""

from sqlalchemy import (Column, String, Boolean, DateTime, Integer, Float,
                        ForeignKey, Text, JSON, Enum, UniqueConstraint)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
import uuid
from app.core.database import Base


class Category(Base):
    __tablename__ = "categories"
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(100), nullable=False, unique=True)
    slug = Column(String(100), nullable=False, unique=True)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    books = relationship("BookCategory", back_populates="category")


class Author(Base):
    __tablename__ = "authors"
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(255), nullable=False)
    bio = Column(Text, nullable=True)
    photo_url = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class BookCategory(Base):
    __tablename__ = "book_categories"
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    book_id = Column(String(36), ForeignKey("books.id", ondelete="CASCADE"), index=True)
    category_id = Column(String(36), ForeignKey("categories.id", ondelete="CASCADE"), index=True)
    category = relationship("Category", back_populates="books")
    book = relationship("Book", back_populates="categories")


class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    price = Column(Float, nullable=False)
    currency = Column(String(3), default="XAF")
    interval = Column(String(20), nullable=False)  # monthly, annual
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class UserSubscription(Base):
    __tablename__ = "user_subscriptions"
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    plan_id = Column(String(36), ForeignKey("subscription_plans.id", ondelete="CASCADE"), index=True)
    status = Column(String(20), default="active")  # active, expired, cancelled
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Payment(Base):
    __tablename__ = "payments"
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    amount = Column(Float, nullable=False)
    currency = Column(String(3), default="XAF")
    method = Column(String(50), nullable=False)  # card, orange_money, mtn_momo
    status = Column(String(50), default="pending")  # pending, awaiting_confirmation, completed, failed, cancelled, expired, refunded
    reference = Column(String(100), nullable=True)
    description = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Order purpose: "book" (pay-per-book) or "subscription"
    item_type = Column(String(20), nullable=True)
    book_id = Column(String(36), ForeignKey("books.id", ondelete="CASCADE"), nullable=True)
    plan_id = Column(String(36), ForeignKey("subscription_plans.id", ondelete="CASCADE"), nullable=True)
    gateway_reference = Column(String(128), nullable=True)
    payment_metadata = Column(JSON, default=dict)
    completed_at = Column(DateTime(timezone=True), nullable=True)

    # For card payments in sandbox mode the charge settles immediately so the
    # checkout flow works fully offline during development.
    def is_auto_confirmable(self) -> bool:
        from app.core.config import settings
        mode = getattr(settings, "PAYMENT_MODE", "sandbox")
        return mode != "live"


class LectureCredit(Base):
    """How many times a reader may still play a book's narration.

    The product sells listening, not books: a book is bought on paper, and in
    the app you buy a single listen. One playback consumes one credit; when the
    credits run out the narration is no longer playable and any downloaded copy
    is taken back, which is what the client asked for.

    Credits are per language, because the same book can be narrated in several
    and each recording is its own purchase.
    """
    __tablename__ = "lecture_credits"
    __table_args__ = (
        UniqueConstraint("user_id", "book_id", "language", name="uq_lecture_credit"),
    )

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    book_id = Column(String(36), ForeignKey("books.id", ondelete="CASCADE"), index=True)
    # ISO code of the recording ("en", "fr", or a dialect tag the admin sets).
    language = Column(String(16), nullable=False, default="en")

    listens_left = Column(Integer, nullable=False, default=0)
    listens_bought = Column(Integer, nullable=False, default=0)
    last_price = Column(Float, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
