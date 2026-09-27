"""add_attendance_bulk_indexes_and_partial_status

Revision ID: e1351c0630e2
Revises: b2c3d4e5f6a7
Create Date: 2026-09-15 12:55:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'e1351c0630e2'
down_revision: Union[str, None] = 'b2c3d4e5f6a7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Safely add 'PARTIAL' to importjobstatus enum
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE importjobstatus ADD VALUE IF NOT EXISTS 'PARTIAL'")

    # 2. Add composite index on attendance_sessions for (school_id, class_id, section_id, attendance_date, session_type)
    op.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS ix_attendance_sessions_daily_unique
        ON attendance_sessions (school_id, class_id, section_id, attendance_date, session_type)
        WHERE deleted_at IS NULL
    """)

    # 3. Add composite index on attendances for (attendance_session_id, student_id)
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_attendances_session_student_active
        ON attendances (attendance_session_id, student_id)
        WHERE deleted_at IS NULL
    """)

    # 4. Add composite index on attendances for (student_id, attendance_date, session_type)
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_attendances_student_date_session_active
        ON attendances (student_id, attendance_date, session_type)
        WHERE deleted_at IS NULL
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_attendances_student_date_session_active")
    op.execute("DROP INDEX IF EXISTS ix_attendances_session_student_active")
    op.execute("DROP INDEX IF EXISTS ix_attendance_sessions_daily_unique")
