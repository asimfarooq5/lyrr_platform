"""
LYRR Platform Backend API
FastAPI-based backend with enterprise features
"""

from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.exceptions import RequestValidationError, HTTPException as StarletteHTTPException
from contextlib import asynccontextmanager

from app.core.config import settings
from app.core.database import init_db, close_db
from app.core.exceptions import (
    http_exception_handler,
    validation_exception_handler,
    general_exception_handler,
)
try:
    from app.core.redis import init_redis, close_redis
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False
    
    async def init_redis():
        pass
    
    async def close_redis():
        pass
from app.api.v1.router import api_router
from app.api.v1.endpoints.admin_portal import router as admin_portal_router
from app.api.v1.endpoints.media_stream import router as media_stream_router
from app.core.logging import setup_logging
import logging

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    # Startup
    setup_logging()
    logger.info("Starting up LYRR Platform...")
    
    await init_db()
    await init_redis()
    
    logger.info(f"LYRR Platform started successfully (environment={settings.ENVIRONMENT})")
    yield
    
    # Shutdown
    logger.info("Shutting down LYRR Platform...")
    await close_redis()
    await close_db()
    logger.info("LYRR Platform shut down successfully")


app = FastAPI(
    title="LYRR Platform API",
    description="Enterprise audiobook synchronization platform",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
)

# ---- Exception Handlers ----
app.add_exception_handler(HTTPException, http_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(Exception, general_exception_handler)
app.add_exception_handler(StarletteHTTPException, http_exception_handler)

# ---- Rate Limiting ----
if settings.RATE_LIMIT_ENABLED:
    try:
        from slowapi import _rate_limit_exceeded_handler
        from slowapi.errors import RateLimitExceeded
        from app.core.rate_limit import limiter

        app.state.limiter = limiter
        app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
        logger.info(f"Rate limiting enabled: {settings.RATE_LIMIT_REQUESTS}/{settings.RATE_LIMIT_WINDOW}s")
    except ImportError:
        logger.warning("slowapi not installed — rate limiting disabled. Install with: pip install slowapi")

# ---- Middleware ----
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)

# ---- Include API routes ----
app.include_router(api_router, prefix="/api/v1")

# Admin portal routes (Jinja2 templates)
app.include_router(admin_portal_router, prefix="/admin")

# Media streaming (audio + cover images)
app.include_router(media_stream_router, prefix="/media")


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT,
    }


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "name": "LYRR Platform",
        "version": "1.0.0",
        "description": "Enterprise audiobook synchronization platform",
        "docs": "/docs" if settings.DEBUG else None,
    }
