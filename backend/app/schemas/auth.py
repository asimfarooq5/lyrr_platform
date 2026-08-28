"""
Authentication schemas
"""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime


class DeviceInfo(BaseModel):
    device_name: Optional[str] = None
    device_type: Optional[str] = "web"  # ios, android, web, desktop
    os_version: Optional[str] = None
    app_version: Optional[str] = None


class UserBase(BaseModel):
    email: EmailStr


class UserCreate(UserBase):
    password: str = Field(..., min_length=8)
    device_info: Optional[DeviceInfo] = None
    phone: Optional[str] = None


class UserResponse(UserBase):
    id: str
    is_active: bool
    is_verified: bool
    is_admin: bool
    created_at: datetime
    phone: Optional[str] = None
    phone_verified: bool = False
    
    class Config:
        from_attributes = True


class LoginRequest(BaseModel):
    username: str
    password: str
    grant_type: Optional[str] = "password"
    device_info: Optional[DeviceInfo] = None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class RefreshRequest(BaseModel):
    refresh_token: str


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8)


class SocialLoginRequest(BaseModel):
    token: str
    device_info: Optional[DeviceInfo] = None


class MagicLinkRequest(BaseModel):
    email: EmailStr


class MagicLinkResponse(BaseModel):
    message: str


class VerifyRequest(BaseModel):
    """Request an OTP for email or phone verification."""
    channel: str  # "email" or "phone"
    target: str   # email address or phone number


class VerifyConfirm(BaseModel):
    """Confirm an OTP and mark the channel verified."""
    channel: str  # "email" or "phone"
    target: str   # email address or phone number
    code: str


class VerifyResponse(BaseModel):
    message: str
    verified: bool = False
    expires_in: Optional[int] = None
    # Sandbox-only: the OTP is returned to the caller for local testing.
    # Never populated in live mode (delivered via email/SMS instead).
    sandbox_otp: Optional[str] = None
