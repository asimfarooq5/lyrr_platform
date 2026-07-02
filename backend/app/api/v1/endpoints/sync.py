"""
Synchronization endpoints for offline/online sync
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc
from typing import List, Dict, Any
from datetime import datetime

from app.core.database import get_db
from app.api.v1.endpoints.auth import get_current_active_user
from app.models.user import User
from app.models.sync import SyncQueue, SyncConflict, SyncEntityType, SyncOperation
from app.models.user_data import Bookmark, Note, ReadingProgress
from app.schemas.sync import (
    SyncPushRequest, SyncPullResponse, SyncConflictResponse,
    SyncResolveRequest, SyncCheckpointResponse
)

router = APIRouter()


@router.post("/push")
async def push_sync(
    request: SyncPushRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Push local changes to server"""
    processed = []
    conflicts = []
    
    for item in request.items:
        try:
            # Check for conflicts
            server_item = await _get_server_entity(
                db, current_user.id, item.entity_type, item.client_entity_id
            )
            
            if server_item and item.server_timestamp:
                # Check if server has newer version
                if server_item.updated_at > item.server_timestamp:
                    # Conflict detected
                    conflict = SyncConflict(
                        user_id=current_user.id,
                        entity_type=item.entity_type,
                        entity_id=server_item.id,
                        server_data=_entity_to_dict(server_item),
                        client_data=item.data,
                        server_timestamp=server_item.updated_at,
                        client_timestamp=item.client_timestamp
                    )
                    db.add(conflict)
                    conflicts.append({
                        "client_id": item.client_entity_id,
                        "conflict_id": conflict.id
                    })
                    continue
            
            # Apply change
            await _apply_change(db, current_user.id, item)
            processed.append(item.client_entity_id)
            
        except Exception as e:
            # Log error but continue processing
            conflicts.append({
                "client_id": item.client_entity_id,
                "error": str(e)
            })
    
    await db.commit()
    
    return {
        "processed": processed,
        "conflicts": conflicts,
        "server_timestamp": datetime.utcnow()
    }


@router.get("/pull", response_model=SyncPullResponse)
async def pull_sync(
    since: datetime,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Pull server changes since last sync"""
    changes = []
    
    # Get bookmarks
    bookmark_result = await db.execute(
        select(Bookmark).where(
            and_(
                Bookmark.user_id == current_user.id,
                Bookmark.updated_at > since
            )
        )
    )
    for bookmark in bookmark_result.scalars().all():
        changes.append({
            "entity_type": "bookmark",
            "entity_id": bookmark.id,
            "operation": "update",
            "data": {
                "id": bookmark.id,
                "book_id": bookmark.book_id,
                "chapter_id": bookmark.chapter_id,
                "word_id": bookmark.word_id,
                "position_seconds": bookmark.position_seconds,
                "note": bookmark.note,
                "color": bookmark.color,
                "created_at": bookmark.created_at.isoformat(),
                "updated_at": bookmark.updated_at.isoformat() if bookmark.updated_at else None
            },
            "timestamp": bookmark.updated_at.isoformat() if bookmark.updated_at else bookmark.created_at.isoformat()
        })
    
    # Get notes
    note_result = await db.execute(
        select(Note).where(
            and_(
                Note.user_id == current_user.id,
                Note.updated_at > since
            )
        )
    )
    for note in note_result.scalars().all():
        changes.append({
            "entity_type": "note",
            "entity_id": note.id,
            "operation": "update",
            "data": {
                "id": note.id,
                "book_id": note.book_id,
                "chapter_id": note.chapter_id,
                "word_id": note.word_id,
                "content": note.content,
                "created_at": note.created_at.isoformat(),
                "updated_at": note.updated_at.isoformat() if note.updated_at else None
            },
            "timestamp": note.updated_at.isoformat() if note.updated_at else note.created_at.isoformat()
        })
    
    # Get progress
    progress_result = await db.execute(
        select(ReadingProgress).where(
            and_(
                ReadingProgress.user_id == current_user.id,
                ReadingProgress.updated_at > since
            )
        )
    )
    for progress in progress_result.scalars().all():
        changes.append({
            "entity_type": "progress",
            "entity_id": progress.id,
            "operation": "update",
            "data": {
                "id": progress.id,
                "book_id": progress.book_id,
                "chapter_id": progress.chapter_id,
                "word_id": progress.word_id,
                "position_seconds": progress.position_seconds,
                "progress_percent": progress.progress_percent,
                "total_reading_time_seconds": progress.total_reading_time_seconds,
                "sessions_count": progress.sessions_count,
                "last_read_at": progress.last_read_at.isoformat()
            },
            "timestamp": progress.updated_at.isoformat() if progress.updated_at else progress.created_at.isoformat()
        })
    
    return {
        "changes": changes,
        "server_timestamp": datetime.utcnow(),
        "has_more": False  # Pagination not implemented for MVP
    }


@router.get("/conflicts", response_model=List[SyncConflictResponse])
async def get_conflicts(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get unresolved sync conflicts"""
    result = await db.execute(
        select(SyncConflict).where(
            and_(
                SyncConflict.user_id == current_user.id,
                SyncConflict.is_resolved == False
            )
        ).order_by(desc(SyncConflict.created_at))
    )
    return result.scalars().all()


@router.post("/resolve/{conflict_id}")
async def resolve_conflict(
    conflict_id: str,
    resolution: SyncResolveRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Resolve a sync conflict"""
    result = await db.execute(
        select(SyncConflict).where(
            and_(
                SyncConflict.id == conflict_id,
                SyncConflict.user_id == current_user.id
            )
        )
    )
    conflict = result.scalar_one_or_none()
    
    if not conflict:
        raise HTTPException(status_code=404, detail="Conflict not found")
    
    # Apply resolution
    if resolution.resolution == "server":
        # Keep server version (do nothing)
        pass
    elif resolution.resolution == "client":
        # Apply client version
        await _apply_change_from_data(
            db, current_user.id, conflict.entity_type, conflict.client_data
        )
    elif resolution.resolution == "merged":
        # Apply merged data
        if resolution.merged_data:
            await _apply_change_from_data(
                db, current_user.id, conflict.entity_type, resolution.merged_data
            )
    
    # Mark conflict as resolved
    conflict.is_resolved = True
    conflict.resolution = resolution.resolution
    conflict.resolved_data = resolution.merged_data
    conflict.resolved_at = datetime.utcnow()
    
    await db.commit()
    
    return {"message": "Conflict resolved"}


@router.get("/checkpoint", response_model=SyncCheckpointResponse)
async def get_checkpoint(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get last sync checkpoint"""
    from app.models.sync import SyncCheckpoint
    
    result = await db.execute(
        select(SyncCheckpoint).where(SyncCheckpoint.user_id == current_user.id)
    )
    checkpoint = result.scalar_one_or_none()
    
    if not checkpoint:
        return {
            "last_sync_at": None,
            "last_sequence": 0,
            "entities_synced": 0
        }
    
    return {
        "last_sync_at": checkpoint.last_sync_at,
        "last_sequence": checkpoint.last_sequence,
        "entities_synced": checkpoint.entities_synced
    }


# Helper functions
async def _get_server_entity(db: AsyncSession, user_id: str, entity_type: str, client_id: str):
    """Get server entity by client ID"""
    if entity_type == "bookmark":
        result = await db.execute(
            select(Bookmark).where(
                and_(
                    Bookmark.user_id == user_id,
                    Bookmark.client_id == client_id
                )
            )
        )
        return result.scalar_one_or_none()
    elif entity_type == "note":
        result = await db.execute(
            select(Note).where(
                and_(
                    Note.user_id == user_id,
                    Note.client_id == client_id
                )
            )
        )
        return result.scalar_one_or_none()
    return None


async def _apply_change(db: AsyncSession, user_id: str, item):
    """Apply a sync change"""
    if item.entity_type == "bookmark":
        await _apply_bookmark_change(db, user_id, item)
    elif item.entity_type == "note":
        await _apply_note_change(db, user_id, item)
    elif item.entity_type == "progress":
        await _apply_progress_change(db, user_id, item)


async def _apply_bookmark_change(db: AsyncSession, user_id: str, item):
    """Apply bookmark change"""
    data = item.data
    
    # Check if exists
    result = await db.execute(
        select(Bookmark).where(
            and_(
                Bookmark.user_id == user_id,
                Bookmark.client_id == item.client_entity_id
            )
        )
    )
    existing = result.scalar_one_or_none()
    
    if existing:
        # Update
        existing.word_id = data.get("word_id", existing.word_id)
        existing.note = data.get("note", existing.note)
        existing.color = data.get("color", existing.color)
        existing.updated_at = datetime.utcnow()
    else:
        # Create
        bookmark = Bookmark(
            user_id=user_id,
            book_id=data["book_id"],
            chapter_id=data.get("chapter_id"),
            word_id=data["word_id"],
            position_seconds=data.get("position_seconds"),
            note=data.get("note"),
            color=data.get("color", "#FFD700"),
            client_id=item.client_entity_id,
            is_synced=True
        )
        db.add(bookmark)


async def _apply_note_change(db: AsyncSession, user_id: str, item):
    """Apply note change"""
    data = item.data
    
    result = await db.execute(
        select(Note).where(
            and_(
                Note.user_id == user_id,
                Note.client_id == item.client_entity_id
            )
        )
    )
    existing = result.scalar_one_or_none()
    
    if existing:
        existing.content = data.get("content", existing.content)
        existing.updated_at = datetime.utcnow()
    else:
        note = Note(
            user_id=user_id,
            book_id=data["book_id"],
            chapter_id=data.get("chapter_id"),
            word_id=data["word_id"],
            content=data["content"],
            client_id=item.client_entity_id,
            is_synced=True
        )
        db.add(note)


async def _apply_progress_change(db: AsyncSession, user_id: str, item):
    """Apply progress change"""
    data = item.data
    
    result = await db.execute(
        select(ReadingProgress).where(
            and_(
                ReadingProgress.user_id == user_id,
                ReadingProgress.book_id == data["book_id"]
            )
        )
    )
    existing = result.scalar_one_or_none()
    
    if existing:
        existing.chapter_id = data.get("chapter_id", existing.chapter_id)
        existing.word_id = data.get("word_id", existing.word_id)
        existing.position_seconds = data.get("position_seconds", existing.position_seconds)
        existing.progress_percent = data.get("progress_percent", existing.progress_percent)
        existing.last_read_at = datetime.utcnow()
        existing.last_synced_at = datetime.utcnow()
    else:
        progress = ReadingProgress(
            user_id=user_id,
            book_id=data["book_id"],
            chapter_id=data.get("chapter_id"),
            word_id=data.get("word_id"),
            position_seconds=data.get("position_seconds", 0),
            progress_percent=data.get("progress_percent", 0),
            last_synced_at=datetime.utcnow()
        )
        db.add(progress)


def _entity_to_dict(entity) -> Dict[str, Any]:
    """Convert entity to dictionary"""
    if isinstance(entity, Bookmark):
        return {
            "id": entity.id,
            "book_id": entity.book_id,
            "word_id": entity.word_id,
            "note": entity.note,
            "color": entity.color
        }
    elif isinstance(entity, Note):
        return {
            "id": entity.id,
            "book_id": entity.book_id,
            "word_id": entity.word_id,
            "content": entity.content
        }
    return {}


async def _apply_change_from_data(db: AsyncSession, user_id: str, entity_type: str, data: Dict):
    """Apply change from conflict resolution"""
    # Similar to _apply_change but from resolved data
    pass
