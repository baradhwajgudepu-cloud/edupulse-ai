"""examination_cycle_papers_and_classes

Revision ID: d4811ae9bc21
Revises: e7102cd8fa4c
Create Date: 2026-09-24 00:30:00.000000

"""
from typing import Sequence, Union
import uuid
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision: str = 'd4811ae9bc21'
down_revision: Union[str, None] = 'e7102cd8fa4c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create exam_papers table
    op.create_table(
        'exam_papers',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('tenant_id', UUID(as_uuid=True), sa.ForeignKey('tenants.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('school_id', UUID(as_uuid=True), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('academic_year_id', UUID(as_uuid=True), sa.ForeignKey('academic_years.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('examination_id', UUID(as_uuid=True), sa.ForeignKey('examinations.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('subject_id', UUID(as_uuid=True), sa.ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('paper_name', sa.String(length=200), nullable=False),
        sa.Column('paper_code', sa.String(length=50), nullable=True),
        sa.Column('default_max_marks', sa.Integer(), server_default='100', nullable=False),
        sa.Column('default_pass_marks', sa.Integer(), server_default='35', nullable=False),
        sa.Column('default_duration_minutes', sa.Integer(), server_default='180', nullable=False),
        sa.Column('order_index', sa.Integer(), server_default='1', nullable=False),
        sa.Column('is_active', sa.Boolean(), server_default='true', nullable=False),
        sa.Column('version', sa.Integer(), server_default='1', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', UUID(as_uuid=True), nullable=True),
        sa.Column('updated_by', UUID(as_uuid=True), nullable=True),
    )
    op.create_index('ix_exam_papers_exam_subject', 'exam_papers', ['examination_id', 'subject_id'])
    op.create_index('ix_exam_papers_tenant_school', 'exam_papers', ['tenant_id', 'school_id'])

    # 2. Create exam_paper_classes table
    op.create_table(
        'exam_paper_classes',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('tenant_id', UUID(as_uuid=True), sa.ForeignKey('tenants.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('school_id', UUID(as_uuid=True), sa.ForeignKey('schools.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('examination_id', UUID(as_uuid=True), sa.ForeignKey('examinations.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('paper_id', UUID(as_uuid=True), sa.ForeignKey('exam_papers.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('class_id', UUID(as_uuid=True), sa.ForeignKey('classes.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('maximum_marks', sa.Integer(), nullable=True),
        sa.Column('pass_marks', sa.Integer(), nullable=True),
        sa.Column('duration_minutes', sa.Integer(), nullable=True),
        sa.Column('is_active', sa.Boolean(), server_default='true', nullable=False),
        sa.Column('version', sa.Integer(), server_default='1', nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', UUID(as_uuid=True), nullable=True),
        sa.Column('updated_by', UUID(as_uuid=True), nullable=True),
        sa.UniqueConstraint('paper_id', 'class_id', name='uq_exam_paper_class')
    )
    op.create_index('ix_exam_paper_classes_exam_class', 'exam_paper_classes', ['examination_id', 'class_id'])

    # 3. Alter exam_schedules
    op.add_column('exam_schedules', sa.Column('paper_id', UUID(as_uuid=True), sa.ForeignKey('exam_papers.id', ondelete='SET NULL'), nullable=True))
    op.alter_column('exam_schedules', 'teacher_subject_assignment_id', nullable=True)
    try:
        op.drop_constraint('uq_exam_schedules_tsa_slot', 'exam_schedules', type_='unique')
    except Exception:
        pass
    op.create_index('ix_exam_schedules_paper_id', 'exam_schedules', ['paper_id'])

    # 4. Data consolidation & migration
    conn = op.get_bind()
    
    # 4.1 Canonical primary exam for Quarterly 2026
    primary_exam_id = uuid.UUID('ea0a2b2e-e6ed-416b-8e85-c15654edff3d')
    res = conn.execute(sa.text("SELECT id, tenant_id, school_id, academic_year_id FROM examinations WHERE id = :id"), {"id": primary_exam_id}).fetchone()
    
    if res:
        tenant_id, school_id, academic_year_id = res[1], res[2], res[3]
        # Update primary exam date range
        conn.execute(sa.text("""
            UPDATE examinations 
            SET start_date = '2026-09-15', end_date = '2026-09-30'
            WHERE id = :id
        """), {"id": primary_exam_id})

        # Ensure all school classes are linked to the primary examination
        class_rows = conn.execute(sa.text("""
            SELECT id FROM classes 
            WHERE school_id = :school_id
        """), {"school_id": school_id}).fetchall()
        
        for c in class_rows:
            class_id = c[0]
            existing = conn.execute(sa.text("""
                SELECT 1 FROM examination_classes 
                WHERE examination_id = :exam_id AND class_id = :class_id
            """), {"exam_id": primary_exam_id, "class_id": class_id}).fetchone()
            
            if not existing:
                conn.execute(sa.text("""
                    INSERT INTO examination_classes (id, examination_id, class_id, tenant_id, school_id, created_at, updated_at)
                    VALUES (:id, :exam_id, :class_id, :tenant_id, :school_id, NOW(), NOW())
                """), {
                    "id": uuid.uuid4(),
                    "exam_id": primary_exam_id,
                    "class_id": class_id,
                    "tenant_id": tenant_id,
                    "school_id": school_id
                })

        # Create exam_papers for each subject in the school under primary examination
        subjects = conn.execute(sa.text("""
            SELECT id, subject_name, subject_code FROM subjects 
            WHERE school_id = :school_id
            ORDER BY subject_name
        """), {"school_id": school_id}).fetchall()

        paper_map = {} # subject_id -> paper_id
        for idx, sub in enumerate(subjects, 1):
            sub_id, sub_name, sub_code = sub[0], sub[1], sub[2]
            paper_id = uuid.uuid4()
            paper_map[sub_id] = paper_id
            conn.execute(sa.text("""
                INSERT INTO exam_papers (
                    id, tenant_id, school_id, academic_year_id, examination_id, subject_id,
                    paper_name, paper_code, default_max_marks, default_pass_marks,
                    default_duration_minutes, order_index, is_active, version, created_at, updated_at
                ) VALUES (
                    :id, :tenant_id, :school_id, :academic_year_id, :exam_id, :sub_id,
                    :name, :code, 100, 35, 180, :idx, true, 1, NOW(), NOW()
                )
            """), {
                "id": paper_id,
                "tenant_id": tenant_id,
                "school_id": school_id,
                "academic_year_id": academic_year_id,
                "exam_id": primary_exam_id,
                "sub_id": sub_id,
                "name": sub_name,
                "code": sub_code,
                "idx": idx
            })

        # Update existing exam_schedules to reference the new paper_id
        for sub_id, p_id in paper_map.items():
            conn.execute(sa.text("""
                UPDATE exam_schedules
                SET paper_id = :paper_id
                WHERE exam_id = :exam_id AND subject_id = :subject_id
            """), {"paper_id": p_id, "exam_id": primary_exam_id, "subject_id": sub_id})

        # Deactivate redundant duplicate examinations and test runs
        duplicate_exam_ids = [
            uuid.UUID('5595db9a-455e-41a0-84e6-281757d79614'),
            uuid.UUID('3e27ceeb-0382-467e-9d09-ef2fdbe28949'),
            uuid.UUID('df3edc61-2955-4f48-bf58-98c1dcfd3824'),
            uuid.UUID('0fa04709-57c8-4d2a-8a23-6f23fc4d2804'),
            uuid.UUID('d36bf21a-9421-44ba-b7be-96d18eb0c3cd'),
            uuid.UUID('9136dd2b-531e-4183-a2d8-5ad8cd5a863c'), # Quarterly Test Run 1
            uuid.UUID('88e659ff-1063-4af4-bb5c-8f7b63bdcfd0'), # Quarterly Test Run 2
            uuid.UUID('e0683a0a-06c0-437b-9892-c145815f1c3b'), # Quarterly sandbox
        ]
        for dup_id in duplicate_exam_ids:
            conn.execute(sa.text("""
                UPDATE examinations
                SET is_active = false, status = 'ARCHIVED'
                WHERE id = :id
            """), {"id": dup_id})


def downgrade() -> None:
    op.drop_index('ix_exam_schedules_paper_id', table_name='exam_schedules')
    op.create_unique_constraint('uq_exam_schedules_tsa_slot', 'exam_schedules', ['exam_id', 'teacher_subject_assignment_id'])
    op.alter_column('exam_schedules', 'teacher_subject_assignment_id', nullable=False)
    op.drop_column('exam_schedules', 'paper_id')
    op.drop_table('exam_paper_classes')
    op.drop_table('exam_papers')
