"""
Email/phone verification service (FRS §4).

Generates and validates one-time passcodes (OTP) for email and phone
verification. Uses Redis as the store when available and falls back to an
in-process cache otherwise, so the flow works in any deployment.

Sending is intentionally a no-op log in sandbox mode: the OTP is returned in
the response so local development can complete verification. Set
VERIFICATION_MODE=live and wire a provider (email SMTP / SMS gateway) for real
delivery.
"""

from __future__ import annotations

import logging
import secrets
import time
from typing import Optional

from app.core.config import settings
from app.core.redis import get_redis

logger = logging.getLogger(__name__)

OTP_TTL_SECONDS = 600  # 10 minutes
OTP_LENGTH = 6
MAX_ATTEMPTS = 5

# In-process fallback store: {key: {"code": ..., "expires_at": ..., "attempts": ...}}
_memory_store: dict = {}


def _key(channel: str, target: str) -> str:
    return f"lyrr:otp:{channel}:{target.strip().lower()}"


def _generate_code() -> str:
    # 6-digit numeric code, first digit never 0 for simpler UX
    return f"{secrets.randbelow(9) + 1}{secrets.randbelow(10 ** (OTP_LENGTH - 1)):0{OTP_LENGTH - 1}d}"


async def _store_otp(key: str, code: str) -> None:
    redis = await get_redis()
    if redis is not None:
        try:
            await redis.set(key, code, ex=OTP_TTL_SECONDS)
            return
        except Exception:
            logger.warning("Redis OTP store failed; using in-memory fallback")
    _memory_store[key] = {"code": code, "expires_at": time.time() + OTP_TTL_SECONDS, "attempts": 0}


async def _get_otp(key: str) -> Optional[str]:
    redis = await get_redis()
    if redis is not None:
        try:
            return await redis.get(key)
        except Exception:
            logger.warning("Redis OTP read failed; using in-memory fallback")
    entry = _memory_store.get(key)
    if not entry:
        return None
    if entry["expires_at"] < time.time():
        _memory_store.pop(key, None)
        return None
    return entry["code"]


async def _delete_otp(key: str) -> None:
    redis = await get_redis()
    if redis is not None:
        try:
            await redis.delete(key)
            return
        except Exception:
            pass
    _memory_store.pop(key, None)


async def request_otp(channel: str, target: str) -> str:
    """Generate and 'send' an OTP for the given channel/target.

    Returns the OTP. In sandbox mode the OTP is returned to the caller so the
    verification flow can complete locally; in live mode it would be emailed or
    SMS'd instead of being returned.
    """
    code = _generate_code()
    await _store_otp(_key(channel, target), code)
    if getattr(settings, "VERIFICATION_MODE", "sandbox") == "live":
        # TODO: send real email/SMS here
        logger.info("OTP for %s %s would be sent (live mode)", channel, target)
        return ""
    logger.info("OTP for %s %s: %s (sandbox)", channel, target, code)
    return code


async def verify_otp(channel: str, target: str, code: str) -> bool:
    """Validate an OTP. Returns True on success and consumes the code."""
    key = _key(channel, target)
    stored = await _get_otp(key)
    if stored is None:
        return False
    if secrets.compare_digest(stored, code.strip()):
        await _delete_otp(key)
        return True
    # Track attempts (best-effort) and clear after MAX_ATTEMPTS failures
    entry = _memory_store.get(key)
    if entry:
        entry["attempts"] = entry.get("attempts", 0) + 1
        if entry["attempts"] >= MAX_ATTEMPTS:
            await _delete_otp(key)
    return False