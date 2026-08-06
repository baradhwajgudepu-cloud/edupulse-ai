import uuid
import enum
from typing import Optional, Dict, Any
from datetime import date, datetime
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Date, Numeric, DateTime, text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class AssignmentStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    TRANSFERRED = "TRANSFERRED"
    ARCHIVED = "ARCHIVED"

class AssignmentType(str, enum.Enum):
    PRIMARY = "PRIMARY"
    SECONDARY = "SECONDARY"
    SUBSTITUTE = "SUBSTITUTE"

class TeacherSubjectAssignment(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a Teacher-Subject assignment in a class/section.
    """
    __tablename__ = "teacher_subject_assignments"

    assignment_type: Mapped[AssignmentType] = mapped_column(
        SQLEnum(AssignmentType, name="assignmenttype", create_type=False),
        nullable=False
    )
    priority: Mapped[Optional[int]] = mapped_column(Integer, default=1, nullable=True)
    weekly_periods: Mapped[int] = mapped_column(Integer, nullable=False)
    workload_percentage: Mapped[float] = mapped_column(Numeric(5, 2), default=0.00, nullable=False)
    
    effective_from: Mapped[date] = mapped_column(Date, nullable=False)
    effective_to: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    
    assigned_by: Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    assigned_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), server_default=text("now()"), nullable=True
    )
    
    status: Mapped[AssignmentStatus] = mapped_column(
        SQLEnum(AssignmentStatus, name="assignmentstatus", create_type=False),
        nullable=False,
        default=AssignmentStatus.ACTIVE
    )
    is_class_teacher: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    room_id: Mapped[Optional[uuid.UUID]] = mapped_column(nullable=True)
    maximum_students: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    remarks: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
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
    subject_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False, index=True
    )
    class_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    section_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sections.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="teacher_subject_assignments")
    school = relationship("School", back_populates="teacher_subject_assignments")
    academic_year = relationship("AcademicYear", back_populates="teacher_subject_assignments")
    teacher = relationship("Teacher", back_populates="teacher_subject_assignments")
    subject = relationship("Subject", back_populates="teacher_subject_assignments")
    class_obj = relationship("Class", back_populates="teacher_subject_assignments")
    section = relationship("Section", back_populates="teacher_subject_assignments")
    timetables: Mapped[list["Timetable"]] = relationship(
        "Timetable",
        back_populates="teacher_subject_assignment",
        cascade="all, delete-orphan"
    )

    homeworks: Mapped[list["Homework"]] = relationship(
        "Homework",
        back_populates="teacher_subject_assignment",
        cascade="all, delete-orphan"
    )

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "teacher_id", "subject_id", "class_id", "section_id", "academic_year_id",
            name="uq_tsa_composite"
        ),
    )

from app.models.timetable import Timetable  # noqa: F401
from app.models.homework import Homework  # noqa: F401
