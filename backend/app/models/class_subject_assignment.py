import uuid
from typing import Optional, List, Dict, Any
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Index, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class ClassSubjectAssignment(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a Class/Section-Subject mapping and period configuration.
    Stores periods per week, duration, preferred days/times, teacher, room, and lab requirements.
    Powers timetable capacity calculation and AI timetable scheduling.
    """
    __tablename__ = "class_subject_assignments"

    weekly_periods: Mapped[int] = mapped_column(Integer, default=3, nullable=False)
    period_duration_minutes: Mapped[int] = mapped_column(Integer, default=45, nullable=False)
    
    preferred_days: Mapped[list] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=list, server_default="[]", nullable=False
    )
    preferred_time: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)  # e.g., "MORNING", "AFTERNOON"
    max_consecutive_periods: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    min_gap_between_sessions: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_lab_required: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    room_id: Mapped[Optional[uuid.UUID]] = mapped_column(nullable=True)
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
    class_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    section_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("sections.id", ondelete="CASCADE"), nullable=True, index=True
    )
    subject_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False, index=True
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
    subject = relationship("Subject", back_populates="class_subject_assignments")
    teacher = relationship("Teacher")

    __table_args__ = (
        UniqueConstraint(
            "academic_year_id", "class_id", "section_id", "subject_id",
            name="uq_class_section_subject_ay"
        ),
        Index("ix_csa_school_ay", "school_id", "academic_year_id"),
        Index("ix_csa_class_subject", "class_id", "subject_id"),
    )
