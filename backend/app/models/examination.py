import uuid
import enum
from typing import Optional, List, Dict, Any
from datetime import date, time, datetime
from sqlalchemy import String, Integer, Float, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Date, Time, Index, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class ExamStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    SCHEDULED = "SCHEDULED"
    ONGOING = "ONGOING"
    MARKS_ENTRY = "MARKS_ENTRY"
    UNDER_REVIEW = "UNDER_REVIEW"
    APPROVED = "APPROVED"
    PUBLISHED = "PUBLISHED"
    LOCKED = "LOCKED"
    COMPLETED = "COMPLETED"
    ARCHIVED = "ARCHIVED"

class ExamType(str, enum.Enum):
    UNIT_TEST = "UNIT_TEST"
    WEEKLY_TEST = "WEEKLY_TEST"
    MONTHLY = "MONTHLY"
    QUARTERLY = "QUARTERLY"
    HALF_YEARLY = "HALF_YEARLY"
    PRE_FINAL = "PRE_FINAL"
    ANNUAL = "ANNUAL"
    FINAL = "FINAL"
    PRACTICAL = "PRACTICAL"
    INTERNAL_ASSESSMENT = "INTERNAL_ASSESSMENT"
    SUPPLEMENTARY = "SUPPLEMENTARY"
    CUSTOM = "CUSTOM"

class ExamTypeCategory(str, enum.Enum):
    SCHOLASTIC = "SCHOLASTIC"
    CO_SCHOLASTIC = "CO_SCHOLASTIC"
    COMPETITIVE = "COMPETITIVE"
    PRACTICAL = "PRACTICAL"
    INTERNAL_ASSESSMENT = "INTERNAL_ASSESSMENT"
    OTHER = "OTHER"

class ExamTypeMaster(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a customizable Exam Type entity.
    """
    __tablename__ = "exam_type_masters"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    code: Mapped[str] = mapped_column(String(50), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    category: Mapped[ExamTypeCategory] = mapped_column(
        SQLEnum(ExamTypeCategory, name="examtypecategory", create_type=False),
        nullable=False,
        default=ExamTypeCategory.SCHOLASTIC
    )
    default_weightage: Mapped[float] = mapped_column(Float, default=100.0, nullable=False)
    is_system: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=True, index=True
    )

    tenant = relationship("Tenant")
    school = relationship("School")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint("tenant_id", "school_id", "code", name="uq_exam_type_tenant_school_code"),
        Index("ix_exam_type_masters_code", "code"),
    )

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
    participating_classes = relationship("ExaminationClass", back_populates="examination", cascade="all, delete-orphan")
    papers = relationship("ExamPaper", back_populates="examination", cascade="all, delete-orphan", order_by="ExamPaper.order_index")
    paper_classes = relationship("ExamPaperClass", back_populates="examination", cascade="all, delete-orphan")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        Index("ix_examinations_start_date", "start_date"),
        Index("ix_examinations_end_date", "end_date"),
        Index("ix_examinations_status", "status"),
    )

class ExaminationClass(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a participating class for an Examination.
    """
    __tablename__ = "examination_classes"

    examination_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("examinations.id", ondelete="CASCADE"), nullable=False, index=True
    )
    class_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )

    examination = relationship("Examination", back_populates="participating_classes")
    class_obj = relationship("Class")

    __table_args__ = (
        UniqueConstraint("examination_id", "class_id", name="uq_examination_participating_class"),
    )


class ExamPaper(Base, BaseModelMixin):
    """
    SQLAlchemy model representing an Exam Paper under an Examination Cycle.
    Each exam cycle has papers (e.g. Mathematics, English, Physics) which can be
    taken by multiple participating classes.
    """
    __tablename__ = "exam_papers"

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
    subject_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False, index=True
    )

    paper_name: Mapped[str] = mapped_column(String(200), nullable=False)
    paper_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    default_max_marks: Mapped[int] = mapped_column(Integer, default=100, nullable=False)
    default_pass_marks: Mapped[int] = mapped_column(Integer, default=35, nullable=False)
    default_duration_minutes: Mapped[int] = mapped_column(Integer, default=180, nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    examination = relationship("Examination", back_populates="papers")
    subject = relationship("Subject")
    class_configs = relationship("ExamPaperClass", back_populates="paper", cascade="all, delete-orphan")
    schedules = relationship("ExamSchedule", back_populates="paper")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        Index("ix_exam_papers_exam_subject", "examination_id", "subject_id"),
        Index("ix_exam_papers_tenant_school", "tenant_id", "school_id"),
    )


class ExamPaperClass(Base, BaseModelMixin):
    """
    SQLAlchemy model representing class-specific overrides for an Exam Paper.
    For example: Mathematics Paper has default 100 marks, but for Class 5 it is 50 marks.
    """
    __tablename__ = "exam_paper_classes"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    examination_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("examinations.id", ondelete="CASCADE"), nullable=False, index=True
    )
    paper_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("exam_papers.id", ondelete="CASCADE"), nullable=False, index=True
    )
    class_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True
    )

    maximum_marks: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    pass_marks: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    duration_minutes: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    examination = relationship("Examination", back_populates="paper_classes")
    paper = relationship("ExamPaper", back_populates="class_configs")
    class_obj = relationship("Class")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint("paper_id", "class_id", name="uq_exam_paper_class"),
        Index("ix_exam_paper_classes_exam_class", "examination_id", "class_id"),
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
    paper_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("exam_papers.id", ondelete="SET NULL"), nullable=True, index=True
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
    teacher_subject_assignment_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("teacher_subject_assignments.id", ondelete="CASCADE"), nullable=True, index=True
    )

    tenant = relationship("Tenant", back_populates="exam_schedules")
    school = relationship("School", back_populates="exam_schedules")
    academic_year = relationship("AcademicYear", back_populates="exam_schedules")
    examination = relationship("Examination", back_populates="schedules")
    paper = relationship("ExamPaper", back_populates="schedules")
    class_obj = relationship("Class")
    section = relationship("Section")
    subject = relationship("Subject")
    teacher_subject_assignment = relationship("TeacherSubjectAssignment")

    @property
    def subject_name(self) -> Optional[str]:
        return self.subject.subject_name if self.subject else None

    @property
    def subject_code(self) -> Optional[str]:
        return self.subject.subject_code if self.subject else None

    @property
    def paper_name(self) -> Optional[str]:
        if self.paper and self.paper.paper_name:
            return self.paper.paper_name
        return self.subject.subject_name if self.subject else None

    @property
    def class_name(self) -> Optional[str]:
        return self.class_obj.name if self.class_obj else None

    @property
    def section_name(self) -> Optional[str]:
        return self.section.name if self.section else None

    @property
    def exam_name(self) -> Optional[str]:
        return self.examination.exam_name if self.examination else None

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        Index("ix_exam_schedules_exam_date", "exam_date"),
        Index("ix_exam_schedules_exam_class_sec", "exam_id", "class_id", "section_id"),
    )

