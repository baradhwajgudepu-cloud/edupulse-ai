import uuid
from typing import Optional
from datetime import date, datetime
from sqlalchemy import Float, Integer, Boolean, ForeignKey, UniqueConstraint, Index, String, Date, DateTime, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin

class StaffAttendance(Base, BaseModelMixin, TenantMixin):
    """
    SQLAlchemy model representing daily staff attendance for teachers,
    utilizing geofenced check-in and check-out logs.
    """
    __tablename__ = "staff_attendances"

    teacher_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("teachers.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    attendance_date: Mapped[date] = mapped_column(Date, nullable=False, default=date.today)

    check_in_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    check_in_latitude: Mapped[float] = mapped_column(Float, nullable=False)
    check_in_longitude: Mapped[float] = mapped_column(Float, nullable=False)
    check_in_distance_meters: Mapped[float] = mapped_column(Float, nullable=False)

    check_out_time: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    check_out_latitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    check_out_longitude: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    check_out_distance_meters: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    is_mocked_location: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    remarks: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Relationships
    teacher = relationship("Teacher", backref="staff_attendances")
    school = relationship("School", backref="staff_attendances")

    __table_args__ = (
        UniqueConstraint("teacher_id", "attendance_date", name="uq_staff_attendance_teacher_date"),
        Index("ix_staff_attendance_date", "attendance_date"),
    )
