import uuid
import enum
from typing import Optional, Dict, Any
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class SubjectStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    ARCHIVED = "ARCHIVED"

class SubjectCategory(str, enum.Enum):
    CORE = "CORE"
    ELECTIVE = "ELECTIVE"
    LANGUAGE = "LANGUAGE"
    OPTIONAL = "OPTIONAL"
    LAB = "LAB"
    SPORTS = "SPORTS"
    ARTS = "ARTS"
    CO_CURRICULAR = "CO_CURRICULAR"

class SubjectType(str, enum.Enum):
    THEORY = "THEORY"
    PRACTICAL = "PRACTICAL"
    THEORY_PRACTICAL = "THEORY_PRACTICAL"

class Subject(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a Subject.
    """
    __tablename__ = "subjects"

    subject_code: Mapped[str] = mapped_column(String(50), nullable=False)
    subject_name: Mapped[str] = mapped_column(String(150), nullable=False)
    short_name: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    
    category: Mapped[SubjectCategory] = mapped_column(
        SQLEnum(SubjectCategory, name="subjectcategory", create_type=False),
        nullable=False
    )
    subject_type: Mapped[SubjectType] = mapped_column(
        SQLEnum(SubjectType, name="subjecttype", create_type=False),
        nullable=False
    )
    
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    credit_hours: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    weekly_periods: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    
    theory_marks: Mapped[Optional[int]] = mapped_column(Integer, default=0, nullable=True)
    practical_marks: Mapped[Optional[int]] = mapped_column(Integer, default=0, nullable=True)
    pass_marks: Mapped[Optional[int]] = mapped_column(Integer, default=0, nullable=True)
    
    display_color: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    display_order: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    
    status: Mapped[SubjectStatus] = mapped_column(
        SQLEnum(SubjectStatus, name="subjectstatus", create_type=False),
        nullable=False,
        default=SubjectStatus.ACTIVE
    )
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

    # Relationships
    tenant = relationship("Tenant", back_populates="subjects")
    school = relationship("School", back_populates="subjects")
    academic_year = relationship("AcademicYear", back_populates="subjects")
    teacher_subject_assignments: Mapped[list["TeacherSubjectAssignment"]] = relationship(
        "TeacherSubjectAssignment",
        back_populates="subject",
        cascade="all, delete-orphan"
    )
    timetables: Mapped[list["Timetable"]] = relationship(
        "Timetable",
        back_populates="subject",
        cascade="all, delete-orphan"
    )
    
    attendance_sessions: Mapped[list["AttendanceSession"]] = relationship(
        "AttendanceSession",
        back_populates="subject",
        cascade="all, delete-orphan"
    )

    attendances: Mapped[list["Attendance"]] = relationship(
        "Attendance",
        back_populates="subject",
        cascade="all, delete-orphan"
    )

    # ==================================================
    # Future Placeholders (Empty for mapper safety)
    # ==================================================
    # class_subject_assignments = relationship("ClassSubjectAssignment", back_populates="subject")
    homeworks: Mapped[list["Homework"]] = relationship(
        "Homework",
        back_populates="subject",
        cascade="all, delete-orphan"
    )
    # examinations = relationship("Examination", back_populates="subject")
    # marks = relationship("Marks", back_populates="subject")

    __mapper_args__ = {
        "version_id_col": version
    }


    __table_args__ = (
        UniqueConstraint(
            "academic_year_id", "subject_code",
            name="uq_subjects_code_ay"
        ),
        UniqueConstraint(
            "academic_year_id", "subject_name",
            name="uq_subjects_name_ay"
        ),
        Index("ix_subjects_subject_code", "subject_code"),
        Index("ix_subjects_subject_name", "subject_name"),
        Index("ix_subjects_category", "category"),
        Index("ix_subjects_status", "status"),
    )

from app.models.teacher_subject_assignment import TeacherSubjectAssignment  # noqa: F401
from app.models.timetable import Timetable  # noqa: F401
from app.models.attendance import AttendanceSession, Attendance  # noqa: F401
from app.models.homework import Homework  # noqa: F401
