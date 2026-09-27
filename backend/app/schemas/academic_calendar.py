import uuid
from typing import Optional, List, Dict, Any
from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field

from app.models.academic_calendar import CalendarEventType, CalendarEventStatus

class CalendarEventCreate(BaseModel):
    event_type: CalendarEventType = CalendarEventType.SCHOOL_HOLIDAY
    title: str = Field(..., max_length=255, min_length=1)
    description: Optional[str] = None
    event_date: date
    source: str = "SCHOOL_ADMIN"
    source_reference: Optional[str] = None
    is_non_working_day: bool = True
    extra_data: Optional[Dict[str, Any]] = None

class CalendarEventUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=255, min_length=1)
    description: Optional[str] = None
    event_date: Optional[date] = None
    event_type: Optional[CalendarEventType] = None
    status: Optional[CalendarEventStatus] = None
    is_non_working_day: Optional[bool] = None
    extra_data: Optional[Dict[str, Any]] = None

class CalendarEventResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    event_date: date
    event_type: CalendarEventType
    title: str
    description: Optional[str] = None
    source: str
    source_reference: Optional[str] = None
    status: CalendarEventStatus
    is_non_working_day: bool
    created_by: Optional[uuid.UUID] = None
    approved_by: Optional[uuid.UUID] = None
    approved_at: Optional[datetime] = None
    extra_data: Dict[str, Any] = {}
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class PrincipalHolidayDeclareRequest(BaseModel):
    school_id: Optional[uuid.UUID] = None
    academic_year_id: Optional[uuid.UUID] = None
    event_date: date
    title: str = Field(..., max_length=255, min_length=1, description="E.g. Emergency Heavy Rain Holiday")
    description: Optional[str] = None
    reason: Optional[str] = Field(None, description="Detailed operational rationale")
    is_non_working_day: bool = True
    auto_approve: bool = True

    model_config = ConfigDict(extra="ignore")

class StateHolidayPopulateRequest(BaseModel):
    school_id: Optional[uuid.UUID] = None
    academic_year_id: Optional[uuid.UUID] = None
    state: Optional[str] = None
    academic_year_code: Optional[str] = None

    model_config = ConfigDict(extra="ignore")

class StateHolidayStatusResponse(BaseModel):
    state: str
    academic_year_code: str
    is_verified: bool
    source: Optional[str] = None
    source_version: Optional[str] = None
    holidays_count: int = 0
    message: str
    can_import: bool = False

class WorkingDaysCalculationResponse(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    start_date: date
    end_date: date
    total_calendar_days: int
    total_working_days: int
    total_non_working_days: int
    working_dates: List[date]
    breakdown: Dict[str, int]

class HolidayImpactResponse(BaseModel):
    holiday_date: date
    is_working_day_originally: bool
    affected_periods_count: int
    affected_classes_count: int
    affected_teachers_count: int
    affected_classes: List[Dict[str, Any]]
    affected_teachers: List[Dict[str, Any]]
    affected_subjects: List[Dict[str, Any]]
    subjects_requiring_recovery: List[str]
    exam_conflict_detected: bool
    exam_conflicts: List[Dict[str, Any]]
    message: str

class AIRecoveryChangeItem(BaseModel):
    class_id: uuid.UUID
    class_name: str
    section_id: uuid.UUID
    section_name: str
    subject_id: uuid.UUID
    subject_name: str
    teacher_id: Optional[uuid.UUID] = None
    teacher_name: Optional[str] = None
    from_slot: str
    to_slot: str
    from_day: str
    from_period: int
    to_day: str
    to_period: int
    strategy: str
    rationale: str

class AIRecoveryPreviewResponse(BaseModel):
    recommendation_id: uuid.UUID
    holiday_date: date
    status: str
    affected_periods: int
    affected_classes: int
    affected_teachers: int
    subjects_requiring_recovery: List[str]
    changes: List[AIRecoveryChangeItem]
    syllabus_recovery_impact: Dict[str, Any]
    unaffected_slots_count: int
    preserves_unaffected_slots: bool = True
    can_apply: bool = True
