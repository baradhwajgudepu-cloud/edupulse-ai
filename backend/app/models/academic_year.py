from enum import Enum as PyEnum
import uuid
from datetime import date
from typing import Optional
from sqlalchemy import String, ForeignKey, Boolean, JSON, Date, Enum as SQLEnum, UniqueConstraint, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class AcademicYearStatus(str, PyEnum):
    UPCOMING = "UPCOMING"
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"
    ARCHIVED = "ARCHIVED"

class AcademicYear(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model for Academic Years.
    Belongs to a Tenant and a School. Only one year can be ACTIVE or CURRENT per school.
    """
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    code: Mapped[str] = mapped_column(String(50), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    # Store as pure DATE values to avoid timezone slippages
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    
    status: Mapped[AcademicYearStatus] = mapped_column(
        SQLEnum(AcademicYearStatus, name="academicyearstatus", create_type=False),
        default=AcademicYearStatus.UPCOMING,
        server_default=AcademicYearStatus.UPCOMING.value,
        nullable=False
    )
    is_current: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    settings: Mapped[Optional[dict]] = mapped_column(JSON, default=dict, server_default="{}", nullable=True)
    
    # Scoping relations
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    
    school: Mapped["School"] = relationship("School", back_populates="academic_years")
    
    classes: Mapped[list["Class"]] = relationship(
        "Class",
        back_populates="academic_year",
        cascade="all, delete-orphan"
    )
    
    sections: Mapped[list["Section"]] = relationship(
        "Section",
        back_populates="academic_year",
        cascade="all, delete-orphan"
    )
    
    students: Mapped[list["Student"]] = relationship(
        "Student",
        back_populates="academic_year",
        cascade="all, delete-orphan"
    )
    
    # Concurrency control
    version: Mapped[int] = mapped_column(default=1, nullable=False)
    
    __table_args__ = (
        UniqueConstraint("school_id", "name", name="uq_academic_years_school_name"),
        UniqueConstraint("school_id", "code", name="uq_academic_years_school_code"),
        
        # Performance/Lookup indexes
        Index("ix_academic_years_status", "status"),
        Index("ix_academic_years_is_current", "is_current"),
        Index("ix_academic_years_dates", "start_date", "end_date"),
    )
    
    __mapper_args__ = {
        "version_id_col": version
    }

# Import School here to ensure SQLAlchemy mapper configuration resolves relationships at startup
from app.models.school import School  # noqa: F401
from app.models.class_entity import Class  # noqa: F401
from app.models.section import Section  # noqa: F401
from app.models.student import Student  # noqa: F401
