"""
Admin endpoints - dashboard, analytics, management
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta

from app.core.database import get_db
from app.models.user import User
from app.models.book import Book, UserBook
from app.models.sync import SyncCheckpoint

router = APIRouter()


@router.get("/dashboard")
async def get_dashboard(
    db: AsyncSession = Depends(get_db),
):
    """Get admin dashboard statistics"""
    # Count users
    user_count = await db.scalar(select(func.count(User.id)))
    
    # Count books
    book_count = await db.scalar(select(func.count(Book.id)))
    
    # Count syncs in last 24h
    yesterday = datetime.utcnow() - timedelta(hours=24)
    sync_count = await db.scalar(
        select(func.count(SyncCheckpoint.id))
        .where(SyncCheckpoint.last_sync_at >= yesterday)
    )
    
    return {
        "total_users": user_count or 0,
        "total_books": book_count or 0,
        "syncs_today": sync_count or 0,
        "period": "24h",
    }


@router.get("/users")
async def list_users(
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db),
):
    """List all users"""
    result = await db.execute(
        select(User).offset(skip).limit(limit)
    )
    users = result.scalars().all()
    
    return {
        "users": [
            {
                "id": u.id,
                "email": u.email,
                "is_active": u.is_active,
                "is_admin": u.is_admin,
                "is_verified": u.is_verified,
                "created_at": u.created_at.isoformat() if u.created_at else None,
            }
            for u in users
        ],
        "total": len(users),
    }


@router.get("/analytics")
async def get_analytics(
    days: int = 30,
    db: AsyncSession = Depends(get_db),
):
    """Get analytics data"""
    since = datetime.utcnow() - timedelta(days=days)
    
    # New users in period
    new_users = await db.scalar(
        select(func.count(User.id)).where(User.created_at >= since)
    )
    
    # Purchases in period
    purchases = await db.scalar(
        select(func.count(UserBook.id)).where(UserBook.purchased_at >= since)
    )
    
    return {
        "period": f"last_{days}_days",
        "new_users": new_users or 0,
        "purchases": purchases or 0,
        "data": {},
    }
