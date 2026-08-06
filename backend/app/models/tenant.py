from enum import Enum
import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Uuid, Boolean, JSON, DateTime, Enum as SQLEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin

class TenantStatus(str, Enum):
    """
    Enum representing status of a Tenant.
    """
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    SUSPENDED = "SUSPENDED"

class Tenant(Base, BaseModelMixin):
    """
    SQLAlchemy Model for Tenants (Organizations) in India.
    Includes branding, localized constants, settings blobs, subscription plans,
    and Indian-specific tax registrations (PAN/GSTIN).
    """
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    display_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    code: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    subdomain: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    website: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    logo_url: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    
    # Defaults configured for Indian Educational Institutions
    timezone: Mapped[str] = mapped_column(String(50), server_default="Asia/Kolkata", default="Asia/Kolkata", nullable=False)
    currency: Mapped[str] = mapped_column(String(10), server_default="INR", default="INR", nullable=False)
    
    address: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    city: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    state: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    country: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    postal_code: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    
    # Indian tax registration columns
    pan: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    gstin: Mapped[Optional[str]] = mapped_column(String(15), nullable=True)
    
    # Toggle and Enum flags
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    status: Mapped[TenantStatus] = mapped_column(
        SQLEnum(TenantStatus, name="tenantstatus"),
        default=TenantStatus.ACTIVE,
        server_default=TenantStatus.ACTIVE.value,
        nullable=False
    )
    
    # Configurable parameters as a JSON document
    settings: Mapped[Optional[dict]] = mapped_column(JSON, default=dict, server_default="{}", nullable=True)
    
    # Subscription & Billing fields for multi-tenant SaaS
    plan: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    subscription_start: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    subscription_end: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    # Optimistic Concurrency Control (OCC) version column
    version: Mapped[int] = mapped_column(default=1, nullable=False)
    
    # Relationship placeholders
    schools: Mapped[list["School"]] = relationship(
        "School",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    classes: Mapped[list["Class"]] = relationship(
        "Class",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    sections: Mapped[list["Section"]] = relationship(
        "Section",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    students: Mapped[list["Student"]] = relationship(
        "Student",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    guardians: Mapped[list["Guardian"]] = relationship(
        "Guardian",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    teachers: Mapped[list["Teacher"]] = relationship(
        "Teacher",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    subjects: Mapped[list["Subject"]] = relationship(
        "Subject",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    teacher_subject_assignments: Mapped[list["TeacherSubjectAssignment"]] = relationship(
        "TeacherSubjectAssignment",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    timetables: Mapped[list["Timetable"]] = relationship(
        "Timetable",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    attendance_sessions: Mapped[list["AttendanceSession"]] = relationship(
        "AttendanceSession",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    attendances: Mapped[list["Attendance"]] = relationship(
        "Attendance",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    homeworks: Mapped[list["Homework"]] = relationship(
        "Homework",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    exam_templates: Mapped[list["ExamTemplate"]] = relationship(
        "ExamTemplate",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    examinations: Mapped[list["Examination"]] = relationship(
        "Examination",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    exam_schedules: Mapped[list["ExamSchedule"]] = relationship(
        "ExamSchedule",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    marks: Mapped[list["Marks"]] = relationship(
        "Marks",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    report_cards: Mapped[list["ReportCardPublication"]] = relationship(
        "ReportCardPublication",
        back_populates="tenant",
        cascade="all, delete-orphan"
    )

    # Enable optimistic concurrency control in SQLAlchemy mapper args
    __mapper_args__ = {
        "version_id_col": version
    }

# Import School here to ensure SQLAlchemy mapper configuration resolves the name 'School' at startup
from app.models.school import School  # noqa: F401
from app.models.class_entity import Class  # noqa: F401
from app.models.section import Section  # noqa: F401
from app.models.student import Student  # noqa: F401
from app.models.guardian import Guardian, StudentGuardian  # noqa: F401
from app.models.teacher import Teacher  # noqa: F401
from app.models.subject import Subject  # noqa: F401
from app.models.teacher_subject_assignment import TeacherSubjectAssignment  # noqa: F401
from app.models.timetable import Timetable  # noqa: F401
from app.models.attendance import AttendanceSession, Attendance  # noqa: F401
from app.models.homework import Homework  # noqa: F401
from app.models.examination import ExamTemplate, Examination, ExamSchedule  # noqa: F401
from app.models.marks import Marks  # noqa: F401
from app.models.report_card import ReportCardPublication  # noqa: F401
