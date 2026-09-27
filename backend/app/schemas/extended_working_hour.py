import uuid
from datetime import datetime, time
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict, Field

class ExtendedWorkingHourBase(BaseModel):
    normal_start_time: str = Field("08:30", description="HH:MM string, e.g. 08:30")
    normal_end_time: str = Field("15:30", description="HH:MM string, e.g. 15:30")
    periods_per_day: int = Field(8, ge=4, le=12, description="Standard regular periods per day")
    lunch_period_number: int = Field(4, ge=2, le=8, description="Designated lunch period")
    working_days: List[str] = Field(
        default=["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"],
        description="Active school working days"
    )

    is_extended_hours_enabled: bool = Field(False, description="Whether school has enabled extended teaching hours")
    extended_start_time: Optional[str] = Field("15:30", description="Extended hours start, e.g. 15:30")
    extended_end_time: Optional[str] = Field("16:15", description="Extended hours end, e.g. 16:15")
    applicable_days: List[str] = Field(default_factory=list, description="Days where extended hours apply")
    additional_periods: int = Field(1, ge=1, le=4, description="Additional teaching periods per extended day")
    activity_type: str = Field("ADDITIONAL_SUBJECT", description="ACADEMIC, REMEDIAL, ADDITIONAL_SUBJECT, EXTRA_CURRICULAR, SPECIAL_CLASS, OTHER")
    
    is_active: bool = True
    settings: Dict[str, Any] = Field(default_factory=dict)

class ExtendedWorkingHourCreate(ExtendedWorkingHourBase):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID

class ExtendedWorkingHourUpdate(BaseModel):
    school_id: Optional[uuid.UUID] = None
    academic_year_id: Optional[uuid.UUID] = None
    normal_start_time: Optional[str] = None
    normal_end_time: Optional[str] = None
    periods_per_day: Optional[int] = Field(None, ge=4, le=12)
    lunch_period_number: Optional[int] = Field(None, ge=2, le=8)
    working_days: Optional[List[str]] = None

    is_extended_hours_enabled: Optional[bool] = None
    extended_start_time: Optional[str] = None
    extended_end_time: Optional[str] = None
    applicable_days: Optional[List[str]] = None
    additional_periods: Optional[int] = Field(None, ge=1, le=4)
    activity_type: Optional[str] = None
    is_active: Optional[bool] = None
    settings: Optional[Dict[str, Any]] = None
    breaks: Optional[List[Dict[str, Any]]] = None
    period_duration_minutes: Optional[int] = Field(None, ge=20, le=90)

class BreakTimingItem(BaseModel):
    id: str
    name: str = "Break"
    break_type: str = "SHORT_BREAK"  # SHORT_BREAK | LUNCH_BREAK
    after_period: int = 4
    duration_minutes: int = 30
    start_time: Optional[str] = None
    end_time: Optional[str] = None

class ExtendedWorkingHourResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    
    normal_start_time: str
    normal_end_time: str
    periods_per_day: int
    lunch_period_number: int
    working_days: List[str]

    is_extended_hours_enabled: bool
    extended_start_time: Optional[str] = None
    extended_end_time: Optional[str] = None
    applicable_days: List[str] = []
    additional_periods: int
    activity_type: str

    # Computed capacity metrics
    weekly_normal_periods: int = 48
    weekly_extended_periods: int = 0
    total_weekly_capacity: int = 48

    # Break timings & recalculated period timings
    period_duration_minutes: int = 45
    breaks: List[Dict[str, Any]] = []
    calculated_timings: List[Dict[str, Any]] = []
    calculated_end_time: Optional[str] = None
    requires_extension: bool = False
    extension_minutes: int = 0

    is_active: bool
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

class TimetableRecalculationPreview(BaseModel):
    normal_start_time: str
    original_end_time: str
    calculated_end_time: str
    extension_minutes: int
    requires_extension: bool
    periods_per_day: int
    period_duration_minutes: int
    breaks: List[Dict[str, Any]]
    period_timings: List[Dict[str, Any]]

class ApplyRecalculatedTimingsRequest(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    approve_extension: bool = False
    new_end_time: Optional[str] = None
    breaks: Optional[List[Dict[str, Any]]] = None
    period_duration_minutes: Optional[int] = None

class TimetableCapacitySummary(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: Optional[uuid.UUID] = None
    section_id: Optional[uuid.UUID] = None
    
    working_days_count: int
    periods_per_day: int
    available_weekly_capacity: int
    
    total_subjects_configured: int
    official_subjects_count: int
    school_added_subjects_count: int
    
    total_required_periods: int
    remaining_capacity: int
    
    is_shortfall: bool = False
    shortfall_periods: int = 0
    shortfall_warning_message: Optional[str] = None
    
    is_extended_hours_enabled: bool = False
    extended_hours_potential_capacity: int = 0
    remediation_options: List[str] = []
