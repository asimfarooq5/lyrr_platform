"""
Social login token verification (FRS §4 - secure login).

Verifies a Google ID token or Apple identity token presented by the client
and returns the verified email address. Raises SocialAuthError on any
failure (bad signature, wrong audience, expired token, provider not
configured).
"""

from __future__ import annotations

import logging
from typing import Optional

from starlette.concurrency import run_in_threadpool

from app.core.config import settings

logger = logging.getLogger(__name__)


class SocialAuthError(Exception):
    """Raised when a social login token cannot be verified."""


def _verify_google_sync(token: str) -> dict:
    from google.oauth2 import id_token as google_id_token
    from google.auth.transport import requests as google_requests

    return google_id_token.verify_oauth2_token(
        token, google_requests.Request(), audience=settings.GOOGLE_CLIENT_ID
    )


async def verify_google_token(token: str) -> str:
    """Verify a Google ID token and return the verified email."""
    if not settings.GOOGLE_CLIENT_ID:
        raise SocialAuthError("Google login is not configured (GOOGLE_CLIENT_ID missing)")
    try:
        claims = await run_in_threadpool(_verify_google_sync, token)
    except Exception as exc:
        raise SocialAuthError(f"Invalid Google token: {exc}") from exc

    email = claims.get("email")
    if not email:
        raise SocialAuthError("Google token did not include an email")
    if not claims.get("email_verified", False):
        raise SocialAuthError("Google email is not verified")
    return email


async def verify_apple_token(token: str) -> str:
    """Verify an Apple identity token (JWT signed by Apple) and return the email."""
    if not settings.APPLE_CLIENT_ID:
        raise SocialAuthError("Apple login is not configured (APPLE_CLIENT_ID missing)")

    import httpx
    from jose import jwt as jose_jwt

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get("https://appleid.apple.com/auth/keys")
            resp.raise_for_status()
            jwks = resp.json()

        unverified_header = jose_jwt.get_unverified_header(token)
        key = next(
            (k for k in jwks["keys"] if k["kid"] == unverified_header.get("kid")), None
        )
        if key is None:
            raise SocialAuthError("Apple signing key not found")

        claims = jose_jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=settings.APPLE_CLIENT_ID,
            issuer="https://appleid.apple.com",
        )
    except SocialAuthError:
        raise
    except Exception as exc:
        raise SocialAuthError(f"Invalid Apple token: {exc}") from exc

    email = claims.get("email")
    if not email:
        raise SocialAuthError("Apple token did not include an email")
    return email


async def verify_provider_token(provider: str, token: str) -> str:
    provider = (provider or "").lower()
    if provider == "google":
        return await verify_google_token(token)
    if provider == "apple":
        return await verify_apple_token(token)
    raise SocialAuthError(f"Unsupported provider: {provider}")
