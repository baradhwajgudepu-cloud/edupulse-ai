import uuid
from typing import Optional, List, Dict, Any
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Index, JSON, Time
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class ExtendedWorkingHour(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a School's Working Hours and Timetable Capacity configuration.
    Defines normal school timings, periods per day, and optional extended teaching hours.
    Used by AI Timetable Engine to discover available period capacity and suggest extended slots
    when capacity shortfall exists.
    """
    __tablename__ = "extended_working_hours"

    normal_start_time: Mapped[Any] = mapped_column(Time, nullable=False)  # e.g., 08:30
    normal_end_time: Mapped[Any] = mapped_column(Time, nullable=False)    # e.g., 15:30
    periods_per_day: Mapped[int] = mapped_column(Integer, default=8, nullable=False)
    lunch_period_number: Mapped[int] = mapped_column(Integer, default=4, nullable=False)
    
    working_days: Mapped[list] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"),
        default=lambda: ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"],
        server_default='["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]',
        nullable=False
    )

    is_extended_hours_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    extended_start_time: Mapped[Optional[Any]] = mapped_column(Time, nullable=True)  # e.g., 15:30
    extended_end_time: Mapped[Optional[Any]] = mapped_column(Time, nullable=True)    # e.g., 16:15
    applicable_days: Mapped[list] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=list, server_default="[]", nullable=False
    )
    additional_periods: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    activity_type: Mapped[str] = mapped_column(String(50), default="ADDITIONAL_SUBJECT", nullable=False)
    # ACADEMIC, REMEDIAL, ADDITIONAL_SUBJECT, EXTRA_CURRICULAR, SPECIAL_CLASS, OTHER

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    settings: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    academic_year_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academic_years.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Relationships
    tenant = relationship("Tenant")
    school = relationship("School")
    academic_year = relationship("AcademicYear")

    __table_args__ = (
        UniqueConstraint(
            "school_id", "academic_year_id",
            name="uq_extended_working_hours_school_ay"
        ),
        Index("ix_ewh_school_ay", "school_id", "academic_year_id"),
    )
