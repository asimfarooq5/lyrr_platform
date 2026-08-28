"""
Category, Author, Subscription, and Payment models
"""

from sqlalchemy import Column, String, Boolean, DateTime, Integer, Float, ForeignKey, Text, JSON, Enum
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
    book_id = Column(String(36), ForeignKey("books.id", ondelete="CASCADE"))
    category_id = Column(String(36), ForeignKey("categories.id", ondelete="CASCADE"))
    category = relationship("Category", back_populates="books")


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
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
    plan_id = Column(String(36), ForeignKey("subscription_plans.id", ondelete="CASCADE"))
    status = Column(String(20), default="active")  # active, expired, cancelled
    started_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Payment(Base):
    __tablename__ = "payments"
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
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
