"""add_academic_planning_and_calendar_tables

Revision ID: g6933ef0cd43
Revises: f5822de9bc32
Create Date: 2026-09-24 13:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID, ENUM

revision: str = 'g6933ef0cd43'
down_revision: Union[str, None] = 'f5822de9bc32'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    # Create Enum types for academic calendar if they don't exist
    cal_event_type = ENUM(
        'PUBLIC_HOLIDAY',
        'SCHOOL_HOLIDAY',
        'PRINCIPAL_DECLARED_HOLIDAY',
        'EXAMINATION',
        'SCHOOL_EVENT',
        'WORKING_DAY',
        'SPECIAL_WORKING_DAY',
        name='calendareventtype',
        create_type=False
    )
    cal_event_type.create(conn, checkfirst=True)

    cal_event_status = ENUM(
        'DRAFT',
        'APPROVED',
        'PUBLISHED',
        'CANCELLED',
        name='calendareventstatus',
        create_type=False
    )
    cal_event_status.create(conn, checkfirst=True)

    # 1. syllabus_coverage_progress
    if 'syllabus_coverage_progress' not in tables:
        op.create_table(
            'syllabus_coverage_progress',
            sa.Column('id', UUID(as_uuid=True), primary_key=True),
            sa.Column('tenant_id', UUID(as_uuid=True), sa.ForeignKey('tenants.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('school_id', UUID(as_uuid=True), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('academic_year_id', UUID(as_uuid=True), sa.ForeignKey('academic_years.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('class_id', UUID(as_uuid=True), sa.ForeignKey('classes.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('section_id', UUID(as_uuid=True), sa.ForeignKey('sections.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('subject_id', UUID(as_uuid=True), sa.ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('syllabus_id', UUID(as_uuid=True), sa.ForeignKey('syllabuses.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('teacher_id', UUID(as_uuid=True), sa.ForeignKey('teachers.id', ondelete='SET NULL'), nullable=True, index=True),
            sa.Column('status', sa.String(30), nullable=False, server_default='PLANNED'),
            sa.Column('completion_percentage', sa.Float(), nullable=False, server_default='0.0'),
            sa.Column('started_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('remarks', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
            sa.Column('version', sa.Integer(), nullable=False, server_default='1'),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('created_by', UUID(as_uuid=True), nullable=True),
            sa.Column('updated_by', UUID(as_uuid=True), nullable=True),
            sa.UniqueConstraint('school_id', 'academic_year_id', 'section_id', 'syllabus_id', name='uq_coverage_progress_school_ay_sec_syll')
        )
        op.create_index('ix_coverage_progress_sec_sub', 'syllabus_coverage_progress', ['section_id', 'subject_id'])
        op.create_index('ix_coverage_progress_teacher', 'syllabus_coverage_progress', ['teacher_id'])

    # 2. timetable_recommendations
    if 'timetable_recommendations' not in tables:
        op.create_table(
            'timetable_recommendations',
            sa.Column('id', UUID(as_uuid=True), primary_key=True),
            sa.Column('tenant_id', UUID(as_uuid=True), sa.ForeignKey('tenants.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('school_id', UUID(as_uuid=True), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('academic_year_id', UUID(as_uuid=True), sa.ForeignKey('academic_years.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('class_id', UUID(as_uuid=True), sa.ForeignKey('classes.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('section_id', UUID(as_uuid=True), sa.ForeignKey('sections.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('recommendation_type', sa.String(50), nullable=False, server_default='INITIAL_GENERATION'),
            sa.Column('status', sa.String(30), nullable=False, server_default='SUGGESTED'),
            sa.Column('suggested_slots', JSONB(), nullable=False, server_default='{}'),
            sa.Column('rationale', JSONB(), nullable=False, server_default='{}'),
            sa.Column('risk_factors', JSONB(), nullable=False, server_default='{}'),
            sa.Column('audit_trail', JSONB(), nullable=False, server_default='{}'),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
            sa.Column('version', sa.Integer(), nullable=False, server_default='1'),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('created_by', UUID(as_uuid=True), nullable=True),
            sa.Column('updated_by', UUID(as_uuid=True), nullable=True),
        )
        op.create_index('ix_timetable_recs_sec_status', 'timetable_recommendations', ['section_id', 'status'])
        op.create_index('ix_timetable_recs_school_ay', 'timetable_recommendations', ['school_id', 'academic_year_id'])

    # 3. academic_calendar_events
    if 'academic_calendar_events' not in tables:
        op.create_table(
            'academic_calendar_events',
            sa.Column('id', UUID(as_uuid=True), primary_key=True),
            sa.Column('tenant_id', UUID(as_uuid=True), sa.ForeignKey('tenants.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('school_id', UUID(as_uuid=True), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('academic_year_id', UUID(as_uuid=True), sa.ForeignKey('academic_years.id', ondelete='CASCADE'), nullable=False, index=True),
            sa.Column('event_date', sa.Date(), nullable=False, index=True),
            sa.Column('event_type', cal_event_type, nullable=False, index=True),
            sa.Column('title', sa.String(255), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('source', sa.String(100), nullable=False, server_default='SCHOOL_ADMIN'),
            sa.Column('source_reference', sa.String(255), nullable=True),
            sa.Column('status', cal_event_status, nullable=False, server_default='APPROVED', index=True),
            sa.Column('is_non_working_day', sa.Boolean(), nullable=False, server_default='true'),
            sa.Column('created_by', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('approved_by', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('approved_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('extra_data', JSONB(), nullable=False, server_default='{}'),
            sa.Column('version', sa.Integer(), nullable=False, server_default='1'),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('updated_by', UUID(as_uuid=True), nullable=True),
        )
        op.create_index('ix_acad_cal_school_ay_date', 'academic_calendar_events', ['school_id', 'academic_year_id', 'event_date'])
        op.create_index('ix_acad_cal_type_status', 'academic_calendar_events', ['event_type', 'status'])

    # 4. state_holiday_masters
    if 'state_holiday_masters' not in tables:
        op.create_table(
            'state_holiday_masters',
            sa.Column('id', UUID(as_uuid=True), primary_key=True),
            sa.Column('state', sa.String(100), nullable=False, index=True),
            sa.Column('academic_year_code', sa.String(50), nullable=False, index=True),
            sa.Column('holiday_date', sa.Date(), nullable=False, index=True),
            sa.Column('holiday_name', sa.String(255), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('source', sa.String(255), nullable=False),
            sa.Column('source_version', sa.String(100), nullable=False),
            sa.Column('source_date', sa.Date(), nullable=True),
            sa.Column('verification_status', sa.String(50), nullable=False, server_default='VERIFIED'),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('created_by', UUID(as_uuid=True), nullable=True),
            sa.Column('updated_by', UUID(as_uuid=True), nullable=True),
            sa.UniqueConstraint('state', 'academic_year_code', 'holiday_date', name='uq_state_ay_holiday_date')
        )
        op.create_index('ix_state_holiday_state_ay', 'state_holiday_masters', ['state', 'academic_year_code'])

    # 5. Add missing columns to syllabus_recovery_plans and recovery_plan_items if absent
    if 'syllabus_recovery_plans' in tables:
        srp_cols = [c['name'] for c in inspector.get_columns('syllabus_recovery_plans')]
        if 'updated_by' not in srp_cols:
            op.add_column('syllabus_recovery_plans', sa.Column('updated_by', UUID(as_uuid=True), nullable=True))

    if 'recovery_plan_items' in tables:
        rpi_cols = [c['name'] for c in inspector.get_columns('recovery_plan_items')]
        if 'created_by' not in rpi_cols:
            op.add_column('recovery_plan_items', sa.Column('created_by', UUID(as_uuid=True), nullable=True))
        if 'updated_by' not in rpi_cols:
            op.add_column('recovery_plan_items', sa.Column('updated_by', UUID(as_uuid=True), nullable=True))


def downgrade() -> None:
    pass

