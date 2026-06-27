"""
Synchronization schemas
"""

from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from datetime import datetime
from enum import Enum


class SyncOperation(str, Enum):
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"


class SyncEntityType(str, Enum):
    BOOKMARK = "bookmark"
    NOTE = "note"
    PROGRESS = "progress"
    SETTINGS = "settings"


class SyncItem(BaseModel):
    """Single sync item from client"""
    entity_type: SyncEntityType
    operation: SyncOperation
    client_entity_id: str  # Client-generated ID
    server_entity_id: Optional[str] = None  # Server ID if known
    data: Dict[str, Any]
    client_timestamp: datetime
    server_timestamp: Optional[datetime] = None
    checksum: Optional[str] = None


class SyncPushRequest(BaseModel):
    """Push changes from client to server"""
    items: List[SyncItem]
    device_id: str
    last_sync_at: Optional[datetime] = None


class SyncPushResponse(BaseModel):
    """Response from push operation"""
    processed: List[str]  # List of successfully processed client_entity_ids
    conflicts: List[Dict[str, Any]]  # List of conflicts
    server_timestamp: datetime


class SyncChange(BaseModel):
    """Single change from server"""
    entity_type: SyncEntityType
    entity_id: str
    operation: SyncOperation
    data: Dict[str, Any]
    timestamp: datetime


class SyncPullResponse(BaseModel):
    """Pull changes from server"""
    changes: List[SyncChange]
    server_timestamp: datetime
    has_more: bool


class SyncConflictResponse(BaseModel):
    """Sync conflict details"""
    id: str
    entity_type: SyncEntityType
    entity_id: Optional[str]
    server_data: Dict[str, Any]
    client_data: Dict[str, Any]
    server_timestamp: datetime
    client_timestamp: datetime
    created_at: datetime


class SyncResolveRequest(BaseModel):
    """Request to resolve a conflict"""
    resolution: str  # "server", "client", or "merged"
    merged_data: Optional[Dict[str, Any]] = None  # Required if resolution is "merged"


class SyncCheckpointResponse(BaseModel):
    """Last sync checkpoint"""
    last_sync_at: Optional[datetime]
    last_sequence: int
    entities_synced: int


class SyncStatusResponse(BaseModel):
    """Overall sync status"""
    pending_changes: int
    unresolved_conflicts: int
    last_sync_at: Optional[datetime]
    is_syncing: bool
