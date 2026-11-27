"""make boolean flags NOT NULL with server defaults

These columns were declared with SQLAlchemy Python-side defaults only, so the
database itself allowed NULL and had no default. Any row written outside the
ORM (raw SQL, data import, migration) could then hold NULL, and every response
schema that types the field as `bool` blew up on serialization — this is what
made GET /me/library return 500 (user_books.is_downloaded was NULL).

Backfill the existing NULLs and move the default down to the database so the
whole class of failure is closed off.

Revision ID: 9b2e5f7c1a30
Revises: 3f9c1a7d24e8
Create Date: 2026-09-24
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "9b2e5f7c1a30"
down_revision: Union[str, None] = "3f9c1a7d24e8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# (table, column) — every boolean the API serializes as a non-optional bool.
FLAGS = [
    ("users", "is_active"),
    ("users", "is_verified"),
    ("users", "is_admin"),
    ("books", "is_featured"),
    ("books", "drm_enabled"),
    ("user_books", "is_downloaded"),
    ("bookmarks", "is_synced"),
    ("notes", "is_synced"),
    ("subscription_plans", "is_active"),
    ("sync_conflicts", "is_resolved"),
    ("user_devices", "is_trusted"),
]


def upgrade() -> None:
    for table, column in FLAGS:
        op.execute(f'UPDATE "{table}" SET "{column}" = false WHERE "{column}" IS NULL')
        op.alter_column(
            table, column,
            existing_type=sa.Boolean(), nullable=False,
            server_default=sa.text("false"),
        )


def downgrade() -> None:
    for table, column in reversed(FLAGS):
        op.alter_column(
            table, column,
            existing_type=sa.Boolean(), nullable=True, server_default=None,
        )
