import uuid
from datetime import datetime, date
from typing import Optional, List, Dict, Any
from sqlalchemy import String, Integer, Float, Boolean, ForeignKey, Index, Text, Date, DateTime, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin


class SyllabusRecoveryPlan(Base, BaseModelMixin):
    """
    SQLAlchemy model representing an AI generated and Human-in-the-Loop editable
    Syllabus Recovery Plan for a subject in a specific class and section.
    Requires Principal/Admin review and approval before becoming operational.
    """
    __tablename__ = "syllabus_recovery_plans"

    # Plan Context
    reason: Mapped[str] = mapped_column(String(255), nullable=False)
    recovery_type: Mapped[str] = mapped_column(String(50), default="CROSS_TEACHER_RECOVERY", nullable=False, index=True)
    current_completion: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    target_completion_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    forecast_completion_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    new_forecast_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    delay_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    duration_weeks: Mapped[int] = mapped_column(Integer, default=2, nullable=False)
    recommended_periods_per_week: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    expected_recovery_periods: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    projected_improvement_days: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # Status: DRAFT, SUGGESTED, PROPOSED, EDITED, APPROVED, REJECTED, CANCELLED, COMPLETED
    status: Mapped[str] = mapped_column(String(30), default="SUGGESTED", nullable=False, index=True)
    rejection_remarks: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    parent_notes: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Multi-tenant and Scope Foreign Keys
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
    teacher_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("teachers.id", ondelete="SET NULL"), nullable=True, index=True
    )
    primary_teacher_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("teachers.id", ondelete="SET NULL"), nullable=True, index=True
    )
    support_teacher_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("teachers.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Factual candidate comparison evaluations (Teacher, Subject, Completion %, Capacity, Compatibility)
    candidate_evaluations: Mapped[list] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=list, server_default="[]", nullable=False
    )

    # Audit Trail and Approvals
    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    approved_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    approved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    audit_trail: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    tenant = relationship("Tenant")
    school = relationship("School")
    academic_year = relationship("AcademicYear")
    class_obj = relationship("Class")
    section = relationship("Section")
    subject = relationship("Subject")
    teacher = relationship("Teacher", foreign_keys=[teacher_id])
    primary_teacher = relationship("Teacher", foreign_keys=[primary_teacher_id])
    support_teacher = relationship("Teacher", foreign_keys=[support_teacher_id])
    items = relationship(
        "RecoveryPlanItem",
        back_populates="recovery_plan",
        cascade="all, delete-orphan",
        order_by="RecoveryPlanItem.date, RecoveryPlanItem.period_number"
    )

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        Index("ix_syllabus_recovery_school_ay", "school_id", "academic_year_id"),
        Index("ix_syllabus_recovery_sec_sub", "section_id", "subject_id"),
        Index("ix_syllabus_recovery_type", "recovery_type"),
    )


class RecoveryPlanItem(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a specific scheduled teaching period within
    an AI Syllabus Recovery Plan.
    Includes phase, duration, topic assignment, conflict detection, and individual approval status.
    """
    __tablename__ = "recovery_plan_items"

    recovery_plan_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("syllabus_recovery_plans.id", ondelete="CASCADE"), nullable=False, index=True
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )

    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    period_number: Mapped[int] = mapped_column(Integer, nullable=False)
    
    # Phase: PHASE_1_CATCHUP, PHASE_2_CORE, PHASE_3_PRACTICE, PHASE_4_BUFFER
    phase: Mapped[str] = mapped_column(String(50), default="PHASE_1_CATCHUP", nullable=False)
    
    syllabus_item_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("syllabuses.id", ondelete="SET NULL"), nullable=True, index=True
    )
    topic_name: Mapped[str] = mapped_column(String(200), nullable=False)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=45, nullable=False)

    teacher_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("teachers.id", ondelete="SET NULL"), nullable=True, index=True
    )
    class_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    section_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sections.id", ondelete="CASCADE"), nullable=False, index=True
    )
    room_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("rooms.id", ondelete="SET NULL"), nullable=True, index=True
    )
    timetable_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("timetables.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Status: SUGGESTED, MODIFIED, APPROVED, REJECTED
    status: Mapped[str] = mapped_column(String(30), default="SUGGESTED", nullable=False)
    is_approved: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    
    # Conflict detection status: NO_CONFLICT, CONFLICT_DETECTED
    conflict_status: Mapped[str] = mapped_column(String(30), default="NO_CONFLICT", nullable=False)
    conflict_message: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    recovery_plan = relationship("SyllabusRecoveryPlan", back_populates="items")
    syllabus = relationship("Syllabus")
    teacher = relationship("Teacher")
    class_obj = relationship("Class")
    section = relationship("Section")
    room = relationship("Room")
    timetable = relationship("Timetable")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        Index("ix_rec_items_plan_date", "recovery_plan_id", "date"),
    )
