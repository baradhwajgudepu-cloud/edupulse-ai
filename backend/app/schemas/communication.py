import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict, Field
from app.models.communication import RequestStatus, RequestPriority, RequestCategory, RecipientType, Module

class CommunicationAttachmentSchema(BaseModel):
    id: uuid.UUID
    file_name: str
    file_type: str
    file_size: int
    file_url: str
    uploaded_by_id: uuid.UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class CommunicationMessageSchema(BaseModel):
    id: uuid.UUID
    request_id: uuid.UUID
    sender_id: uuid.UUID
    sender_role: str
    message: str
    created_at: datetime
    attachments: List[CommunicationAttachmentSchema] = []

    model_config = ConfigDict(from_attributes=True)

class CommunicationParticipantSchema(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    role: str
    last_read_at: Optional[datetime] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class CommunicationAuditLogSchema(BaseModel):
    id: uuid.UUID
    request_id: uuid.UUID
    user_id: uuid.UUID
    action: str
    details: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class CommunicationRequestCreate(BaseModel):
    student_id: uuid.UUID
    recipient_type: RecipientType
    category: RequestCategory
    module: Optional[Module] = None
    reference_type: Optional[str] = None
    reference_id: Optional[str] = None
    subject: str = Field(..., max_length=200, min_length=1)
    priority: RequestPriority = RequestPriority.NORMAL
    message: str

class CommunicationRequestReply(BaseModel):
    message: str

class CommunicationRequestStatusUpdate(BaseModel):
    status: RequestStatus

class CommunicationRequestAssign(BaseModel):
    assigned_to_id: uuid.UUID

class CommunicationRequestResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    student_id: uuid.UUID
    creator_id: uuid.UUID
    assigned_to_id: Optional[uuid.UUID] = None
    recipient_type: RecipientType
    category: RequestCategory
    module: Optional[Module] = None
    reference_type: Optional[str] = None
    reference_id: Optional[str] = None
    subject: str
    priority: RequestPriority
    status: RequestStatus
    created_at: datetime
    updated_at: datetime
    resolved_at: Optional[datetime] = None
    is_active: bool
    version: int
    unread_messages_count: int = 0
    student_name: Optional[str] = None
    student_class_section: Optional[str] = None
    creator_name: Optional[str] = None
    assigned_to_name: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class CommunicationRequestDetailResponse(BaseModel):
    request: CommunicationRequestResponse
    messages: List[CommunicationMessageSchema] = []
    participants: List[CommunicationParticipantSchema] = []
    audit_logs: List[CommunicationAuditLogSchema] = []

    model_config = ConfigDict(from_attributes=True)

class CommunicationAnalyticsResponse(BaseModel):
    total_requests: int
    open_count: int
    acknowledged_count: int
    in_progress_count: int
    waiting_for_parent_count: int
    escalated_count: int
    resolved_count: int
    average_resolution_time_hours: float
    sla_breaches_count: int
    requests_by_category: Dict[str, int]
    requests_by_school: Dict[str, int]
    requests_by_priority: Dict[str, int]
    requests_over_time: List[Dict[str, Any]]
    escalation_rate: float
    resolution_rate: float

class UnreadCountResponse(BaseModel):
    unread_count: int
