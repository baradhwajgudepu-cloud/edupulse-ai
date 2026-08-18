import enum
import uuid
from datetime import date, datetime, timezone
from typing import Optional
from sqlalchemy import String, Integer, Date, DateTime, Uuid, ForeignKey, Enum as SQLEnum, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class LeaveType(str, enum.Enum):
    CASUAL = "CASUAL"
    SICK = "SICK"
    EARNED = "EARNED"
    EMERGENCY = "EMERGENCY"
    OTHER = "OTHER"

class LeaveStatus(str, enum.Enum):
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"
    CANCELLED = "CANCELLED"

class TeacherLeave(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy model representing a Teacher's Leave Request.
    """
    __tablename__ = "teacher_leaves"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    teacher_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("teachers.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    leave_type: Mapped[LeaveType] = mapped_column(
        SQLEnum(LeaveType, name="teacherleavetype", create_type=False),
        nullable=False
    )
    start_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    end_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    reason: Mapped[str] = mapped_column(String(500), nullable=False)
    remarks: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    status: Mapped[LeaveStatus] = mapped_column(
        SQLEnum(LeaveStatus, name="teacherleavestatus", create_type=False),
        nullable=False,
        default=LeaveStatus.PENDING,
        server_default="PENDING",
        index=True
    )
    
    requested_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        nullable=False, 
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now()
    )
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    reviewed_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )
    reviewer_remarks: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    cancelled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    cancellation_reason: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Relationships
    teacher = relationship("Teacher", backref="teacher_leaves")
    school = relationship("School", backref="teacher_leaves")
    reviewer = relationship("User", backref="reviewed_teacher_leaves")
