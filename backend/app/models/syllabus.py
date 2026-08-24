import uuid
from typing import Optional
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Index, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class Syllabus(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a Syllabus entry.
    """
    __tablename__ = "syllabuses"

    syllabus_code: Mapped[str] = mapped_column(String(50), nullable=False)
    unit_name: Mapped[str] = mapped_column(String(150), nullable=False)
    chapter_name: Mapped[str] = mapped_column(String(150), nullable=False)
    topic_name: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    sequence_order: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
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
    class_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    subject_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Relationships
    tenant = relationship("Tenant")
    school = relationship("School")
    academic_year = relationship("AcademicYear")
    class_obj = relationship("Class")
    subject = relationship("Subject")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "academic_year_id", "class_id", "subject_id", "syllabus_code",
            name="uq_syllabus_code_ay_class_sub"
        ),
        Index("ix_syllabuses_syllabus_code", "syllabus_code"),
    )
