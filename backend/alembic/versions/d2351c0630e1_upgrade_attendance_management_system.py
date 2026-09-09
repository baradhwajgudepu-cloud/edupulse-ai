"""upgrade_attendance_management_system

Revision ID: d2351c0630e1
Revises: 110b066b5955
Create Date: 2026-09-05 16:50:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'd2351c0630e1'
down_revision: Union[str, None] = '110b066b5955'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    
    # 1. Update attendance_sessions
    op.alter_column('attendance_sessions', 'timetable_id', existing_type=sa.Uuid(), nullable=True)
    
    # Add session_type to attendance_sessions
    session_type_enum = sa.Enum('FULL_DAY', 'MORNING', 'AFTERNOON', 'PERIOD', name='attendancesessiontype')
    session_type_enum.create(bind, checkfirst=True)
    
    res = bind.execute(sa.text(
        "SELECT column_name FROM information_schema.columns WHERE table_name='attendance_sessions' AND column_name='session_type'"
    )).fetchone()
    if not res:
        op.add_column('attendance_sessions', sa.Column('session_type', sa.Enum('FULL_DAY', 'MORNING', 'AFTERNOON', 'PERIOD', name='attendancesessiontype'), server_default='FULL_DAY', nullable=False))
        op.create_index('ix_attendance_sessions_session_type', 'attendance_sessions', ['session_type'], unique=False)

    # 2. Update attendances
    op.alter_column('attendances', 'timetable_id', existing_type=sa.Uuid(), nullable=True)
    
    res = bind.execute(sa.text(
        "SELECT column_name FROM information_schema.columns WHERE table_name='attendances' AND column_name='session_type'"
    )).fetchone()
    if not res:
        op.add_column('attendances', sa.Column('session_type', sa.Enum('FULL_DAY', 'MORNING', 'AFTERNOON', 'PERIOD', name='attendancesessiontype'), server_default='FULL_DAY', nullable=False))
        op.create_index('ix_attendances_session_type', 'attendances', ['session_type'], unique=False)

    # 3. Create attendance_audit_logs table if not exists
    res = bind.execute(sa.text(
        "SELECT table_name FROM information_schema.tables WHERE table_name='attendance_audit_logs'"
    )).fetchone()
    if not res:
        op.create_table(
            'attendance_audit_logs',
            sa.Column('id', sa.Uuid(), nullable=False),
            sa.Column('tenant_id', sa.Uuid(), nullable=False),
            sa.Column('school_id', sa.Uuid(), nullable=False),
            sa.Column('attendance_id', sa.Uuid(), nullable=True),
            sa.Column('student_id', sa.Uuid(), nullable=False),
            sa.Column('attendance_date', sa.Date(), nullable=False),
            sa.Column('session_type', sa.String(length=30), server_default='FULL_DAY', nullable=False),
            sa.Column('old_status', sa.String(length=30), nullable=True),
            sa.Column('new_status', sa.String(length=30), nullable=False),
            sa.Column('action', sa.String(length=30), nullable=False),
            sa.Column('changed_by', sa.Uuid(), nullable=True),
            sa.Column('changed_by_role', sa.String(length=50), nullable=True),
            sa.Column('timestamp', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
            sa.Column('source', sa.String(length=50), server_default='MANUAL', nullable=False),
            sa.Column('reason', sa.String(length=500), nullable=True),
            sa.Column('audit_metadata', sa.JSON().with_variant(postgresql.JSONB(astext_type=sa.Text()), 'postgresql'), server_default='{}', nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
            sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
            sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('created_by', sa.Uuid(), nullable=True),
            sa.Column('updated_by', sa.Uuid(), nullable=True),
            sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['attendance_id'], ['attendances.id'], ondelete='SET NULL'),
            sa.ForeignKeyConstraint(['student_id'], ['students.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['changed_by'], ['users.id'], ondelete='SET NULL'),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index('ix_attendance_audit_logs_student_date', 'attendance_audit_logs', ['student_id', 'attendance_date'], unique=False)
        op.create_index('ix_attendance_audit_logs_school_date', 'attendance_audit_logs', ['school_id', 'attendance_date'], unique=False)
        op.create_index('ix_attendance_audit_logs_tenant_school', 'attendance_audit_logs', ['tenant_id', 'school_id'], unique=False)


def downgrade() -> None:
    op.drop_table('attendance_audit_logs')
    op.drop_column('attendances', 'session_type')
    op.drop_column('attendance_sessions', 'session_type')
