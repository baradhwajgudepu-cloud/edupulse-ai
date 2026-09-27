import uuid
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Index, Text, DateTime, JSON, Enum as SQLEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import BaseModelMixin
from app.models.school import SchoolBoard

class CurriculumMaster(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a verified global curriculum master template.
    Immutable to individual schools.
    """
    __tablename__ = "curriculum_masters"

    board: Mapped[SchoolBoard] = mapped_column(
        SQLEnum(SchoolBoard, name="schoolboard", create_type=False),
        nullable=False,
        index=True
    )
    state: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, index=True)
    academic_year_code: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    class_level: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    class_name: Mapped[str] = mapped_column(String(100), nullable=False)
    subject_code: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    subject_name: Mapped[str] = mapped_column(String(150), nullable=False)

    source: Mapped[str] = mapped_column(String(255), nullable=False)
    source_version: Mapped[str] = mapped_column(String(50), nullable=False)
    retrieved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    verification_status: Mapped[str] = mapped_column(String(30), default="VERIFIED", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    metadata_json: Mapped[Optional[Dict[str, Any]]] = mapped_column(JSON, default=dict, nullable=True)

    items: Mapped[List["CurriculumMasterItem"]] = relationship(
        "CurriculumMasterItem",
        back_populates="master",
        cascade="all, delete-orphan",
        order_by="CurriculumMasterItem.sequence_order"
    )

    __table_args__ = (
        UniqueConstraint(
            "board", "state", "academic_year_code", "class_level", "subject_code",
            name="uq_curriculum_master_board_state_ay_class_sub"
        ),
        Index("ix_curriculum_masters_lookup", "board", "academic_year_code", "class_level"),
    )

class CurriculumMasterItem(Base, BaseModelMixin):
    """
    SQLAlchemy model representing an individual chapter or topic item in the curriculum master.
    """
    __tablename__ = "curriculum_master_items"

    curriculum_master_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("curriculum_masters.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    item_code: Mapped[str] = mapped_column(String(80), nullable=False)
    unit_name: Mapped[str] = mapped_column(String(150), nullable=False)
    chapter_name: Mapped[str] = mapped_column(String(150), nullable=False)
    topic_name: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    sequence_order: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    estimated_periods: Mapped[int] = mapped_column(Integer, default=4, nullable=False)
    learning_outcomes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    master: Mapped["CurriculumMaster"] = relationship("CurriculumMaster", back_populates="items")

    __table_args__ = (
        UniqueConstraint("curriculum_master_id", "item_code", name="uq_curriculum_master_item_code"),
        Index("ix_curriculum_master_items_seq", "curriculum_master_id", "sequence_order"),
    )
