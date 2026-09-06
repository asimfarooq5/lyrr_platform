"""
SMS delivery service.

Sends SMS via a generic HTTP gateway (SMS_API_URL), which covers most
aggregators (Twilio, Africa's Talking, local Orange/MTN SMS APIs) that
accept a bearer-authenticated POST with {"to", "message", "sender_id"}.
No-ops with a log line when no gateway is configured.
"""

from __future__ import annotations

import logging

from app.core.config import settings

logger = logging.getLogger(__name__)


def is_configured() -> bool:
    return bool(settings.SMS_API_URL)


async def send_sms(to: str, message: str) -> bool:
    if not is_configured():
        logger.info("SMS gateway not configured; skipping SMS to %s", to)
        return False

    import httpx

    headers = {}
    if settings.SMS_API_KEY:
        headers["Authorization"] = f"Bearer {settings.SMS_API_KEY}"

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                settings.SMS_API_URL,
                json={"to": to, "message": message, "sender_id": settings.SMS_SENDER_ID},
                headers=headers,
            )
            response.raise_for_status()
        return True
    except Exception:
        logger.exception("Failed to send SMS to %s", to)
        return False


async def send_otp_sms(to: str, code: str) -> bool:
    return await send_sms(to, f"Your LYRR verification code is {code}. It expires in 10 minutes.")
