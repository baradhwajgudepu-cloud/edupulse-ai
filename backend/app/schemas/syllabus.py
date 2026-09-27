import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, ConfigDict

class SyllabusCreate(BaseModel):
    class_id: uuid.UUID
    subject_id: uuid.UUID
    section_id: Optional[uuid.UUID] = None
    syllabus_code: str = Field(..., max_length=50, min_length=1)
    unit_name: str = Field(..., max_length=150, min_length=1)
    chapter_name: str = Field(..., max_length=150, min_length=1)
    topic_name: str = Field(..., max_length=150, min_length=1)
    description: Optional[str] = None
    sequence_order: int = Field(1, ge=1)
    estimated_periods: int = Field(4, ge=1)
    coverage_status: str = Field("PENDING", description="PENDING, ONGOING, or COMPLETED")
    lifecycle_status: str = Field("PLANNED", description="PLANNED, IN_PROGRESS, COMPLETED, DEFERRED, REOPENED")

class SyllabusUpdate(BaseModel):
    section_id: Optional[uuid.UUID] = None
    syllabus_code: Optional[str] = Field(None, max_length=50, min_length=1)
    unit_name: Optional[str] = Field(None, max_length=150, min_length=1)
    chapter_name: Optional[str] = Field(None, max_length=150, min_length=1)
    topic_name: Optional[str] = Field(None, max_length=150, min_length=1)
    description: Optional[str] = None
    sequence_order: Optional[int] = Field(None, ge=1)
    estimated_periods: Optional[int] = Field(None, ge=1)
    is_active: Optional[bool] = None
    coverage_status: Optional[str] = None
    lifecycle_status: Optional[str] = None
    completed_at: Optional[datetime] = None

class SyllabusCoverageUpdate(BaseModel):
    coverage_status: str = Field(..., description="PENDING, ONGOING, or COMPLETED")

class SyllabusReorderItem(BaseModel):
    id: uuid.UUID
    sequence_order: int = Field(..., ge=1)

class SyllabusReorderRequest(BaseModel):
    items: List[SyllabusReorderItem]

class SyllabusResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    subject_id: uuid.UUID
    section_id: Optional[uuid.UUID] = None
    syllabus_code: str
    unit_name: str
    chapter_name: str
    topic_name: str
    description: Optional[str] = None
    sequence_order: int
    estimated_periods: int = 4
    coverage_status: str = "PENDING"
    lifecycle_status: str = "PLANNED"
    completed_at: Optional[datetime] = None
    curriculum_master_id: Optional[uuid.UUID] = None
    source: Optional[str] = None
    source_version: Optional[str] = None
    verification_status: Optional[str] = "VERIFIED"
    derived_from: Optional[str] = None
    is_custom: bool = False
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

class TopicCreateRequest(BaseModel):
    class_id: uuid.UUID
    subject_id: uuid.UUID
    section_id: Optional[uuid.UUID] = None
    unit_name: str = Field(..., max_length=150, min_length=1)
    chapter_name: str = Field(..., max_length=150, min_length=1)
    topic_name: str = Field(..., max_length=150, min_length=1)
    estimated_periods: int = Field(3, ge=1, le=50)
    description: Optional[str] = None
    sequence_order: Optional[int] = None

class ChapterCreateRequest(BaseModel):
    class_id: uuid.UUID
    subject_id: uuid.UUID
    section_id: Optional[uuid.UUID] = None
    unit_name: str = Field(..., max_length=150, min_length=1)
    chapter_name: str = Field(..., max_length=150, min_length=1)
    initial_topic_name: Optional[str] = None
    estimated_periods: int = Field(4, ge=1, le=50)
    description: Optional[str] = None

class UnitCreateRequest(BaseModel):
    class_id: uuid.UUID
    subject_id: uuid.UUID
    section_id: Optional[uuid.UUID] = None
    unit_name: str = Field(..., max_length=150, min_length=1)
    initial_chapter_name: Optional[str] = None
    initial_topic_name: Optional[str] = None
    estimated_periods: int = Field(4, ge=1, le=50)

class UnitRenameRequest(BaseModel):
    class_id: uuid.UUID
    subject_id: uuid.UUID
    old_unit_name: str = Field(..., min_length=1, max_length=150)
    new_unit_name: str = Field(..., min_length=1, max_length=150)

class UnitDeleteRequest(BaseModel):
    class_id: uuid.UUID
    subject_id: uuid.UUID
    unit_name: str = Field(..., min_length=1, max_length=150)

class ChapterUpdateRequest(BaseModel):
    class_id: uuid.UUID
    subject_id: uuid.UUID
    unit_name: Optional[str] = Field(None, max_length=150)
    old_chapter_name: str = Field(..., min_length=1, max_length=150)
    new_chapter_name: str = Field(..., min_length=1, max_length=150)
    estimated_periods: Optional[int] = Field(None, ge=1)
    lifecycle_status: Optional[str] = None
    remarks: Optional[str] = None

class ChapterDeleteRequest(BaseModel):
    class_id: uuid.UUID
    subject_id: uuid.UUID
    unit_name: Optional[str] = None
    chapter_name: str = Field(..., min_length=1, max_length=150)

class ClassSubjectDeleteRequest(BaseModel):
    class_id: uuid.UUID
    subject_id: uuid.UUID

class SyllabusCoverageProgressUpdate(BaseModel):
    status: str = Field(..., description="PLANNED, IN_PROGRESS, COMPLETED, DEFERRED, REOPENED")
    completion_percentage: float = Field(0.0, ge=0.0, le=100.0)
    completed_at: Optional[datetime] = None
    started_at: Optional[datetime] = None
    remarks: Optional[str] = None

class SyllabusCoverageProgressRead(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    subject_id: uuid.UUID
    syllabus_id: uuid.UUID
    teacher_id: Optional[uuid.UUID] = None
    status: str
    completion_percentage: float
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    remarks: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class ChapterCoverageItem(BaseModel):
    chapter_name: str
    total_topics: int
    completed_topics: int
    ongoing_topics: int
    pending_topics: int
    coverage_percentage: float
    estimated_periods: int = 0
    planned_periods: int = 0
    completed_periods: int = 0
    lifecycle_status: str = "PLANNED"

class SubjectCoverageSummary(BaseModel):
    subject_id: uuid.UUID
    subject_name: str
    class_id: uuid.UUID
    class_name: str
    section_id: Optional[uuid.UUID] = None
    section_name: Optional[str] = None
    total_topics: int
    completed_topics: int
    ongoing_topics: int
    pending_topics: int
    coverage_percentage: float
    total_estimated_periods: int = 0
    planned_periods: int = 0
    completed_periods: int = 0
    weekly_timetable_periods: int = 0
    chapters: List[ChapterCoverageItem] = Field(default_factory=list)

