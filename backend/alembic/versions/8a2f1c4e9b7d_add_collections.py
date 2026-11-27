"""add collections (Kindle-style shelves)

Revision ID: 8a2f1c4e9b7d
Revises: 1ca47ac25443
Create Date: 2026-09-06 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8a2f1c4e9b7d'
down_revision: Union[str, None] = '1ca47ac25443'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'collections',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE')),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_table(
        'collection_books',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('collection_id', sa.String(length=36), sa.ForeignKey('collections.id', ondelete='CASCADE')),
        sa.Column('book_id', sa.String(length=36), sa.ForeignKey('books.id', ondelete='CASCADE')),
        sa.Column('added_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table('collection_books')
    op.drop_table('collections')
