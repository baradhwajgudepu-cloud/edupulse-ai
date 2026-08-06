import uuid
from datetime import time, datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from app.models.timetable import DayOfWeek, PeriodType, TimetableStatus

class TimetableBase(BaseModel):
    day_of_week: DayOfWeek
    period_number: int = Field(..., ge=1)
    period_id: Optional[uuid.UUID] = None
    
    start_time: time
    end_time: time
    
    period_type: PeriodType
    room_id: Optional[uuid.UUID] = None
    is_available: bool = True
    
    settings: Dict[str, Any] = Field(default_factory=dict)
    ai_metrics: Dict[str, Any] = Field(default_factory=dict)

class TimetableCreate(TimetableBase):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    teacher_subject_assignment_id: Optional[uuid.UUID] = None
    class_id: uuid.UUID
    section_id: uuid.UUID

class TimetableUpdate(BaseModel):
    day_of_week: Optional[DayOfWeek] = None
    period_number: Optional[int] = Field(None, ge=1)
    period_id: Optional[uuid.UUID] = None
    
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    
    period_type: Optional[PeriodType] = None
    room_id: Optional[uuid.UUID] = None
    is_available: Optional[bool] = None
    
    status: Optional[TimetableStatus] = None
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

class TimetableResponse(TimetableBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    teacher_subject_assignment_id: Optional[uuid.UUID] = None
    class_id: uuid.UUID
    section_id: uuid.UUID
    teacher_id: Optional[uuid.UUID] = None
    subject_id: Optional[uuid.UUID] = None
    
    status: TimetableStatus
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
