import uuid
from datetime import date
from typing import Optional
from sqlalchemy import String, Integer, ForeignKey, Date, JSON, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class AcademicSetupImportRow(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy staging model representing a normalized academic setup record
    (Academic Year, Class, Section) uploaded via migration, waiting to be validated or executed.
    """
    __tablename__ = "academic_setup_import_rows"

    import_job_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("import_jobs.id", ondelete="CASCADE"), nullable=False, index=True
    )
    row_number: Mapped[int] = mapped_column(Integer, nullable=False)

    # Academic Year fields
    academic_year_name: Mapped[str] = mapped_column(String(100), nullable=False)
    academic_year_code: Mapped[str] = mapped_column(String(50), nullable=False)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)

    # Class fields
    class_name: Mapped[str] = mapped_column(String(100), nullable=False)
    class_code: Mapped[str] = mapped_column(String(50), nullable=False)
    class_level: Mapped[int] = mapped_column(Integer, nullable=False)
    class_category: Mapped[str] = mapped_column(String(50), default="PRIMARY", nullable=False)
    class_capacity: Mapped[int] = mapped_column(Integer, nullable=False)

    # Section fields
    section_name: Mapped[str] = mapped_column(String(100), nullable=False)
    section_code: Mapped[str] = mapped_column(String(50), nullable=False)
    section_capacity: Mapped[int] = mapped_column(Integer, nullable=False)

    # Resolved IDs (if they already exist in database)
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

    # Validation fields
    validation_status: Mapped[str] = mapped_column(String(50), default="pending", nullable=False, index=True)  # pending, valid, invalid
    validation_error_code: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    validation_error_message: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)

    # Execution fields (populated during start_job execution phase later)
    created_academic_year_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("academic_years.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_class_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("classes.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_section_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("sections.id", ondelete="SET NULL"), nullable=True, index=True
    )

    import_job = relationship("ImportJob", back_populates="academic_setup_rows")

    __table_args__ = (
        Index("ix_academic_setup_rows_job_id_row_num", "import_job_id", "row_number", unique=True),
    )
