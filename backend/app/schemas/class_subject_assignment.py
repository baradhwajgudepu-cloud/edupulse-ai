import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict, Field

class ClassSubjectAssignmentBase(BaseModel):
    weekly_periods: int = Field(3, ge=1, le=20, description="Periods required per week")
    period_duration_minutes: int = Field(45, ge=15, le=120)
    preferred_days: List[str] = Field(default_factory=list, description="e.g. ['MONDAY', 'WEDNESDAY', 'FRIDAY']")
    preferred_time: Optional[str] = Field(None, description="e.g. 'MORNING', 'AFTERNOON'")
    max_consecutive_periods: int = Field(1, ge=1, le=4)
    min_gap_between_sessions: int = Field(1, ge=0, le=5)
    is_lab_required: bool = False
    room_id: Optional[uuid.UUID] = None
    is_active: bool = True
    settings: Dict[str, Any] = Field(default_factory=dict)

class ClassSubjectAssignmentCreate(ClassSubjectAssignmentBase):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    section_id: Optional[uuid.UUID] = None
    subject_id: uuid.UUID
    teacher_id: Optional[uuid.UUID] = None

class ClassSubjectAssignmentBatchCreate(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    subject_id: uuid.UUID
    class_ids: List[uuid.UUID] = Field(..., min_length=1)
    section_ids: Optional[List[uuid.UUID]] = None
    teacher_id: Optional[uuid.UUID] = None
    weekly_periods: int = Field(3, ge=1, le=20)
    period_duration_minutes: int = Field(45, ge=15, le=120)
    preferred_days: List[str] = Field(default_factory=list)
    preferred_time: Optional[str] = None
    room_id: Optional[uuid.UUID] = None
    is_lab_required: bool = False

class ClassSubjectAssignmentUpdate(BaseModel):
    weekly_periods: Optional[int] = Field(None, ge=1, le=20)
    period_duration_minutes: Optional[int] = Field(None, ge=15, le=120)
    preferred_days: Optional[List[str]] = None
    preferred_time: Optional[str] = None
    max_consecutive_periods: Optional[int] = Field(None, ge=1, le=4)
    min_gap_between_sessions: Optional[int] = Field(None, ge=0, le=5)
    is_lab_required: Optional[bool] = None
    room_id: Optional[uuid.UUID] = None
    teacher_id: Optional[uuid.UUID] = None
    is_active: Optional[bool] = None
    settings: Optional[Dict[str, Any]] = None

class ClassSubjectAssignmentResponse(ClassSubjectAssignmentBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    section_id: Optional[uuid.UUID] = None
    subject_id: uuid.UUID
    teacher_id: Optional[uuid.UUID] = None

    # Enhanced audit & display attributes
    subject_name: Optional[str] = None
    subject_code: Optional[str] = None
    source_type: Optional[str] = None
    class_name: Optional[str] = None
    section_name: Optional[str] = None
    teacher_name: Optional[str] = None

    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
