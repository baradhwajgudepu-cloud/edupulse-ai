import uuid
import enum
from typing import Optional, Dict, Any
from datetime import date, datetime
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Date, DateTime, text, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class AttendanceSessionStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    SUBMITTED = "SUBMITTED"
    LOCKED = "LOCKED"

class AttendanceStatus(str, enum.Enum):
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    LATE = "LATE"
    HALF_DAY = "HALF_DAY"
    MEDICAL_LEAVE = "MEDICAL_LEAVE"
    EXCUSED = "EXCUSED"
    HOLIDAY = "HOLIDAY"
    ONLINE = "ONLINE"

class AttendanceSource(str, enum.Enum):
    MANUAL = "MANUAL"
    BIOMETRIC = "BIOMETRIC"
    RFID = "RFID"
    FACE_RECOGNITION = "FACE_RECOGNITION"
    IMPORT = "IMPORT"

class AttendanceReason(str, enum.Enum):
    SICK = "SICK"
    PERSONAL = "PERSONAL"
    SPORTS = "SPORTS"
    OFFICIAL = "OFFICIAL"
    UNKNOWN = "UNKNOWN"

class AttendanceSession(Base, BaseModelMixin):
    """
    SQLAlchemy model representing an Attendance Session for a specific timetable slot.
    """
    __tablename__ = "attendance_sessions"

    attendance_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[AttendanceSessionStatus] = mapped_column(
        SQLEnum(AttendanceSessionStatus, name="attendancesessionstatus", create_type=False),
        nullable=False,
        default=AttendanceSessionStatus.DRAFT
    )
    
    marked_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    marked_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    settings: Mapped[dict] = mapped_column(
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
    timetable_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("timetables.id", ondelete="CASCADE"), nullable=False, index=True
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
    tenant = relationship("Tenant", back_populates="attendance_sessions")
    school = relationship("School", back_populates="attendance_sessions")
    academic_year = relationship("AcademicYear", back_populates="attendance_sessions")
    timetable = relationship("Timetable", back_populates="attendance_sessions")
    class_obj = relationship("Class", back_populates="attendance_sessions")
    section = relationship("Section", back_populates="attendance_sessions")
    teacher = relationship("Teacher", back_populates="attendance_sessions")
    subject = relationship("Subject", back_populates="attendance_sessions")

    attendances = relationship(
        "Attendance",
        back_populates="attendance_session",
        cascade="all, delete-orphan"
    )

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "timetable_id", "attendance_date",
            name="uq_attendance_sessions_slot"
        ),
        Index("ix_attendance_sessions_date", "attendance_date"),
    )


class Attendance(Base, BaseModelMixin):
    """
    SQLAlchemy model representing individual student attendance records.
    """
    __tablename__ = "attendances"

    attendance_date: Mapped[date] = mapped_column(Date, nullable=False)
    attendance_status: Mapped[AttendanceStatus] = mapped_column(
        SQLEnum(AttendanceStatus, name="attendancestatus", create_type=False),
        nullable=False
    )
    attendance_source: Mapped[AttendanceSource] = mapped_column(
        SQLEnum(AttendanceSource, name="attendancesource", create_type=False),
        nullable=False,
        default=AttendanceSource.MANUAL
    )
    attendance_reason: Mapped[AttendanceReason] = mapped_column(
        SQLEnum(AttendanceReason, name="attendancereason", create_type=False),
        nullable=False,
        default=AttendanceReason.UNKNOWN
    )
    remarks: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    parent_viewed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    parent_viewed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    settings: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), 
        default=lambda: {"notification_status": "PENDING", "notification_sent_at": None, "sms_sent": False, "push_sent": False},
        server_default='{"notification_status": "PENDING", "notification_sent_at": null, "sms_sent": false, "push_sent": false}',
        nullable=False
    )
    ai_metrics: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"),
        default=lambda: {"attendance_percentage": None, "absence_streak": None, "predicted_dropout_risk": None, "late_frequency": None, "attendance_trend": None, "exam_risk_score": None},
        server_default='{"attendance_percentage": null, "absence_streak": null, "predicted_dropout_risk": null, "late_frequency": null, "attendance_trend": null, "exam_risk_score": null}',
        nullable=False
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
    attendance_session_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("attendance_sessions.id", ondelete="CASCADE"), nullable=False, index=True
    )
    student_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True
    )
    timetable_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("timetables.id", ondelete="CASCADE"), nullable=False, index=True
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
    tenant = relationship("Tenant", back_populates="attendances")
    school = relationship("School", back_populates="attendances")
    academic_year = relationship("AcademicYear", back_populates="attendances")
    attendance_session = relationship("AttendanceSession", back_populates="attendances")
    student = relationship("Student", back_populates="attendances")
    timetable = relationship("Timetable", back_populates="attendances")
    class_obj = relationship("Class", back_populates="attendances")
    section = relationship("Section", back_populates="attendances")
    teacher = relationship("Teacher", back_populates="attendances")
    subject = relationship("Subject", back_populates="attendances")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "student_id", "timetable_id", "attendance_date",
            name="uq_attendances_student_slot"
        ),
        UniqueConstraint(
            "attendance_session_id", "student_id",
            name="uq_attendances_session_student"
        ),
        Index("ix_attendances_date", "attendance_date"),
        Index("ix_attendances_status", "attendance_status"),
    )
