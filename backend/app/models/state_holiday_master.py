import uuid
from typing import Optional
from datetime import date
from sqlalchemy import String, Date, Text, UniqueConstraint, Index
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class StateHolidayMaster(Base, BaseModelMixin):
    """
    SQLAlchemy model representing official, verified State / Central Public Holidays.
    Maintained at platform/state level from official government gazettes.
    Cannot be modified or corrupted by individual school administrators.
    """
    __tablename__ = "state_holiday_masters"

    state: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    academic_year_code: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    holiday_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    holiday_name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Official gazette source tracking
    source: Mapped[str] = mapped_column(String(255), nullable=False)
    source_version: Mapped[str] = mapped_column(String(100), nullable=False)
    source_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    
    # Verification status: VERIFIED, PENDING_VERIFICATION, UNVERIFIED
    verification_status: Mapped[str] = mapped_column(String(50), default="VERIFIED", nullable=False)

    __table_args__ = (
        UniqueConstraint("state", "academic_year_code", "holiday_date", name="uq_state_ay_holiday_date"),
        Index("ix_state_holiday_state_ay", "state", "academic_year_code"),
    )
