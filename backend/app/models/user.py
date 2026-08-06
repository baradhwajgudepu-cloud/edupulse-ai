from enum import Enum as PyEnum
import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, ForeignKey, Boolean, DateTime, Enum as SQLEnum, UniqueConstraint, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class UserStatus(str, PyEnum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    SUSPENDED = "SUSPENDED"
    LOCKED = "LOCKED"

class User(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model representing system Users.
    Belongs to a Tenant and can be assigned to multiple Schools.
    Includes brute-force prevention and hashed password reset fields.
    """
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)

    status: Mapped[UserStatus] = mapped_column(
        SQLEnum(UserStatus, name="userstatus", create_type=False),
        default=UserStatus.ACTIVE,
        server_default=UserStatus.ACTIVE.value,
        nullable=False
    )
    is_superuser: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    must_change_password: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)

    # Brute-force protection
    failed_login_attempts: Mapped[int] = mapped_column(default=0, server_default="0", nullable=False)
    locked_until: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    last_login: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Password Reset Tokens (Hashed in DB)
    password_reset_hash: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    password_reset_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Scoping relations
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    # Many-to-many relationship with Schools and Roles (defined in app.models.role)
    schools: Mapped[list["School"]] = relationship(
        "School",
        secondary="school_users"
    )
    roles: Mapped[list["Role"]] = relationship(
        "Role",
        secondary="user_roles",
        back_populates="users"
    )

    version: Mapped[int] = mapped_column(default=1, nullable=False)

    __table_args__ = (
        UniqueConstraint("tenant_id", "email", name="uq_users_tenant_email"),
        Index("ix_users_status", "status"),
    )

    __mapper_args__ = {
        "version_id_col": version
    }

# Import dependencies to resolve mappings at load time
from app.models.role import Role, school_users, user_roles  # noqa: F401
from app.models.school import School  # noqa: F401
