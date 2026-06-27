"""
LYRR Platform Backend API
FastAPI-based backend with enterprise features
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.core.database import init_db, close_db
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
    
    logger.info("LYRR Platform started successfully")
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

# Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)

# Include API routes
app.include_router(api_router, prefix="/api/v1")


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "version": "1.0.0"}


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "name": "LYRR Platform",
        "version": "1.0.0",
        "description": "Enterprise audiobook synchronization platform",
        "docs": "/docs" if settings.DEBUG else None,
    }
