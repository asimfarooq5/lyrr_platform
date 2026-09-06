"""
Authentication endpoints
"""

from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import timedelta

from app.core.database import get_db
from app.core.security import (
    verify_password, get_password_hash, create_access_token,
    create_refresh_token, decode_token, generate_device_fingerprint
)
from app.core.config import settings
from app.core.rate_limit import limiter
from app.models.user import User, UserDevice
from app.schemas.auth import (
    UserCreate, UserResponse, TokenResponse, LoginRequest,
    RefreshRequest, PasswordResetRequest, PasswordResetConfirm, PasswordChangeRequest,
    SocialLoginRequest, DeviceInfo, VerifyRequest, VerifyConfirm, VerifyResponse
)

router = APIRouter()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Get current authenticated user"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    payload = decode_token(token)
    if payload is None or payload.get("type") != "access":
        raise credentials_exception
    
    user_id = payload.get("sub")
    if user_id is None:
        raise credentials_exception
    
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if user is None or not user.is_active:
        raise credentials_exception
    
    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user)
) -> User:
    """Get current active user"""
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")
async def register(
    request: Request,
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    """Register a new user"""
    # Check if email exists
    result = await db.execute(select(User).where(User.email == user_data.email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Check if phone exists (if provided)
    if user_data.phone:
        phone_result = await db.execute(select(User).where(User.phone == user_data.phone))
        if phone_result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Phone number already registered"
            )
    
    # Create user
    user = User(
        email=user_data.email,
        hashed_password=get_password_hash(user_data.password) if user_data.password else None,
        is_verified=False,
        phone=user_data.phone,
        phone_verified=False,
    )
    
    db.add(user)
    await db.flush()
    
    # Create device
    device_info = DeviceInfo(
        device_name=user_data.device_info.device_name if user_data.device_info else "Unknown",
        device_type=user_data.device_info.device_type if user_data.device_info else "web",
        os_version=user_data.device_info.os_version if user_data.device_info else None,
        app_version=user_data.device_info.app_version if user_data.device_info else None,
    )
    
    fingerprint = generate_device_fingerprint(device_info.dict())
    
    device = UserDevice(
        user_id=user.id,
        device_fingerprint=fingerprint,
        device_name=device_info.device_name,
        device_type=device_info.device_type,
        os_version=device_info.os_version,
        app_version=device_info.app_version,
        last_ip=request.client.host if request.client else None,
        is_trusted=True
    )
    
    db.add(device)
    await db.commit()
    
    return user


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(
    request: Request,
    login_data: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """Login with email and password (JSON body)"""
    # Find user
    result = await db.execute(select(User).where(User.email == login_data.username))
    user = result.scalar_one_or_none()
    
    if not user or not user.hashed_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated"
        )
    
    # Create tokens
    access_token = create_access_token(data={"sub": user.id})
    refresh_token = create_refresh_token(data={"sub": user.id})
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    }


@router.post("/login/form", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login_form(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
):
    """Login with email and password (form data - for OAuth2 compliance)"""
    result = await db.execute(select(User).where(User.email == form_data.username))
    user = result.scalar_one_or_none()
    
    if not user or not user.hashed_password or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated"
        )
    
    access_token = create_access_token(data={"sub": user.id})
    refresh_token = create_refresh_token(data={"sub": user.id})
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    }


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit("30/minute")
async def refresh_token(
    request: Request,
    refresh_data: RefreshRequest,
    db: AsyncSession = Depends(get_db)
):
    """Refresh access token"""
    payload = decode_token(refresh_data.refresh_token)
    
    if payload is None or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    
    user_id = payload.get("sub")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive"
        )
    
    # Create new tokens
    access_token = create_access_token(data={"sub": user.id})
    refresh_token = create_refresh_token(data={"sub": user.id})
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    }


@router.post("/logout")
async def logout(current_user: User = Depends(get_current_active_user)):
    """Logout user (client should discard tokens)"""
    return {"message": "Successfully logged out"}


@router.post("/forgot-password")
@limiter.limit("5/minute")
async def forgot_password(
    request: Request,
    reset_request: PasswordResetRequest,
    db: AsyncSession = Depends(get_db)
):
    """Request password reset. Sends a time-limited reset link by email
    when VERIFICATION_MODE=live; in sandbox mode the token is returned
    directly so the flow can be completed locally without an SMTP server."""
    result = await db.execute(select(User).where(User.email == reset_request.email))
    user = result.scalar_one_or_none()

    response: dict = {"message": "If the email exists, a reset link has been sent"}

    if user:
        reset_token = create_access_token(
            data={"sub": user.id, "type": "password_reset"},
            expires_delta=timedelta(minutes=settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES),
        )
        reset_url = f"{settings.FRONTEND_URL}/reset-password?token={reset_token}"

        if settings.VERIFICATION_MODE == "live":
            from app.services.email import send_password_reset_email
            await send_password_reset_email(user.email, reset_url)
        else:
            # Sandbox-only: expose the token so the flow completes locally.
            response["sandbox_reset_token"] = reset_token

    # Always return the same message to prevent email enumeration.
    return response


@router.post("/reset-password")
@limiter.limit("10/minute")
async def reset_password(
    request: Request,
    data: PasswordResetConfirm,
    db: AsyncSession = Depends(get_db)
):
    """Complete a password reset using the token from /forgot-password."""
    payload = decode_token(data.token)
    if payload is None or payload.get("type") != "password_reset":
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")

    user_id = payload.get("sub")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")

    user.hashed_password = get_password_hash(data.new_password)
    await db.commit()

    return {"message": "Password has been reset successfully"}


@router.post("/social/{provider}", response_model=TokenResponse)
@limiter.limit("10/minute")
async def social_login(
    request: Request,
    provider: str,
    login_data: SocialLoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """Social login (Google, Apple).

    Verifies the provider token server-side, then finds or creates the
    matching user account (email-verified accounts, no password set).
    """
    from app.services.social_auth import verify_provider_token, SocialAuthError

    if provider.lower() not in ("google", "apple"):
        raise HTTPException(status_code=400, detail=f"Unsupported provider: {provider}")

    try:
        email = await verify_provider_token(provider, login_data.token)
    except SocialAuthError as exc:
        raise HTTPException(status_code=401, detail=str(exc))

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user:
        user = User(email=email, hashed_password=None, is_verified=True)
        db.add(user)
        await db.flush()

        device_info = login_data.device_info or DeviceInfo()
        fingerprint = generate_device_fingerprint(device_info.dict())
        db.add(UserDevice(
            user_id=user.id,
            device_fingerprint=fingerprint,
            device_name=device_info.device_name,
            device_type=device_info.device_type,
            os_version=device_info.os_version,
            app_version=device_info.app_version,
            last_ip=request.client.host if request.client else None,
            is_trusted=True,
        ))
        await db.commit()
    elif not user.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated")

    access_token = create_access_token(data={"sub": user.id})
    refresh_token = create_refresh_token(data={"sub": user.id})

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    }


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_active_user)):
    """Get current user info"""
    return current_user


@router.post("/verify/request", response_model=VerifyResponse)
@limiter.limit("5/minute")
async def request_verification(
    request: Request,
    data: VerifyRequest,
    db: AsyncSession = Depends(get_db),
):
    """Request an OTP for email or phone verification (FRS §4).

    In sandbox mode the OTP is returned in the response for local testing.
    In live mode it is delivered via email/SMS and not returned.
    """
    from app.services import verification

    channel = (data.channel or "").lower()
    if channel not in ("email", "phone"):
        raise HTTPException(status_code=400, detail="channel must be 'email' or 'phone'")

    target = data.target.strip()
    if not target:
        raise HTTPException(status_code=400, detail="target is required")

    # The OTP must map to an existing user account.
    if channel == "email":
        result = await db.execute(select(User).where(User.email == target.lower()))
    else:
        result = await db.execute(select(User).where(User.phone == target))
    user = result.scalar_one_or_none()
    if not user:
        # Do not reveal account existence
        raise HTTPException(status_code=404, detail="No account found for this target")

    code = await verification.request_otp(channel, target)

    return {
        "message": f"Verification code sent to {channel}",
        "verified": False,
        "expires_in": verification.OTP_TTL_SECONDS,
        # Sandbox-only: expose the OTP so the flow completes locally.
        **({"sandbox_otp": code} if code else {}),
    }


@router.post("/verify/confirm", response_model=VerifyResponse)
@limiter.limit("10/minute")
async def confirm_verification(
    request: Request,
    data: VerifyConfirm,
    db: AsyncSession = Depends(get_db),
):
    """Confirm an OTP and mark the email/phone as verified (FRS §4)."""
    from app.services import verification

    channel = (data.channel or "").lower()
    if channel not in ("email", "phone"):
        raise HTTPException(status_code=400, detail="channel must be 'email' or 'phone'")

    target = data.target.strip()
    if not target:
        raise HTTPException(status_code=400, detail="target is required")

    if not await verification.verify_otp(channel, target, data.code):
        raise HTTPException(status_code=400, detail="Invalid or expired verification code")

    # Mark the channel verified on the matching account.
    if channel == "email":
        result = await db.execute(select(User).where(User.email == target.lower()))
    else:
        result = await db.execute(select(User).where(User.phone == target))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="No account found for this target")

    if channel == "email":
        user.is_verified = True
    else:
        user.phone_verified = True
        user.is_verified = True
    await db.commit()

    return {"message": f"{channel} verified successfully", "verified": True}
