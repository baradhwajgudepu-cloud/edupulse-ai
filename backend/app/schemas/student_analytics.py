import uuid
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field

class TrendPoint(BaseModel):
    label: str
    value: float
    model_config = ConfigDict(from_attributes=True)

class ExamTrendPoint(BaseModel):
    label: str
    value: float
    tooltip_detail: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)

class SubjectScorePoint(BaseModel):
    subject: str
    score: float
    grade: Optional[str] = None
    strong: bool = False
    needs_support: bool = False
    model_config = ConfigDict(from_attributes=True)

class ExamSummaryItem(BaseModel):
    examination_name: str
    exam_type: str
    exam_date: str
    total_max_marks: float
    total_obtained_marks: float
    percentage: float
    grade: str
    status: str
    model_config = ConfigDict(from_attributes=True)

class Student360Attendance(BaseModel):
    has_data: bool = False
    attendance_rate: Optional[float] = None
    total_days: int = 0
    present_days: int = 0
    absent_days: int = 0
    late_days: int = 0
    leave_days: int = 0
    working_days: int = 0
    monthly_trend: List[TrendPoint] = Field(default_factory=list)
    model_config = ConfigDict(from_attributes=True)

class Student360Academics(BaseModel):
    has_data: bool = False
    academic_average: Optional[float] = None
    current_score: Optional[float] = None
    overall_grade: Optional[str] = None
    class_rank: Optional[str] = None
    section_rank: Optional[str] = None
    completed_examinations: List[ExamSummaryItem] = Field(default_factory=list)
    exam_trends: List[ExamTrendPoint] = Field(default_factory=list)
    subject_scores: List[SubjectScorePoint] = Field(default_factory=list)
    model_config = ConfigDict(from_attributes=True)

class Student360Fees(BaseModel):
    has_data: bool = False
    total_assigned: float = 0.0
    total_paid: float = 0.0
    balance_outstanding: float = 0.0
    paid_percentage: Optional[float] = None
    status: str = "No fee records"
    model_config = ConfigDict(from_attributes=True)

class Student360AiAnalysis(BaseModel):
    has_data: bool = False
    data_state: str = "NO_DATA"  # NO_DATA, PARTIAL_DATA, SUFFICIENT_DATA
    trend: Optional[str] = None
    headline: Optional[str] = None
    insight: Optional[str] = None
    strong_highlights: List[str] = Field(default_factory=list)
    support_highlights: List[str] = Field(default_factory=list)
    action_recommendation: Optional[str] = None
    status_message: Optional[str] = "Insufficient data for AI analysis"
    model_config = ConfigDict(from_attributes=True)

class HomeworkItem(BaseModel):
    title: str
    subject: str
    status: str
    date: str
    model_config = ConfigDict(from_attributes=True)

class StudentActivityLogItem(BaseModel):
    time: str
    event: str
    by: str
    model_config = ConfigDict(from_attributes=True)

class Student360ReportCard(BaseModel):
    id: uuid.UUID
    title: str
    status: str
    generated_date: Optional[str] = None
    published_date: Optional[str] = None
    is_available: bool = True
    pdf_url: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)

class StudentAnalyticsResponse(BaseModel):
    student_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: Optional[uuid.UUID] = None
    attendance: Student360Attendance
    academics: Student360Academics
    fees: Student360Fees
    ai_analysis: Student360AiAnalysis
    homework: List[HomeworkItem] = Field(default_factory=list)
    activity_logs: List[StudentActivityLogItem] = Field(default_factory=list)
    reports: List[Student360ReportCard] = Field(default_factory=list)
    model_config = ConfigDict(from_attributes=True)
