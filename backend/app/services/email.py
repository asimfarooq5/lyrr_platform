"""
Email delivery service.

Sends transactional email (OTP codes, password reset links) via SMTP.
No-ops with a log line when SMTP is not configured, so local/demo
deployments keep working without credentials.
"""

from __future__ import annotations

import logging
from email.message import EmailMessage

from app.core.config import settings

logger = logging.getLogger(__name__)


def is_configured() -> bool:
    return bool(settings.SMTP_HOST and settings.SMTP_USERNAME and settings.SMTP_PASSWORD)


async def send_email(to: str, subject: str, body: str, html_body: str | None = None) -> bool:
    """Send an email. Returns True if a delivery attempt was made and succeeded."""
    if not is_configured():
        logger.info("SMTP not configured; skipping email to %s (subject=%r)", to, subject)
        return False

    import aiosmtplib

    message = EmailMessage()
    message["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
    message["To"] = to
    message["Subject"] = subject
    message.set_content(body)
    if html_body:
        message.add_alternative(html_body, subtype="html")

    try:
        await aiosmtplib.send(
            message,
            hostname=settings.SMTP_HOST,
            port=settings.SMTP_PORT,
            username=settings.SMTP_USERNAME,
            password=settings.SMTP_PASSWORD,
            start_tls=settings.SMTP_USE_TLS,
        )
        return True
    except Exception:
        logger.exception("Failed to send email to %s", to)
        return False


async def send_otp_email(to: str, code: str) -> bool:
    return await send_email(
        to,
        subject="Your LYRR verification code",
        body=f"Your LYRR verification code is {code}. It expires in 10 minutes.",
        html_body=f"<p>Your LYRR verification code is <strong>{code}</strong>.</p>"
                  f"<p>It expires in 10 minutes.</p>",
    )


async def send_password_reset_email(to: str, reset_url: str) -> bool:
    return await send_email(
        to,
        subject="Reset your LYRR password",
        body=f"Reset your password using this link (valid for "
             f"{settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES} minutes): {reset_url}",
        html_body=f"<p>Reset your password using the link below "
                  f"(valid for {settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES} minutes):</p>"
                  f'<p><a href="{reset_url}">{reset_url}</a></p>',
    )
