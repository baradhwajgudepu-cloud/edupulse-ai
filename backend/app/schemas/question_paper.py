import uuid
from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field

class ExtractedQuestionItem(BaseModel):
    id: Optional[uuid.UUID] = None
    question_number: str
    parent_question_id: Optional[uuid.UUID] = None
    section_name: Optional[str] = "Section A"
    sequence_order: int = 1
    question_text: Optional[str] = None
    max_marks: float = 5.0
    question_type: str = "SHORT" # MCQ, SHORT, LONG, NUMERICAL
    difficulty: str = "MEDIUM" # EASY, MEDIUM, HARD
    chapter_name: Optional[str] = None
    topic_name: Optional[str] = None
    syllabus_id: Optional[uuid.UUID] = None
    extraction_confidence: Optional[float] = 1.0
    mapping_confidence: Optional[float] = None
    mapping_source: Optional[str] = None # AI, MANUAL, TEACHER_REVIEWED
    review_status: str = "PENDING" # PENDING, VERIFIED, FLAGGED_FOR_REVIEW
    sub_questions: List["ExtractedQuestionItem"] = []

    model_config = ConfigDict(from_attributes=True)


class QuestionPaperResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    examination_id: uuid.UUID
    paper_id: uuid.UUID
    title: str
    total_marks: float
    total_questions: int
    sections_count: int
    source_file_name: Optional[str] = None
    source_file_type: Optional[str] = None
    storage_reference: Optional[str] = None
    processing_status: str
    verification_status: str
    verified_by: Optional[uuid.UUID] = None
    verified_at: Optional[datetime] = None
    ai_extraction_metadata: Dict[str, Any] = {}
    syllabus_coverage_metrics: Dict[str, Any] = {}
    questions: List[ExtractedQuestionItem] = []
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class QuestionPaperExtractionResponse(BaseModel):
    paper_id: uuid.UUID
    question_paper_id: uuid.UUID
    title: str
    detected_questions_count: int
    detected_maximum_marks: float
    detected_sections_count: int
    overall_confidence: float
    low_confidence_count: int
    verification_status: str
    questions: List[ExtractedQuestionItem] = []


class QuestionPaperVerifyRequest(BaseModel):
    title: Optional[str] = None
    total_marks: Optional[float] = None
    questions: List[ExtractedQuestionItem]
    mark_as_verified: bool = True


class QuestionSyllabusMapRequest(BaseModel):
    question_id: uuid.UUID
    syllabus_id: uuid.UUID
    chapter_name: Optional[str] = None
    topic_name: Optional[str] = None


class SyllabusTopicOption(BaseModel):
    syllabus_id: uuid.UUID
    unit_name: Optional[str] = None
    chapter_name: str
    topic_name: str
    estimated_periods: int = 4

    model_config = ConfigDict(from_attributes=True)


class StudentQuestionMarkEntry(BaseModel):
    question_id: uuid.UUID
    marks_obtained: float
    max_marks: float
    is_attempted: bool = True
    remarks: Optional[str] = None


class QuestionWiseStudentRow(BaseModel):
    student_id: uuid.UUID
    student_name: str
    admission_number: str
    roll_number: Optional[str] = None
    question_marks: Dict[str, float] = {} # question_id (str) -> marks_obtained
    total_obtained: float = 0.0
    max_marks: float = 100.0
    is_complete: bool = True
    result_status: str = "PRESENT" # PRESENT, ABSENT, MALPRACTICE, EXEMPTED
    remarks: Optional[str] = None


class QuestionWiseMarksMatrixResponse(BaseModel):
    paper_id: uuid.UUID
    exam_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    subject_id: uuid.UUID
    class_name: str
    section_name: str
    subject_name: str
    total_max_marks: float
    questions: List[ExtractedQuestionItem] = []
    rows: List[QuestionWiseStudentRow] = []
    mode: str = "QUESTION_WISE" # TOTAL_ONLY, QUESTION_WISE


class QuestionWiseMarksBatchSubmit(BaseModel):
    is_draft: bool = False
    rows: List[QuestionWiseStudentRow]


class QuestionWiseAnalyticsResponse(BaseModel):
    paper_id: uuid.UUID
    exam_id: uuid.UUID
    exam_name: str
    subject_name: str
    class_name: str
    total_students_assessed: int
    class_average_pct: float
    highest_score: float
    lowest_score: float
    pass_percentage: float
    has_question_data: bool
    data_sufficiency: str # NO_QUESTION_DATA, TOTAL_MARKS_ONLY, QUESTION_WISE_AVAILABLE
    message: str
    question_analytics: List[Dict[str, Any]] = []
    topic_analytics: List[Dict[str, Any]] = []
    chapter_analytics: List[Dict[str, Any]] = []
    syllabus_coverage: Dict[str, Any] = {}


class ExamDeletionImpactResponse(BaseModel):
    exam_id: uuid.UUID
    exam_name: str
    status: str
    papers_count: int
    results_count: int
    question_papers_count: int
    can_delete_direct: bool
    can_archive: bool
    can_permanent_delete: bool
    warning_message: str
    affected_summary: str


class ExamDeleteRequest(BaseModel):
    mode: str = Field("standard", description="standard, archive, permanent")
    confirmation_name: Optional[str] = Field(None, description="Must match examination name when mode is permanent")
