import uuid
import enum
from typing import Optional, Dict, Any
from datetime import date, datetime
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Date, Index, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class HomeworkStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    PUBLISHED = "PUBLISHED"
    ARCHIVED = "ARCHIVED"

class HomeworkPriority(str, enum.Enum):
    LOW = "LOW"
    NORMAL = "NORMAL"
    HIGH = "HIGH"

class Homework(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a Homework entry.
    """
    __tablename__ = "homeworks"

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    due_date: Mapped[date] = mapped_column(Date, nullable=False)
    priority: Mapped[HomeworkPriority] = mapped_column(
        SQLEnum(HomeworkPriority, name="homeworkpriority", create_type=False),
        nullable=False,
        default=HomeworkPriority.NORMAL
    )
    status: Mapped[HomeworkStatus] = mapped_column(
        SQLEnum(HomeworkStatus, name="homeworkstatus", create_type=False),
        nullable=False,
        default=HomeworkStatus.DRAFT
    )
    attachment_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    estimated_minutes: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
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
    teacher_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("teachers.id", ondelete="CASCADE"), nullable=False, index=True
    )
    teacher_subject_assignment_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("teacher_subject_assignments.id", ondelete="CASCADE"), nullable=False, index=True
    )
    subject_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False, index=True
    )
    class_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    section_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sections.id", ondelete="CASCADE"), nullable=False, index=True
    )
    timetable_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("timetables.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="homeworks")
    school = relationship("School", back_populates="homeworks")
    academic_year = relationship("AcademicYear", back_populates="homeworks")
    teacher = relationship("Teacher", back_populates="homeworks")
    teacher_subject_assignment = relationship("TeacherSubjectAssignment", back_populates="homeworks")
    subject = relationship("Subject", back_populates="homeworks")
    class_obj = relationship("Class", back_populates="homeworks")
    section = relationship("Section", back_populates="homeworks")
    timetable = relationship("Timetable", back_populates="homeworks")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        Index("ix_homeworks_due_date", "due_date"),
        Index("ix_homeworks_status", "status"),
    )
