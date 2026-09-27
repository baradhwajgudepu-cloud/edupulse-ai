"""add_missing_audit_columns_to_school_admin_and_compliance

Revision ID: i8155gh2ef65
Revises: d4f43db6
Create Date: 2026-09-26 14:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision: str = 'i8155gh2ef65'
down_revision: Union[str, None] = 'd4f43db6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLES = [
    "school_profiles",
    "school_recognitions",
    "school_custom_fields",
    "school_documents",
    "document_access_logs",
    "payroll_policies",
    "teacher_payroll_profiles",
    "teacher_payrolls",
    "payroll_audit_logs",
]


def upgrade() -> None:
    for table in TABLES:
        op.execute(f"""
            DO $$
            BEGIN
                IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '{table}') THEN
                    IF NOT EXISTS (
                        SELECT 1 FROM information_schema.columns
                        WHERE table_name = '{table}' AND column_name = 'created_by'
                    ) THEN
                        ALTER TABLE {table} ADD COLUMN created_by UUID;
                    END IF;
                    IF NOT EXISTS (
                        SELECT 1 FROM information_schema.columns
                        WHERE table_name = '{table}' AND column_name = 'updated_by'
                    ) THEN
                        ALTER TABLE {table} ADD COLUMN updated_by UUID;
                    END IF;
                END IF;
            END
            $$;
        """)


def downgrade() -> None:
    for table in TABLES:
        op.execute(f"""
            DO $$
            BEGIN
                IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '{table}') THEN
                    ALTER TABLE {table} DROP COLUMN IF EXISTS updated_by;
                    ALTER TABLE {table} DROP COLUMN IF EXISTS created_by;
                END IF;
            END
            $$;
        """)
