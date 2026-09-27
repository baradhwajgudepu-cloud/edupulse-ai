"""add_question_paper_and_question_marks

Revision ID: e7102cd8fa4c
Revises: c1720de8fa3b
Create Date: 2026-09-24 00:10:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = 'e7102cd8fa4c'
down_revision: Union[str, None] = 'c1720de8fa3b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create question_papers table
    op.create_table(
        'question_papers',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('tenant_id', UUID(as_uuid=True), sa.ForeignKey('tenants.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('school_id', UUID(as_uuid=True), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('academic_year_id', UUID(as_uuid=True), sa.ForeignKey('academic_years.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('examination_id', UUID(as_uuid=True), sa.ForeignKey('examinations.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('paper_id', UUID(as_uuid=True), sa.ForeignKey('exam_schedules.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('title', sa.String(length=200), nullable=False),
        sa.Column('total_marks', sa.Numeric(precision=5, scale=2), server_default='100.0', nullable=False),
        sa.Column('total_questions', sa.Integer(), server_default='0', nullable=False),
        sa.Column('sections_count', sa.Integer(), server_default='1', nullable=False),
        sa.Column('source_file_name', sa.String(length=255), nullable=True),
        sa.Column('source_file_type', sa.String(length=50), nullable=True),
        sa.Column('storage_reference', sa.String(length=500), nullable=True),
        sa.Column('processing_status', sa.String(length=50), server_default='PENDING', nullable=False),
        sa.Column('verification_status', sa.String(length=50), server_default='UNVERIFIED', nullable=False),
        sa.Column('verified_by', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('verified_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('ai_extraction_metadata', JSONB, server_default='{}', nullable=False),
        sa.Column('syllabus_coverage_metrics', JSONB, server_default='{}', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', UUID(as_uuid=True), nullable=True),
        sa.Column('updated_by', UUID(as_uuid=True), nullable=True),
        sa.UniqueConstraint('paper_id', name='uq_question_paper_schedule_paper')
    )
    op.create_index('ix_question_papers_exam_paper', 'question_papers', ['examination_id', 'paper_id'])

    # 2. Alter exam_questions table
    op.add_column('exam_questions', sa.Column('question_paper_id', UUID(as_uuid=True), sa.ForeignKey('question_papers.id', ondelete='CASCADE'), nullable=True))
    op.add_column('exam_questions', sa.Column('parent_question_id', UUID(as_uuid=True), sa.ForeignKey('exam_questions.id', ondelete='CASCADE'), nullable=True))
    op.add_column('exam_questions', sa.Column('section_name', sa.String(length=50), nullable=True))
    op.add_column('exam_questions', sa.Column('sequence_order', sa.Integer(), server_default='1', nullable=False))
    op.add_column('exam_questions', sa.Column('extraction_confidence', sa.Numeric(precision=4, scale=3), nullable=True))
    op.add_column('exam_questions', sa.Column('mapping_confidence', sa.Numeric(precision=4, scale=3), nullable=True))
    op.add_column('exam_questions', sa.Column('mapping_source', sa.String(length=50), nullable=True))
    op.add_column('exam_questions', sa.Column('review_status', sa.String(length=50), server_default='PENDING', nullable=False))
    op.alter_column('exam_questions', 'chapter_name', nullable=True)

    op.create_index('ix_exam_questions_paper', 'exam_questions', ['question_paper_id'])
    op.create_index('ix_exam_questions_schedule', 'exam_questions', ['exam_schedule_id'])

    # Safely drop unique constraint if exists
    try:
        op.drop_constraint('uq_exam_subject_question_number', 'exam_questions', type_='unique')
    except Exception:
        pass

    # 3. Create student_question_marks table
    op.create_table(
        'student_question_marks',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('tenant_id', UUID(as_uuid=True), sa.ForeignKey('tenants.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('school_id', UUID(as_uuid=True), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('academic_year_id', UUID(as_uuid=True), sa.ForeignKey('academic_years.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('examination_id', UUID(as_uuid=True), sa.ForeignKey('examinations.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('exam_schedule_id', UUID(as_uuid=True), sa.ForeignKey('exam_schedules.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('question_id', UUID(as_uuid=True), sa.ForeignKey('exam_questions.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('student_id', UUID(as_uuid=True), sa.ForeignKey('students.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('marks_obtained', sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column('max_marks', sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column('is_attempted', sa.Boolean(), server_default='true', nullable=False),
        sa.Column('remarks', sa.String(length=255), nullable=True),
        sa.Column('audit_history', JSONB, server_default='[]', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', UUID(as_uuid=True), nullable=True),
        sa.Column('updated_by', UUID(as_uuid=True), nullable=True),
        sa.UniqueConstraint('question_id', 'student_id', name='uq_student_question_marks_q_student')
    )
    op.create_index('ix_student_qmarks_schedule_student', 'student_question_marks', ['exam_schedule_id', 'student_id'])
    op.create_index('ix_student_qmarks_question', 'student_question_marks', ['question_id'])


def downgrade() -> None:
    op.drop_table('student_question_marks')
    op.drop_index('ix_exam_questions_schedule', table_name='exam_questions')
    op.drop_index('ix_exam_questions_paper', table_name='exam_questions')
    op.drop_column('exam_questions', 'review_status')
    op.drop_column('exam_questions', 'mapping_source')
    op.drop_column('exam_questions', 'mapping_confidence')
    op.drop_column('exam_questions', 'extraction_confidence')
    op.drop_column('exam_questions', 'sequence_order')
    op.drop_column('exam_questions', 'section_name')
    op.drop_column('exam_questions', 'parent_question_id')
    op.drop_column('exam_questions', 'question_paper_id')
    op.drop_table('question_papers')
