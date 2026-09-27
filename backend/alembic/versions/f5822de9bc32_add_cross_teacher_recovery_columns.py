"""add_cross_teacher_recovery_columns

Revision ID: f5822de9bc32
Revises: d4811ae9bc21
Create Date: 2026-09-24 10:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = 'f5822de9bc32'
down_revision: Union[str, None] = 'd4811ae9bc21'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    if 'syllabus_recovery_plans' not in tables:
        op.create_table(
            'syllabus_recovery_plans',
            sa.Column('id', UUID(as_uuid=True), primary_key=True),
            sa.Column('tenant_id', UUID(as_uuid=True), sa.ForeignKey('tenants.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('school_id', UUID(as_uuid=True), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('academic_year_id', UUID(as_uuid=True), sa.ForeignKey('academic_years.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('class_id', UUID(as_uuid=True), sa.ForeignKey('classes.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('section_id', UUID(as_uuid=True), sa.ForeignKey('sections.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('subject_id', UUID(as_uuid=True), sa.ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('teacher_id', UUID(as_uuid=True), sa.ForeignKey('teachers.id', ondelete='SET NULL'), nullable=True, index=True),
            sa.Column('primary_teacher_id', UUID(as_uuid=True), sa.ForeignKey('teachers.id', ondelete='SET NULL'), nullable=True, index=True),
            sa.Column('support_teacher_id', UUID(as_uuid=True), sa.ForeignKey('teachers.id', ondelete='SET NULL'), nullable=True, index=True),
            sa.Column('reason', sa.String(255), nullable=False),
            sa.Column('recovery_type', sa.String(50), nullable=False, server_default='CROSS_TEACHER_RECOVERY'),
            sa.Column('current_completion', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('target_completion_date', sa.Date(), nullable=True),
            sa.Column('forecast_completion_date', sa.Date(), nullable=True),
            sa.Column('new_forecast_date', sa.Date(), nullable=True),
            sa.Column('delay_days', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('duration_weeks', sa.Integer(), nullable=False, server_default='2'),
            sa.Column('recommended_periods_per_week', sa.Integer(), nullable=False, server_default='1'),
            sa.Column('expected_recovery_periods', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('projected_improvement_days', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('status', sa.String(30), nullable=False, server_default='SUGGESTED'),
            sa.Column('rejection_remarks', sa.Text(), nullable=True),
            sa.Column('parent_notes', sa.String(255), nullable=True),
            sa.Column('candidate_evaluations', JSONB(), nullable=False, server_default='[]'),
            sa.Column('created_by', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('approved_by', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('approved_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('audit_trail', JSONB(), nullable=False, server_default='{}'),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
            sa.Column('version', sa.Integer(), nullable=False, server_default='1'),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        )
        op.create_index('ix_syllabus_recovery_school_ay', 'syllabus_recovery_plans', ['school_id', 'academic_year_id'])
        op.create_index('ix_syllabus_recovery_sec_sub', 'syllabus_recovery_plans', ['section_id', 'subject_id'])
        op.create_index('ix_syllabus_recovery_type', 'syllabus_recovery_plans', ['recovery_type'])
        op.create_index('ix_srp_primary_teacher', 'syllabus_recovery_plans', ['primary_teacher_id'])
        op.create_index('ix_srp_support_teacher', 'syllabus_recovery_plans', ['support_teacher_id'])
    else:
        cols = [c['name'] for c in inspector.get_columns('syllabus_recovery_plans')]
        if 'recovery_type' not in cols:
            op.add_column('syllabus_recovery_plans', sa.Column('recovery_type', sa.String(50), nullable=False, server_default='CROSS_TEACHER_RECOVERY'))
            op.create_index('ix_syllabus_recovery_type', 'syllabus_recovery_plans', ['recovery_type'])
        if 'delay_days' not in cols:
            op.add_column('syllabus_recovery_plans', sa.Column('delay_days', sa.Integer(), nullable=False, server_default='0'))
        if 'duration_weeks' not in cols:
            op.add_column('syllabus_recovery_plans', sa.Column('duration_weeks', sa.Integer(), nullable=False, server_default='2'))
        if 'recommended_periods_per_week' not in cols:
            op.add_column('syllabus_recovery_plans', sa.Column('recommended_periods_per_week', sa.Integer(), nullable=False, server_default='1'))
        if 'projected_improvement_days' not in cols:
            op.add_column('syllabus_recovery_plans', sa.Column('projected_improvement_days', sa.Integer(), nullable=False, server_default='0'))
        if 'parent_notes' not in cols:
            op.add_column('syllabus_recovery_plans', sa.Column('parent_notes', sa.String(255), nullable=True))
        if 'primary_teacher_id' not in cols:
            op.add_column('syllabus_recovery_plans', sa.Column('primary_teacher_id', UUID(as_uuid=True), sa.ForeignKey('teachers.id', ondelete='SET NULL'), nullable=True))
            op.create_index('ix_srp_primary_teacher', 'syllabus_recovery_plans', ['primary_teacher_id'])
        if 'support_teacher_id' not in cols:
            op.add_column('syllabus_recovery_plans', sa.Column('support_teacher_id', UUID(as_uuid=True), sa.ForeignKey('teachers.id', ondelete='SET NULL'), nullable=True))
            op.create_index('ix_srp_support_teacher', 'syllabus_recovery_plans', ['support_teacher_id'])
        if 'candidate_evaluations' not in cols:
            op.add_column('syllabus_recovery_plans', sa.Column('candidate_evaluations', JSONB(), nullable=False, server_default='[]'))

    if 'recovery_plan_items' not in tables:
        op.create_table(
            'recovery_plan_items',
            sa.Column('id', UUID(as_uuid=True), primary_key=True),
            sa.Column('recovery_plan_id', UUID(as_uuid=True), sa.ForeignKey('syllabus_recovery_plans.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('tenant_id', UUID(as_uuid=True), sa.ForeignKey('tenants.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('date', sa.Date(), nullable=False, index=True),
            sa.Column('period_number', sa.Integer(), nullable=False),
            sa.Column('phase', sa.String(50), nullable=False, server_default='PHASE_1_CATCHUP'),
            sa.Column('syllabus_item_id', UUID(as_uuid=True), sa.ForeignKey('syllabuses.id', ondelete='SET NULL'), nullable=True, index=True),
            sa.Column('topic_name', sa.String(200), nullable=False),
            sa.Column('duration_minutes', sa.Integer(), nullable=False, server_default='45'),
            sa.Column('teacher_id', UUID(as_uuid=True), sa.ForeignKey('teachers.id', ondelete='SET NULL'), nullable=True, index=True),
            sa.Column('class_id', UUID(as_uuid=True), sa.ForeignKey('classes.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('section_id', UUID(as_uuid=True), sa.ForeignKey('sections.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('room_id', UUID(as_uuid=True), sa.ForeignKey('rooms.id', ondelete='SET NULL'), nullable=True, index=True),
            sa.Column('timetable_id', UUID(as_uuid=True), sa.ForeignKey('timetables.id', ondelete='SET NULL'), nullable=True, index=True),
            sa.Column('status', sa.String(30), nullable=False, server_default='SUGGESTED'),
            sa.Column('is_approved', sa.Boolean(), nullable=False, server_default='false'),
            sa.Column('conflict_status', sa.String(30), nullable=False, server_default='NO_CONFLICT'),
            sa.Column('conflict_message', sa.String(500), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
            sa.Column('version', sa.Integer(), nullable=False, server_default='1'),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        )
        op.create_index('ix_rec_items_plan_date', 'recovery_plan_items', ['recovery_plan_id', 'date'])
        op.create_index('ix_rec_items_timetable', 'recovery_plan_items', ['timetable_id'])
    else:
        item_cols = [c['name'] for c in inspector.get_columns('recovery_plan_items')]
        if 'timetable_id' not in item_cols:
            op.add_column('recovery_plan_items', sa.Column('timetable_id', UUID(as_uuid=True), sa.ForeignKey('timetables.id', ondelete='SET NULL'), nullable=True))
            op.create_index('ix_rec_items_timetable', 'recovery_plan_items', ['timetable_id'])


def downgrade() -> None:
    pass
