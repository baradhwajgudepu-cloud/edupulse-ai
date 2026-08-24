import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict

class SyllabusCreate(BaseModel):
    class_id: uuid.UUID
    subject_id: uuid.UUID
    syllabus_code: str = Field(..., max_length=50, min_length=1)
    unit_name: str = Field(..., max_length=150, min_length=1)
    chapter_name: str = Field(..., max_length=150, min_length=1)
    topic_name: str = Field(..., max_length=150, min_length=1)
    description: Optional[str] = None
    sequence_order: int = Field(1, ge=1)

class SyllabusUpdate(BaseModel):
    syllabus_code: Optional[str] = Field(None, max_length=50, min_length=1)
    unit_name: Optional[str] = Field(None, max_length=150, min_length=1)
    chapter_name: Optional[str] = Field(None, max_length=150, min_length=1)
    topic_name: Optional[str] = Field(None, max_length=150, min_length=1)
    description: Optional[str] = None
    sequence_order: Optional[int] = Field(None, ge=1)
    is_active: Optional[bool] = None

class SyllabusResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    subject_id: uuid.UUID
    syllabus_code: str
    unit_name: str
    chapter_name: str
    topic_name: str
    description: Optional[str] = None
    sequence_order: int
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
