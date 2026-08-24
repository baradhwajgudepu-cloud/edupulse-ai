import uuid
from datetime import date
from typing import Optional
from sqlalchemy import String, Integer, ForeignKey, Date, JSON, Index, Numeric
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class GuardianImportRow(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy staging model representing a parent/guardian import staging record,
    uploaded via migration, waiting to be validated or executed.
    """
    __tablename__ = "guardian_import_rows"

    import_job_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("import_jobs.id", ondelete="CASCADE"), nullable=False, index=True
    )
    row_number: Mapped[int] = mapped_column(Integer, nullable=False)
    source_identifier: Mapped[str] = mapped_column(String(255), nullable=False, index=True)

    # Core guardian attributes staging fields
    guardian_type: Mapped[str] = mapped_column(String(50), nullable=False)
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    middle_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    gender: Mapped[str] = mapped_column(String(20), nullable=False)
    date_of_birth: Mapped[date] = mapped_column(Date, nullable=False)
    aadhaar_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    pan_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    occupation: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    qualification: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    organization: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    annual_income: Mapped[Optional[float]] = mapped_column(Numeric(12, 2), nullable=True)
    
    mobile: Mapped[str] = mapped_column(String(20), nullable=False)
    alternate_mobile: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    
    emergency_contact_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    emergency_contact_mobile: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    photo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    address: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Resolved scope UUID keys
    school_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=True, index=True
    )

    # Validation tracking
    validation_status: Mapped[str] = mapped_column(String(50), default="pending", nullable=False, index=True)  # pending, valid, invalid
    validation_error_code: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    validation_error_message: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)

    # Resolved existing guardian ID (if already exists in system)
    resolved_guardian_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("guardians.id", ondelete="SET NULL"), nullable=True, index=True
    )
    
    # Created guardian ID (populated during start_job execution phase later)
    created_guardian_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("guardians.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Relationships
    import_job = relationship("ImportJob", back_populates="guardian_rows")
    resolved_guardian = relationship("Guardian", foreign_keys=[resolved_guardian_id])
    created_guardian = relationship("Guardian", foreign_keys=[created_guardian_id])

    __table_args__ = (
        Index("ix_guardian_import_rows_job_id_row_num", "import_job_id", "row_number", unique=True),
    )
