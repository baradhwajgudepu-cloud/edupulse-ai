import uuid
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
from app.schemas.teacher import TeacherResponse


class Teacher360Overview(BaseModel):
    total_classes: int = 0
    total_sections: int = 0
    weekly_periods: int = 0
    primary_subjects: List[str] = Field(default_factory=list)
    class_teacher_of: List[str] = Field(default_factory=list)
    syllabus_completion_rate: float = 0.0
    expected_syllabus_rate: float = 0.0
    syllabus_pace_variance: float = 0.0
    syllabus_pace_status: str = "ON_TRACK"
    marks_submission_rate: float = 0.0
    attendance_rate: Optional[float] = None
    active_students_taught: int = 0


class TeacherClassAssignmentItem(BaseModel):
    assignment_id: uuid.UUID
    class_id: uuid.UUID
    class_name: str
    section_id: uuid.UUID
    section_name: str
    subject_id: uuid.UUID
    subject_name: str
    subject_code: Optional[str] = None
    assignment_type: str = "PRIMARY"
    weekly_periods: int = 0
    workload_percentage: float = 0.0
    student_count: int = 0
    is_class_teacher: bool = False
    room_number: Optional[str] = None
    priority: Optional[int] = 1


class TeacherSyllabusTopic(BaseModel):
    id: uuid.UUID
    syllabus_code: str
    unit_name: str
    chapter_name: str
    topic_name: str
    sequence_order: int
    estimated_periods: int
    coverage_status: str = "PENDING"
    completed_at: Optional[str] = None
    is_expected_by_now: bool = False


class TeacherSyllabusSubjectProgress(BaseModel):
    class_id: uuid.UUID
    class_name: str
    section_id: uuid.UUID
    section_name: str
    subject_id: uuid.UUID
    subject_name: str
    total_topics: int = 0
    completed_topics: int = 0
    expected_topics_by_now: int = 0
    actual_completion_percentage: float = 0.0
    expected_completion_percentage: float = 0.0
    pace_variance: float = 0.0
    pace_status: str = "ON_TRACK"  # ON_TRACK, AHEAD, SLIGHTLY_BEHIND, BEHIND
    topics: List[TeacherSyllabusTopic] = Field(default_factory=list)


class TeacherTimetableSlot(BaseModel):
    id: uuid.UUID
    day_of_week: str
    period_number: int
    start_time: str
    end_time: str
    period_type: str = "REGULAR"
    subject_name: Optional[str] = None
    class_name: Optional[str] = None
    section_name: Optional[str] = None
    room_number: Optional[str] = None
    is_active: bool = True


class TeacherAttendanceSummary(BaseModel):
    has_data: bool = False
    attendance_rate: Optional[float] = None
    present_days: int = 0
    absent_days: int = 0
    leave_days: int = 0
    total_recorded_days: int = 0
    monthly_trend: List[Dict[str, Any]] = Field(default_factory=list)
    recent_logs: List[Dict[str, Any]] = Field(default_factory=list)


class TeacherHomeworkItem(BaseModel):
    id: uuid.UUID
    title: str
    class_name: str
    section_name: str
    subject_name: str
    assigned_date: str
    due_date: str
    submission_count: int = 0
    total_students: int = 0
    status: str = "ACTIVE"


class TeacherExamComplianceItem(BaseModel):
    exam_id: uuid.UUID
    exam_name: str
    exam_type: str
    exam_date: str
    class_name: str
    section_name: str
    subject_name: str
    total_students: int = 0
    marks_entered_count: int = 0
    marks_pending_count: int = 0
    compliance_percentage: float = 0.0
    status: str = "PENDING"  # COMPLETED, PARTIAL, PENDING


class SubjectWorkloadItem(BaseModel):
    subject_name: str
    weekly_periods: int
    percentage: float


class ClassWorkloadItem(BaseModel):
    class_name: str
    weekly_periods: int
    percentage: float


class TeacherWorkloadSummary(BaseModel):
    weekly_period_capacity: int = 30
    assigned_weekly_periods: int = 0
    utilization_rate: float = 0.0
    subject_distribution: List[SubjectWorkloadItem] = Field(default_factory=list)
    class_distribution: List[ClassWorkloadItem] = Field(default_factory=list)


class Teacher360Response(BaseModel):
    teacher: TeacherResponse
    overview: Teacher360Overview
    assignments: List[TeacherClassAssignmentItem] = Field(default_factory=list)
    syllabus_progress: List[TeacherSyllabusSubjectProgress] = Field(default_factory=list)
    timetable: List[TeacherTimetableSlot] = Field(default_factory=list)
    attendance: TeacherAttendanceSummary
    homework: List[TeacherHomeworkItem] = Field(default_factory=list)
    exam_compliance: List[TeacherExamComplianceItem] = Field(default_factory=list)
    workload: TeacherWorkloadSummary
