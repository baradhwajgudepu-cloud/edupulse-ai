import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from app.models.subject import SubjectStatus, SubjectCategory, SubjectType

class SubjectBase(BaseModel):
    subject_code: str = Field(..., min_length=1, max_length=50)
    subject_name: str = Field(..., min_length=1, max_length=150)
    short_name: Optional[str] = Field(None, max_length=50)
    category: SubjectCategory = Field(..., description="CORE, ELECTIVE, LANGUAGE, OPTIONAL, LAB, SPORTS, ARTS, CO_CURRICULAR")
    subject_type: SubjectType = Field(..., description="THEORY, PRACTICAL, THEORY_PRACTICAL")
    description: Optional[str] = Field(None, max_length=500)
    credit_hours: Optional[int] = Field(None, ge=0)
    weekly_periods: Optional[int] = Field(None, ge=0)
    
    theory_marks: Optional[int] = Field(0, ge=0)
    practical_marks: Optional[int] = Field(0, ge=0)
    pass_marks: Optional[int] = Field(0, ge=0)
    
    display_color: Optional[str] = Field(None, max_length=20, pattern=r"^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$", description="Hex color code (e.g. #FF5733)")
    display_order: Optional[int] = None
    
    settings: Dict[str, Any] = Field(default_factory=dict)
    ai_metrics: Dict[str, Any] = Field(default_factory=dict)

class SubjectCreate(SubjectBase):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID

class SubjectUpdate(BaseModel):
    subject_code: Optional[str] = Field(None, min_length=1, max_length=50)
    subject_name: Optional[str] = Field(None, min_length=1, max_length=150)
    short_name: Optional[str] = Field(None, max_length=50)
    category: Optional[SubjectCategory] = None
    subject_type: Optional[SubjectType] = None
    description: Optional[str] = Field(None, max_length=500)
    credit_hours: Optional[int] = Field(None, ge=0)
    weekly_periods: Optional[int] = Field(None, ge=0)
    
    theory_marks: Optional[int] = Field(None, ge=0)
    practical_marks: Optional[int] = Field(None, ge=0)
    pass_marks: Optional[int] = Field(None, ge=0)
    
    display_color: Optional[str] = Field(None, max_length=20, pattern=r"^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$")
    display_order: Optional[int] = None
    
    status: Optional[SubjectStatus] = None
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

class SubjectResponse(SubjectBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    status: SubjectStatus
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
