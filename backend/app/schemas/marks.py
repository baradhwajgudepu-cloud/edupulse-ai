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


class SingleMarkEntry(BaseModel):
    student_id: uuid.UUID
    marks_obtained: Optional[float] = Field(None, ge=0)
    result_status: ExamResult = ExamResult.PRESENT
    remarks: Optional[str] = Field(None, max_length=500)
    override_reason: Optional[str] = Field(None, max_length=500)
    status: Optional[MarksStatus] = None
    version: Optional[int] = None

class BulkMarksEntry(BaseModel):
    exam_schedule_id: uuid.UUID
    teacher_subject_assignment_id: Optional[uuid.UUID] = None
    marks: List[SingleMarkEntry]

class LockUnlockRequest(BaseModel):
    exam_schedule_id: uuid.UUID
    reason: Optional[str] = Field(None, max_length=500)

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

# ==================================================
# Workflow Review & Approval Schemas
# ==================================================
class MarksSubmitForReviewRequest(BaseModel):
    exam_schedule_id: uuid.UUID
    teacher_subject_assignment_id: Optional[uuid.UUID] = None
    notes: Optional[str] = Field(None, max_length=500)
    allow_partial: Optional[bool] = False

class MarksApprovalRequest(BaseModel):
    exam_schedule_id: uuid.UUID
    remarks: Optional[str] = Field(None, max_length=500)

class MarksReturnRequest(BaseModel):
    exam_schedule_id: uuid.UUID
    correction_reason: str = Field(..., min_length=3, max_length=500)

class MarksReviewQueueItem(BaseModel):
    exam_schedule_id: uuid.UUID
    examination_id: uuid.UUID
    exam_name: str
    class_id: uuid.UUID
    class_name: str
    section_id: uuid.UUID
    section_name: str
    subject_id: uuid.UUID
    subject_name: str
    teacher_id: Optional[uuid.UUID] = None
    teacher_name: Optional[str] = None
    exam_date: str
    max_marks: int
    pass_marks: int
    total_students: int
    entered_count: int
    missing_count: int
    pass_count: int
    fail_count: int
    absent_count: int
    average_score: Optional[float] = None
    highest_score: Optional[float] = None
    lowest_score: Optional[float] = None
    pass_percentage: float
    batch_status: MarksStatus
    last_submitted_at: Optional[datetime] = None
    correction_reason: Optional[str] = None

# ==================================================
# Parent Academics & Results Schemas
# ==================================================
class ParentSubjectMarkItem(BaseModel):
    subject_id: uuid.UUID
    subject_name: str
    subject_code: Optional[str] = None
    exam_date: Optional[str] = None
    maximum_marks: int
    pass_marks: int
    marks_obtained: Optional[float] = None
    result_status: ExamResult
    grade: Optional[str] = None
    remarks: Optional[str] = None
    is_passed: bool

class ParentExamResultResponse(BaseModel):
    examination_id: uuid.UUID
    exam_name: str
    exam_type: str
    academic_year_name: str
    student_id: uuid.UUID
    student_name: str
    roll_number: Optional[str] = None
    class_name: str
    section_name: str
    total_max_marks: int
    total_obtained_marks: float
    overall_percentage: float
    overall_grade: Optional[str] = None
    status: str
    subject_marks: List[ParentSubjectMarkItem]

class ParentTimetableSlot(BaseModel):
    exam_schedule_id: uuid.UUID
    examination_id: uuid.UUID
    exam_name: str
    exam_type: str
    subject_id: uuid.UUID
    subject_name: str
    exam_date: str
    start_time: str
    end_time: str
    max_marks: int
    pass_marks: int
    room_number: Optional[str] = None

class ParentReportCardItem(BaseModel):
    report_card_id: uuid.UUID
    examination_id: uuid.UUID
    exam_name: str
    academic_year_name: str
    status: str
    total_marks: float
    percentage: float
    grade: Optional[str] = None
    rank: Optional[int] = None
    generated_at: Optional[datetime] = None
    pdf_download_url: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class MarksExcelUploadSummary(BaseModel):
    total_rows: int
    matched_students: int
    saved_count: int
    errors: List[str] = Field(default_factory=list)
    marks: List[MarksResponse] = Field(default_factory=list)

# ==================================================
# Exam-Wide Bulk Upload Schemas
# ==================================================
class ExamWideUploadRowPreview(BaseModel):
    row_number: int
    class_name: str
    section_name: str
    roll_number: str
    student_name: Optional[str] = None
    subject_name: str
    max_marks: int
    marks_obtained: Optional[float] = None
    status: str = "PRESENT"
    remarks: Optional[str] = None
    is_valid: bool = True
    error_message: Optional[str] = None
    student_id: Optional[str] = None
    exam_schedule_id: Optional[str] = None
    class_id: Optional[str] = None
    section_id: Optional[str] = None
    subject_id: Optional[str] = None

class ExamWideUploadPreviewResponse(BaseModel):
    total_rows: int
    valid_rows_count: int
    invalid_rows_count: int
    classes_detected: List[str]
    sections_detected: List[str]
    subjects_detected: List[str]
    students_count: int
    errors: List[str] = Field(default_factory=list)
    preview_rows: List[ExamWideUploadRowPreview] = Field(default_factory=list)

class ExamWideUploadConfirmRequest(BaseModel):
    exam_id: uuid.UUID
    school_id: uuid.UUID
    rows: List[ExamWideUploadRowPreview]
    auto_approve: bool = False

class ExamWideUploadSummary(BaseModel):
    examination_id: uuid.UUID
    examination_name: str
    students_processed: int
    classes_count: int
    sections_count: int
    subjects_count: int
    total_records: int
    saved_count: int
    failed_count: int

class ExaminationPublishSummary(BaseModel):
    examination_id: uuid.UUID
    examination_name: str
    total_expected_records: int
    marks_entered_count: int
    published_count: int
    missing_count: int
    is_fully_published: bool
    missing_breakdown: List[Dict[str, Any]] = Field(default_factory=list)
