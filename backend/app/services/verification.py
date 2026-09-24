"""
Email/phone verification service (FRS §4).

Generates and validates one-time passcodes (OTP) for email and phone
verification.

STORAGE: codes are persisted in the database. Process memory cannot be used
because the API runs as multiple uvicorn workers — each worker is a separate
process, so a code issued by one worker would be invisible to the worker that
handles the confirmation. Redis is used as a fast path when it is reachable,
with the database as the system of record.

Delivery: with VERIFICATION_MODE=sandbox the code is only logged (and returned
to the caller when DEV_EXPOSE_TOKENS is on). Set VERIFICATION_MODE=live and
configure SMTP/SMS for real delivery.
"""

from __future__ import annotations

import hashlib
import logging
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.redis import get_redis
from app.models.verification import VerificationCode

logger = logging.getLogger(__name__)

OTP_TTL_SECONDS = 600  # 10 minutes
OTP_LENGTH = 6
MAX_ATTEMPTS = 5


def _key(channel: str, target: str) -> str:
    return f"lyrr:otp:{channel}:{target.strip().lower()}"


def _hash(code: str) -> str:
    return hashlib.sha256(code.encode()).hexdigest()


def _generate_code() -> str:
    # 6-digit numeric code, first digit never 0 for simpler UX
    return f"{secrets.randbelow(9) + 1}{secrets.randbelow(10 ** (OTP_LENGTH - 1)):0{OTP_LENGTH - 1}d}"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


async def request_otp(channel: str, target: str, db: AsyncSession) -> str:
    """Issue an OTP for the channel/target and deliver it.

    Returns the code in sandbox mode (so local flows can complete), otherwise
    an empty string — in live mode the code only travels via email/SMS.
    """
    target = target.strip()
    code = _generate_code()
    now = _utcnow()

    # Invalidate any outstanding codes for this target, then store the new one.
    await db.execute(
        delete(VerificationCode).where(
            VerificationCode.channel == channel,
            VerificationCode.target == target.lower(),
        )
    )
    db.add(VerificationCode(
        channel=channel,
        target=target.lower(),
        code_hash=_hash(code),
        expires_at=now + timedelta(seconds=OTP_TTL_SECONDS),
    ))

    # Best-effort Redis mirror so a deployment with Redis avoids a DB read.
    redis = await get_redis()
    if redis is not None:
        try:
            await redis.set(_key(channel, target), code, ex=OTP_TTL_SECONDS)
        except Exception:
            logger.debug("Redis OTP mirror failed (non-fatal)", exc_info=True)

    if getattr(settings, "VERIFICATION_MODE", "sandbox") == "live":
        if channel == "email":
            from app.services.email import send_otp_email
            sent = await send_otp_email(target, code)
        else:
            from app.services.sms import send_otp_sms
            sent = await send_otp_sms(target, code)
        if not sent:
            logger.warning(
                "OTP for %s %s could not be delivered (gateway not configured or failed)",
                channel, target,
            )
        return ""

    logger.info("OTP for %s %s: %s (sandbox)", channel, target, code)
    return code


async def verify_otp(channel: str, target: str, code: str, db: AsyncSession) -> bool:
    """Validate an OTP for the channel/target. Consumes the code on success."""
    target = target.strip().lower()
    submitted = (code or "").strip()
    if not submitted:
        return False

    row = (await db.execute(
        select(VerificationCode)
        .where(
            VerificationCode.channel == channel,
            VerificationCode.target == target,
            VerificationCode.consumed.is_(False),
        )
        .order_by(VerificationCode.created_at.desc())
        .limit(1)
    )).scalar_one_or_none()

    if row is None:
        return False

    # Expired: drop it and reject.
    expires_at = row.expires_at
    if expires_at is not None and expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at is None or expires_at < _utcnow():
        await db.delete(row)
        return False

    if secrets.compare_digest(row.code_hash, _hash(submitted)):
        row.consumed = True
        await db.flush()
        redis = await get_redis()
        if redis is not None:
            try:
                await redis.delete(_key(channel, target))
            except Exception:
                pass
        return True

    # Wrong code: count the attempt and burn the code once the limit is hit.
    row.attempts = (row.attempts or 0) + 1
    if row.attempts >= MAX_ATTEMPTS:
        await db.delete(row)
    await db.flush()
    return False
