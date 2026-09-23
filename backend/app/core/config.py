"""
Application configuration
"""

from pydantic_settings import BaseSettings
from pydantic import field_validator
from typing import List, Optional
import os


class Settings(BaseSettings):
    # App
    APP_NAME: str = "LYRR Platform"
    DEBUG: bool = False
    ENVIRONMENT: str = "production"
    
    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # Database
    DATABASE_URL: str = "postgresql+asyncpg://user:pass@localhost/lyrr"
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 10
    
    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # Elasticsearch
    ELASTICSEARCH_URL: str = "http://localhost:9200"
    
    # Security
    SECRET_KEY: str = "your-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # Encryption
    ENCRYPTION_KEY: str = "your-encryption-key-32-chars-long"
    DRM_KEY_ROTATION_HOURS: int = 24
    
    # AWS/S3
    AWS_ACCESS_KEY_ID: Optional[str] = None
    AWS_SECRET_ACCESS_KEY: Optional[str] = None
    AWS_REGION: str = "us-east-1"
    S3_BUCKET: str = "lyrr-media"
    S3_ENDPOINT: Optional[str] = None
    
    # AI Services
    OPENAI_API_KEY: Optional[str] = None
    ANTHROPIC_API_KEY: Optional[str] = None
    ELEVENLABS_API_KEY: Optional[str] = None
    
    # OAuth
    GOOGLE_CLIENT_ID: Optional[str] = None
    GOOGLE_CLIENT_SECRET: Optional[str] = None
    APPLE_CLIENT_ID: Optional[str] = None
    APPLE_CLIENT_SECRET: Optional[str] = None
    
    # CORS
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "https://lyrr.app",
        "https://admin.lyrr.app",
    ]
    # Flutter's web dev server binds a new random localhost port every run,
    # so a fixed allow-list can never cover it — match any localhost/127.0.0.1
    # port instead. Only applied outside production (see main.py).
    CORS_ORIGIN_REGEX_DEV: str = r"^https?://(localhost|127\.0\.0\.1):\d+$"
    
    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_REQUESTS: int = 100
    RATE_LIMIT_WINDOW: int = 60
    
    # Media
    MAX_UPLOAD_SIZE_MB: int = 500
    MAX_COVER_SIZE_MB: int = 10
    MEDIA_AUTH_ENABLED: bool = True
    SUPPORTED_AUDIO_FORMATS: List[str] = ["mp3", "m4a", "wav", "flac"]
    ALLOWED_AUDIO_MIME_TYPES: List[str] = ["audio/mpeg", "audio/mp4", "audio/wav", "audio/flac", "audio/x-m4a", "audio/aac"]
    ALLOWED_IMAGE_MIME_TYPES: List[str] = ["image/jpeg", "image/png", "image/webp"]
    
    # CSRF
    CSRF_ENABLED: bool = True
    
    # Sync
    SYNC_BATCH_SIZE: int = 100
    SYNC_CONFLICT_RESOLUTION: str = "server_wins"
    
    # Payments
    PAYMENT_MODE: str = "sandbox"  # sandbox or live
    PAYMENT_CURRENCY: str = "XAF"
    DEFAULT_BOOK_PRICE: float = 500.0

    # Live payment gateway credentials (only required when PAYMENT_MODE=live)
    STRIPE_SECRET_KEY: Optional[str] = None
    STRIPE_WEBHOOK_SECRET: Optional[str] = None

    # CamPay — Mobile Money aggregator for MTN + Orange (Cameroon).
    # Docs: https://demo.campay.net/en/developer/
    # Sandbox base: https://demo.campay.net/api   Production: https://www.campay.net/api
    CAMPAY_BASE_URL: str = "https://demo.campay.net/api"
    # Either the permanent app token (APP KEYS) or the app username/password
    # issued when you register an application on Campay.
    CAMPAY_PERMANENT_TOKEN: Optional[str] = None
    CAMPAY_USERNAME: Optional[str] = None
    CAMPAY_PASSWORD: Optional[str] = None
    # Used to validate the HS256 JWT signature on Campay webhook callbacks.
    CAMPAY_WEBHOOK_KEY: Optional[str] = None

    # Email/phone verification + password reset delivery
    VERIFICATION_MODE: str = "sandbox"  # sandbox (return code) or live (send email/SMS)
    # Safety gate: even in sandbox/VERIFICATION_MODE, OTPs and password-reset
    # tokens are only echoed back in API responses when this is explicitly
    # enabled AND the app is not running in production. Defaults to False so a
    # production deploy can never leak credentials through a mis-set sandbox
    # mode.
    DEV_EXPOSE_TOKENS: bool = False
    SMTP_HOST: Optional[str] = None
    SMTP_PORT: int = 587
    SMTP_USERNAME: Optional[str] = None
    SMTP_PASSWORD: Optional[str] = None
    SMTP_USE_TLS: bool = True
    SMTP_FROM_EMAIL: str = "no-reply@lyrr.app"
    SMTP_FROM_NAME: str = "LYRR"

    # Generic HTTP SMS gateway (Twilio-compatible). SMS_API_URL receives a
    # POST with {"to": ..., "message": ...} plus SMS_API_KEY as a Bearer token.
    SMS_API_URL: Optional[str] = None
    SMS_API_KEY: Optional[str] = None
    SMS_SENDER_ID: str = "LYRR"

    # Password reset links point back at the client app / web portal.
    FRONTEND_URL: str = "http://localhost:8080"
    PASSWORD_RESET_TOKEN_EXPIRE_MINUTES: int = 30

    # This API's own publicly reachable base URL - used for server-to-server
    # gateway callbacks (e.g. Orange Money's notif_url), which must hit this
    # backend, not the frontend/web portal that FRONTEND_URL points at.
    PUBLIC_API_URL: str = "http://localhost:8000"

    # Bypass per-book purchase checks so all published books are readable
    # by any authenticated user. Defaults to False (FRS §14: books/audio must
    # not be accessible without a valid purchase/subscription); flip to True
    # only for demo/sandbox deployments that intentionally skip licensing.
    BYPASS_LIBRARY_PERMISSIONS: bool = False

    # Lifetime of the short-lived, book-scoped token that audio URLs carry in
    # their query string (players and the downloader cannot send headers).
    # Long enough to cover one listening session plus seeking/seeking-retries,
    # short enough that a URL leaked into a log stops working quickly.
    MEDIA_TOKEN_EXPIRE_MINUTES: int = 180

    @property
    def expose_dev_tokens(self) -> bool:
        """True only when it is safe to echo OTPs / reset tokens in responses.

        Requires an explicit opt-in AND a non-production environment, so a
        production deployment can never leak credentials via a leftover sandbox
        setting.
        """
        return self.DEV_EXPOSE_TOKENS and self.ENVIRONMENT != "production"
    
    @field_validator("SECRET_KEY")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        if v in ("your-secret-key-change-in-production", "", "your-secret-key"):
            raise ValueError(
                "SECRET_KEY must be changed from the default value. "
                "Generate a strong key with: openssl rand -hex 32"
            )
        if len(v) < 32:
            raise ValueError(
                f"SECRET_KEY must be at least 32 characters (got {len(v)}). "
                "Generate a strong key with: openssl rand -hex 32"
            )
        return v
    
    @field_validator("ENCRYPTION_KEY")
    @classmethod
    def validate_encryption_key(cls, v: str) -> str:
        if v in ("your-encryption-key-32-chars-long", "", "your-encryption-key"):
            raise ValueError(
                "ENCRYPTION_KEY must be changed from the default value. "
                "Generate a key with: openssl rand -hex 16"
            )
        if len(v) < 16:
            raise ValueError(
                f"ENCRYPTION_KEY must be at least 16 characters (got {len(v)})"
            )
        return v
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"


settings = Settings()
