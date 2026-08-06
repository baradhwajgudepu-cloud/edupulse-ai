import uuid
import enum
from typing import Optional, Dict, Any
from datetime import date
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Date, Numeric
from sqlalchemy.orm import Mapped, mapped_column, relationship as orm_relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin
from app.models.student import StudentGender

class GuardianType(str, enum.Enum):
    FATHER = "FATHER"
    MOTHER = "MOTHER"
    LEGAL_GUARDIAN = "LEGAL_GUARDIAN"
    GRANDPARENT = "GRANDPARENT"
    UNCLE = "UNCLE"
    AUNT = "AUNT"
    OTHER = "OTHER"

class GuardianStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"

class StudentGuardianRelationship(str, enum.Enum):
    FATHER = "FATHER"
    MOTHER = "MOTHER"
    GUARDIAN = "GUARDIAN"
    GRANDPARENT = "GRANDPARENT"
    RELATIVE = "RELATIVE"
    OTHER = "OTHER"

class Guardian(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a parent or legal guardian.
    """
    __tablename__ = "guardians"

    guardian_type: Mapped[GuardianType] = mapped_column(
        SQLEnum(GuardianType, name="guardiantype", create_type=False),
        nullable=False
    )
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    middle_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    gender: Mapped[StudentGender] = mapped_column(
        SQLEnum(StudentGender, name="studentgender", create_type=False),
        nullable=False
    )
    date_of_birth: Mapped[date] = mapped_column(Date, nullable=False)
    aadhaar_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    pan_number: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    occupation: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    qualification: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    organization: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    annual_income: Mapped[Optional[float]] = mapped_column(Numeric(12, 2), nullable=True)
    
    mobile: Mapped[str] = mapped_column(String(20), nullable=False)
    is_mobile_verified: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    alternate_mobile: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    email: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    is_email_verified: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    
    emergency_contact_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    emergency_contact_mobile: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    photo_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    address: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    communication_preferences: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    
    status: Mapped[GuardianStatus] = mapped_column(
        SQLEnum(GuardianStatus, name="guardianstatus", create_type=False),
        nullable=False,
        default=GuardianStatus.ACTIVE
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    
    settings: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    ai_metrics: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )

    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, unique=True, index=True
    )

    # Relationships
    tenant = orm_relationship("Tenant", back_populates="guardians")
    school = orm_relationship("School", back_populates="guardians")
    user = orm_relationship("User")
    students = orm_relationship("StudentGuardian", back_populates="guardian", cascade="all, delete-orphan")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "mobile",
            name="uq_guardians_mobile"
        ),
        UniqueConstraint(
            "tenant_id", "email",
            name="uq_guardians_email"
        ),
        UniqueConstraint(
            "tenant_id", "aadhaar_number",
            name="uq_guardians_aadhaar"
        ),
        UniqueConstraint(
            "tenant_id", "pan_number",
            name="uq_guardians_pan"
        ),
    )


class StudentGuardian(Base, BaseModelMixin):
    """
    Many-to-Many mapping table between Students and Guardians.
    """
    __tablename__ = "student_guardians"

    student_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True
    )
    guardian_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("guardians.id", ondelete="CASCADE"), nullable=False, index=True
    )
    
    relationship: Mapped[StudentGuardianRelationship] = mapped_column(
        SQLEnum(StudentGuardianRelationship, name="studentguardianrelationship", create_type=False),
        nullable=False
    )
    
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    can_pickup_student: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    receives_notifications: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Relationships
    student = orm_relationship("Student", back_populates="guardians")
    guardian = orm_relationship("Guardian", back_populates="students")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        UniqueConstraint(
            "student_id", "guardian_id",
            name="uq_student_guardians_mapping"
        ),
    )
