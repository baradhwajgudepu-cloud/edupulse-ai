"""add_attendance_to_importtype

Revision ID: a1b2c3d4e5f6
Revises: 9ec78aa02588
Create Date: 2026-09-13 09:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '9ec78aa02588'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Safely alter PostgreSQL importtype enum to include ATTENDANCE
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE importtype ADD VALUE IF NOT EXISTS 'ATTENDANCE'")
        op.execute("ALTER TYPE attendancesource ADD VALUE IF NOT EXISTS 'IMPORT'")


def downgrade() -> None:
    # PostgreSQL does not natively support dropping enum values without type recreation.
    pass
