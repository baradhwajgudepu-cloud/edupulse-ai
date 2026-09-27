import uuid
from typing import Optional, Dict, Any
from sqlalchemy import String, ForeignKey, Text, Integer, JSON
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin


class SchoolResetAudit(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy Model representing durable audit records for School Data Reset operations.
    Persisted independently to survive transaction rollbacks.
    """
    __tablename__ = "school_reset_audits"

    audit_id: Mapped[str] = mapped_column(String(100), nullable=False, unique=True, index=True)
    actor_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True
    )
    actor_role: Mapped[str] = mapped_column(String(50), nullable=False)
    actor_email: Mapped[str] = mapped_column(String(255), nullable=False)

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
    school_name: Mapped[str] = mapped_column(String(255), nullable=False)

    reason: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True
    )  # REQUESTED, STARTED, COMPLETED, FAILED, ROLLED_BACK

    deletion_counts: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True)
    total_records_deleted: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    summary_snapshot: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, nullable=True)
