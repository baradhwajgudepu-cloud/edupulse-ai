from datetime import datetime, timezone
import uuid
import enum
from typing import Optional, Dict, Any
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, JSON, Uuid, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class NotificationEventType(str, enum.Enum):
    ATTENDANCE_ABSENT = "ATTENDANCE_ABSENT"
    ATTENDANCE_LATE = "ATTENDANCE_LATE"
    ATTENDANCE_HALF_DAY = "ATTENDANCE_HALF_DAY"
    MARKS_PUBLISHED = "MARKS_PUBLISHED"
    EXAM_SCHEDULE = "EXAM_SCHEDULE"
    EXAM_REMINDER = "EXAM_REMINDER"
    ANNOUNCEMENT = "ANNOUNCEMENT"
    HOLIDAY = "HOLIDAY"
    EMERGENCY_ALERT = "EMERGENCY_ALERT"
    FEE_REMINDER = "FEE_REMINDER"
    FEE_OVERDUE = "FEE_OVERDUE"

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

class NotificationDeliveryChannel(str, enum.Enum):
    IN_APP = "IN_APP"
    PUSH = "PUSH"
    WHATSAPP = "WHATSAPP"
    SMS = "SMS"
    EMAIL = "EMAIL"

class NotificationDeliveryStatus(str, enum.Enum):
    PENDING = "PENDING"
    QUEUED = "QUEUED"
    SENT = "SENT"
    DELIVERED = "DELIVERED"
    READ = "READ"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"


class Notification(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a Notification record.
    """
    __tablename__ = "notifications"
    __table_args__ = (
        UniqueConstraint("tenant_id", "event_key", name="uq_notifications_tenant_event_key"),
        UniqueConstraint("tenant_id", "idempotency_key", name="uq_notifications_tenant_idempotency_key"),
    )

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
    
    student_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("students.id", ondelete="CASCADE"), nullable=True, index=True
    )
    event_key: Mapped[Optional[str]] = mapped_column(String(500), nullable=True, index=True)
    
    push_status: Mapped[str] = mapped_column(String(50), default="NOT_CONFIGURED", server_default="'NOT_CONFIGURED'", nullable=False)
    email_status: Mapped[str] = mapped_column(String(50), default="NOT_CONFIGURED", server_default="'NOT_CONFIGURED'", nullable=False)
    sms_status: Mapped[str] = mapped_column(String(50), default="NOT_CONFIGURED", server_default="'NOT_CONFIGURED'", nullable=False)
    
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

    # Centralized Notification Engine Extended Fields
    scheduled_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    published_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    sender_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    event_type: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, index=True)
    idempotency_key: Mapped[Optional[str]] = mapped_column(String(500), nullable=True, index=True)

    # Relationships
    tenant = relationship("Tenant")
    school = relationship("School")
    target_user = relationship("User", foreign_keys=[target_user_id])
    sender = relationship("User", foreign_keys=[sender_id])
    student = relationship("Student")

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
    enable_whatsapp: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    enable_in_app: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)

    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    tenant = relationship("Tenant")
    user = relationship("User")

    __mapper_args__ = {
        "version_id_col": version
    }


class UserDeviceToken(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a registered User Device Token for push notifications.
    """
    __tablename__ = "user_device_tokens"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    device_token: Mapped[str] = mapped_column(String(500), nullable=False)
    platform: Mapped[str] = mapped_column(String(50), nullable=False)  # "android", "ios", "web"
    app_type: Mapped[str] = mapped_column(String(50), nullable=False)  # "admin", "principal", "teacher", "parent"
    last_seen_at: Mapped[datetime] = mapped_column(nullable=False, default=lambda: datetime.now(timezone.utc))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    tenant = relationship("Tenant")
    user = relationship("User")

    __mapper_args__ = {
        "version_id_col": version
    }


class NotificationDelivery(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a single Channel Delivery Tracking record.
    """
    __tablename__ = "notification_deliveries"

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    notification_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("notifications.id", ondelete="CASCADE"), nullable=False, index=True
    )
    recipient_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    channel: Mapped[NotificationDeliveryChannel] = mapped_column(
        SQLEnum(NotificationDeliveryChannel, name="notificationdeliverychannel"), nullable=False, index=True
    )
    provider: Mapped[str] = mapped_column(String(100), nullable=False)
    provider_message_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True, index=True)
    status: Mapped[NotificationDeliveryStatus] = mapped_column(
        SQLEnum(NotificationDeliveryStatus, name="notificationdeliverystatus"),
        default=NotificationDeliveryStatus.PENDING,
        nullable=False,
        index=True
    )
    error_code: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    error_message: Mapped[Optional[str]] = mapped_column(String(2000), nullable=True)
    
    sent_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    delivered_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    read_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    failed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    tenant = relationship("Tenant")
    notification = relationship("Notification")
    recipient = relationship("User")

    __mapper_args__ = {
        "version_id_col": version
    }
