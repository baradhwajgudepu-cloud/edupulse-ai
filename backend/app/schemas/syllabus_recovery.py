import uuid
import datetime as dt
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, ConfigDict


class RecoveryPlanItemBase(BaseModel):
    date: dt.date
    period_number: int = Field(..., ge=1, le=12)
    phase: str = Field("PHASE_1_CATCHUP", description="PHASE_1_CATCHUP, PHASE_2_CORE, PHASE_3_PRACTICE, PHASE_4_BUFFER")
    syllabus_item_id: Optional[uuid.UUID] = None
    topic_name: str = Field(..., min_length=1, max_length=200)
    duration_minutes: int = Field(45, ge=15, le=180)
    teacher_id: Optional[uuid.UUID] = None
    class_id: uuid.UUID
    section_id: uuid.UUID
    room_id: Optional[uuid.UUID] = None
    status: str = Field("SUGGESTED", description="SUGGESTED, MODIFIED, APPROVED, REJECTED")
    is_approved: bool = False
    conflict_status: str = Field("NO_CONFLICT", description="NO_CONFLICT, CONFLICT_DETECTED")
    conflict_message: Optional[str] = None
    timetable_id: Optional[uuid.UUID] = None


class RecoveryPlanItemCreate(RecoveryPlanItemBase):
    pass


class RecoveryPlanItemUpdate(BaseModel):
    id: Optional[uuid.UUID] = None
    date: Optional[dt.date] = None
    period_number: Optional[int] = Field(None, ge=1, le=12)
    phase: Optional[str] = None
    syllabus_item_id: Optional[uuid.UUID] = None
    topic_name: Optional[str] = None
    duration_minutes: Optional[int] = None
    teacher_id: Optional[uuid.UUID] = None
    room_id: Optional[uuid.UUID] = None
    status: Optional[str] = None
    is_approved: Optional[bool] = None
    conflict_status: Optional[str] = None
    conflict_message: Optional[str] = None
    timetable_id: Optional[uuid.UUID] = None


class RecoveryPlanItemRead(RecoveryPlanItemBase):
    id: uuid.UUID
    recovery_plan_id: uuid.UUID
    tenant_id: uuid.UUID
    teacher_name: Optional[str] = None
    class_name: Optional[str] = None
    section_name: Optional[str] = None
    room_name: Optional[str] = None
    is_active: bool
    version: int

    model_config = ConfigDict(from_attributes=True)


class SyllabusRecoveryPlanBase(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    subject_id: uuid.UUID
    teacher_id: Optional[uuid.UUID] = None
    recovery_type: str = "TEACHER_SELF_RECOVERY"
    primary_teacher_id: Optional[uuid.UUID] = None
    support_teacher_id: Optional[uuid.UUID] = None
    delay_days: int = 0
    duration_weeks: int = 2
    recommended_periods_per_week: int = 1
    projected_improvement_days: int = 0
    parent_notes: Optional[str] = None
    candidate_evaluations: Optional[List[Dict[str, Any]]] = None
    reason: str = Field(..., min_length=1, max_length=255)
    current_completion: float = Field(0.0, ge=0.0, le=100.0)
    target_completion_date: Optional[dt.date] = None
    forecast_completion_date: Optional[dt.date] = None
    new_forecast_date: Optional[dt.date] = None
    expected_recovery_periods: float = Field(0.0, ge=0.0)
    status: str = Field("SUGGESTED", description="DRAFT, SUGGESTED, EDITED, APPROVED, REJECTED, APPLIED")
    rejection_remarks: Optional[str] = None


class SyllabusRecoveryPlanCreate(SyllabusRecoveryPlanBase):
    items: List[RecoveryPlanItemCreate] = []


class SyllabusRecoveryPlanUpdate(BaseModel):
    reason: Optional[str] = None
    recovery_type: Optional[str] = None
    primary_teacher_id: Optional[uuid.UUID] = None
    support_teacher_id: Optional[uuid.UUID] = None
    delay_days: Optional[int] = None
    duration_weeks: Optional[int] = None
    recommended_periods_per_week: Optional[int] = None
    projected_improvement_days: Optional[int] = None
    parent_notes: Optional[str] = None
    candidate_evaluations: Optional[List[Dict[str, Any]]] = None
    current_completion: Optional[float] = None
    target_completion_date: Optional[dt.date] = None
    forecast_completion_date: Optional[dt.date] = None
    new_forecast_date: Optional[dt.date] = None
    expected_recovery_periods: Optional[float] = None
    status: Optional[str] = None
    rejection_remarks: Optional[str] = None
    items: Optional[List[RecoveryPlanItemUpdate]] = None


class SyllabusRecoveryPlanRead(SyllabusRecoveryPlanBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    class_name: Optional[str] = None
    section_name: Optional[str] = None
    subject_name: Optional[str] = None
    teacher_name: Optional[str] = None
    primary_teacher_name: Optional[str] = None
    support_teacher_name: Optional[str] = None
    created_by: Optional[uuid.UUID] = None
    approved_by: Optional[uuid.UUID] = None
    approved_at: Optional[dt.datetime] = None
    audit_trail: Dict[str, Any] = {}
    is_active: bool
    version: int
    created_at: dt.datetime
    updated_at: dt.datetime
    items: List[RecoveryPlanItemRead] = []

    model_config = ConfigDict(from_attributes=True)


class RecoveryValidationItem(BaseModel):
    id: Optional[uuid.UUID] = None
    date: dt.date
    period_number: int
    teacher_id: Optional[uuid.UUID] = None
    class_id: uuid.UUID
    section_id: uuid.UUID
    room_id: Optional[uuid.UUID] = None
    topic_name: Optional[str] = None


class RecoveryValidationRequest(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    items: List[RecoveryValidationItem]


class ItemConflictResult(BaseModel):
    item_index: int
    item_id: Optional[uuid.UUID] = None
    has_conflict: bool
    conflict_type: Optional[str] = None  # TEACHER_CLASH, ROOM_CLASH, HOLIDAY_COLLISION, EXAM_COLLISION, NO_CONFLICT
    conflict_message: Optional[str] = None


class RecoveryValidationResponse(BaseModel):
    is_valid: bool
    total_conflicts: int
    results: List[ItemConflictResult]


class RecoveryApprovalRequest(BaseModel):
    action: str = Field(..., description="APPROVE or REJECT")
    remarks: Optional[str] = None


# Parent / Student progress schemas (Sanitized)
class StudentSyllabusTopicProgress(BaseModel):
    topic_id: uuid.UUID
    chapter_name: str
    topic_name: str
    status: str  # COMPLETED, IN_PROGRESS, UPCOMING
    completed_at: Optional[dt.datetime] = None
    order_index: int


class StudentSubjectProgress(BaseModel):
    subject_id: uuid.UUID
    subject_name: str
    teacher_name: Optional[str] = None
    total_topics: int
    completed_topics: int
    in_progress_topics: int
    completion_percentage: float
    target_completion_date: Optional[dt.date] = None
    forecast_completion_date: Optional[dt.date] = None
    status_badge: str  # "On schedule", "Slightly behind", "Recovery plan active"
    topics: List[StudentSyllabusTopicProgress] = []


class StudentSyllabusProgressResponse(BaseModel):
    student_id: uuid.UUID
    student_name: str
    class_id: uuid.UUID
    class_name: str
    section_id: uuid.UUID
    section_name: str
    overall_completion_percentage: float
    subjects: List[StudentSubjectProgress] = []


# Absence Impact schemas
class AbsenceImpactPeriod(BaseModel):
    date: dt.date
    period_number: int
    class_id: uuid.UUID
    class_name: str
    section_id: uuid.UUID
    section_name: str
    subject_id: uuid.UUID
    subject_name: str
    syllabus_item_id: Optional[uuid.UUID] = None
    topic_name: str


class AffectedClassSummary(BaseModel):
    class_id: uuid.UUID
    class_name: str
    section_id: uuid.UUID
    section_name: str
    subject_id: uuid.UUID
    subject_name: str
    missed_periods_count: int
    current_completion: float
    old_forecast_date: Optional[dt.date] = None
    new_forecast_date: Optional[dt.date] = None
    delay_days: int


class TeacherAbsenceImpactResponse(BaseModel):
    teacher_id: uuid.UUID
    teacher_name: str
    absence_date: dt.date
    total_missed_periods: int
    affected_periods: List[AbsenceImpactPeriod] = []
    affected_classes: List[AffectedClassSummary] = []
    estimated_recovery_periods_needed: int
    recommended_action: str


# Academic Heatmap schemas
class AcademicHeatmapCell(BaseModel):
    class_id: uuid.UUID
    class_name: str
    section_id: uuid.UUID
    section_name: str
    subject_id: uuid.UUID
    subject_name: str
    teacher_id: Optional[uuid.UUID] = None
    teacher_name: Optional[str] = None
    completion_percentage: float
    status: str  # ON_TRACK, AT_RISK, DELAYED, NO_PROGRESS, AHEAD
    delay_days: int
    target_date: Optional[dt.date] = None
    forecast_date: Optional[dt.date] = None
    recovery_plan_active: bool = False
    recovery_plan_id: Optional[uuid.UUID] = None


class AcademicHeatmapResponse(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    classes: List[Dict[str, Any]] = []
    subjects: List[Dict[str, Any]] = []
    cells: List[AcademicHeatmapCell] = []
    summary: Dict[str, Any] = {}


# =============================================================================
# CROSS-TEACHER SYLLABUS RECOVERY INTELLIGENCE SCHEMAS
# =============================================================================

class CandidateEvaluation(BaseModel):
    teacher_id: uuid.UUID
    teacher_name: str
    official_email: Optional[str] = None
    subject_id: uuid.UUID
    subject_name: str
    source_class_name: Optional[str] = None
    syllabus_completion_pct: float
    is_completed: bool
    max_weekly_periods: int
    current_weekly_periods: int
    available_capacity: int
    has_capacity: bool
    qualification: Optional[str] = None
    specialization: Optional[str] = None
    is_same_subject: bool
    class_compatibility: str  # SAME_GRADE_PARALLEL_SECTION, SAME_GRADE, OTHER_GRADE, NOT_APPLICABLE
    schedule_compatibility: str  # COMPATIBLE, NO_FREE_SLOTS, CONFLICT
    compatible_slots: List[Dict[str, Any]] = []
    eligibility_status: str  # ELIGIBLE, NO_CAPACITY, SCHEDULE_CONFLICT, INSUFFICIENT_PROGRESS, INELIGIBLE_SUBJECT
    eligibility_notes: str


class CrossTeacherRecoveryRecommendation(BaseModel):
    plan_id: Optional[uuid.UUID] = None
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    class_name: str
    section_id: uuid.UUID
    section_name: str
    subject_id: uuid.UUID
    subject_name: str
    primary_teacher_id: Optional[uuid.UUID] = None
    primary_teacher_name: Optional[str] = None
    current_completion: float
    target_completion_date: Optional[dt.date] = None
    original_forecast_date: Optional[dt.date] = None
    delay_days: int
    recommended_support_teacher_id: Optional[uuid.UUID] = None
    recommended_support_teacher_name: Optional[str] = None
    recommended_periods_per_week: int = 1
    duration_weeks: int = 2
    total_recovery_periods: int = 2
    new_projected_date: Optional[dt.date] = None
    projected_improvement_days: int = 0
    ai_recommendation_text: str
    proposed_slots: List[Dict[str, Any]] = []
    candidate_evaluations: List[CandidateEvaluation] = []
    status: str = "PROPOSED"
    disclaimer: str = "Projected improvement is an estimate based on current teaching pace and available timetable capacity."


class CrossTeacherApprovalRequest(BaseModel):
    action: str = Field("APPROVE", description="APPROVE, REJECT, CANCEL")
    selected_teacher_id: Optional[uuid.UUID] = None
    remarks: Optional[str] = None


class CrossTeacherEditRequest(BaseModel):
    support_teacher_id: Optional[uuid.UUID] = None
    recommended_periods_per_week: Optional[int] = None
    duration_weeks: Optional[int] = None
    parent_notes: Optional[str] = None
    items: Optional[List[RecoveryPlanItemUpdate]] = None


class RecoveryAnalyticsSummary(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    month_name: Optional[str] = None
    normal_periods: int
    recovery_periods: int
    cross_teacher_support_periods: int
    teacher_absence_recovery_periods: int
    active_recovery_plans_count: int
    approved_recovery_plans_count: int
    completed_recovery_plans_count: int
    subject_breakdown: List[Dict[str, Any]] = []
    class_breakdown: List[Dict[str, Any]] = []
