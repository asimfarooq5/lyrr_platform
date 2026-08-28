"""
CSRF token generation and validation for admin portal

Uses Redis as the token store when available (correct for multi-worker
deployments), falling back to in-memory storage for single-process dev.
"""

import secrets
import hmac
import time
import logging
from typing import Optional

from app.core.redis import get_redis

logger = logging.getLogger(__name__)

# In-memory token store fallback: {session_id: {"token": str, "expires_at": float}}
_csrf_tokens: dict = {}

CSRF_TOKEN_EXPIRY_SECONDS = 86400  # 24 hours
CSRF_TOKEN_BYTES = 32

# Redis key prefix for CSRF tokens
_CSRF_KEY_PREFIX = "lyrr:csrf:"


def _csrf_key(session_id: str) -> str:
    return f"{_CSRF_KEY_PREFIX}{session_id}"


def _cleanup_expired() -> None:
    """Remove expired tokens from in-memory store (fallback only)"""
    now = time.time()
    expired = [sid for sid, data in _csrf_tokens.items() if data.get("expires_at", 0) < now]
    for sid in expired:
        del _csrf_tokens[sid]


async def generate_csrf_token(session_id: str) -> str:
    """Generate and store a CSRF token for a session"""
    token = secrets.token_urlsafe(CSRF_TOKEN_BYTES)
    redis = await get_redis()
    if redis is not None:
        try:
            await redis.set(_csrf_key(session_id), token, ex=CSRF_TOKEN_EXPIRY_SECONDS)
            return token
        except Exception as e:
            logger.warning(f"Redis CSRF store unavailable, falling back to memory: {e}")
    _cleanup_expired()
    _csrf_tokens[session_id] = {
        "token": token,
        "expires_at": time.time() + CSRF_TOKEN_EXPIRY_SECONDS,
    }
    return token


async def verify_csrf_token(session_id: str, token: str) -> bool:
    """Verify a CSRF token for a session using constant-time comparison"""
    if not token or not session_id:
        return False
    redis = await get_redis()
    if redis is not None:
        try:
            expected = await redis.get(_csrf_key(session_id))
            if expected is None:
                return False
            if hmac.compare_digest(expected, token):
                await redis.delete(_csrf_key(session_id))
                return True
            return False
        except Exception as e:
            logger.warning(f"Redis CSRF verification failed, falling back to memory: {e}")
    data = _csrf_tokens.get(session_id)
    if not data:
        return False
    expected = data.get("token")
    if not expected:
        return False
    # Check expiry
    if data.get("expires_at", 0) < time.time():
        del _csrf_tokens[session_id]
        return False
    # Constant-time comparison
    result = hmac.compare_digest(expected, token)
    # Remove used token (one-time use)
    if result:
        del _csrf_tokens[session_id]
    return result


async def revoke_csrf_tokens(session_id: str) -> None:
    """Revoke all CSRF tokens for a session (e.g., on logout)"""
    redis = await get_redis()
    if redis is not None:
        try:
            await redis.delete(_csrf_key(session_id))
            return
        except Exception as e:
            logger.warning(f"Redis CSRF revoke failed, falling back to memory: {e}")
    _csrf_tokens.pop(session_id, None)
