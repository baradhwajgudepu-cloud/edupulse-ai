import uuid
import enum
from typing import Optional, List
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class ClassStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    ARCHIVED = "ARCHIVED"

class ClassCategory(str, enum.Enum):
    PRE_PRIMARY = "PRE_PRIMARY"
    PRIMARY = "PRIMARY"
    MIDDLE = "MIDDLE"
    HIGH = "HIGH"
    HIGHER_SECONDARY = "HIGHER_SECONDARY"
    OTHER = "OTHER"

class Class(Base, BaseModelMixin):
    """
    SQLAlchemy model for academic Classes.
    Coded as class_entity to prevent naming collisions with Python's reserved 'class' keyword.
    """
    __tablename__ = "classes"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    display_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    code: Mapped[str] = mapped_column(String(50), nullable=False)
    level: Mapped[int] = mapped_column(Integer, nullable=False)
    
    category: Mapped[ClassCategory] = mapped_column(
        SQLEnum(ClassCategory, name="classcategory", create_type=False),
        nullable=False,
        default=ClassCategory.PRIMARY
    )
    
    stream: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    capacity: Mapped[int] = mapped_column(Integer, nullable=False)
    
    promotion_order: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    
    next_class_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("classes.id", ondelete="SET NULL"),
        nullable=True
    )
    
    status: Mapped[ClassStatus] = mapped_column(
        SQLEnum(ClassStatus, name="classstatus", create_type=False),
        nullable=False,
        default=ClassStatus.ACTIVE
    )
    
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    
    settings: Mapped[dict] = mapped_column(JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False)
    ai_metrics: Mapped[dict] = mapped_column(JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False)
    
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

    # Relationships
    tenant = relationship("Tenant", back_populates="classes")
    school = relationship("School", back_populates="classes")
    academic_year = relationship("AcademicYear", back_populates="classes")
    
    sections: Mapped[list["Section"]] = relationship(
        "Section",
        back_populates="class_obj",
        cascade="all, delete-orphan"
    )
    
    students: Mapped[list["Student"]] = relationship(
        "Student",
        back_populates="class_obj",
        cascade="all, delete-orphan"
    )
    
    # Self-referential relationship for promotion paths
    next_class = relationship("Class", remote_side="Class.id", backref="prev_classes")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "academic_year_id", "code",
            name="uq_classes_academic_year_code"
        ),
        UniqueConstraint(
            "academic_year_id", "name",
            name="uq_classes_academic_year_name"
        ),
    )

# Import Section here to ensure SQLAlchemy mapper configuration resolves relationships at startup
from app.models.section import Section  # noqa: F401
from app.models.student import Student  # noqa: F401
