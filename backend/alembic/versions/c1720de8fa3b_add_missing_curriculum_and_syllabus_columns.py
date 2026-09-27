"""add_missing_curriculum_and_syllabus_columns

Revision ID: c1720de8fa3b
Revises: c1720de8fa3a
Create Date: 2026-09-23 18:15:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = 'c1720de8fa3b'
down_revision: Union[str, None] = 'c1720de8fa3a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add missing audit/soft-delete columns to curriculum_masters
    op.add_column('curriculum_masters', sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('curriculum_masters', sa.Column('created_by', sa.UUID(), nullable=True))
    op.add_column('curriculum_masters', sa.Column('updated_by', sa.UUID(), nullable=True))

    # 2. Add estimated_periods and audit/soft-delete columns to curriculum_master_items
    op.add_column('curriculum_master_items', sa.Column('estimated_periods', sa.Integer(), server_default='4', nullable=False))
    op.add_column('curriculum_master_items', sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('curriculum_master_items', sa.Column('created_by', sa.UUID(), nullable=True))
    op.add_column('curriculum_master_items', sa.Column('updated_by', sa.UUID(), nullable=True))

    # 3. Add estimated_periods and lifecycle_status to syllabuses
    op.add_column('syllabuses', sa.Column('estimated_periods', sa.Integer(), server_default='4', nullable=False))
    op.add_column('syllabuses', sa.Column('lifecycle_status', sa.String(length=30), server_default='PLANNED', nullable=False))


def downgrade() -> None:
    # 3. Drop from syllabuses
    op.drop_column('syllabuses', 'lifecycle_status')
    op.drop_column('syllabuses', 'estimated_periods')

    # 2. Drop from curriculum_master_items
    op.drop_column('curriculum_master_items', 'updated_by')
    op.drop_column('curriculum_master_items', 'created_by')
    op.drop_column('curriculum_master_items', 'deleted_at')
    op.drop_column('curriculum_master_items', 'estimated_periods')

    # 1. Drop from curriculum_masters
    op.drop_column('curriculum_masters', 'updated_by')
    op.drop_column('curriculum_masters', 'created_by')
    op.drop_column('curriculum_masters', 'deleted_at')
