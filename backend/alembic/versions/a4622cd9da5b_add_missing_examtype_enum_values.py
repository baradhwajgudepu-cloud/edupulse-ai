"""add_missing_examtype_enum_values

Revision ID: a4622cd9da5b
Revises: f3511c0852e4
Create Date: 2026-09-23 14:45:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'a4622cd9da5b'
down_revision: Union[str, None] = 'f3511c0852e4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Safely alter PostgreSQL examtype enum to include all required exam types
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE examtype ADD VALUE IF NOT EXISTS 'WEEKLY_TEST'")
        op.execute("ALTER TYPE examtype ADD VALUE IF NOT EXISTS 'FINAL'")
        op.execute("ALTER TYPE examtype ADD VALUE IF NOT EXISTS 'PRACTICAL'")
        op.execute("ALTER TYPE examtype ADD VALUE IF NOT EXISTS 'INTERNAL_ASSESSMENT'")
        op.execute("ALTER TYPE examtype ADD VALUE IF NOT EXISTS 'CUSTOM'")


def downgrade() -> None:
    # PostgreSQL does not natively support dropping enum values without type recreation.
    pass
