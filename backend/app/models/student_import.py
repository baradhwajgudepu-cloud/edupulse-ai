import uuid
from datetime import date
from typing import Optional
from sqlalchemy import String, Integer, ForeignKey, Date, JSON, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class StudentImportRow(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy staging model representing a normalized student record uploaded via migration,
    waiting to be validated or executed.
    """
    __tablename__ = "student_import_rows"

    import_job_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("import_jobs.id", ondelete="CASCADE"), nullable=False, index=True
    )
    row_number: Mapped[int] = mapped_column(Integer, nullable=False)

    # Core student attributes staging fields
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    middle_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    gender: Mapped[str] = mapped_column(String(20), nullable=False)
    date_of_birth: Mapped[date] = mapped_column(Date, nullable=False)
    blood_group: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    aadhaar_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    emis_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    mobile: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    photo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Address & Medical JSONB staging payloads
    address: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    medical_information: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )

    admission_number: Mapped[str] = mapped_column(String(50), nullable=False)
    roll_number: Mapped[str] = mapped_column(String(30), nullable=False)
    admission_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[str] = mapped_column(String(50), default="ACTIVE", nullable=False)

    # Resolved scope UUID keys
    school_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=True, index=True
    )
    academic_year_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("academic_years.id", ondelete="CASCADE"), nullable=True, index=True
    )
    class_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=True, index=True
    )
    section_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("sections.id", ondelete="CASCADE"), nullable=True, index=True
    )

    # Validation tracking
    validation_status: Mapped[str] = mapped_column(String(50), default="pending", nullable=False)  # pending, valid, invalid
    validation_error_code: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    validation_error_message: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)

    # Created student reference after execution
    created_student_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("students.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Relationships
    import_job = relationship("ImportJob", back_populates="student_rows")
    created_student = relationship("Student")
