import uuid
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from sqlalchemy import String, Integer, Float, Boolean, ForeignKey, UniqueConstraint, Index, Text, Numeric, DateTime, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class QuestionPaper(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a verified Question Paper document tied to an Examination Paper schedule.
    """
    __tablename__ = "question_papers"

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
    paper_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("exam_schedules.id", ondelete="CASCADE"), nullable=False, index=True
    )

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    total_marks: Mapped[float] = mapped_column(Numeric(5, 2), default=100.0, nullable=False)
    total_questions: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    sections_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    source_file_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    source_file_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True) # PDF, IMAGE, MANUAL
    storage_reference: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    processing_status: Mapped[str] = mapped_column(String(50), default="PENDING", nullable=False) # PENDING, EXTRACTED, VERIFIED, FAILED
    verification_status: Mapped[str] = mapped_column(String(50), default="UNVERIFIED", nullable=False) # UNVERIFIED, VERIFIED
    verified_by: Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    verified_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    ai_extraction_metadata: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    syllabus_coverage_metrics: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )

    # Relationships
    examination = relationship("Examination")
    paper_schedule = relationship("ExamSchedule")
    questions = relationship("ExamQuestion", back_populates="question_paper", cascade="all, delete-orphan", order_by="ExamQuestion.sequence_order")

    __table_args__ = (
        UniqueConstraint("paper_id", name="uq_question_paper_schedule_paper"),
        Index("ix_question_papers_exam_paper", "examination_id", "paper_id"),
    )


class StudentQuestionMarks(Base, BaseModelMixin):
    """
    SQLAlchemy model representing individual question marks per student (Mode B).
    """
    __tablename__ = "student_question_marks"

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
    question_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("exam_questions.id", ondelete="CASCADE"), nullable=False, index=True
    )
    student_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True
    )

    marks_obtained: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False)
    max_marks: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False)
    is_attempted: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    remarks: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    audit_history: Mapped[list] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=list, server_default="[]", nullable=False
    )

    # Relationships
    question = relationship("ExamQuestion", back_populates="student_marks")
    student = relationship("Student")
    exam_schedule = relationship("ExamSchedule")
    examination = relationship("Examination")

    __table_args__ = (
        UniqueConstraint("question_id", "student_id", name="uq_student_question_marks_q_student"),
        Index("ix_student_qmarks_schedule_student", "exam_schedule_id", "student_id"),
        Index("ix_student_qmarks_question", "question_id"),
    )
