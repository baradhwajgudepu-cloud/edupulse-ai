"""add_compliance_catalogue_records_and_audit

Revision ID: l9277ij4gh87
Revises: k9266hi3fg76
Create Date: 2026-09-27 09:10:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'l9277ij4gh87'
down_revision: Union[str, None] = 'k9266hi3fg76'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. school_compliance_requirements
    op.execute("""
        CREATE TABLE IF NOT EXISTS school_compliance_requirements (
            id UUID PRIMARY KEY,
            code VARCHAR(100) UNIQUE NOT NULL,
            title VARCHAR(255) NOT NULL,
            category VARCHAR(50) NOT NULL,
            applicable_authority VARCHAR(255) NOT NULL,
            statutory_reference VARCHAR(255) NOT NULL,
            requirement_description TEXT NOT NULL,
            what_school_must_maintain TEXT NOT NULL,
            required_documents JSON DEFAULT '[]' NOT NULL,
            field_schema JSON DEFAULT '{}' NOT NULL,
            default_validity_months INTEGER,
            renewal_reminder_days INTEGER DEFAULT 60 NOT NULL,
            mandatory BOOLEAN DEFAULT TRUE NOT NULL,
            sort_order INTEGER DEFAULT 0 NOT NULL,
            is_active BOOLEAN DEFAULT TRUE NOT NULL,
            created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
            updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
            deleted_at TIMESTAMPTZ,
            created_by UUID,
            updated_by UUID
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_school_compliance_requirements_category ON school_compliance_requirements(category)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_school_compliance_requirements_code ON school_compliance_requirements(code)")

    # 2. school_compliance_records
    op.execute("""
        CREATE TABLE IF NOT EXISTS school_compliance_records (
            id UUID PRIMARY KEY,
            tenant_id UUID NOT NULL,
            school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
            requirement_id UUID NOT NULL REFERENCES school_compliance_requirements(id) ON DELETE CASCADE,
            status VARCHAR(50) DEFAULT 'MISSING_EVIDENCE' NOT NULL,
            certificate_number VARCHAR(100),
            issuing_authority VARCHAR(255),
            issue_date DATE,
            expiry_date DATE,
            last_inspection_date DATE,
            next_renewal_date DATE,
            primary_document_id UUID REFERENCES school_documents(id) ON DELETE SET NULL,
            supporting_document_ids JSON DEFAULT '[]' NOT NULL,
            photo_evidence_urls JSON DEFAULT '[]' NOT NULL,
            specific_data JSON DEFAULT '{}' NOT NULL,
            missing_items JSON DEFAULT '[]' NOT NULL,
            verification_status VARCHAR(50) DEFAULT 'UNVERIFIED' NOT NULL,
            verified_at TIMESTAMPTZ,
            verified_by UUID REFERENCES users(id) ON DELETE SET NULL,
            verification_notes VARCHAR(500),
            remarks VARCHAR(500),
            created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
            updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
            deleted_at TIMESTAMPTZ,
            created_by UUID,
            updated_by UUID,
            CONSTRAINT uq_school_compliance_record UNIQUE (school_id, requirement_id)
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_school_compliance_records_school_id ON school_compliance_records(school_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_school_compliance_records_requirement_id ON school_compliance_records(requirement_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_school_compliance_records_tenant_id ON school_compliance_records(tenant_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_school_compliance_records_status ON school_compliance_records(status)")

    # 3. compliance_audit_logs
    op.execute("""
        CREATE TABLE IF NOT EXISTS compliance_audit_logs (
            id UUID PRIMARY KEY,
            tenant_id UUID NOT NULL,
            school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
            record_id UUID NOT NULL REFERENCES school_compliance_records(id) ON DELETE CASCADE,
            action VARCHAR(100) NOT NULL,
            actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
            actor_name VARCHAR(255),
            actor_role VARCHAR(100),
            changes JSON DEFAULT '{}' NOT NULL,
            notes TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
            updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
            deleted_at TIMESTAMPTZ,
            created_by UUID,
            updated_by UUID
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_compliance_audit_logs_record_id ON compliance_audit_logs(record_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_compliance_audit_logs_school_id ON compliance_audit_logs(school_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_compliance_audit_logs_tenant_id ON compliance_audit_logs(tenant_id)")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS compliance_audit_logs CASCADE")
    op.execute("DROP TABLE IF EXISTS school_compliance_records CASCADE")
    op.execute("DROP TABLE IF EXISTS school_compliance_requirements CASCADE")
