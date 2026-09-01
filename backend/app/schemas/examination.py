import uuid
from datetime import date, time, datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.examination import ExamStatus, ExamType, ExamTypeCategory

# ==================================================
# Exam Type Master Schemas
# ==================================================
class ExamTypeMasterCreate(BaseModel):
    name: str = Field(..., max_length=100, min_length=1)
    code: str = Field(..., max_length=50, min_length=1)
    description: Optional[str] = None
    category: ExamTypeCategory = ExamTypeCategory.SCHOLASTIC
    default_weightage: float = Field(100.0, ge=0.0, le=1000.0)
    school_id: Optional[uuid.UUID] = None
    is_active: bool = True

class ExamTypeMasterUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=100, min_length=1)
    description: Optional[str] = None
    category: Optional[ExamTypeCategory] = None
    default_weightage: Optional[float] = Field(None, ge=0.0, le=1000.0)
    is_active: Optional[bool] = None

class ExamTypeMasterResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: Optional[uuid.UUID] = None
    name: str
    code: str
    description: Optional[str] = None
    category: ExamTypeCategory
    default_weightage: float
    is_system: bool
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ==================================================
# Exam Template Schemas
# ==================================================
class ExamTemplateCreate(BaseModel):
    template_name: str = Field(..., max_length=200, min_length=1)
    exam_type: ExamType
    subject_configs: List[Dict[str, Any]] = Field(default_factory=list)
    settings: Dict[str, Any] = Field(default_factory=dict)

class ExamTemplateUpdate(BaseModel):
    template_name: Optional[str] = Field(None, max_length=200, min_length=1)
    exam_type: Optional[ExamType] = None
    subject_configs: Optional[List[Dict[str, Any]]] = None
    settings: Optional[Dict[str, Any]] = None

class ExamTemplateResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    template_name: str
    exam_type: ExamType
    subject_configs: List[Dict[str, Any]]
    settings: Dict[str, Any]
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ==================================================
# Exam Schedule Schemas
# ==================================================
class ExamScheduleCreate(BaseModel):
    class_id: uuid.UUID
    section_id: uuid.UUID
    subject_id: uuid.UUID
    teacher_subject_assignment_id: Optional[uuid.UUID] = None
    exam_date: date
    start_time: time
    end_time: time
    max_marks: int = Field(100, ge=1)
    pass_marks: int = Field(35, ge=1)
    room_number: Optional[str] = Field(None, max_length=50)

class ExamScheduleUpdate(BaseModel):
    exam_date: Optional[date] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    max_marks: Optional[int] = Field(None, ge=1)
    pass_marks: Optional[int] = Field(None, ge=1)
    room_number: Optional[str] = Field(None, max_length=50)

class ExamScheduleResponse(BaseModel):
    id: uuid.UUID
    exam_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    subject_id: uuid.UUID
    teacher_subject_assignment_id: Optional[uuid.UUID] = None
    exam_date: date
    start_time: time
    end_time: time
    max_marks: int
    pass_marks: int
    room_number: Optional[str] = None
    is_active: bool
    version: int
    subject_name: Optional[str] = None
    subject_code: Optional[str] = None
    class_name: Optional[str] = None
    section_name: Optional[str] = None
    exam_name: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


# ==================================================
# Examination Schemas
# ==================================================
class ExaminationCreate(BaseModel):
    school_id: uuid.UUID
    academic_year_id: Optional[uuid.UUID] = None
    exam_name: str = Field(..., max_length=200, min_length=1)
    exam_type: ExamType
    start_date: date
    end_date: date
    description: Optional[str] = None
    participating_class_ids: Optional[List[uuid.UUID]] = None
    settings: Dict[str, Any] = Field(default_factory=lambda: {
        "copied_from_template": False
    })
    ai_metrics: Dict[str, Any] = Field(default_factory=lambda: {
        "predicted_completion": None,
        "exam_complexity": None,
        "student_risk_prediction": None,
        "average_expected_score": None
    })

class ExaminationUpdate(BaseModel):
    exam_name: Optional[str] = Field(None, max_length=200, min_length=1)
    exam_type: Optional[ExamType] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    description: Optional[str] = None
    status: Optional[ExamStatus] = None
    participating_class_ids: Optional[List[uuid.UUID]] = None
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

class ExamStatusTransitionRequest(BaseModel):
    new_status: ExamStatus
    reason: Optional[str] = Field(None, max_length=500)
    is_administrative_override: bool = False

class ExaminationWizardCreate(BaseModel):
    school_id: uuid.UUID
    academic_year_id: Optional[uuid.UUID] = None
    exam_name: str = Field(..., max_length=200, min_length=1)
    exam_type: ExamType
    start_date: date
    end_date: date
    description: Optional[str] = None
    target_scope: str = Field(default="ALL_CLASSES") # ALL_CLASSES, SPECIFIC_CLASSES, SPECIFIC_SECTIONS
    class_ids: Optional[List[uuid.UUID]] = None
    section_ids: Optional[List[uuid.UUID]] = None
    participating_class_ids: Optional[List[uuid.UUID]] = None
    settings: Dict[str, Any] = Field(default_factory=lambda: {
        "copied_from_template": False
    })
    schedules: List[ExamScheduleCreate] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_targeting_and_dates(self) -> "ExaminationWizardCreate":
        if self.end_date < self.start_date:
            raise ValueError("end_date must be after start_date")
        if self.target_scope == "SPECIFIC_CLASSES":
            if not self.class_ids or len(self.class_ids) == 0:
                raise ValueError("class_ids must not be empty when target_scope is SPECIFIC_CLASSES")
        elif self.target_scope == "SPECIFIC_SECTIONS":
            if not self.section_ids or len(self.section_ids) == 0:
                raise ValueError("section_ids must not be empty when target_scope is SPECIFIC_SECTIONS")
        return self

class ExaminationCopyRequest(BaseModel):
    source_exam_id: uuid.UUID
    new_exam_name: str = Field(..., max_length=200, min_length=1)
    new_start_date: date
    new_end_date: date

class ExaminationResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    exam_name: str
    exam_type: ExamType
    start_date: date
    end_date: date
    status: ExamStatus
    description: Optional[str] = None
    participating_class_ids: List[uuid.UUID] = []
    settings: Dict[str, Any]
    ai_metrics: Dict[str, Any]
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None
    created_by: Optional[uuid.UUID] = None
    updated_by: Optional[uuid.UUID] = None
    
    schedules: List[ExamScheduleResponse] = []

    model_config = ConfigDict(from_attributes=True)


# ==================================================
# Bulk Timetable Generation Schemas
# ==================================================
class BulkTimetablePreviewRequest(BaseModel):
    school_id: uuid.UUID
    examination_id: uuid.UUID
    class_ids: List[uuid.UUID]
    section_ids: Optional[List[uuid.UUID]] = None
    subject_ids: Optional[List[uuid.UUID]] = None
    start_date: date
    gap_days: int = Field(1, ge=0, le=14)
    start_time: time = Field(default=time(9, 0))
    duration_minutes: int = Field(180, ge=30, le=360)
    exclude_weekends: bool = True
    max_marks: int = Field(100, ge=1)
    pass_marks: int = Field(35, ge=1)

class BulkTimetablePreviewItem(BaseModel):
    class_id: uuid.UUID
    class_name: str
    section_id: uuid.UUID
    section_name: str
    subject_id: uuid.UUID
    subject_name: str
    teacher_subject_assignment_id: Optional[uuid.UUID] = None
    exam_date: date
    start_time: time
    end_time: time
    max_marks: int
    pass_marks: int
    room_number: Optional[str] = None

class BulkTimetablePreviewResponse(BaseModel):
    total_slots: int
    schedules: List[BulkTimetablePreviewItem]

class BulkTimetableConfirmRequest(BaseModel):
    school_id: uuid.UUID
    examination_id: uuid.UUID
    schedules: List[ExamScheduleCreate]
