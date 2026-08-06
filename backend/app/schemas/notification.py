import uuid
from datetime import datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field, ConfigDict
from app.models.notification import NotificationType, NotificationPriority, NotificationStatus, NotificationTargetRole

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
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None


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


class UnreadCountResponse(BaseModel):
    """
    Schema representing total unread notifications count.
    """
    unread_count: int
