import uuid
from typing import Optional
from sqlalchemy import Table, Column, ForeignKey, String, Boolean, UniqueConstraint, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

# 1. School-Users association table allowing multi-school memberships per tenant
school_users = Table(
    "school_users",
    Base.metadata,
    Column("user_id", ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
    Column("school_id", ForeignKey("schools.id", ondelete="CASCADE"), primary_key=True),
)

# 2. User-Roles association table mapping users to roles
user_roles = Table(
    "user_roles",
    Base.metadata,
    Column("user_id", ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
    Column("role_id", ForeignKey("roles.id", ondelete="CASCADE"), primary_key=True),
)

# 3. Role-Permissions association table mapping roles to permissions
role_permissions = Table(
    "role_permissions",
    Base.metadata,
    Column("role_id", ForeignKey("roles.id", ondelete="CASCADE"), primary_key=True),
    Column("permission_id", ForeignKey("permissions.id", ondelete="CASCADE"), primary_key=True),
)

class Role(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model representing Custom and System Roles.
    Scoped to a Tenant. Default roles (seeded) are marked by is_system=True.
    """
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    code: Mapped[str] = mapped_column(String(50), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    is_system: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    # Relationships
    permissions: Mapped[list["Permission"]] = relationship(
        "Permission",
        secondary=role_permissions,
        back_populates="roles"
    )
    users: Mapped[list["User"]] = relationship(
        "User",
        secondary=user_roles,
        back_populates="roles"
    )

    version: Mapped[int] = mapped_column(default=1, nullable=False)

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_roles_tenant_code"),
        Index("ix_roles_is_system", "is_system"),
    )

    __mapper_args__ = {
        "version_id_col": version
    }

# Import Permission & User here to resolve relationship definitions at startup
from app.models.permission import Permission  # noqa: F401
from app.models.user import User  # noqa: F401
