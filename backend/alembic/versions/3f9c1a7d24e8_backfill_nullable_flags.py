"""backfill nullable flags added after their tables existed

Columns introduced by later features (users.phone_verified, books.rating /
rating_count / sales_count) were added as NULLable, so rows that predate them
hold NULL. That breaks response serialization — a NULL phone_verified made
every /auth/me call raise a validation error and the mobile app's login fail
with a 500. Backfill the rows and make the columns non-null with defaults.

Revision ID: 3f9c1a7d24e8
Revises: 77a24989ebc9
Create Date: 2026-09-24
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "3f9c1a7d24e8"
down_revision: Union[str, None] = "77a24989ebc9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # users.phone_verified
    op.execute("UPDATE users SET phone_verified = false WHERE phone_verified IS NULL")
    op.alter_column(
        "users", "phone_verified",
        existing_type=sa.Boolean(), nullable=False,
        server_default=sa.text("false"),
    )

    # books — storefront counters
    op.execute("UPDATE books SET rating = 0.0 WHERE rating IS NULL")
    op.execute("UPDATE books SET rating_count = 0 WHERE rating_count IS NULL")
    op.execute("UPDATE books SET sales_count = 0 WHERE sales_count IS NULL")
    op.alter_column("books", "rating",
                    existing_type=sa.Float(), nullable=False,
                    server_default=sa.text("0.0"))
    op.alter_column("books", "rating_count",
                    existing_type=sa.Integer(), nullable=False,
                    server_default=sa.text("0"))
    op.alter_column("books", "sales_count",
                    existing_type=sa.Integer(), nullable=False,
                    server_default=sa.text("0"))


def downgrade() -> None:
    op.alter_column("books", "sales_count",
                    existing_type=sa.Integer(), nullable=True, server_default=None)
    op.alter_column("books", "rating_count",
                    existing_type=sa.Integer(), nullable=True, server_default=None)
    op.alter_column("books", "rating",
                    existing_type=sa.Float(), nullable=True, server_default=None)
    op.alter_column("users", "phone_verified",
                    existing_type=sa.Boolean(), nullable=True, server_default=None)
