import uuid
from typing import Optional
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, JSON
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class Room(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy model representing physical classrooms, labs, and halls.
    Belongs to a School and Tenant.
    """
    __tablename__ = "rooms"

    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    room_number: Mapped[str] = mapped_column(String(50), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    room_type: Mapped[str] = mapped_column(String(50), default="CLASSROOM", nullable=False)
    capacity: Mapped[int] = mapped_column(Integer, default=40, nullable=False)
    floor: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    building: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    settings: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )

    __table_args__ = (
        UniqueConstraint("tenant_id", "school_id", "room_number", name="uq_rooms_tenant_school_room_number"),
    )
