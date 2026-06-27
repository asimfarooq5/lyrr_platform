"""
Security utilities - JWT, encryption, password hashing
"""

from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from jose import JWTError, jwt
from passlib.context import CryptContext
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64
import hashlib
import hmac
import secrets
import json

from app.core.config import settings

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Encryption - Generate proper Fernet key from settings
# Fernet requires 32 url-safe base64-encoded bytes
def _get_fernet_key():
    """Generate a valid Fernet key from settings"""
    key_material = settings.ENCRYPTION_KEY.encode()
    # Use PBKDF2 to derive a proper key
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=b'lyrr-platform-salt',  # In production, use a proper salt
        iterations=100000,
    )
    key = base64.urlsafe_b64encode(kdf.derive(key_material))
    return key

cipher_suite = Fernet(_get_fernet_key())


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password"""
    return pwd_context.hash(password)


def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt


def create_refresh_token(data: Dict[str, Any]) -> str:
    """Create JWT refresh token"""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt


def decode_token(token: str) -> Optional[Dict[str, Any]]:
    """Decode and verify JWT token"""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        return payload
    except JWTError:
        return None


def encrypt_data(data: str) -> str:
    """Encrypt sensitive data"""
    return cipher_suite.encrypt(data.encode()).decode()


def decrypt_data(encrypted_data: str) -> str:
    """Decrypt sensitive data"""
    return cipher_suite.decrypt(encrypted_data.encode()).decode()


def generate_device_fingerprint(device_info: Dict[str, str]) -> str:
    """Generate unique device fingerprint"""
    data = json.dumps(device_info, sort_keys=True)
    return hashlib.sha256(data.encode()).hexdigest()[:32]


def generate_drm_key(book_id: str, user_id: str, device_id: str) -> str:
    """Generate DRM license key"""
    secret = f"{book_id}:{user_id}:{device_id}:{settings.SECRET_KEY}"
    return hmac.new(
        settings.SECRET_KEY.encode(),
        secret.encode(),
        hashlib.sha256
    ).hexdigest()[:32]


def verify_drm_key(key: str, book_id: str, user_id: str, device_id: str) -> bool:
    """Verify DRM license key"""
    expected = generate_drm_key(book_id, user_id, device_id)
    return hmac.compare_digest(key, expected)


def generate_secure_token(length: int = 32) -> str:
    """Generate cryptographically secure random token"""
    return secrets.token_urlsafe(length)


# Dependency for FastAPI
def get_current_active_user(token: str = None) -> Optional[Dict[str, Any]]:
    """
    Get current active user from token
    This is a simplified version - in production, use proper dependency injection
    """
    if not token:
        return None
    return decode_token(token)
