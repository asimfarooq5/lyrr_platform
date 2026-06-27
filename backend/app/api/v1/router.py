"""
API Router - v1
"""

from fastapi import APIRouter

from app.api.v1.endpoints import auth, books, users, sync, media, admin

api_router = APIRouter()

# Auth routes
api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])

# Book routes
api_router.include_router(books.router, prefix="/books", tags=["books"])

# User routes
api_router.include_router(users.router, prefix="/me", tags=["user"])

# Sync routes
api_router.include_router(sync.router, prefix="/sync", tags=["sync"])

# Media routes
api_router.include_router(media.router, prefix="/media", tags=["media"])

# Admin routes
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
