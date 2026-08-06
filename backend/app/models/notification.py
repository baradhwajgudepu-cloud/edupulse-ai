import uuid
import enum
from typing import Optional, Dict, Any
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class NotificationType(str, enum.Enum):
    ATTENDANCE = "ATTENDANCE"
    HOMEWORK = "HOMEWORK"
    EXAMINATION = "EXAMINATION"
    MARKS = "MARKS"
    REPORT_CARD = "REPORT_CARD"
    ANNOUNCEMENT = "ANNOUNCEMENT"
    EVENT = "EVENT"
    HOLIDAY = "HOLIDAY"
    FEE = "FEE"
    GENERAL = "GENERAL"

class NotificationPriority(str, enum.Enum):
    LOW = "LOW"
    NORMAL = "NORMAL"
    HIGH = "HIGH"
    URGENT = "URGENT"

class NotificationStatus(str, enum.Enum):
    UNREAD = "UNREAD"
    READ = "READ"
    ARCHIVED = "ARCHIVED"

class NotificationTargetRole(str, enum.Enum):
    PARENT = "PARENT"
    TEACHER = "TEACHER"
    PRINCIPAL = "PRINCIPAL"
    ADMIN = "ADMIN"
    STAFF = "STAFF"


class Notification(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a Notification record.
    """
    __tablename__ = "notifications"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    
    notification_type: Mapped[NotificationType] = mapped_column(
        SQLEnum(NotificationType, name="notificationtype"), nullable=False
    )
    priority: Mapped[NotificationPriority] = mapped_column(
        SQLEnum(NotificationPriority, name="notificationpriority"), nullable=False
    )
    
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    message: Mapped[str] = mapped_column(String(2000), nullable=False)
    
    target_role: Mapped[NotificationTargetRole] = mapped_column(
        SQLEnum(NotificationTargetRole, name="notificationtargetrole"), nullable=False
    )
    target_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=True, index=True
    )
    
    related_module: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    related_record_id: Mapped[Optional[uuid.UUID]] = mapped_column(Uuid(as_uuid=True), nullable=True)
    
    status: Mapped[NotificationStatus] = mapped_column(
        SQLEnum(NotificationStatus, name="notificationstatus"),
        default=NotificationStatus.UNREAD,
        nullable=False
    )
    
    is_push_sent: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    is_email_sent: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    is_sms_sent: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    
    settings: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    ai_metrics: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    tenant = relationship("Tenant")
    school = relationship("School")
    target_user = relationship("User")

    __mapper_args__ = {
        "version_id_col": version
    }


class NotificationPreference(Base, BaseModelMixin):
    """
    SQLAlchemy model representing communication category preferences per user.
    """
    __tablename__ = "notification_preferences"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True, index=True
    )
    
    enable_homework: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    enable_attendance: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    enable_marks: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    enable_report_card: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    enable_announcements: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    enable_events: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    enable_fee: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    
    enable_push: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    enable_email: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    enable_sms: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)

    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    tenant = relationship("Tenant")
    user = relationship("User")

    __mapper_args__ = {
        "version_id_col": version
    }
