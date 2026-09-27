"""school_subjects_and_timetable_capacity

Revision ID: d4f43db6
Revises: f3511c0852e4
Create Date: 2026-09-26 13:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'd4f43db6'
down_revision: Union[str, None] = 'h7044fg1de54'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Update SubjectCategory enum values if on Postgres
    with op.get_context().autocommit_block():
        for val in ['ADDITIONAL', 'VOCATIONAL', 'OTHER', 'SKILL', 'REMEDIAL']:
            op.execute(f"""
                DO $$
                BEGIN
                    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subjectcategory') THEN
                        ALTER TYPE subjectcategory ADD VALUE IF NOT EXISTS '{val}';
                    END IF;
                END
                $$;
            """)

    # 2. Add source_type to subjects table
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_name = 'subjects' AND column_name = 'source_type'
            ) THEN
                ALTER TABLE subjects ADD COLUMN source_type VARCHAR(50) DEFAULT 'BOARD_OFFICIAL' NOT NULL;
                CREATE INDEX IF NOT EXISTS ix_subjects_source_type ON subjects (source_type);
            END IF;
        END
        $$;
    """)

    # 3. Create class_subject_assignments table
    op.execute("""
        CREATE TABLE IF NOT EXISTS class_subject_assignments (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            weekly_periods INTEGER NOT NULL DEFAULT 3,
            period_duration_minutes INTEGER NOT NULL DEFAULT 45,
            preferred_days JSONB NOT NULL DEFAULT '[]',
            preferred_time VARCHAR(50),
            max_consecutive_periods INTEGER NOT NULL DEFAULT 1,
            min_gap_between_sessions INTEGER NOT NULL DEFAULT 1,
            is_lab_required BOOLEAN NOT NULL DEFAULT FALSE,
            room_id UUID,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            settings JSONB NOT NULL DEFAULT '{}',
            tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
            school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
            academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE CASCADE,
            class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
            section_id UUID REFERENCES sections(id) ON DELETE CASCADE,
            subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
            teacher_id UUID REFERENCES teachers(id) ON DELETE SET NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()) NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()) NOT NULL,
            deleted_at TIMESTAMP WITH TIME ZONE,
            created_by UUID,
            updated_by UUID,
            CONSTRAINT uq_class_section_subject_ay UNIQUE (academic_year_id, class_id, section_id, subject_id)
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_csa_school_ay ON class_subject_assignments (school_id, academic_year_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_csa_class_subject ON class_subject_assignments (class_id, subject_id)")

    # 4. Create extended_working_hours table
    op.execute("""
        CREATE TABLE IF NOT EXISTS extended_working_hours (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            normal_start_time TIME NOT NULL DEFAULT '08:30:00',
            normal_end_time TIME NOT NULL DEFAULT '15:30:00',
            periods_per_day INTEGER NOT NULL DEFAULT 8,
            lunch_period_number INTEGER NOT NULL DEFAULT 4,
            working_days JSONB NOT NULL DEFAULT '["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]',
            is_extended_hours_enabled BOOLEAN NOT NULL DEFAULT FALSE,
            extended_start_time TIME,
            extended_end_time TIME,
            applicable_days JSONB NOT NULL DEFAULT '[]',
            additional_periods INTEGER NOT NULL DEFAULT 1,
            activity_type VARCHAR(50) NOT NULL DEFAULT 'ADDITIONAL_SUBJECT',
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            settings JSONB NOT NULL DEFAULT '{}',
            tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
            school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
            academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE CASCADE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()) NOT NULL,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()) NOT NULL,
            deleted_at TIMESTAMP WITH TIME ZONE,
            created_by UUID,
            updated_by UUID,
            CONSTRAINT uq_extended_working_hours_school_ay UNIQUE (school_id, academic_year_id)
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_ewh_school_ay ON extended_working_hours (school_id, academic_year_id)")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS extended_working_hours CASCADE;")
    op.execute("DROP TABLE IF EXISTS class_subject_assignments CASCADE;")
    op.execute("ALTER TABLE subjects DROP COLUMN IF EXISTS source_type;")
