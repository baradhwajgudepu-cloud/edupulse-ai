import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from app.models.subject import SubjectStatus, SubjectCategory, SubjectType

class SubjectBase(BaseModel):
    subject_code: str = Field(..., min_length=1, max_length=50)
    subject_name: str = Field(..., min_length=1, max_length=150)
    short_name: Optional[str] = Field(None, max_length=50)
    category: SubjectCategory = Field(..., description="CORE, ADDITIONAL, ELECTIVE, REMEDIAL, LANGUAGE, SKILL, OPTIONAL, LAB, SPORTS, ARTS, CO_CURRICULAR, VOCATIONAL, OTHER")
    subject_type: SubjectType = Field(..., description="THEORY, PRACTICAL, THEORY_PRACTICAL")
    source_type: Optional[str] = Field("BOARD_OFFICIAL", description="BOARD_OFFICIAL or SCHOOL_ADDED")
    description: Optional[str] = Field(None, max_length=500)
    credit_hours: Optional[int] = Field(None, ge=0)
    weekly_periods: Optional[int] = Field(None, ge=0)
    
    theory_marks: Optional[int] = Field(0, ge=0)
    practical_marks: Optional[int] = Field(0, ge=0)
    pass_marks: Optional[int] = Field(0, ge=0)
    
    # Assessment & Report Card policies
    is_examination_applicable: Optional[bool] = Field(True, description="Whether examinations apply")
    is_marks_applicable: Optional[bool] = Field(True, description="Whether marks entry applies")
    max_marks: Optional[int] = Field(100, ge=0)
    appears_in_report_card: Optional[bool] = Field(True, description="Appears in student report card")
    included_in_consolidated_result: Optional[bool] = Field(True, description="Included in consolidated results")
    included_in_rank_calculation: Optional[bool] = Field(True, description="Included in student rank calculation")

    display_color: Optional[str] = Field(None, max_length=20, pattern=r"^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$", description="Hex color code (e.g. #FF5733)")
    display_order: Optional[int] = None
    
    settings: Dict[str, Any] = Field(default_factory=dict)
    ai_metrics: Dict[str, Any] = Field(default_factory=dict)

class SubjectCreate(SubjectBase):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    source_type: Optional[str] = Field("SCHOOL_ADDED", description="Default SCHOOL_ADDED for custom subjects")

class SubjectUpdate(BaseModel):
    subject_code: Optional[str] = Field(None, min_length=1, max_length=50)
    subject_name: Optional[str] = Field(None, min_length=1, max_length=150)
    short_name: Optional[str] = Field(None, max_length=50)
    category: Optional[SubjectCategory] = None
    subject_type: Optional[SubjectType] = None
    source_type: Optional[str] = None
    description: Optional[str] = Field(None, max_length=500)
    credit_hours: Optional[int] = Field(None, ge=0)
    weekly_periods: Optional[int] = Field(None, ge=0)
    
    theory_marks: Optional[int] = Field(None, ge=0)
    practical_marks: Optional[int] = Field(None, ge=0)
    pass_marks: Optional[int] = Field(None, ge=0)
    
    is_examination_applicable: Optional[bool] = None
    is_marks_applicable: Optional[bool] = None
    max_marks: Optional[int] = None
    appears_in_report_card: Optional[bool] = None
    included_in_consolidated_result: Optional[bool] = None
    included_in_rank_calculation: Optional[bool] = None

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
    source_type: str = "BOARD_OFFICIAL"
    is_examination_applicable: bool = True
    is_marks_applicable: bool = True
    max_marks: int = 100
    appears_in_report_card: bool = True
    included_in_consolidated_result: bool = True
    included_in_rank_calculation: bool = True
    status: SubjectStatus
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
