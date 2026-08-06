import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from app.models.marks import MarksStatus, ExamResult

# ==================================================
# Marks CRUD Schemas
# ==================================================
class MarksCreate(BaseModel):
    maximum_marks: int = Field(..., ge=1)
    marks_obtained: Optional[float] = Field(None, ge=0)
    result_status: ExamResult = ExamResult.PRESENT
    remarks: Optional[str] = Field(None, max_length=500)
    status: MarksStatus = MarksStatus.DRAFT
    grade: Optional[str] = Field(None, max_length=10)
    settings: Dict[str, Any] = Field(default_factory=lambda: {"bulk_entry": True})
    ai_metrics: Dict[str, Any] = Field(default_factory=lambda: {
        "predicted_grade": None,
        "class_average": None,
        "risk_level": "LOW"
    })
    
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    examination_id: uuid.UUID
    exam_schedule_id: uuid.UUID
    student_id: uuid.UUID
    teacher_subject_assignment_id: uuid.UUID
    teacher_id: uuid.UUID
    subject_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID

class MarksUpdate(BaseModel):
    marks_obtained: Optional[float] = Field(None, ge=0)
    result_status: Optional[ExamResult] = None
    remarks: Optional[str] = Field(None, max_length=500)
    status: Optional[MarksStatus] = None
    grade: Optional[str] = Field(None, max_length=10)
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

class MarksResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    examination_id: uuid.UUID
    exam_schedule_id: uuid.UUID
    student_id: uuid.UUID
    teacher_subject_assignment_id: uuid.UUID
    teacher_id: uuid.UUID
    subject_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    
    maximum_marks: int
    marks_obtained: Optional[float] = None
    result_status: ExamResult
    status: MarksStatus
    grade: Optional[str] = None
    remarks: Optional[str] = None
    settings: Dict[str, Any]
    ai_metrics: Dict[str, Any]
    audit_history: List[Dict[str, Any]]
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ==================================================
# Bulk Operations & Wizard Schemas
# ==================================================
class SingleMarkEntry(BaseModel):
    student_id: uuid.UUID
    marks_obtained: Optional[float] = Field(None, ge=0)
    result_status: ExamResult = ExamResult.PRESENT
    remarks: Optional[str] = Field(None, max_length=500)

class BulkMarksEntry(BaseModel):
    exam_schedule_id: uuid.UUID
    teacher_subject_assignment_id: uuid.UUID
    marks: List[SingleMarkEntry]

# ==================================================
# Smart Missing & Summaries Schemas
# ==================================================
class StudentShortInfo(BaseModel):
    id: uuid.UUID
    first_name: str
    last_name: str
    roll_number: str

class MarkWizardItem(BaseModel):
    student: StudentShortInfo
    mark_record: Optional[MarksResponse] = None
    is_missing: bool = True

class SmartMissingSummary(BaseModel):
    total_students: int
    entered_count: int
    missing_count: int
    average_score: Optional[float] = None
    highest_score: Optional[float] = None
    lowest_score: Optional[float] = None
    missing_students: List[StudentShortInfo] = []
    entries: List[MarkWizardItem] = []

class PublishSummaryResponse(BaseModel):
    exam_name: str
    subject_name: str
    class_name: str
    total_students: int
    entered_count: int
    missing_count: int
    pass_percentage: float

class ResultSummaryResponse(BaseModel):
    class_average: float
    pass_percentage: float
    highest_score: float
    lowest_score: float
    missing_count: int
    absent_count: int
