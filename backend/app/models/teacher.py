import uuid
import enum
from typing import Optional, Dict, Any
from datetime import date
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Date, Numeric
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin
from app.models.student import StudentGender

class TeacherStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    ON_LEAVE = "ON_LEAVE"
    RETIRED = "RETIRED"

class EmploymentType(str, enum.Enum):
    FULL_TIME = "FULL_TIME"
    PART_TIME = "PART_TIME"
    CONTRACT = "CONTRACT"
    VISITING = "VISITING"

class Teacher(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a Teacher.
    """
    __tablename__ = "teachers"

    employee_code: Mapped[str] = mapped_column(String(50), nullable=False)
    staff_code: Mapped[str] = mapped_column(String(50), nullable=False)
    
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    middle_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    
    gender: Mapped[StudentGender] = mapped_column(
        SQLEnum(StudentGender, name="studentgender", create_type=False),
        nullable=False
    )
    date_of_birth: Mapped[date] = mapped_column(Date, nullable=False)
    blood_group: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    aadhaar_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    pan_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    
    mobile: Mapped[str] = mapped_column(String(20), nullable=False)
    alternate_mobile: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    official_email: Mapped[str] = mapped_column(String(255), nullable=False)
    personal_email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    
    emergency_contact_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    emergency_contact_mobile: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    emergency_contact_relation: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    photo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    address: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    
    qualification: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    specialization: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    experience_years: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    
    joining_date: Mapped[date] = mapped_column(Date, nullable=False)
    date_of_confirmation: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    date_of_resignation: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    date_of_retirement: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    
    employment_type: Mapped[EmploymentType] = mapped_column(
        SQLEnum(EmploymentType, name="employmenttype", create_type=False),
        nullable=False
    )
    designation: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    department: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    salary: Mapped[Optional[float]] = mapped_column(Numeric(12, 2), nullable=True)
    
    status: Mapped[TeacherStatus] = mapped_column(
        SQLEnum(TeacherStatus, name="teacherstatus", create_type=False),
        nullable=False,
        default=TeacherStatus.ACTIVE
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
    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, unique=True, index=True
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="teachers")
    school = relationship("School", back_populates="teachers")
    user = relationship("User")
    teacher_subject_assignments: Mapped[list["TeacherSubjectAssignment"]] = relationship(
        "TeacherSubjectAssignment",
        back_populates="teacher",
        cascade="all, delete-orphan"
    )
    timetables: Mapped[list["Timetable"]] = relationship(
        "Timetable",
        back_populates="teacher",
        cascade="all, delete-orphan"
    )
    
    attendance_sessions: Mapped[list["AttendanceSession"]] = relationship(
        "AttendanceSession",
        back_populates="teacher",
        cascade="all, delete-orphan"
    )

    attendances: Mapped[list["Attendance"]] = relationship(
        "Attendance",
        back_populates="teacher",
        cascade="all, delete-orphan"
    )

    # ==================================================
    # Future Placeholders (Empty for mapper safety)
    # ==================================================
    # teacher_subjects = relationship("TeacherSubject", back_populates="teacher")
    # class_teacher_assignments = relationship("ClassTeacher", back_populates="teacher")
    homeworks: Mapped[list["Homework"]] = relationship(
        "Homework",
        back_populates="teacher",
        cascade="all, delete-orphan"
    )
    # exam_duties = relationship("ExamDuty", back_populates="teacher")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "school_id", "employee_code",
            name="uq_teachers_employee_school"
        ),
        UniqueConstraint(
            "school_id", "staff_code",
            name="uq_teachers_staff_school"
        ),
        UniqueConstraint(
            "tenant_id", "mobile",
            name="uq_teachers_mobile"
        ),
        UniqueConstraint(
            "tenant_id", "official_email",
            name="uq_teachers_official_email"
        ),
        UniqueConstraint(
            "tenant_id", "personal_email",
            name="uq_teachers_personal_email"
        ),
        UniqueConstraint(
            "tenant_id", "aadhaar_number",
            name="uq_teachers_aadhaar"
        ),
        UniqueConstraint(
            "tenant_id", "pan_number",
            name="uq_teachers_pan"
        ),
    )

from app.models.teacher_subject_assignment import TeacherSubjectAssignment  # noqa: F401
from app.models.timetable import Timetable  # noqa: F401
from app.models.attendance import AttendanceSession, Attendance  # noqa: F401
from app.models.homework import Homework  # noqa: F401
