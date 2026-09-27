"""add_school_admin_compliance_payroll_documents

Revision ID: h7044fg1de54
Revises: g6933ef0cd43
Create Date: 2026-09-26 13:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = 'h7044fg1de54'
down_revision: Union[str, None] = 'g6933ef0cd43'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    # 1. school_profiles
    if "school_profiles" not in tables:
        op.create_table(
            "school_profiles",
            sa.Column("id", UUID(as_uuid=True), primary_key=True),
            sa.Column("tenant_id", UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("school_id", UUID(as_uuid=True), sa.ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, unique=True, index=True),
            sa.Column("school_category", sa.String(100), nullable=True),
            sa.Column("management_type", sa.String(100), nullable=True),
            sa.Column("school_level", sa.String(100), nullable=True),
            sa.Column("established_year", sa.Integer(), nullable=True),
            sa.Column("medium_of_instruction", sa.String(100), server_default="English", nullable=True),
            sa.Column("gender_type", sa.String(50), server_default="Co-Education", nullable=True),
            sa.Column("minority_status", sa.String(100), server_default="Non-Minority", nullable=True),
            sa.Column("area_type", sa.String(50), server_default="Urban", nullable=True),
            sa.Column("school_photo_url", sa.String(1024), nullable=True),
            sa.Column("school_motto", sa.String(255), nullable=True),
            sa.Column("correspondent_name", sa.String(255), nullable=True),
            sa.Column("headmaster_name", sa.String(255), nullable=True),
            sa.Column("management_contact", sa.String(100), nullable=True),
            sa.Column("emergency_contact", sa.String(100), nullable=True),
            sa.Column("school_working_hours", sa.String(100), server_default="08:30 AM - 04:00 PM", nullable=True),
            sa.Column("office_working_hours", sa.String(100), server_default="09:00 AM - 05:00 PM", nullable=True),
            sa.Column("morning_assembly_time", sa.String(50), server_default="08:45 AM", nullable=True),
            sa.Column("lunch_time", sa.String(50), server_default="12:30 PM - 01:15 PM", nullable=True),
            sa.Column("total_capacity", sa.Integer(), server_default="1000", nullable=False),
            sa.Column("current_capacity", sa.Integer(), server_default="0", nullable=False),
            sa.Column("total_sections_count", sa.Integer(), server_default="0", nullable=False),
            sa.Column("has_transport", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("has_hostel", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("has_library", sa.Boolean(), server_default="true", nullable=False),
            sa.Column("has_laboratory", sa.Boolean(), server_default="true", nullable=False),
            sa.Column("has_sports_facilities", sa.Boolean(), server_default="true", nullable=False),
            sa.Column("has_smart_classrooms", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("has_computer_lab", sa.Boolean(), server_default="true", nullable=False),
            sa.Column("has_medical_room", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("has_cctv", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("has_fire_safety", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("has_water_sanitation", sa.Boolean(), server_default="true", nullable=False),
            sa.Column("has_electricity_backup", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("has_accessibility_ramps", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("udise_status", sa.String(50), server_default="CONFIGURED", nullable=False),
            sa.Column("udise_verification_status", sa.String(50), server_default="UNVERIFIED", nullable=False),
            sa.Column("udise_verified_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("udise_verified_by", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
            sa.Column("udise_notes", sa.String(500), nullable=True),
            sa.Column("custom_values", sa.JSON(), server_default="{}", nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True)
        )

    # 2. school_recognitions
    if "school_recognitions" not in tables:
        op.create_table(
            "school_recognitions",
            sa.Column("id", UUID(as_uuid=True), primary_key=True),
            sa.Column("tenant_id", UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("school_id", UUID(as_uuid=True), sa.ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("authority_level", sa.String(50), nullable=False),
            sa.Column("authority_name", sa.String(255), nullable=False),
            sa.Column("recognition_type", sa.String(50), nullable=False),
            sa.Column("recognition_number", sa.String(100), nullable=False),
            sa.Column("certificate_number", sa.String(100), nullable=True),
            sa.Column("proceedings_order_number", sa.String(100), nullable=True),
            sa.Column("issue_date", sa.Date(), nullable=True),
            sa.Column("valid_from", sa.Date(), nullable=True),
            sa.Column("valid_until", sa.Date(), nullable=True),
            sa.Column("status", sa.String(50), server_default="ACTIVE", nullable=False),
            sa.Column("document_id", UUID(as_uuid=True), nullable=True),
            sa.Column("remarks", sa.String(500), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True)
        )

    # 3. school_custom_fields
    if "school_custom_fields" not in tables:
        op.create_table(
            "school_custom_fields",
            sa.Column("id", UUID(as_uuid=True), primary_key=True),
            sa.Column("tenant_id", UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("school_id", UUID(as_uuid=True), sa.ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("field_name", sa.String(100), nullable=False),
            sa.Column("field_key", sa.String(100), nullable=False),
            sa.Column("field_type", sa.String(50), nullable=False),
            sa.Column("field_options", sa.JSON(), server_default="[]", nullable=True),
            sa.Column("is_required", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("visible_to_principal", sa.Boolean(), server_default="true", nullable=False),
            sa.Column("visible_to_teachers", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("visible_to_parents", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
            sa.UniqueConstraint("school_id", "field_key", name="uq_school_custom_field_key")
        )

    # 4. school_documents
    if "school_documents" not in tables:
        op.create_table(
            "school_documents",
            sa.Column("id", UUID(as_uuid=True), primary_key=True),
            sa.Column("tenant_id", UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("school_id", UUID(as_uuid=True), sa.ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("category", sa.String(50), nullable=False),
            sa.Column("title", sa.String(255), nullable=False),
            sa.Column("document_number", sa.String(100), nullable=True),
            sa.Column("file_name", sa.String(255), nullable=False),
            sa.Column("file_path", sa.String(1024), nullable=False),
            sa.Column("file_size_bytes", sa.Integer(), server_default="0", nullable=False),
            sa.Column("content_type", sa.String(100), server_default="application/pdf", nullable=False),
            sa.Column("expiry_date", sa.Date(), nullable=True),
            sa.Column("confidentiality_level", sa.String(50), server_default="STANDARD", nullable=False),
            sa.Column("is_password_protected", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("passcode_salt", sa.String(64), nullable=True),
            sa.Column("passcode_hash", sa.String(128), nullable=True),
            sa.Column("is_archived", sa.Boolean(), server_default="false", nullable=False),
            sa.Column("remarks", sa.String(500), nullable=True),
            sa.Column("uploaded_by", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True)
        )

    # 5. document_access_logs
    if "document_access_logs" not in tables:
        op.create_table(
            "document_access_logs",
            sa.Column("id", UUID(as_uuid=True), primary_key=True),
            sa.Column("tenant_id", UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("school_id", UUID(as_uuid=True), sa.ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("document_id", UUID(as_uuid=True), sa.ForeignKey("school_documents.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
            sa.Column("action", sa.String(50), nullable=False),
            sa.Column("ip_address", sa.String(100), nullable=True),
            sa.Column("user_agent", sa.String(255), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True)
        )

    # 6. payroll_policies
    if "payroll_policies" not in tables:
        op.create_table(
            "payroll_policies",
            sa.Column("id", UUID(as_uuid=True), primary_key=True),
            sa.Column("tenant_id", UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("school_id", UUID(as_uuid=True), sa.ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("policy_name", sa.String(100), server_default="Standard School Payroll Policy", nullable=False),
            sa.Column("calculation_basis", sa.String(50), server_default="WORKING_DAYS", nullable=False),
            sa.Column("standard_working_days", sa.Integer(), server_default="24", nullable=False),
            sa.Column("daily_rate_formula", sa.String(50), server_default="GROSS_DIVIDED_BY_WORKING_DAYS", nullable=False),
            sa.Column("half_day_deduction_factor", sa.Numeric(4, 2), server_default="0.50", nullable=False),
            sa.Column("unpaid_leave_deduction_factor", sa.Numeric(4, 2), server_default="1.00", nullable=False),
            sa.Column("late_grace_count", sa.Integer(), server_default="3", nullable=False),
            sa.Column("late_deduction_factor", sa.Numeric(4, 2), server_default="0.25", nullable=False),
            sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True)
        )

    # 7. teacher_payroll_profiles
    if "teacher_payroll_profiles" not in tables:
        op.create_table(
            "teacher_payroll_profiles",
            sa.Column("id", UUID(as_uuid=True), primary_key=True),
            sa.Column("tenant_id", UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("school_id", UUID(as_uuid=True), sa.ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("teacher_id", UUID(as_uuid=True), sa.ForeignKey("teachers.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("monthly_gross_salary", sa.Numeric(12, 2), nullable=False),
            sa.Column("basic_salary", sa.Numeric(12, 2), server_default="0.00", nullable=False),
            sa.Column("hra_allowance", sa.Numeric(12, 2), server_default="0.00", nullable=False),
            sa.Column("special_allowance", sa.Numeric(12, 2), server_default="0.00", nullable=False),
            sa.Column("other_allowances", sa.Numeric(12, 2), server_default="0.00", nullable=False),
            sa.Column("provident_fund_deduction", sa.Numeric(12, 2), server_default="0.00", nullable=False),
            sa.Column("tax_deduction", sa.Numeric(12, 2), server_default="0.00", nullable=False),
            sa.Column("other_deductions", sa.Numeric(12, 2), server_default="0.00", nullable=False),
            sa.Column("paid_leave_quota_per_year", sa.Integer(), server_default="12", nullable=False),
            sa.Column("bank_account_number", sa.String(50), nullable=True),
            sa.Column("bank_ifsc", sa.String(20), nullable=True),
            sa.Column("bank_name", sa.String(100), nullable=True),
            sa.Column("effective_from", sa.Date(), nullable=False),
            sa.Column("effective_until", sa.Date(), nullable=True),
            sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
            sa.UniqueConstraint("school_id", "teacher_id", name="uq_school_teacher_payroll_profile")
        )

    # 8. teacher_payrolls
    if "teacher_payrolls" not in tables:
        op.create_table(
            "teacher_payrolls",
            sa.Column("id", UUID(as_uuid=True), primary_key=True),
            sa.Column("tenant_id", UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("school_id", UUID(as_uuid=True), sa.ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("teacher_id", UUID(as_uuid=True), sa.ForeignKey("teachers.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("policy_id", UUID(as_uuid=True), sa.ForeignKey("payroll_policies.id", ondelete="SET NULL"), nullable=True),
            sa.Column("month", sa.Integer(), nullable=False),
            sa.Column("year", sa.Integer(), nullable=False),
            sa.Column("calculation_date", sa.Date(), nullable=False),
            sa.Column("calendar_days", sa.Integer(), server_default="30", nullable=False),
            sa.Column("applicable_working_days", sa.Integer(), server_default="24", nullable=False),
            sa.Column("present_days", sa.Numeric(5, 2), server_default="0.00", nullable=False),
            sa.Column("approved_leave_days", sa.Numeric(5, 2), server_default="0.00", nullable=False),
            sa.Column("half_days", sa.Integer(), server_default="0", nullable=False),
            sa.Column("unpaid_absence_days", sa.Numeric(5, 2), server_default="0.00", nullable=False),
            sa.Column("holidays_count", sa.Integer(), server_default="0", nullable=False),
            sa.Column("on_duty_days", sa.Integer(), server_default="0", nullable=False),
            sa.Column("late_days", sa.Integer(), server_default="0", nullable=False),
            sa.Column("unmarked_days", sa.Integer(), server_default="0", nullable=False),
            sa.Column("gross_salary", sa.Numeric(12, 2), nullable=False),
            sa.Column("daily_rate", sa.Numeric(12, 2), nullable=False),
            sa.Column("attendance_deductions", sa.Numeric(12, 2), server_default="0.00", nullable=False),
            sa.Column("statutory_deductions", sa.Numeric(12, 2), server_default="0.00", nullable=False),
            sa.Column("manual_adjustments", sa.Numeric(12, 2), server_default="0.00", nullable=False),
            sa.Column("adjustment_reason", sa.String(255), nullable=True),
            sa.Column("net_payable", sa.Numeric(12, 2), nullable=False),
            sa.Column("ai_explanation", sa.Text(), nullable=True),
            sa.Column("ai_anomalies", sa.JSON(), server_default="[]", nullable=True),
            sa.Column("status", sa.String(50), server_default="DRAFT", nullable=False),
            sa.Column("calculated_by", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
            sa.Column("approved_by", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
            sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("disbursed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
            sa.UniqueConstraint("school_id", "teacher_id", "month", "year", name="uq_school_teacher_payroll_month_year")
        )
        op.create_index("ix_teacher_payrolls_period", "teacher_payrolls", ["school_id", "year", "month"])

    # 9. payroll_audit_logs
    if "payroll_audit_logs" not in tables:
        op.create_table(
            "payroll_audit_logs",
            sa.Column("id", UUID(as_uuid=True), primary_key=True),
            sa.Column("tenant_id", UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("school_id", UUID(as_uuid=True), sa.ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("payroll_id", UUID(as_uuid=True), sa.ForeignKey("teacher_payrolls.id", ondelete="CASCADE"), nullable=True, index=True),
            sa.Column("teacher_id", UUID(as_uuid=True), sa.ForeignKey("teachers.id", ondelete="CASCADE"), nullable=False, index=True),
            sa.Column("action", sa.String(50), nullable=False),
            sa.Column("actor_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
            sa.Column("previous_net_pay", sa.Numeric(12, 2), nullable=True),
            sa.Column("revised_net_pay", sa.Numeric(12, 2), nullable=True),
            sa.Column("delta_amount", sa.Numeric(12, 2), nullable=True),
            sa.Column("notes", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True)
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = sa.inspect(conn)
    tables = inspector.get_table_names()

    drop_order = [
        "payroll_audit_logs",
        "teacher_payrolls",
        "teacher_payroll_profiles",
        "payroll_policies",
        "document_access_logs",
        "school_documents",
        "school_custom_fields",
        "school_recognitions",
        "school_profiles",
    ]

    for table in drop_order:
        if table in tables:
            op.drop_table(table)
