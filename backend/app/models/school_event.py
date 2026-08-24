import uuid
import enum
from typing import Optional
from datetime import date, time
from sqlalchemy import String, Integer, Boolean, ForeignKey, Enum as SQLEnum, Date, Time, Index, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class EventAudience(str, enum.Enum):
    ALL = "ALL"
    STUDENTS = "STUDENTS"
    PARENTS = "PARENTS"
    TEACHERS = "TEACHERS"

class EventStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    PUBLISHED = "PUBLISHED"
    CANCELLED = "CANCELLED"
    COMPLETED = "COMPLETED"

class SchoolEvent(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a School Event or Holiday.
    """
    __tablename__ = "school_events"

    event_name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    event_date: Mapped[date] = mapped_column(Date, nullable=False)
    start_time: Mapped[time] = mapped_column(Time, nullable=False)
    end_time: Mapped[time] = mapped_column(Time, nullable=False)
    venue: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    
    target_audience: Mapped[EventAudience] = mapped_column(
        SQLEnum(EventAudience, name="eventaudience", create_type=False),
        nullable=False,
        default=EventAudience.ALL
    )
    status: Mapped[EventStatus] = mapped_column(
        SQLEnum(EventStatus, name="eventstatus", create_type=False),
        nullable=False,
        default=EventStatus.DRAFT
    )
    
    is_holiday: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    academic_year_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academic_years.id", ondelete="CASCADE"), nullable=False, index=True
    )

    tenant = relationship("Tenant")
    school = relationship("School")
    academic_year = relationship("AcademicYear")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        Index("ix_school_events_event_date", "event_date"),
        Index("ix_school_events_status", "status"),
        Index("ix_school_events_target_audience", "target_audience"),
    )
