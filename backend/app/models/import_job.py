import uuid
import enum
from datetime import datetime
from typing import Optional, List
from sqlalchemy import String, Integer, ForeignKey, UniqueConstraint, Index, DateTime, Enum as SQLEnum, Uuid, JSON, text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class ImportType(str, enum.Enum):
    STUDENTS = "STUDENTS"
    ACADEMIC_SETUP = "ACADEMIC_SETUP"
    GUARDIANS = "GUARDIANS"
    GUARDIAN_MAPPING = "GUARDIAN_MAPPING"
    STAFF = "STAFF"
    FEE_MASTERS = "FEE_MASTERS"
    FEE_ASSIGNMENTS = "FEE_ASSIGNMENTS"
    PAYMENTS = "PAYMENTS"
    OPENING_BALANCES = "OPENING_BALANCES"
    DOCUMENTS = "DOCUMENTS"

class ImportJobStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    VALIDATING = "VALIDATING"
    VALIDATED = "VALIDATED"
    RUNNING = "RUNNING"
    COMPLETED = "COMPLETED"
    COMPLETED_WITH_ERRORS = "COMPLETED_WITH_ERRORS"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"

class ImportJob(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model representing a metadata record for one bulk data onboarding/migration job.
    """
    __tablename__ = "import_jobs"

    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    import_type: Mapped[ImportType] = mapped_column(
        SQLEnum(ImportType, name="importtype", create_type=False), nullable=False
    )
    status: Mapped[ImportJobStatus] = mapped_column(
        SQLEnum(ImportJobStatus, name="importjobstatus", create_type=False),
        default=ImportJobStatus.DRAFT,
        nullable=False
    )
    source_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    file_checksum: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    
    total_rows: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    processed_rows: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    successful_rows: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    failed_rows: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    skipped_rows: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    
    started_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    error_summary: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)
    job_metadata: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )

    # Relationships
    rows: Mapped[List["ImportJobRow"]] = relationship(
        "ImportJobRow", back_populates="import_job", cascade="all, delete-orphan"
    )
    student_rows: Mapped[List["StudentImportRow"]] = relationship(
        "StudentImportRow", back_populates="import_job", cascade="all, delete-orphan"
    )
    academic_setup_rows: Mapped[List["AcademicSetupImportRow"]] = relationship(
        "AcademicSetupImportRow", back_populates="import_job", cascade="all, delete-orphan"
    )
    guardian_rows: Mapped[List["GuardianImportRow"]] = relationship(
        "GuardianImportRow", back_populates="import_job", cascade="all, delete-orphan"
    )
    student_guardian_rows: Mapped[List["StudentGuardianImportRow"]] = relationship(
        "StudentGuardianImportRow", back_populates="import_job", cascade="all, delete-orphan"
    )


    __table_args__ = (
        Index("ix_import_jobs_checksum_active", "tenant_id", "school_id", "import_type", "file_checksum",
              postgresql_where=text("status IN ('VALIDATING', 'VALIDATED', 'RUNNING')")),
    )

class ImportJobRow(Base, BaseModelMixin):
    """
    SQLAlchemy Model representing the outcome/audit-trail of a single row in an import job.
    """
    __tablename__ = "import_job_rows"

    import_job_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("import_jobs.id", ondelete="CASCADE"), nullable=False, index=True
    )
    row_number: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False)  # success, failed, skipped
    error_code: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    error_message: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)
    source_identifier: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)  # e.g., admission number
    entity_id: Mapped[Optional[uuid.UUID]] = mapped_column(Uuid(as_uuid=True), nullable=True)
    row_metadata: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )

    # Relationships
    import_job: Mapped[ImportJob] = relationship("ImportJob", back_populates="rows")

    __table_args__ = (
        Index("ix_import_job_rows_job_id_row_num", "import_job_id", "row_number", unique=True),
    )
