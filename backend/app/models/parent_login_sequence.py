import uuid
from sqlalchemy import String, ForeignKey, Integer, UniqueConstraint, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class ParentLoginSequence(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model representing sequence counters for generating sequential Parent Login IDs.
    Enforces a unique constraint per school within a tenant boundary.
    """
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    prefix: Mapped[str] = mapped_column(String(50), nullable=False)
    next_sequence: Mapped[int] = mapped_column(Integer, default=1, server_default="1", nullable=False)

    # Scoping relations
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    school: Mapped["School"] = relationship("School")

    __table_args__ = (
        UniqueConstraint("tenant_id", "school_id", name="uq_parent_login_sequences_tenant_school"),
    )
