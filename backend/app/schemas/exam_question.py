import uuid
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field

from app.models.exam_question import QuestionDifficulty, QuestionType

class ExamQuestionBase(BaseModel):
    question_number: str = Field(..., max_length=20, description="e.g. Q1, 1, 2a")
    question_text: Optional[str] = Field(None, description="Optional question text/prompt")
    max_marks: float = Field(..., gt=0, description="Maximum marks allocated for this question")
    chapter_name: str = Field(..., max_length=150, description="Mapped syllabus chapter name")
    topic_name: Optional[str] = Field(None, max_length=150, description="Mapped syllabus topic name")
    difficulty: QuestionDifficulty = Field(default=QuestionDifficulty.MEDIUM)
    question_type: QuestionType = Field(default=QuestionType.SHORT)
    syllabus_id: Optional[uuid.UUID] = Field(None, description="Optional foreign key to syllabus topic")
    exam_schedule_id: Optional[uuid.UUID] = Field(None, description="Optional exam schedule paper ID")

class ExamQuestionCreate(ExamQuestionBase):
    subject_id: uuid.UUID

class ExamQuestionBulkCreate(BaseModel):
    subject_id: uuid.UUID
    academic_year_id: Optional[uuid.UUID] = None
    questions: List[ExamQuestionBase]

class ExamQuestionUpdate(BaseModel):
    question_number: Optional[str] = Field(None, max_length=20)
    question_text: Optional[str] = None
    max_marks: Optional[float] = Field(None, gt=0)
    chapter_name: Optional[str] = Field(None, max_length=150)
    topic_name: Optional[str] = Field(None, max_length=150)
    difficulty: Optional[QuestionDifficulty] = None
    question_type: Optional[QuestionType] = None
    syllabus_id: Optional[uuid.UUID] = None
    exam_schedule_id: Optional[uuid.UUID] = None

class ExamQuestionResponse(ExamQuestionBase):
    id: uuid.UUID
    examination_id: uuid.UUID
    subject_id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
