import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from app.models.report_card import ReportCardStatus

# ==================================================
# Report Card Base & Action Request Schemas
# ==================================================
class ReportCardGenerateRequest(BaseModel):
    student_id: uuid.UUID
    school_id: uuid.UUID
    settings: Dict[str, Any] = Field(default_factory=lambda: {
        "generated_from_live_data": True,
        "show_attendance": True,
        "language": "en"
    })
    teacher_remarks: Optional[str] = Field(None, max_length=500)

class ReportCardClassGenerateRequest(BaseModel):
    class_id: uuid.UUID
    section_id: uuid.UUID
    school_id: uuid.UUID
    settings: Dict[str, Any] = Field(default_factory=lambda: {
        "generated_from_live_data": True,
        "show_attendance": True,
        "language": "en"
    })

# ==================================================
# Database Entity Response Schema
# ==================================================
class ReportCardResponse(BaseModel):
    id: uuid.UUID
    verification_uuid: uuid.UUID
    status: ReportCardStatus
    pdf_url: Optional[str] = None
    pdf_history: List[Dict[str, Any]]
    generated_at: Optional[datetime] = None
    published_at: Optional[datetime] = None
    approved_at: Optional[datetime] = None
    generated_by: Optional[uuid.UUID] = None
    published_by: Optional[uuid.UUID] = None
    approved_by: Optional[uuid.UUID] = None
    settings: Dict[str, Any]
    ai_metrics: Dict[str, Any]
    is_active: bool
    version: int
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    student_id: uuid.UUID
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

# ==================================================
# Dynamic Preview & Summary Schemas
# ==================================================
class ReportCardSubjectMarkRow(BaseModel):
    subject_name: str
    maximum_marks: int
    marks_obtained: Optional[float] = None
    result_status: str
    grade: str
    remarks: Optional[str] = None

class ReportCardPreviewResponse(BaseModel):
    student_id: uuid.UUID
    student_name: str
    admission_number: str
    roll_number: str
    class_name: str
    section_name: str
    
    attendance_total: int
    attendance_present: int
    attendance_percentage: float
    
    overall_percentage: float
    overall_grade: str
    promotion_status: str
    
    subject_marks: List[ReportCardSubjectMarkRow]
    teacher_remarks: Optional[str] = None
    principal_remarks: Optional[str] = None
    ai_narrative: str
    
    is_valid: bool = True
    missing_reasons: List[str] = []

# ==================================================
# Bulk Class Action Response
# ==================================================
class StudentFailureDetail(BaseModel):
    student_id: uuid.UUID
    student_name: str
    reasons: List[str]

class BulkClassGenerateResponse(BaseModel):
    total_students: int
    generated_count: int
    failed_count: int
    failures: List[StudentFailureDetail] = []

# ==================================================
# Verification Response Schema
# ==================================================
class VerificationResponse(BaseModel):
    student_name: str
    roll_number: str
    class_name: str
    section_name: str
    academic_year: str
    status: ReportCardStatus
    verification_date: datetime
    generated_at: Optional[datetime] = None
    published_at: Optional[datetime] = None
    pdf_url: Optional[str] = None
