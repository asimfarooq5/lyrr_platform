"""attach narration to a chapter

Gives an audiobook clip a chapter, so a multi-file recording uploads one clip
per chapter and each chapter can carry its own word timings.

Revision ID: 4ce1f786a38a
Revises: 9b2e5f7c1a30
Create Date: 2026-09-24
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "4ce1f786a38a"
down_revision: Union[str, None] = "9b2e5f7c1a30"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "book_media",
        sa.Column("chapter_id", sa.String(length=36), nullable=True),
    )
    op.create_index(
        op.f("ix_book_media_chapter_id"), "book_media", ["chapter_id"], unique=False
    )
    op.create_foreign_key(
        "fk_book_media_chapter_id", "book_media", "chapters",
        ["chapter_id"], ["id"], ondelete="CASCADE",
    )


def downgrade() -> None:
    op.drop_constraint("fk_book_media_chapter_id", "book_media", type_="foreignkey")
    op.drop_index(op.f("ix_book_media_chapter_id"), table_name="book_media")
    op.drop_column("book_media", "chapter_id")
