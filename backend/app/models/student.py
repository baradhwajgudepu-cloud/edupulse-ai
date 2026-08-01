import uuid
import enum
from typing import Optional, Dict, Any
from datetime import date, datetime
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Date, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class StudentGender(str, enum.Enum):
    MALE = "MALE"
    FEMALE = "FEMALE"
    OTHER = "OTHER"

class StudentStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    SUSPENDED = "SUSPENDED"
    WITHDRAWN = "WITHDRAWN"
    ALUMNI = "ALUMNI"

class Student(Base, BaseModelMixin):
    """
    SQLAlchemy model for Students.
    """
    __tablename__ = "students"

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
    emis_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    mobile: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    photo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    # Address and Medical JSON configurations
    address: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    medical_information: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    
    admission_number: Mapped[str] = mapped_column(String(50), nullable=False)
    roll_number: Mapped[str] = mapped_column(String(30), nullable=False)
    admission_date: Mapped[date] = mapped_column(Date, nullable=False)
    
    # Timestamps representing status transition lifecycle
    admitted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    promoted_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    transferred_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    withdrawn_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    graduated_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    status: Mapped[StudentStatus] = mapped_column(
        SQLEnum(StudentStatus, name="studentstatus", create_type=False),
        nullable=False,
        default=StudentStatus.ACTIVE
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
    section_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sections.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Relationships
    tenant = relationship("Tenant", back_populates="students")
    school = relationship("School", back_populates="students")
    academic_year = relationship("AcademicYear", back_populates="students")
    class_obj = relationship("Class", back_populates="students")
    section = relationship("Section", back_populates="students")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "school_id", "admission_number",
            name="uq_students_admission_school"
        ),
        UniqueConstraint(
            "section_id", "roll_number",
            name="uq_students_roll_section"
        ),
        UniqueConstraint(
            "aadhaar_number",
            name="uq_students_aadhaar"
        ),
    )
