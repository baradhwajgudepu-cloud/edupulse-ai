import uuid
import enum
from typing import Optional, Dict, Any
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Time, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class TimetableStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    ARCHIVED = "ARCHIVED"

class DayOfWeek(str, enum.Enum):
    MONDAY = "MONDAY"
    TUESDAY = "TUESDAY"
    WEDNESDAY = "WEDNESDAY"
    THURSDAY = "THURSDAY"
    FRIDAY = "FRIDAY"
    SATURDAY = "SATURDAY"
    SUNDAY = "SUNDAY"

class PeriodType(str, enum.Enum):
    REGULAR = "REGULAR"
    LAB = "LAB"
    SPORTS = "SPORTS"
    LIBRARY = "LIBRARY"
    BREAK = "BREAK"
    EXAM = "EXAM"

class Timetable(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a Timetable entry/period slot.
    """
    __tablename__ = "timetables"

    day_of_week: Mapped[DayOfWeek] = mapped_column(
        SQLEnum(DayOfWeek, name="dayofweek", create_type=False),
        nullable=False
    )
    period_number: Mapped[int] = mapped_column(Integer, nullable=False)
    period_id: Mapped[Optional[uuid.UUID]] = mapped_column(nullable=True)
    
    start_time: Mapped[Any] = mapped_column(Time, nullable=False)
    end_time: Mapped[Any] = mapped_column(Time, nullable=False)
    
    period_type: Mapped[PeriodType] = mapped_column(
        SQLEnum(PeriodType, name="periodtype", create_type=False),
        nullable=False
    )
    room_id: Mapped[Optional[uuid.UUID]] = mapped_column(nullable=True)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    
    status: Mapped[TimetableStatus] = mapped_column(
        SQLEnum(TimetableStatus, name="timetablestatus", create_type=False),
        nullable=False,
        default=TimetableStatus.ACTIVE
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    
    settings: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    ai_metrics: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )

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
    teacher_subject_assignment_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("teacher_subject_assignments.id", ondelete="CASCADE"), nullable=True, index=True
    )
    class_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    section_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sections.id", ondelete="CASCADE"), nullable=False, index=True
    )
    teacher_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("teachers.id", ondelete="CASCADE"), nullable=True, index=True
    )
    subject_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("subjects.id", ondelete="CASCADE"), nullable=True, index=True
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="timetables")
    school = relationship("School", back_populates="timetables")
    academic_year = relationship("AcademicYear", back_populates="timetables")
    teacher_subject_assignment = relationship("TeacherSubjectAssignment", back_populates="timetables")
    class_obj = relationship("Class", back_populates="timetables")
    section = relationship("Section", back_populates="timetables")
    teacher = relationship("Teacher", back_populates="timetables")
    subject = relationship("Subject", back_populates="timetables")
    attendance_sessions: Mapped[list["AttendanceSession"]] = relationship(
        "AttendanceSession",
        back_populates="timetable",
        cascade="all, delete-orphan"
    )
    attendances: Mapped[list["Attendance"]] = relationship(
        "Attendance",
        back_populates="timetable",
        cascade="all, delete-orphan"
    )

    homeworks: Mapped[list["Homework"]] = relationship(
        "Homework",
        back_populates="timetable",
        cascade="all, delete-orphan"
    )

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "teacher_id", "day_of_week", "period_number", "academic_year_id",
            name="uq_timetables_teacher_slot"
        ),
        UniqueConstraint(
            "class_id", "section_id", "day_of_week", "period_number", "academic_year_id",
            name="uq_timetables_class_slot"
        ),
        UniqueConstraint(
            "teacher_subject_assignment_id", "day_of_week", "period_number",
            name="uq_timetables_tsa_slot"
        ),
        Index("ix_timetables_day_of_week", "day_of_week"),
        Index("ix_timetables_period_number", "period_number"),
    )

from app.models.attendance import AttendanceSession, Attendance  # noqa: F401
from app.models.homework import Homework  # noqa: F401
