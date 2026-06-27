"""
Sync models for offline/online synchronization
"""

from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, Text, JSON, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
import uuid

from app.core.database import Base


class SyncOperation(str, enum.Enum):
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"


class SyncEntityType(str, enum.Enum):
    BOOKMARK = "bookmark"
    NOTE = "note"
    PROGRESS = "progress"
    SETTINGS = "settings"


class SyncQueue(Base):
    """Queue of sync operations from devices"""
    __tablename__ = "sync_queue"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
    device_id = Column(String(36), ForeignKey("user_devices.id", ondelete="CASCADE"))
    
    # Operation details
    operation = Column(Enum(SyncOperation), nullable=False)
    entity_type = Column(Enum(SyncEntityType), nullable=False)
    entity_id = Column(String(36), nullable=True)  # Server ID if known
    client_entity_id = Column(String(36), nullable=False)  # Client-generated ID
    
    # Data
    data = Column(JSON, nullable=False)  # Full entity data
    checksum = Column(String(64), nullable=True)  # For conflict detection
    
    # Status
    status = Column(String(20), default="pending")  # pending, processing, completed, failed
    error_message = Column(Text, nullable=True)
    
    # Timestamps
    client_timestamp = Column(DateTime(timezone=True), nullable=False)
    server_timestamp = Column(DateTime(timezone=True), server_default=func.now())
    processed_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    user = relationship("User")


class SyncConflict(Base):
    """Conflicts requiring manual resolution"""
    __tablename__ = "sync_conflicts"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
    
    # Conflict details
    entity_type = Column(Enum(SyncEntityType), nullable=False)
    entity_id = Column(String(36), nullable=True)
    
    # Data snapshots
    server_data = Column(JSON, nullable=False)
    client_data = Column(JSON, nullable=False)
    server_timestamp = Column(DateTime(timezone=True), nullable=False)
    client_timestamp = Column(DateTime(timezone=True), nullable=False)
    
    # Resolution
    resolution = Column(String(20), nullable=True)  # server, client, merged
    resolved_data = Column(JSON, nullable=True)
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    
    # Status
    is_resolved = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User")


class SyncCheckpoint(Base):
    """Last sync checkpoint for each device"""
    __tablename__ = "sync_checkpoints"
    
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"))
    device_id = Column(String(36), ForeignKey("user_devices.id", ondelete="CASCADE"))
    
    # Checkpoint
    last_sync_at = Column(DateTime(timezone=True), nullable=False)
    last_sequence = Column(Integer, default=0)  # For incremental sync
    
    # Stats
    entities_synced = Column(Integer, default=0)
    conflicts_count = Column(Integer, default=0)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    __table_args__ = (
        # Unique constraint on user + device
    )
