import uuid
import enum
from typing import Optional, Dict, Any, List
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Date, Time, Index, Text, Numeric
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class MarksStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    SUBMITTED = "SUBMITTED"
    UNDER_REVIEW = "UNDER_REVIEW"
    RETURNED = "RETURNED"
    APPROVED = "APPROVED"
    PUBLISHED = "PUBLISHED"
    LOCKED = "LOCKED"

class ExamResult(str, enum.Enum):
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    MALPRACTICE = "MALPRACTICE"
    EXEMPTED = "EXEMPTED"

class Marks(Base, BaseModelMixin):
    """
    SQLAlchemy model representing Student Marks.
    """
    __tablename__ = "marks"

    maximum_marks: Mapped[int] = mapped_column(Integer, nullable=False)
    marks_obtained: Mapped[Optional[float]] = mapped_column(Numeric(5, 2), nullable=True)
    result_status: Mapped[ExamResult] = mapped_column(
        SQLEnum(ExamResult, name="examresult", create_type=False),
        nullable=False,
        default=ExamResult.PRESENT
    )
    status: Mapped[MarksStatus] = mapped_column(
        SQLEnum(MarksStatus, name="marksstatus", create_type=False),
        nullable=False,
        default=MarksStatus.DRAFT
    )
    grade: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    remarks: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    settings: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    ai_metrics: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    audit_history: Mapped[list] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=list, server_default="[]", nullable=False
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
    examination_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("examinations.id", ondelete="CASCADE"), nullable=False, index=True
    )
    exam_schedule_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("exam_schedules.id", ondelete="CASCADE"), nullable=False, index=True
    )
    student_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True
    )
    teacher_subject_assignment_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("teacher_subject_assignments.id", ondelete="CASCADE"), nullable=False, index=True
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

    tenant = relationship("Tenant", back_populates="marks")
    school = relationship("School", back_populates="marks")
    academic_year = relationship("AcademicYear", back_populates="marks")
    student = relationship("Student", back_populates="marks")
    examination = relationship("Examination")
    exam_schedule = relationship("ExamSchedule")
    teacher_subject_assignment = relationship("TeacherSubjectAssignment")
    teacher = relationship("Teacher")
    subject = relationship("Subject")
    class_obj = relationship("Class")
    section = relationship("Section")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "exam_schedule_id", "student_id",
            name="uq_marks_student_subject_schedule"
        ),
        Index("ix_marks_status", "status"),
    )
