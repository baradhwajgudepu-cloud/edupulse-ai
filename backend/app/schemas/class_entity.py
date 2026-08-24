import uuid
from datetime import datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.class_entity import ClassStatus, ClassCategory

class ClassBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100, description="e.g. Grade 1, Class 8, UKG")
    display_name: Optional[str] = Field(None, max_length=100, description="Optional user-facing descriptive name")
    code: str = Field(..., min_length=2, max_length=50, pattern=r"^[A-Z0-9_]+$", description="e.g. CLASS_8A, GRADE_1")
    level: int = Field(..., ge=0, description="Academic level weight, e.g. 1 for Grade 1, 8 for Class 8")
    category: ClassCategory = Field(default=ClassCategory.PRIMARY, description="e.g. PRE_PRIMARY, PRIMARY, MIDDLE, HIGH, etc.")
    stream: Optional[str] = Field(None, max_length=50, description="e.g. Science, Commerce, Arts")
    description: Optional[str] = Field(None, max_length=500)
    capacity: int = Field(..., ge=1, description="Maximum student capacity")
    promotion_order: Optional[int] = Field(None, ge=0, description="Optional sorting weight for automated promotion path sequence")
    next_class_id: Optional[uuid.UUID] = Field(None, description="Direct target class destination for automatic promotion path")
    settings: Dict[str, Any] = Field(default_factory=dict, description="Custom configurations")
    ai_metrics: Dict[str, Any] = Field(default_factory=dict, description="AI recommended parameters, forecasted strengths")

class ClassCreate(ClassBase):
    school_id: uuid.UUID = Field(..., description="Target school ID")
    academic_year_id: uuid.UUID = Field(..., description="Target academic year ID")

class ClassUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    display_name: Optional[str] = Field(None, max_length=100)
    code: Optional[str] = Field(None, min_length=2, max_length=50, pattern=r"^[A-Z0-9_]+$")
    level: Optional[int] = Field(None, ge=0)
    category: Optional[ClassCategory] = None
    stream: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = Field(None, max_length=500)
    capacity: Optional[int] = Field(None, ge=1)
    promotion_order: Optional[int] = Field(None, ge=0)
    next_class_id: Optional[uuid.UUID] = None
    status: Optional[ClassStatus] = None
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

class ClassResponse(ClassBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    status: ClassStatus
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class ClassPromote(BaseModel):
    target_academic_year_id: Optional[uuid.UUID] = None
    section_mappings: Dict[str, str] = Field(default_factory=dict, description="Maps source section ID to target section ID")


class PromotedStudentInfo(BaseModel):
    student_id: uuid.UUID
    name: str
    previous_section_id: uuid.UUID
    new_section_id: Optional[uuid.UUID] = None
    status: str  # PROMOTED, CONDITIONALLY_PROMOTED, DETAINED, PROMOTION_UNDER_REVIEW, GRADUATED, BLOCKED


class ClassPromoteResponse(BaseModel):
    total_students: int
    eligible: int
    conditional: int
    detained: int
    graduated: int
    blocked: int
    promoted_students: list[PromotedStudentInfo]
    failures: list[str] = Field(default_factory=list)
    settings: Dict[str, Any] = Field(default_factory=dict)
