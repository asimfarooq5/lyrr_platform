"""
Rate limiting setup.

The Limiter is created here so both main.py (exception handler wiring)
and individual endpoints (e.g. login) can share the same instance.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

from app.core.config import settings

limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[f"{settings.RATE_LIMIT_REQUESTS}/{settings.RATE_LIMIT_WINDOW}second"],
    enabled=settings.RATE_LIMIT_ENABLED,
)
