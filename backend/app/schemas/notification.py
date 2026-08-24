import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field, ConfigDict
from app.models.notification import (
    NotificationType, NotificationPriority, NotificationStatus,
    NotificationTargetRole, NotificationDeliveryChannel, NotificationDeliveryStatus
)

class NotificationCreate(BaseModel):
    """
    Schema representing user broadcast/manual notification creation payload.
    """
    notification_type: NotificationType
    priority: NotificationPriority
    title: str = Field(..., max_length=200)
    message: str = Field(..., max_length=2000)
    target_role: NotificationTargetRole
    school_id: Optional[uuid.UUID] = None
    target_user_id: Optional[uuid.UUID] = None
    related_module: Optional[str] = Field(None, max_length=100)
    related_record_id: Optional[uuid.UUID] = None
    student_id: Optional[uuid.UUID] = None
    event_key: Optional[str] = Field(None, max_length=500)
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None
    
    # Extended fields
    scheduled_at: Optional[datetime] = None
    published_at: Optional[datetime] = None
    sender_id: Optional[uuid.UUID] = None
    event_type: Optional[str] = Field(None, max_length=100)
    idempotency_key: Optional[str] = Field(None, max_length=500)


class NotificationUpdate(BaseModel):
    """
    Schema representing user state updates (e.g. marking read or soft deleting).
    """
    status: Optional[NotificationStatus] = None
    is_active: Optional[bool] = None


class NotificationResponse(BaseModel):
    """
    Schema representing single Notification details response payload.
    """
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    notification_type: NotificationType
    priority: NotificationPriority
    title: str
    message: str
    target_role: NotificationTargetRole
    target_user_id: Optional[uuid.UUID]
    related_module: Optional[str]
    related_record_id: Optional[uuid.UUID]
    student_id: Optional[uuid.UUID]
    event_key: Optional[str]
    push_status: str
    email_status: str
    sms_status: str
    status: NotificationStatus
    is_push_sent: bool
    is_email_sent: bool
    is_sms_sent: bool
    settings: Dict[str, Any]
    ai_metrics: Dict[str, Any]
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime

    # Extended fields
    scheduled_at: Optional[datetime]
    published_at: Optional[datetime]
    sender_id: Optional[uuid.UUID]
    event_type: Optional[str]
    idempotency_key: Optional[str]

    model_config = ConfigDict(from_attributes=True)


class DeviceTokenCreate(BaseModel):
    device_token: str = Field(..., max_length=500)
    platform: str = Field(..., max_length=50)  # "android", "ios", "web"
    app_type: str = Field(..., max_length=50)  # "admin", "principal", "teacher", "parent"


class DeviceTokenDeactivate(BaseModel):
    device_token: str = Field(..., max_length=500)


class DeviceTokenResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    user_id: uuid.UUID
    device_token: str
    platform: str
    app_type: str
    last_seen_at: datetime
    is_active: bool
    version: int

    model_config = ConfigDict(from_attributes=True)


class NotificationPreferenceResponse(BaseModel):
    """
    Schema representing user preference details response payload.
    """
    id: uuid.UUID
    tenant_id: uuid.UUID
    user_id: uuid.UUID
    enable_homework: bool
    enable_attendance: bool
    enable_marks: bool
    enable_report_card: bool
    enable_announcements: bool
    enable_events: bool
    enable_fee: bool
    enable_push: bool
    enable_email: bool
    enable_sms: bool
    enable_whatsapp: bool
    enable_in_app: bool
    version: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class NotificationPreferenceUpdate(BaseModel):
    """
    Schema representing partial user preference settings updates.
    """
    enable_homework: Optional[bool] = None
    enable_attendance: Optional[bool] = None
    enable_marks: Optional[bool] = None
    enable_report_card: Optional[bool] = None
    enable_announcements: Optional[bool] = None
    enable_events: Optional[bool] = None
    enable_fee: Optional[bool] = None
    enable_push: Optional[bool] = None
    enable_email: Optional[bool] = None
    enable_sms: Optional[bool] = None
    enable_whatsapp: Optional[bool] = None
    enable_in_app: Optional[bool] = None


class UnreadCountResponse(BaseModel):
    """
    Schema representing total unread notifications count.
    """
    unread_count: int


class NotificationDeliveryResponse(BaseModel):
    """
    Schema representing delivery record details.
    """
    id: uuid.UUID
    tenant_id: uuid.UUID
    notification_id: uuid.UUID
    recipient_id: uuid.UUID
    channel: NotificationDeliveryChannel
    provider: str
    provider_message_id: Optional[str]
    status: NotificationDeliveryStatus
    error_code: Optional[str]
    error_message: Optional[str]
    sent_at: Optional[datetime]
    delivered_at: Optional[datetime]
    read_at: Optional[datetime]
    failed_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
