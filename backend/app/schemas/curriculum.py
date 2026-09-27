import uuid
from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field

class CurriculumMasterItemRead(BaseModel):
    id: uuid.UUID
    item_code: str
    unit_name: str
    chapter_name: str
    topic_name: str
    description: Optional[str] = None
    sequence_order: int
    estimated_periods: int = 4
    learning_outcomes: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class CurriculumMasterRead(BaseModel):
    id: uuid.UUID
    board: str
    state: Optional[str] = None
    academic_year_code: str
    class_level: int
    class_name: str
    subject_code: str
    subject_name: str
    source: str
    source_version: str
    verification_status: str
    is_active: bool
    items: List[CurriculumMasterItemRead] = []

    model_config = ConfigDict(from_attributes=True)

class CurriculumPopulateRequest(BaseModel):
    school_id: Optional[uuid.UUID] = None
    academic_year_id: Optional[uuid.UUID] = None
    board: Optional[str] = Field(None, description="e.g. CBSE, ICSE, SSC, STATE, IB")
    state: Optional[str] = None
    class_ids: Optional[List[uuid.UUID]] = None
    subject_ids: Optional[List[uuid.UUID]] = None
    override_existing: bool = False

class CurriculumPopulateResponse(BaseModel):
    success: bool
    board: str
    cloned_count: int
    available: bool
    message: str
    details: Optional[Dict[str, Any]] = None

class CurriculumStatusRead(BaseModel):
    is_populated: bool = False
    verified_curriculum_available: bool = False
    board: str = "Not Configured"
    state: Optional[str] = None
    academic_year_name: Optional[str] = None
    source: Optional[str] = None
    source_version: Optional[str] = None
    verification_status: Optional[str] = None
    derived_from: Optional[str] = None
    total_subjects_with_syllabus: int = 0
    total_chapters: int = 0
    total_topics: int = 0
    status_badge: str = "UNAVAILABLE"
    message: str = ""

class CurriculumPopulateResultRead(BaseModel):
    success: bool = False
    message: str = ""
    board: str = ""
    state: Optional[str] = None
    academic_year_name: str = ""
    total_classes_processed: int = 0
    total_subjects_matched: int = 0
    total_chapters_populated: int = 0
    total_topics_populated: int = 0
    source: str = ""
    source_version: str = ""
    verification_status: str = "VERIFIED"

class CurriculumDerivePreviousRequest(BaseModel):
    source_academic_year_id: uuid.UUID
    target_academic_year_id: uuid.UUID
    class_ids: Optional[List[uuid.UUID]] = None


class SyllabusImportItem(BaseModel):
    syllabus_code: str
    unit_name: str
    chapter_name: str
    topic_name: str
    description: Optional[str] = None
    sequence_order: int = 1
    estimated_periods: int = 4
    lifecycle_status: str = "PLANNED"

class SyllabusImportRequest(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    subject_id: uuid.UUID
    items: List[SyllabusImportItem]

class CurriculumResolveSubject(BaseModel):
    subject_name: str
    units: List[str] = []

class CurriculumResolveResponse(BaseModel):
    verified_available: bool = False
    board: Optional[str] = None
    state: Optional[str] = None
    academic_year: Optional[str] = None
    source: Optional[str] = None
    verification_status: Optional[str] = None
    subjects: List[CurriculumResolveSubject] = []
    message: Optional[str] = None

class CustomChapterRequest(BaseModel):
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    subject_id: uuid.UUID
    unit_name: str
    chapter_name: str
    topic_name: str
    description: Optional[str] = None
    sequence_order: int = 1
    estimated_periods: int = 4

class AIDraftSyllabusTopic(BaseModel):
    unit_name: str
    chapter_name: str
    topic_name: str
    description: Optional[str] = None
    sequence_order: int = 1
    estimated_periods: int = 4

class AIDraftSyllabusRequest(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    subject_id: uuid.UUID
    num_units: Optional[int] = Field(2, ge=1, le=10)
    chapters_per_unit: Optional[int] = Field(2, ge=1, le=6)

class AIDraftSyllabusResponse(BaseModel):
    subject_id: uuid.UUID
    subject_name: str
    class_id: uuid.UUID
    class_name: str
    is_ai_draft: bool = True
    status: str = "AI GENERATED DRAFT"
    disclaimer: str = (
        "AI GENERATED DRAFT: This draft syllabus is generated for school-specific curriculum planning. "
        "It is NOT officially prescribed by CBSE, ICSE, or State Board. Administrator review and approval required."
    )
    topics: List[AIDraftSyllabusTopic] = []

class AIDraftSyllabusApproveRequest(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    subject_id: uuid.UUID
    topics: List[AIDraftSyllabusTopic]


