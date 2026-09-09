"""add_missing_marksstatus_enum_values

Revision ID: 9ec78aa02588
Revises: d2351c0630e1
Create Date: 2026-09-09 07:56:40.618731

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
# Additional imports here if needed

# revision identifiers, used by Alembic.
revision: str = '9ec78aa02588'
down_revision: Union[str, None] = 'd2351c0630e1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Safely alter PostgreSQL marksstatus enum to include all required lifecycle values
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE marksstatus ADD VALUE IF NOT EXISTS 'SUBMITTED'")
        op.execute("ALTER TYPE marksstatus ADD VALUE IF NOT EXISTS 'UNDER_REVIEW'")
        op.execute("ALTER TYPE marksstatus ADD VALUE IF NOT EXISTS 'RETURNED'")
        op.execute("ALTER TYPE marksstatus ADD VALUE IF NOT EXISTS 'APPROVED'")


def downgrade() -> None:
    # PostgreSQL does not natively support dropping enum values without type recreation.
    pass

