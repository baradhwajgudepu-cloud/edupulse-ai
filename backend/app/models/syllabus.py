import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Index, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class Syllabus(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a Syllabus entry.
    """
    __tablename__ = "syllabuses"

    syllabus_code: Mapped[str] = mapped_column(String(50), nullable=False)
    unit_name: Mapped[str] = mapped_column(String(150), nullable=False)
    chapter_name: Mapped[str] = mapped_column(String(150), nullable=False)
    topic_name: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    sequence_order: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    estimated_periods: Mapped[int] = mapped_column(Integer, default=4, nullable=False)
    coverage_status: Mapped[str] = mapped_column(String(30), default="PENDING", nullable=False)
    lifecycle_status: Mapped[str] = mapped_column(String(30), default="PLANNED", nullable=False)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

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
    subject_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False, index=True
    )
    section_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("sections.id", ondelete="CASCADE"), nullable=True, index=True
    )

    # Master Curriculum Linkage & Audit Trail
    curriculum_master_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("curriculum_masters.id", ondelete="SET NULL"), nullable=True, index=True
    )
    source: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    source_version: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    retrieved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    verification_status: Mapped[str] = mapped_column(String(30), default="VERIFIED", nullable=False)
    derived_from: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    is_custom: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Relationships
    tenant = relationship("Tenant")
    school = relationship("School")
    academic_year = relationship("AcademicYear")
    class_obj = relationship("Class")
    section = relationship("Section")
    subject = relationship("Subject")
    curriculum_master = relationship("CurriculumMaster")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "academic_year_id", "class_id", "subject_id", "syllabus_code",
            name="uq_syllabus_code_ay_class_sub"
        ),
        Index("ix_syllabuses_syllabus_code", "syllabus_code"),
    )
