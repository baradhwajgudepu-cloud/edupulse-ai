import uuid
import enum
from datetime import date, datetime
from decimal import Decimal
from typing import Optional, List
from sqlalchemy import String, Integer, text, func, Boolean, ForeignKey, UniqueConstraint, Index, Date, DateTime, Numeric, Enum as SQLEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class ConcessionType(str, enum.Enum):
    FIXED = "FIXED"
    PERCENTAGE = "PERCENTAGE"

class PaymentMethod(str, enum.Enum):
    CASH = "CASH"
    BANK_TRANSFER = "BANK_TRANSFER"
    CARD = "CARD"
    CHEQUE = "CHEQUE"
    ONLINE = "ONLINE"

class PaymentStatus(str, enum.Enum):
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"

class FeeAssignmentStatus(str, enum.Enum):
    UNPAID = "UNPAID"
    PARTIALLY_PAID = "PARTIALLY_PAID"
    PAID = "PAID"

class FineType(str, enum.Enum):
    FIXED = "FIXED"
    PERCENTAGE = "PERCENTAGE"
    DAILY_FIXED = "DAILY_FIXED"


class FeeType(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model representing a Fee Type (e.g. Tuition, Transport, Exam).
    """
    __tablename__ = "fee_types"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    code: Mapped[str] = mapped_column(String(50), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    is_system: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_fee_types_tenant_code"),
    )


class Scholarship(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model representing a Fee Concession/Scholarship rules.
    """
    __tablename__ = "scholarships"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    concession_type: Mapped[ConcessionType] = mapped_column(
        SQLEnum(ConcessionType, name="concessiontype", create_type=False), nullable=False
    )
    value: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )

    __table_args__ = (
        Index(
            "uq_scholarships_tenant_school_name_lower",
            "tenant_id",
            "school_id",
            text("lower(name)"),
            unique=True,
            postgresql_where=text("deleted_at IS NULL")
        ),
    )


class FeeStructure(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model representing a Fee Structure defining cost per class/year.
    """
    __tablename__ = "fee_structures"

    fee_type_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("fee_types.id", ondelete="CASCADE"), nullable=False
    )
    academic_year_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academic_years.id", ondelete="CASCADE"), nullable=False
    )
    class_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("classes.id", ondelete="SET NULL"), nullable=True
    )
    
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    due_date: Mapped[date] = mapped_column(Date, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )

    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    fee_type = relationship("FeeType")
    academic_year = relationship("AcademicYear")
    class_entity = relationship("Class")
    fine_rule = relationship("FineRule", back_populates="fee_structure", uselist=False, cascade="all, delete-orphan")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        Index(
            "uq_fee_structure_active",
            "tenant_id",
            "school_id",
            "academic_year_id",
            "class_id",
            "fee_type_id",
            unique=True,
            postgresql_where=text("deleted_at IS NULL")
        ),
    )


class FineRule(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model representing late fee policies per structure.
    """
    __tablename__ = "fine_rules"

    fee_structure_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("fee_structures.id", ondelete="CASCADE"), nullable=False
    )
    grace_period_days: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    fine_type: Mapped[FineType] = mapped_column(
        SQLEnum(FineType, name="finetype", create_type=False), nullable=False
    )
    fine_value: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )

    fee_structure = relationship("FeeStructure", back_populates="fine_rule")

    __table_args__ = (
        UniqueConstraint("fee_structure_id", name="uq_fine_rules_fee_structure"),
    )


class StudentFeeAssignment(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model mapping fee structure entries to individual students.
    """
    __tablename__ = "student_fee_assignments"

    student_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("students.id", ondelete="CASCADE"), nullable=False
    )
    fee_structure_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("fee_structures.id", ondelete="RESTRICT"), nullable=False
    )
    academic_year_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academic_years.id", ondelete="CASCADE"), nullable=False
    )

    assigned_amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    scholarship_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("scholarships.id", ondelete="SET NULL"), nullable=True
    )
    discount_amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0.00"), server_default="0.00", nullable=False)
    fine_amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0.00"), server_default="0.00", nullable=False)
    paid_amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0.00"), server_default="0.00", nullable=False)
    status: Mapped[FeeAssignmentStatus] = mapped_column(
        SQLEnum(FeeAssignmentStatus, name="feeassignmentstatus", create_type=False), default=FeeAssignmentStatus.UNPAID, nullable=False
    )

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    student = relationship("Student")
    fee_structure = relationship("FeeStructure")
    scholarship = relationship("Scholarship")
    academic_year = relationship("AcademicYear")

    __table_args__ = (
        UniqueConstraint("student_id", "fee_structure_id", name="uq_student_fee_assignments_student_structure"),
    )

    __mapper_args__ = {
        "version_id_col": version
    }


class FeePayment(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model storing student transaction payments.
    """
    __tablename__ = "fee_payments"

    student_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("students.id", ondelete="CASCADE"), nullable=False
    )
    academic_year_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academic_years.id", ondelete="CASCADE"), nullable=False
    )
    amount_paid: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    payment_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    payment_method: Mapped[PaymentMethod] = mapped_column(
        SQLEnum(PaymentMethod, name="paymentmethod", create_type=False), nullable=False
    )
    status: Mapped[PaymentStatus] = mapped_column(
        SQLEnum(PaymentStatus, name="paymentstatus", create_type=False), default=PaymentStatus.COMPLETED, nullable=False
    )
    transaction_reference: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    remarks: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    cancel_reason: Mapped[Optional[str]] = mapped_column(String(250), nullable=True)
    cancelled_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    student = relationship("Student")
    academic_year = relationship("AcademicYear")
    cancelled_by_user = relationship("User")
    allocations = relationship("FeePaymentAllocation", back_populates="payment", cascade="all, delete-orphan")
    receipt = relationship("FeeReceipt", back_populates="payment", uselist=False, cascade="all, delete-orphan")

    __mapper_args__ = {
        "version_id_col": version
    }


class FeePaymentAllocation(Base):
    """
    SQLAlchemy Association Model mapping a payment to assignments.
    """
    __tablename__ = "fee_payment_allocations"

    payment_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("fee_payments.id", ondelete="CASCADE"), primary_key=True
    )
    assignment_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("student_fee_assignments.id", ondelete="RESTRICT"), primary_key=True
    )
    amount_allocated: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)

    # Relationships
    payment = relationship("FeePayment", back_populates="allocations")
    assignment = relationship("StudentFeeAssignment")


class FeeReceipt(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model storing receipt references.
    """
    __tablename__ = "fee_receipts"

    payment_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("fee_payments.id", ondelete="CASCADE"), nullable=False
    )
    receipt_number: Mapped[str] = mapped_column(String(50), nullable=False)
    pdf_path: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Relationships
    payment = relationship("FeePayment", back_populates="receipt")

    __table_args__ = (
        UniqueConstraint("payment_id", name="uq_fee_receipts_payment"),
        UniqueConstraint("receipt_number", name="uq_fee_receipts_number"),
    )


# Import dependencies to resolve mappings at load time
from app.models.tenant import Tenant  # noqa: F401
from app.models.school import School  # noqa: F401
from app.models.academic_year import AcademicYear  # noqa: F401
from app.models.class_entity import Class  # noqa: F401
from app.models.student import Student  # noqa: F401
from app.models.user import User  # noqa: F401
