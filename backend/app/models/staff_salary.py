import uuid
import enum
from datetime import date
from decimal import Decimal
from typing import Optional
from sqlalchemy import String, Integer, ForeignKey, UniqueConstraint, Enum as SQLEnum, Date, Numeric
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class SalaryStatus(str, enum.Enum):
    GENERATED = "GENERATED"
    PENDING = "PENDING"
    PAID = "PAID"

class SalaryPaymentMethod(str, enum.Enum):
    BANK_TRANSFER = "BANK_TRANSFER"
    CASH = "CASH"
    CHEQUE = "CHEQUE"
    ONLINE = "ONLINE"

class StaffSalary(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy model representing staff salary slips and disbursements.
    Linked to a staff member (Teacher model), school, and tenant.
    """
    __tablename__ = "staff_salaries"

    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    staff_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("teachers.id", ondelete="CASCADE"), nullable=False, index=True
    )

    month: Mapped[int] = mapped_column(Integer, nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False)

    base_salary: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    allowances: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    deductions: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"), nullable=False)
    net_salary: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)

    status: Mapped[SalaryStatus] = mapped_column(
        SQLEnum(SalaryStatus, name="salarystatus", create_type=False),
        default=SalaryStatus.PENDING,
        nullable=False
    )

    payment_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    payment_method: Mapped[Optional[SalaryPaymentMethod]] = mapped_column(
        SQLEnum(SalaryPaymentMethod, name="salarypaymentmethod", create_type=False),
        nullable=True
    )
    reference_number: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    remarks: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    staff = relationship("Teacher", foreign_keys=[staff_id], lazy="joined")
    expense = relationship("Expense", back_populates="salary_payment", uselist=False)

    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "school_id", "staff_id", "month", "year",
            name="uq_staff_salaries_tenant_school_staff_month_year"
        ),
    )
