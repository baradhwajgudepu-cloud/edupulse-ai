import uuid
import enum
from decimal import Decimal
from datetime import date, datetime, timezone
from typing import Optional, List, Dict, Any
from sqlalchemy import (
    String, Integer, Boolean, ForeignKey, UniqueConstraint, Index, Date, DateTime, JSON, Text, Uuid, Numeric, Enum as SQLEnum, func
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin


class PayrollCalculationBasis(str, enum.Enum):
    CALENDAR_DAYS = "CALENDAR_DAYS"      # e.g., 30 or 31 days in month
    WORKING_DAYS = "WORKING_DAYS"        # Excludes scheduled weekends and holidays
    FIXED_30_DAYS = "FIXED_30_DAYS"      # Uniform commercial 30-day basis


class DailyRateFormula(str, enum.Enum):
    GROSS_DIVIDED_BY_WORKING_DAYS = "GROSS_DIVIDED_BY_WORKING_DAYS"
    GROSS_DIVIDED_BY_CALENDAR_DAYS = "GROSS_DIVIDED_BY_CALENDAR_DAYS"
    BASIC_DIVIDED_BY_WORKING_DAYS = "BASIC_DIVIDED_BY_WORKING_DAYS"


class PayrollStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    REVIEWED = "REVIEWED"
    APPROVED = "APPROVED"
    DISBURSED = "DISBURSED"


class PayrollAuditAction(str, enum.Enum):
    CALCULATED = "CALCULATED"
    REVIEWED = "REVIEWED"
    APPROVED = "APPROVED"
    RECALCULATED_ATTENDANCE_CORRECTION = "RECALCULATED_ATTENDANCE_CORRECTION"
    DISBURSED = "DISBURSED"


class PayrollPolicy(Base, BaseModelMixin, TenantMixin):
    """
    Configurable School-level Payroll Policy determining how attendance maps to pay.
    """
    __tablename__ = "payroll_policies"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    policy_name: Mapped[str] = mapped_column(String(100), nullable=False, default="Standard School Payroll Policy")
    calculation_basis: Mapped[PayrollCalculationBasis] = mapped_column(
        SQLEnum(PayrollCalculationBasis, native_enum=False),
        default=PayrollCalculationBasis.WORKING_DAYS,
        server_default="WORKING_DAYS",
        nullable=False
    )
    standard_working_days: Mapped[int] = mapped_column(Integer, default=24, server_default="24", nullable=False)
    daily_rate_formula: Mapped[DailyRateFormula] = mapped_column(
        SQLEnum(DailyRateFormula, native_enum=False),
        default=DailyRateFormula.GROSS_DIVIDED_BY_WORKING_DAYS,
        server_default="GROSS_DIVIDED_BY_WORKING_DAYS",
        nullable=False
    )

    half_day_deduction_factor: Mapped[Decimal] = mapped_column(Numeric(4, 2), default=Decimal("0.50"), nullable=False)
    unpaid_leave_deduction_factor: Mapped[Decimal] = mapped_column(Numeric(4, 2), default=Decimal("1.00"), nullable=False)
    
    # Grace rules
    late_grace_count: Mapped[int] = mapped_column(Integer, default=3, server_default="3", nullable=False)  # 3 lates allowed per month
    late_deduction_factor: Mapped[Decimal] = mapped_column(Numeric(4, 2), default=Decimal("0.25"), nullable=False)  # Quarter day deduction per late thereafter

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)

    school = relationship("School", backref="payroll_policies")


class TeacherPayrollProfile(Base, BaseModelMixin, TenantMixin):
    """
    Staff Compensation Profile linked to Teacher entity.
    """
    __tablename__ = "teacher_payroll_profiles"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    teacher_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("teachers.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    monthly_gross_salary: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    basic_salary: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    hra_allowance: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    special_allowance: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    other_allowances: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)

    provident_fund_deduction: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    tax_deduction: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    other_deductions: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)

    paid_leave_quota_per_year: Mapped[int] = mapped_column(Integer, default=12, server_default="12", nullable=False)
    bank_account_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    bank_ifsc: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    bank_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    effective_from: Mapped[date] = mapped_column(Date, nullable=False, default=date.today)
    effective_until: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)

    teacher = relationship("Teacher", backref="payroll_profile")
    school = relationship("School", backref="teacher_payroll_profiles")

    __table_args__ = (
        UniqueConstraint("school_id", "teacher_id", name="uq_school_teacher_payroll_profile"),
    )


class TeacherPayroll(Base, BaseModelMixin, TenantMixin):
    """
    Monthly attendance-based payroll calculation record.
    Traceable, explainable, and audit-logged.
    """
    __tablename__ = "teacher_payrolls"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    teacher_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("teachers.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    policy_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("payroll_policies.id", ondelete="SET NULL"),
        nullable=True
    )

    month: Mapped[int] = mapped_column(Integer, nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    calculation_date: Mapped[date] = mapped_column(Date, nullable=False, default=date.today)

    # Attendance Input Counts
    calendar_days: Mapped[int] = mapped_column(Integer, default=30, nullable=False)
    applicable_working_days: Mapped[int] = mapped_column(Integer, default=24, nullable=False)
    present_days: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=Decimal("0.00"), nullable=False)
    approved_leave_days: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=Decimal("0.00"), nullable=False)
    half_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    unpaid_absence_days: Mapped[Decimal] = mapped_column(Numeric(5, 2), default=Decimal("0.00"), nullable=False)
    holidays_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    on_duty_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    late_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    unmarked_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # Monetary Breakdown
    gross_salary: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    daily_rate: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    attendance_deductions: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    statutory_deductions: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    manual_adjustments: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    adjustment_reason: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    net_payable: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)

    # AI Insight & Anomaly Detection
    ai_explanation: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    ai_anomalies: Mapped[Optional[list]] = mapped_column(JSON, default=list, server_default="[]", nullable=True)

    # Workflow & Approval
    status: Mapped[PayrollStatus] = mapped_column(
        SQLEnum(PayrollStatus, native_enum=False),
        default=PayrollStatus.DRAFT,
        server_default="DRAFT",
        nullable=False,
        index=True
    )
    calculated_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )
    approved_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )
    approved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    disbursed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    teacher = relationship("Teacher", backref="payrolls")
    school = relationship("School", backref="payrolls")
    policy = relationship("PayrollPolicy")
    calculator_user = relationship("User", foreign_keys=[calculated_by])
    approver_user = relationship("User", foreign_keys=[approved_by])

    __table_args__ = (
        UniqueConstraint("school_id", "teacher_id", "month", "year", name="uq_school_teacher_payroll_month_year"),
        Index("ix_teacher_payrolls_period", "school_id", "year", "month"),
    )


class PayrollAuditLog(Base, BaseModelMixin, TenantMixin):
    """
    Immutable audit log for all payroll events, adjustments, and retroactive attendance alerts.
    """
    __tablename__ = "payroll_audit_logs"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    payroll_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("teacher_payrolls.id", ondelete="CASCADE"),
        nullable=True,
        index=True
    )
    teacher_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("teachers.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    action: Mapped[PayrollAuditAction] = mapped_column(
        SQLEnum(PayrollAuditAction, native_enum=False),
        nullable=False
    )
    actor_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )

    previous_net_pay: Mapped[Optional[Decimal]] = mapped_column(Numeric(12, 2), nullable=True)
    revised_net_pay: Mapped[Optional[Decimal]] = mapped_column(Numeric(12, 2), nullable=True)
    delta_amount: Mapped[Optional[Decimal]] = mapped_column(Numeric(12, 2), nullable=True)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    payroll = relationship("TeacherPayroll", backref="audit_logs")
    teacher = relationship("Teacher")
    actor = relationship("User", foreign_keys=[actor_id])
