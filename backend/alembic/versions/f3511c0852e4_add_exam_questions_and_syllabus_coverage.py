"""add_exam_questions_and_syllabus_coverage

Revision ID: f3511c0852e4
Revises: f2461c0741e3
Create Date: 2026-09-23 09:05:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'f3511c0852e4'
down_revision: Union[str, None] = 'f2461c0741e3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create Enums if they do not exist
    with op.get_context().autocommit_block():
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'questiondifficulty') THEN
                    CREATE TYPE questiondifficulty AS ENUM ('EASY', 'MEDIUM', 'HARD');
                END IF;
            END
            $$;
        """)
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'questiontype') THEN
                    CREATE TYPE questiontype AS ENUM ('MCQ', 'SHORT', 'LONG', 'NUMERICAL');
                END IF;
            END
            $$;
        """)

    # 2. Add coverage_status and completed_at to syllabuses
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'syllabuses' AND column_name = 'coverage_status'
            ) THEN
                ALTER TABLE syllabuses ADD COLUMN coverage_status VARCHAR(30) NOT NULL DEFAULT 'PENDING';
            END IF;
        END
        $$;
    """)
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'syllabuses' AND column_name = 'completed_at'
            ) THEN
                ALTER TABLE syllabuses ADD COLUMN completed_at TIMESTAMPTZ NULL;
            END IF;
        END
        $$;
    """)

    # 3. Create exam_questions table
    op.execute("""
        CREATE TABLE IF NOT EXISTS exam_questions (
            id UUID PRIMARY KEY,
            examination_id UUID NOT NULL REFERENCES examinations(id) ON DELETE CASCADE,
            subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
            exam_schedule_id UUID NULL REFERENCES exam_schedules(id) ON DELETE CASCADE,
            question_number VARCHAR(20) NOT NULL,
            question_text TEXT NULL,
            max_marks NUMERIC(5, 2) NOT NULL,
            chapter_name VARCHAR(150) NOT NULL,
            topic_name VARCHAR(150) NULL,
            difficulty questiondifficulty NOT NULL DEFAULT 'MEDIUM',
            question_type questiontype NOT NULL DEFAULT 'SHORT',
            syllabus_id UUID NULL REFERENCES syllabuses(id) ON DELETE SET NULL,
            tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
            school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
            academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE CASCADE,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            deleted_at TIMESTAMPTZ NULL,
            created_by UUID NULL,
            updated_by UUID NULL,
            CONSTRAINT uq_exam_subject_question_number UNIQUE (examination_id, subject_id, question_number)
        );
    """)

    # 4. Indexes (each in its own op.execute call for asyncpg compatibility)
    op.execute("CREATE INDEX IF NOT EXISTS ix_exam_questions_exam_subject ON exam_questions (examination_id, subject_id);")
    op.execute("CREATE INDEX IF NOT EXISTS ix_exam_questions_chapter ON exam_questions (chapter_name);")
    op.execute("CREATE INDEX IF NOT EXISTS ix_exam_questions_tenant_id ON exam_questions (tenant_id);")
    op.execute("CREATE INDEX IF NOT EXISTS ix_exam_questions_school_id ON exam_questions (school_id);")
    op.execute("CREATE INDEX IF NOT EXISTS ix_exam_questions_academic_year_id ON exam_questions (academic_year_id);")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS exam_questions CASCADE;")
    op.execute("ALTER TABLE syllabuses DROP COLUMN IF EXISTS coverage_status;")
    op.execute("ALTER TABLE syllabuses DROP COLUMN IF EXISTS completed_at;")
