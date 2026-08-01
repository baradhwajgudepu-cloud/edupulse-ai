import uuid
from datetime import datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, ConfigDict, Field

from app.models.section import SectionStatus

class SectionBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100, description="e.g. Section A, Section B, Lotus")
    code: str = Field(..., min_length=1, max_length=50, pattern=r"^[A-Z0-9_]+$", description="e.g. SEC_A, SEC_B")
    capacity: int = Field(..., ge=1, description="Maximum student capacity")
    room_number: Optional[str] = Field(None, max_length=50, description="Optional classroom identifier")
    sort_order: int = Field(default=1, ge=1, description="Sort order weight for display")
    description: Optional[str] = Field(None, max_length=500)
    settings: Dict[str, Any] = Field(default_factory=dict, description="Custom configurations")
    ai_metrics: Dict[str, Any] = Field(default_factory=dict, description="AI models parameters, risk tracking")

class SectionCreate(SectionBase):
    school_id: uuid.UUID = Field(..., description="Target school ID")
    academic_year_id: uuid.UUID = Field(..., description="Target academic year ID")
    class_id: uuid.UUID = Field(..., description="Target class ID")

class SectionUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    code: Optional[str] = Field(None, min_length=1, max_length=50, pattern=r"^[A-Z0-9_]+$")
    capacity: Optional[int] = Field(None, ge=1)
    room_number: Optional[str] = Field(None, max_length=50)
    sort_order: Optional[int] = Field(None, ge=1)
    description: Optional[str] = Field(None, max_length=500)
    status: Optional[SectionStatus] = None
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

class SectionResponse(SectionBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    status: SectionStatus
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
