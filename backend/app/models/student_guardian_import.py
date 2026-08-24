import uuid
from typing import Optional
from sqlalchemy import String, Integer, ForeignKey, Boolean, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship as orm_relationship

from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class StudentGuardianImportRow(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy staging model representing a student-guardian mapping import staging record,
    uploaded via migration, waiting to be validated or executed.
    """
    __tablename__ = "student_guardian_import_rows"

    import_job_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("import_jobs.id", ondelete="CASCADE"), nullable=False, index=True
    )
    row_number: Mapped[int] = mapped_column(Integer, nullable=False)

    # Core relationship attributes
    student_admission_number: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    guardian_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    relationship: Mapped[str] = mapped_column(String(50), nullable=False)
    is_primary: Mapped[Optional[bool]] = mapped_column(Boolean, default=False, nullable=True)
    can_pickup_student: Mapped[Optional[bool]] = mapped_column(Boolean, default=True, nullable=True)
    receives_notifications: Mapped[Optional[bool]] = mapped_column(Boolean, default=True, nullable=True)

    # Resolved scope UUID keys
    school_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=True, index=True
    )

    # Validation tracking
    validation_status: Mapped[str] = mapped_column(String(50), default="pending", nullable=False, index=True)
    validation_error_code: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    validation_error_message: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)

    # Resolved existing IDs (if already exist in system)
    resolved_student_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("students.id", ondelete="SET NULL"), nullable=True, index=True
    )
    resolved_guardian_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("guardians.id", ondelete="SET NULL"), nullable=True, index=True
    )
    
    # Created mapping ID (populated during start_job execution phase later)
    created_mapping_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("student_guardians.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Relationships
    import_job = orm_relationship("ImportJob", back_populates="student_guardian_rows")
    resolved_student = orm_relationship("Student", foreign_keys=[resolved_student_id])
    resolved_guardian = orm_relationship("Guardian", foreign_keys=[resolved_guardian_id])
    created_mapping = orm_relationship("StudentGuardian", foreign_keys=[created_mapping_id])

    __table_args__ = (
        Index("ix_student_guardian_import_rows_job_id_row_num", "import_job_id", "row_number", unique=True),
    )
