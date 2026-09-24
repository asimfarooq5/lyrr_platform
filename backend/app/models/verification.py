"""
One-time verification codes (email/phone OTP) and password-reset codes.

Stored in the database rather than process memory so the codes work correctly
when the API runs as multiple uvicorn workers (each worker is a separate
process with its own memory) and survive a restart. Redis is used only as a
fast path when it is available.
"""

from sqlalchemy import Column, String, Integer, DateTime, Boolean, Index
from sqlalchemy.sql import func
import uuid

from app.core.database import Base


class VerificationCode(Base):
    __tablename__ = "verification_codes"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    channel = Column(String(10), nullable=False)   # "email" | "phone"
    target = Column(String(255), nullable=False)   # email address or phone number
    code_hash = Column(String(64), nullable=False)  # sha256 of the code
    attempts = Column(Integer, default=0, nullable=False)
    consumed = Column(Boolean, default=False, nullable=False)

    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        # Lookups are always "latest code for this channel+target".
        Index("ix_verification_codes_channel_target", "channel", "target"),
    )
