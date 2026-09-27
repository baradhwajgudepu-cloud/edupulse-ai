import uuid
from typing import Optional, List, Dict, Any
from datetime import datetime, date
from pydantic import BaseModel, Field, ConfigDict

class SyllabusPredictionItem(BaseModel):
    subject_id: uuid.UUID
    subject_name: str
    class_id: uuid.UUID
    class_name: str
    section_id: Optional[uuid.UUID] = None
    section_name: Optional[str] = None
    teacher_id: Optional[uuid.UUID] = None
    teacher_name: Optional[str] = None
    total_chapters: int
    completed_chapters: int
    in_progress_chapters: int
    remaining_chapters: int
    total_topics: int
    completed_topics: int
    completion_percentage: float
    planned_pace: float = Field(..., description="Planned chapters per week")
    actual_pace: float = Field(..., description="Actual chapters completed per week")
    projected_completion_date: Optional[str] = Field(None, description="Projected completion date string (YYYY-MM-DD), labeled as estimate")
    is_estimate: bool = True
    target_exam_name: Optional[str] = None
    target_exam_date: Optional[str] = None
    days_gap_to_exam: Optional[int] = None
    risk_status: str = Field(..., description="ON_TRACK, AT_RISK, LIKELY_TO_MISS_TARGET")
    data_sufficiency: str = Field(..., description="SUFFICIENT, NO_SYLLABUS, WAITING_FOR_PROGRESS, INSUFFICIENT_DATA")
    message: str
    recommended_action: Optional[str] = None

class AdaptiveRecommendationItem(BaseModel):
    id: str
    subject_id: uuid.UUID
    subject_name: str
    class_id: uuid.UUID
    class_name: str
    section_id: Optional[uuid.UUID] = None
    section_name: Optional[str] = None
    risk_status: str
    current_weekly_periods: int
    recommended_weekly_periods: int
    periods_difference: int
    duration_weeks: int
    rationale: str
    impact_explanation: str
    is_optional: bool = True

class AcademicPlanningSummary(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    school_wide_completion_pct: float
    total_subjects_tracked: int
    on_track_count: int
    at_risk_count: int
    likely_to_miss_count: int
    insufficient_data_count: int
    upcoming_exams_count: int
    pending_timetable_suggestions_count: int
    class_summaries: List[Dict[str, Any]] = Field(default_factory=list)
    at_risk_subjects: List[SyllabusPredictionItem] = Field(default_factory=list)
    adaptive_recommendations: List[AdaptiveRecommendationItem] = Field(default_factory=list)

class TimetableAISlotItem(BaseModel):
    day_of_week: str
    period_number: int
    start_time: str
    end_time: str
    period_type: str = "REGULAR"
    subject_id: Optional[uuid.UUID] = None
    subject_name: Optional[str] = None
    teacher_id: Optional[uuid.UUID] = None
    teacher_name: Optional[str] = None
    room_id: Optional[uuid.UUID] = None
    room_number: Optional[str] = None

class TimetableAIRecommendationRequest(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    periods_per_day: int = Field(7, ge=4, le=10)
    working_days: List[str] = Field(
        default=["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
    )
    lunch_period_number: int = Field(4, ge=2, le=6)
    avoid_teacher_clashes: Optional[bool] = True
    balance_daily_workload: Optional[bool] = True

class TimetableAIApproveRequest(BaseModel):
    recommendation_id: uuid.UUID
    publish_immediately: bool = True

class TimetableAIRecommendationResponse(BaseModel):
    recommendation_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    status: str = "SUGGESTED"
    confidence_level: float = 0.95
    data_sufficiency: str = "SUFFICIENT"
    suggested_slots: List[TimetableAISlotItem]
    workload_analysis: Dict[str, Any]
    rationale: Dict[str, Any]
    risk_factors: Dict[str, Any]
    can_publish: bool = True

class TimetableSlotValidation(BaseModel):
    day_of_week: str
    period_number: int
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    period_type: str = "REGULAR"
    teacher_id: Optional[uuid.UUID] = None
    subject_id: Optional[uuid.UUID] = None
    room_id: Optional[uuid.UUID] = None

class TimetableGridValidationRequest(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    slots: List[TimetableSlotValidation]

class TimetableGridConflictItem(BaseModel):
    day_of_week: str
    period_number: int
    conflict_type: str
    message: str
    severity: str = "ERROR"

class TimetableGridValidationResponse(BaseModel):
    has_conflict: bool
    conflicts: List[TimetableGridConflictItem]
    warnings: List[str] = Field(default_factory=list)
