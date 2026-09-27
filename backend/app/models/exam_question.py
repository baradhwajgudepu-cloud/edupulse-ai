import uuid
import enum
from typing import Optional
from sqlalchemy import String, Integer, ForeignKey, UniqueConstraint, Index, Text, Numeric, Enum as SQLEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class QuestionDifficulty(str, enum.Enum):
    EASY = "EASY"
    MEDIUM = "MEDIUM"
    HARD = "HARD"

class QuestionType(str, enum.Enum):
    MCQ = "MCQ"
    SHORT = "SHORT"
    LONG = "LONG"
    NUMERICAL = "NUMERICAL"

class ExamQuestion(Base, BaseModelMixin):
    """
    SQLAlchemy model representing an examination question mapped to syllabus chapter/topic.
    """
    __tablename__ = "exam_questions"

    examination_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("examinations.id", ondelete="CASCADE"), nullable=False, index=True
    )
    subject_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False, index=True
    )
    exam_schedule_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("exam_schedules.id", ondelete="CASCADE"), nullable=True, index=True
    )
    
    question_paper_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("question_papers.id", ondelete="CASCADE"), nullable=True, index=True
    )
    parent_question_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("exam_questions.id", ondelete="CASCADE"), nullable=True, index=True
    )
    
    question_number: Mapped[str] = mapped_column(String(20), nullable=False)
    section_name: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    sequence_order: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    question_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    max_marks: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False)
    chapter_name: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    topic_name: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    
    difficulty: Mapped[QuestionDifficulty] = mapped_column(
        SQLEnum(QuestionDifficulty, name="questiondifficulty", create_type=False),
        nullable=False,
        default=QuestionDifficulty.MEDIUM
    )
    question_type: Mapped[QuestionType] = mapped_column(
        SQLEnum(QuestionType, name="questiontype", create_type=False),
        nullable=False,
        default=QuestionType.SHORT
    )
    
    syllabus_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("syllabuses.id", ondelete="SET NULL"), nullable=True, index=True
    )
    extraction_confidence: Mapped[Optional[float]] = mapped_column(Numeric(4, 3), nullable=True)
    mapping_confidence: Mapped[Optional[float]] = mapped_column(Numeric(4, 3), nullable=True)
    mapping_source: Mapped[Optional[str]] = mapped_column(String(50), nullable=True) # AI, MANUAL, TEACHER_REVIEWED
    review_status: Mapped[str] = mapped_column(String(50), default="PENDING", nullable=False) # PENDING, VERIFIED, FLAGGED_FOR_REVIEW

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    academic_year_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academic_years.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Relationships
    examination = relationship("Examination")
    subject = relationship("Subject")
    exam_schedule = relationship("ExamSchedule")
    syllabus = relationship("Syllabus")
    question_paper = relationship("QuestionPaper", back_populates="questions")
    parent_question = relationship("ExamQuestion", remote_side="ExamQuestion.id", backref="sub_questions")
    student_marks = relationship("StudentQuestionMarks", back_populates="question", cascade="all, delete-orphan")
    tenant = relationship("Tenant")
    school = relationship("School")
    academic_year = relationship("AcademicYear")

    __table_args__ = (
        Index("ix_exam_questions_exam_subject", "examination_id", "subject_id"),
        Index("ix_exam_questions_paper", "question_paper_id"),
        Index("ix_exam_questions_schedule", "exam_schedule_id"),
        Index("ix_exam_questions_chapter", "chapter_name"),
    )
