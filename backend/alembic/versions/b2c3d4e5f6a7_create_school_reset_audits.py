"""create_school_reset_audits

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-09-14 17:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'b2c3d4e5f6a7'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'school_reset_audits',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('audit_id', sa.String(length=100), nullable=False),
        sa.Column('actor_id', sa.UUID(), nullable=True),
        sa.Column('actor_role', sa.String(length=50), nullable=False),
        sa.Column('actor_email', sa.String(length=255), nullable=False),
        sa.Column('tenant_id', sa.UUID(), nullable=False),
        sa.Column('school_id', sa.UUID(), nullable=False),
        sa.Column('school_name', sa.String(length=255), nullable=False),
        sa.Column('reason', sa.Text(), nullable=False),
        sa.Column('status', sa.String(length=50), nullable=False),
        sa.Column('deletion_counts', sa.JSON(), nullable=True),
        sa.Column('total_records_deleted', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('summary_snapshot', sa.JSON(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.UUID(), nullable=True),
        sa.Column('updated_by', sa.UUID(), nullable=True),
        sa.ForeignKeyConstraint(['actor_id'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_school_reset_audits_audit_id', 'school_reset_audits', ['audit_id'], unique=True)
    op.create_index('ix_school_reset_audits_school_id', 'school_reset_audits', ['school_id'], unique=False)
    op.create_index('ix_school_reset_audits_status', 'school_reset_audits', ['status'], unique=False)
    op.create_index('ix_school_reset_audits_tenant_id', 'school_reset_audits', ['tenant_id'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_school_reset_audits_tenant_id', table_name='school_reset_audits')
    op.drop_index('ix_school_reset_audits_status', table_name='school_reset_audits')
    op.drop_index('ix_school_reset_audits_school_id', table_name='school_reset_audits')
    op.drop_index('ix_school_reset_audits_audit_id', table_name='school_reset_audits')
    op.drop_table('school_reset_audits')
