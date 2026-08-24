import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

from app.models.announcement import AnnouncementAudienceType, AnnouncementStatus
from app.models.notification import NotificationTargetRole, NotificationPriority

class AnnouncementCreate(BaseModel):
    title: str = Field(..., max_length=200, min_length=1)
    message: str = Field(..., min_length=1)
    audience_type: AnnouncementAudienceType = AnnouncementAudienceType.ROLE
    target_role: Optional[NotificationTargetRole] = None
    target_class_id: Optional[uuid.UUID] = None
    target_section_id: Optional[uuid.UUID] = None
    publish_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    priority: NotificationPriority = NotificationPriority.NORMAL
    attachment_url: Optional[str] = Field(None, max_length=500)

class AnnouncementUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=200, min_length=1)
    message: Optional[str] = None
    audience_type: Optional[AnnouncementAudienceType] = None
    target_role: Optional[NotificationTargetRole] = None
    target_class_id: Optional[uuid.UUID] = None
    target_section_id: Optional[uuid.UUID] = None
    publish_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    priority: Optional[NotificationPriority] = None
    attachment_url: Optional[str] = Field(None, max_length=500)
    status: Optional[AnnouncementStatus] = None

class AnnouncementResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    title: str
    message: str
    audience_type: AnnouncementAudienceType
    target_role: Optional[NotificationTargetRole] = None
    target_class_id: Optional[uuid.UUID] = None
    target_section_id: Optional[uuid.UUID] = None
    publish_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    priority: NotificationPriority
    attachment_url: Optional[str] = None
    status: AnnouncementStatus
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
