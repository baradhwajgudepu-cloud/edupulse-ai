import uuid
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field

# A. Student Insights
class StudentInsightRequest(BaseModel):
    student_id: uuid.UUID = Field(..., description="Student UUID to generate insights for.")

class StudentInsightResponse(BaseModel):
    performance_trend: str = Field(..., description="Academic performance trend (e.g. improving, declining).")
    attendance_trend: str = Field(..., description="Attendance trend and observations.")
    improvement_areas: List[str] = Field(..., description="Subject areas or skills to improve.")
    attention_areas: List[str] = Field(..., description="Critical areas needing immediate attention.")
    recent_academic_changes: Optional[str] = Field(None, description="Any recent changes in academic performance.")
    suggested_actions: List[str] = Field(..., description="Suggested actions for the teacher.")
    summary: str = Field(..., description="A detailed summary of the academic insight.")

# B. Class Performance Analysis
class ClassAnalysisRequest(BaseModel):
    class_id: uuid.UUID = Field(..., description="Class UUID.")
    section_id: uuid.UUID = Field(..., description="Section UUID.")
    subject_id: uuid.UUID = Field(..., description="Subject UUID.")

class ClassAnalysisResponse(BaseModel):
    class_average: float = Field(..., description="Class average percentage.")
    grade_distribution: Dict[str, int] = Field(..., description="Count of students per grade (e.g., A, B, C, D, F).")
    pass_percentage: float = Field(..., description="Percentage of students passing the assessments.")
    improvement_trend: str = Field(..., description="Overall trend of the class performance.")
    students_improving: List[str] = Field(..., description="Names of students showing noticeable academic progress.")
    students_declining: List[str] = Field(..., description="Names of students showing academic decline or needing intervention.")
    strong_areas: List[str] = Field(..., description="Topics or topics groups where the class performed well.")
    needs_reinforcement_areas: List[str] = Field(..., description="Topics needing reinforcement or revision.")
    suggested_actions: List[str] = Field(..., description="Suggested teaching interventions/actions.")

# C. AI Remark Generator
class RemarkGenerationRequest(BaseModel):
    student_id: uuid.UUID = Field(..., description="Student UUID.")
    subject_id: uuid.UUID = Field(..., description="Subject UUID to generate remarks for.")

class RemarkGenerationResponse(BaseModel):
    draft_remark: str = Field(..., description="The AI-generated draft remark for the student.")

# D. AI Homework / Question Generator
class HomeworkGenerationRequest(BaseModel):
    class_id: uuid.UUID = Field(..., description="Class UUID.")
    section_id: uuid.UUID = Field(..., description="Section UUID.")
    subject_id: uuid.UUID = Field(..., description="Subject UUID.")
    topic: str = Field(..., description="Topic of the homework.")
    difficulty: str = Field(..., description="Difficulty level (e.g. EASY, MEDIUM, HARD, MIXED).")
    number_of_questions: int = Field(..., description="Number of questions to generate.")
    marks: int = Field(..., description="Total marks for the homework.")
    question_type: Optional[str] = Field(None, description="Optional filter for question type (e.g. MCQ, SHORT, LONG).")

class QuestionsGenerationRequest(BaseModel):
    class_id: uuid.UUID = Field(..., description="Class UUID.")
    section_id: uuid.UUID = Field(..., description="Section UUID.")
    subject_id: uuid.UUID = Field(..., description="Subject UUID.")
    topic: str = Field(..., description="Topic of the questions.")
    difficulty: str = Field(..., description="Difficulty level (e.g. EASY, MEDIUM, HARD, MIXED).")
    number_of_questions: int = Field(..., description="Number of questions to generate.")
    marks: int = Field(..., description="Total marks for the questions.")
    question_type: Optional[str] = Field(None, description="Optional filter for question type (e.g. MCQ, SHORT, LONG).")

class GeneratedQuestion(BaseModel):
    text: str = Field(..., description="Question prompt text.")
    marks: int = Field(..., description="Marks allotted to this question.")
    difficulty: str = Field(..., description="Difficulty of the question.")
    choices: Optional[List[str]] = Field(None, description="Multiple choice options if applicable.")
    answer_key: Optional[str] = Field(None, description="Optional correct answer or answer explanation.")

class HomeworkGenerationResponse(BaseModel):
    title: str = Field(..., description="Suggested homework title.")
    description: str = Field(..., description="Homework instructions and description.")
    learning_objective: str = Field(..., description="Academic learning objective.")
    difficulty: str = Field(..., description="Difficulty level.")
    estimated_minutes: int = Field(..., description="Estimated time in minutes to complete.")
    questions: List[GeneratedQuestion] = Field(..., description="List of generated questions.")

class QuestionsGenerationResponse(BaseModel):
    questions: List[GeneratedQuestion] = Field(..., description="List of generated questions.")
