import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, Float, Boolean, ForeignKey, UniqueConstraint, Index, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class SyllabusCoverageProgress(Base, BaseModelMixin):
    """
    SQLAlchemy model representing actual teaching progress for a specific
    syllabus topic/chapter within a class section and academic year.
    Supports teacher updates, start/completion timestamps, remarks, and lifecycle status.
    """
    __tablename__ = "syllabus_coverage_progress"

    status: Mapped[str] = mapped_column(String(30), default="PLANNED", nullable=False)
    completion_percentage: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    started_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    remarks: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

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
    class_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    section_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sections.id", ondelete="CASCADE"), nullable=False, index=True
    )
    subject_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False, index=True
    )
    syllabus_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("syllabuses.id", ondelete="CASCADE"), nullable=False, index=True
    )
    teacher_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("teachers.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Relationships
    tenant = relationship("Tenant")
    school = relationship("School")
    academic_year = relationship("AcademicYear")
    class_obj = relationship("Class")
    section = relationship("Section")
    subject = relationship("Subject")
    syllabus = relationship("Syllabus")
    teacher = relationship("Teacher")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "school_id", "academic_year_id", "section_id", "syllabus_id",
            name="uq_coverage_progress_school_ay_sec_syll"
        ),
        Index("ix_coverage_progress_sec_sub", "section_id", "subject_id"),
        Index("ix_coverage_progress_teacher", "teacher_id"),
    )
