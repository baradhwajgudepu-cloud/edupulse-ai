import uuid
import enum
from datetime import date
from decimal import Decimal
from typing import Optional
from sqlalchemy import String, ForeignKey, Enum as SQLEnum, Date, Numeric
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class ExpenseCategory(str, enum.Enum):
    STAFF = "STAFF"
    INFRASTRUCTURE = "INFRASTRUCTURE"
    ACADEMIC = "ACADEMIC"
    OPERATIONS = "OPERATIONS"
    OTHER = "OTHER"

class Expense(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy model representing school expenditures.
    Can be an operational expense or linked to a staff salary disbursement.
    """
    __tablename__ = "expenses"

    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    category: Mapped[ExpenseCategory] = mapped_column(
        SQLEnum(ExpenseCategory, name="expensecategory", create_type=False),
        nullable=False,
        index=True
    )
    subcategory: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    expense_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    description: Mapped[str] = mapped_column(String(500), nullable=False)
    paid_to: Mapped[str] = mapped_column(String(150), nullable=False)
    payment_method: Mapped[str] = mapped_column(String(50), nullable=False, default="BANK_TRANSFER")
    reference_number: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    receipt_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    salary_payment_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("staff_salaries.id", ondelete="SET NULL"),
        nullable=True,
        unique=True,
        index=True
    )
    status: Mapped[str] = mapped_column(String(20), default="APPROVED", nullable=False)

    salary_payment = relationship("StaffSalary", back_populates="expense", foreign_keys=[salary_payment_id])
