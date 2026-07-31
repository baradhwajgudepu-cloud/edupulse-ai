from typing import Optional
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin

class Permission(Base, BaseModelMixin):
    """
    SQLAlchemy Model representing system permissions (e.g. school.create, academic_year.delete).
    Definitions are system-wide (global).
    """
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    code: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Many-to-many relationship with roles
    roles: Mapped[list["Role"]] = relationship(
        "Role",
        secondary="role_permissions",
        back_populates="permissions"
    )

# Import Role here to resolve relationships at startup
from app.models.role import Role  # noqa: F401
