import uuid
from datetime import date, time, datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models.examination import ExamStatus, ExamType

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
    teacher_subject_assignment_id: uuid.UUID
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
    teacher_subject_assignment_id: uuid.UUID
    exam_date: date
    start_time: time
    end_time: time
    max_marks: int
    pass_marks: int
    room_number: Optional[str] = None
    is_active: bool
    version: int

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
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

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
