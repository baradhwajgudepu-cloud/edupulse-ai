import uuid
import enum
from typing import Optional
from datetime import datetime
from sqlalchemy import String, Integer, Boolean, ForeignKey, Enum as SQLEnum, DateTime, Index, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.mixins import BaseModelMixin
from app.models.notification import NotificationTargetRole, NotificationPriority

class AnnouncementAudienceType(str, enum.Enum):
    ROLE = "ROLE"
    CLASS = "CLASS"
    SECTION = "SECTION"

class AnnouncementStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    PUBLISHED = "PUBLISHED"
    CANCELLED = "CANCELLED"

class Announcement(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a persistent Announcement or Circular.
    """
    __tablename__ = "announcements"

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    
    audience_type: Mapped[AnnouncementAudienceType] = mapped_column(
        SQLEnum(AnnouncementAudienceType, name="announcementaudiencetype", create_type=False),
        nullable=False,
        default=AnnouncementAudienceType.ROLE
    )
    
    target_role: Mapped[Optional[NotificationTargetRole]] = mapped_column(
        SQLEnum(NotificationTargetRole, name="notificationtargetrole", create_type=False),
        nullable=True
    )
    
    target_class_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("classes.id", ondelete="SET NULL"), nullable=True, index=True
    )
    target_section_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("sections.id", ondelete="SET NULL"), nullable=True, index=True
    )
    
    publish_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    
    priority: Mapped[NotificationPriority] = mapped_column(
        SQLEnum(NotificationPriority, name="notificationpriority", create_type=False),
        nullable=False,
        default=NotificationPriority.NORMAL
    )
    
    attachment_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    status: Mapped[AnnouncementStatus] = mapped_column(
        SQLEnum(AnnouncementStatus, name="announcementstatus", create_type=False),
        nullable=False,
        default=AnnouncementStatus.DRAFT
    )
    
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    academic_year_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academic_years.id", ondelete="CASCADE"), nullable=False, index=True
    )

    tenant = relationship("Tenant")
    school = relationship("School")
    academic_year = relationship("AcademicYear")
    class_obj = relationship("Class")
    section = relationship("Section")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        Index("ix_announcements_status", "status"),
        Index("ix_announcements_publish_at", "publish_at"),
    )
