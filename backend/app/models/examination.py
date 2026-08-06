import uuid
import enum
from typing import Optional, List, Dict, Any
from datetime import date, time, datetime
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Date, Time, Index, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class ExamStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    PUBLISHED = "PUBLISHED"
    LOCKED = "LOCKED"
    COMPLETED = "COMPLETED"
    ARCHIVED = "ARCHIVED"

class ExamType(str, enum.Enum):
    UNIT_TEST = "UNIT_TEST"
    MONTHLY = "MONTHLY"
    QUARTERLY = "QUARTERLY"
    HALF_YEARLY = "HALF_YEARLY"
    PRE_FINAL = "PRE_FINAL"
    ANNUAL = "ANNUAL"
    SUPPLEMENTARY = "SUPPLEMENTARY"

class ExamTemplate(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a reusable Exam Template.
    """
    __tablename__ = "exam_templates"

    template_name: Mapped[str] = mapped_column(String(200), nullable=False)
    exam_type: Mapped[ExamType] = mapped_column(
        SQLEnum(ExamType, name="examtype", create_type=False),
        nullable=False
    )
    subject_configs: Mapped[list] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=list, server_default="[]", nullable=False
    )
    settings: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
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

    tenant = relationship("Tenant", back_populates="exam_templates")
    school = relationship("School", back_populates="exam_templates")
    academic_year = relationship("AcademicYear", back_populates="exam_templates")

    __mapper_args__ = {
        "version_id_col": version
    }

class Examination(Base, BaseModelMixin):
    """
    SQLAlchemy model representing an Examination master entity.
    """
    __tablename__ = "examinations"

    exam_name: Mapped[str] = mapped_column(String(200), nullable=False)
    exam_type: Mapped[ExamType] = mapped_column(
        SQLEnum(ExamType, name="examtype", create_type=False),
        nullable=False
    )
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[ExamStatus] = mapped_column(
        SQLEnum(ExamStatus, name="examstatus", create_type=False),
        nullable=False,
        default=ExamStatus.DRAFT
    )
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    
    settings: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    ai_metrics: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
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

    tenant = relationship("Tenant", back_populates="examinations")
    school = relationship("School", back_populates="examinations")
    academic_year = relationship("AcademicYear", back_populates="examinations")
    schedules = relationship("ExamSchedule", back_populates="examination", cascade="all, delete-orphan")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        Index("ix_examinations_start_date", "start_date"),
        Index("ix_examinations_end_date", "end_date"),
        Index("ix_examinations_status", "status"),
    )

class ExamSchedule(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a specific Exam Schedule slot.
    """
    __tablename__ = "exam_schedules"

    exam_date: Mapped[date] = mapped_column(Date, nullable=False)
    start_time: Mapped[time] = mapped_column(Time, nullable=False)
    end_time: Mapped[time] = mapped_column(Time, nullable=False)
    max_marks: Mapped[int] = mapped_column(Integer, default=100, nullable=False)
    pass_marks: Mapped[int] = mapped_column(Integer, default=35, nullable=False)
    room_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    
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
    exam_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("examinations.id", ondelete="CASCADE"), nullable=False, index=True
    )
    class_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    section_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sections.id", ondelete="CASCADE"), nullable=False, index=True
    )
    subject_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False, index=True
    )
    teacher_subject_assignment_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("teacher_subject_assignments.id", ondelete="CASCADE"), nullable=False, index=True
    )

    tenant = relationship("Tenant", back_populates="exam_schedules")
    school = relationship("School", back_populates="exam_schedules")
    academic_year = relationship("AcademicYear", back_populates="exam_schedules")
    examination = relationship("Examination", back_populates="schedules")
    class_obj = relationship("Class")
    section = relationship("Section")
    subject = relationship("Subject")
    teacher_subject_assignment = relationship("TeacherSubjectAssignment")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "exam_id", "teacher_subject_assignment_id",
            name="uq_exam_schedules_tsa_slot"
        ),
        Index("ix_exam_schedules_exam_date", "exam_date"),
    )
