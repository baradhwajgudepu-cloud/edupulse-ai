import uuid
import enum
from typing import Optional
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class SectionStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"

class Section(Base, BaseModelMixin):
    """
    SQLAlchemy model for Sections.
    Belongs to a Class, Academic Year, School, and Tenant.
    """
    __tablename__ = "sections"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    code: Mapped[str] = mapped_column(String(50), nullable=False)
    capacity: Mapped[int] = mapped_column(Integer, nullable=False)
    room_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=1, server_default="1", nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    status: Mapped[SectionStatus] = mapped_column(
        SQLEnum(SectionStatus, name="sectionstatus", create_type=False),
        nullable=False,
        default=SectionStatus.ACTIVE
    )
    
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    
    settings: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    ai_metrics: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    
    # Optimistic Concurrency Control
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Scopes and boundaries
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

    # Relationships
    tenant = relationship("Tenant", back_populates="sections")
    school = relationship("School", back_populates="sections")
    academic_year = relationship("AcademicYear", back_populates="sections")
    class_obj = relationship("Class", back_populates="sections")
    
    students: Mapped[list["Student"]] = relationship(
        "Student",
        back_populates="section",
        cascade="all, delete-orphan"
    )

    teacher_subject_assignments: Mapped[list["TeacherSubjectAssignment"]] = relationship(
        "TeacherSubjectAssignment",
        back_populates="section",
        cascade="all, delete-orphan"
    )

    timetables: Mapped[list["Timetable"]] = relationship(
        "Timetable",
        back_populates="section",
        cascade="all, delete-orphan"
    )
    
    attendance_sessions: Mapped[list["AttendanceSession"]] = relationship(
        "AttendanceSession",
        back_populates="section",
        cascade="all, delete-orphan"
    )

    attendances: Mapped[list["Attendance"]] = relationship(
        "Attendance",
        back_populates="section",
        cascade="all, delete-orphan"
    )

    homeworks: Mapped[list["Homework"]] = relationship(
        "Homework",
        back_populates="section",
        cascade="all, delete-orphan"
    )

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "class_id", "code",
            name="uq_sections_class_code"
        ),
        UniqueConstraint(
            "class_id", "name",
            name="uq_sections_class_name"
        ),
    )

# Import Student here to ensure SQLAlchemy mapper configuration resolves relationships at startup
from app.models.student import Student  # noqa: F401
from app.models.teacher_subject_assignment import TeacherSubjectAssignment  # noqa: F401
from app.models.timetable import Timetable  # noqa: F401
from app.models.attendance import AttendanceSession, Attendance  # noqa: F401
from app.models.homework import Homework  # noqa: F401
