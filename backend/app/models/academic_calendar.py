import uuid
import enum
from typing import Optional, Dict, Any
from datetime import date, datetime
from sqlalchemy import String, Integer, Boolean, ForeignKey, Enum as SQLEnum, Date, DateTime, Index, Text, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class CalendarEventType(str, enum.Enum):
    PUBLIC_HOLIDAY = "PUBLIC_HOLIDAY"
    SCHOOL_HOLIDAY = "SCHOOL_HOLIDAY"
    PRINCIPAL_DECLARED_HOLIDAY = "PRINCIPAL_DECLARED_HOLIDAY"
    EXAMINATION = "EXAMINATION"
    SCHOOL_EVENT = "SCHOOL_EVENT"
    WORKING_DAY = "WORKING_DAY"
    SPECIAL_WORKING_DAY = "SPECIAL_WORKING_DAY"

class CalendarEventStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    APPROVED = "APPROVED"
    PUBLISHED = "PUBLISHED"
    CANCELLED = "CANCELLED"

class AcademicCalendarEvent(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy model representing an Academic Calendar event, holiday, or special working day.
    Authoritative record for school working-day calculations, timetable impact analysis,
    and syllabus completion projections.
    """
    __tablename__ = "academic_calendar_events"

    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    academic_year_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academic_years.id", ondelete="CASCADE"), nullable=False, index=True
    )
    event_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    
    event_type: Mapped[CalendarEventType] = mapped_column(
        SQLEnum(CalendarEventType, name="calendareventtype", create_type=False),
        nullable=False,
        index=True
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Source tracking: STATE_GOVT_GAZETTE, SCHOOL_ADMIN, PRINCIPAL, EXAM_MODULE, etc.
    source: Mapped[str] = mapped_column(String(100), default="SCHOOL_ADMIN", nullable=False)
    source_reference: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    status: Mapped[CalendarEventStatus] = mapped_column(
        SQLEnum(CalendarEventStatus, name="calendareventstatus", create_type=False),
        nullable=False,
        default=CalendarEventStatus.APPROVED,
        index=True
    )

    # True for public/school/principal holidays; False for regular working days, events, special working days
    is_non_working_day: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    approved_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    approved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    extra_data: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Scoping relations
    school = relationship("School")
    academic_year = relationship("AcademicYear")
    creator = relationship("User", foreign_keys=[created_by])
    approver = relationship("User", foreign_keys=[approved_by])

    __table_args__ = (
        Index("ix_acad_cal_school_ay_date", "school_id", "academic_year_id", "event_date"),
        Index("ix_acad_cal_type_status", "event_type", "status"),
    )
