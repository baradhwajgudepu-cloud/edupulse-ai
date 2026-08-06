import uuid
from datetime import date, datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from app.models.homework import HomeworkStatus, HomeworkPriority

class HomeworkCreate(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    teacher_id: uuid.UUID
    teacher_subject_assignment_id: uuid.UUID
    subject_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    timetable_id: Optional[uuid.UUID] = None
    title: str = Field(..., max_length=200, min_length=1)
    description: str
    due_date: date
    priority: HomeworkPriority = HomeworkPriority.NORMAL
    status: HomeworkStatus = HomeworkStatus.DRAFT
    attachment_url: Optional[str] = None
    estimated_minutes: Optional[int] = Field(None, ge=0)
    settings: Dict[str, Any] = Field(default_factory=lambda: {
        "template_used": False,
        "notification_status": "PENDING",
        "notification_sent_at": None
    })
    ai_metrics: Dict[str, Any] = Field(default_factory=lambda: {
        "estimated_difficulty": None,
        "predicted_completion_time": None,
        "copied_from_previous": False
    })

class HomeworkCreateFromTimetable(BaseModel):
    title: str = Field(..., max_length=200, min_length=1)
    description: str
    due_date: date
    priority: HomeworkPriority = HomeworkPriority.NORMAL
    status: HomeworkStatus = HomeworkStatus.DRAFT
    attachment_url: Optional[str] = None
    estimated_minutes: Optional[int] = Field(None, ge=0)

class HomeworkUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=200, min_length=1)
    description: Optional[str] = None
    due_date: Optional[date] = None
    priority: Optional[HomeworkPriority] = None
    status: Optional[HomeworkStatus] = None
    attachment_url: Optional[str] = None
    estimated_minutes: Optional[int] = Field(None, ge=0)
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

class HomeworkCopyRequest(BaseModel):
    homework_id: uuid.UUID
    target_section_ids: List[uuid.UUID]

class HomeworkResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    teacher_id: uuid.UUID
    teacher_subject_assignment_id: uuid.UUID
    subject_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    timetable_id: Optional[uuid.UUID] = None
    title: str
    description: str
    due_date: date
    priority: HomeworkPriority
    status: HomeworkStatus
    attachment_url: Optional[str] = None
    estimated_minutes: Optional[int] = None
    is_active: bool
    settings: Dict[str, Any]
    ai_metrics: Dict[str, Any]
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None
    created_by: Optional[uuid.UUID] = None
    updated_by: Optional[uuid.UUID] = None

    model_config = ConfigDict(from_attributes=True)
