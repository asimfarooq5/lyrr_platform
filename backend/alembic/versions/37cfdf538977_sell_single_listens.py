"""sell single listens

The product sells listening rather than books: a book is bought on paper, and
in the app a reader buys one listen at a time. Credits are tracked per reader,
per book and per language, because the same book can be narrated in several.

Revision ID: 37cfdf538977
Revises: 4ce1f786a38a
Create Date: 2026-10-06
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "37cfdf538977"
down_revision: Union[str, None] = "4ce1f786a38a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "lecture_credits",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=True),
        sa.Column("book_id", sa.String(length=36), nullable=True),
        sa.Column("language", sa.String(length=16), nullable=False, server_default="en"),
        sa.Column("listens_left", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("listens_bought", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_price", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["book_id"], ["books.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "book_id", "language", name="uq_lecture_credit"),
    )
    op.create_index("ix_lecture_credits_book_id", "lecture_credits", ["book_id"])
    op.create_index("ix_lecture_credits_user_id", "lecture_credits", ["user_id"])

    # Price of one listen, set by the admin when the book is uploaded.
    op.add_column("books", sa.Column("lecture_price", sa.Float(), nullable=True))
    # Which language a narration clip is in; one clip per chapter per language.
    op.add_column(
        "book_media",
        sa.Column("language", sa.String(length=16), nullable=False, server_default="en"),
    )


def downgrade() -> None:
    op.drop_column("book_media", "language")
    op.drop_column("books", "lecture_price")
    op.drop_index("ix_lecture_credits_user_id", table_name="lecture_credits")
    op.drop_index("ix_lecture_credits_book_id", table_name="lecture_credits")
    op.drop_table("lecture_credits")
