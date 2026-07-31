from enum import Enum as PyEnum
import uuid
from typing import Optional
from sqlalchemy import String, ForeignKey, Boolean, JSON, DateTime, Enum as SQLEnum, UniqueConstraint, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class SchoolBoard(str, PyEnum):
    CBSE = "CBSE"
    ICSE = "ICSE"
    SSC = "SSC"
    STATE = "STATE"
    IB = "IB"
    IGCSE = "IGCSE"
    CAMBRIDGE = "CAMBRIDGE"
    OTHER = "OTHER"

class SchoolType(str, PyEnum):
    PRIMARY = "PRIMARY"
    HIGH_SCHOOL = "HIGH_SCHOOL"
    JR_COLLEGE = "JR_COLLEGE"
    DEGREE_COLLEGE = "DEGREE_COLLEGE"
    UNIVERSITY = "UNIVERSITY"
    OTHER = "OTHER"

class SchoolStatus(str, PyEnum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    SUSPENDED = "SUSPENDED"

class School(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model for School campuses.
    Enforces composite unique constraints and database level indexes.
    Supports multi-tenancy, custom branding, and optimistic concurrency versioning.
    """
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    display_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    code: Mapped[str] = mapped_column(String(20), nullable=False)
    
    board: Mapped[SchoolBoard] = mapped_column(SQLEnum(SchoolBoard, name="schoolboard"), nullable=False)
    school_type: Mapped[SchoolType] = mapped_column(SQLEnum(SchoolType, name="schooltype"), default=SchoolType.HIGH_SCHOOL, nullable=False)
    
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    phone: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    website: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    principal_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    
    address: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    city: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    state: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    country: Mapped[Optional[str]] = mapped_column(String(100), server_default="India", default="India", nullable=True)
    postal_code: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    
    logo_url: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    
    # Flags and status enums
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    status: Mapped[SchoolStatus] = mapped_column(
        SQLEnum(SchoolStatus, name="schoolstatus"),
        default=SchoolStatus.ACTIVE,
        server_default=SchoolStatus.ACTIVE.value,
        nullable=False
    )
    
    settings: Mapped[Optional[dict]] = mapped_column(JSON, default=dict, server_default="{}", nullable=True)
    
    # Indian Educational Registry Fields
    udise_code: Mapped[Optional[str]] = mapped_column(String(20), unique=True, index=True, nullable=True)
    
    # ForeignKey and relation to tenant
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    tenant: Mapped["Tenant"] = relationship("Tenant", back_populates="schools")
    
    academic_years: Mapped[list["AcademicYear"]] = relationship(
        "AcademicYear",
        back_populates="school",
        cascade="all, delete-orphan"
    )
    
    # Versioning column for optimistic concurrency control (OCC)
    version: Mapped[int] = mapped_column(default=1, nullable=False)
    
    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_schools_tenant_code"),
        UniqueConstraint("tenant_id", "email", name="uq_schools_tenant_email"),
        
        # Individual indexes
        Index("ix_schools_status", "status"),
        Index("ix_schools_is_active", "is_active"),
        Index("ix_schools_city", "city"),
        Index("ix_schools_board", "board")
    )
    
    __mapper_args__ = {
        "version_id_col": version
    }

# Import AcademicYear here to ensure SQLAlchemy mapper configuration resolves relationships at startup
from app.models.academic_year import AcademicYear  # noqa: F401
