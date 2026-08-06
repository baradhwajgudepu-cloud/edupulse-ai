import uuid
from datetime import date, datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from app.models.teacher_subject_assignment import AssignmentStatus, AssignmentType

class TeacherSubjectAssignmentBase(BaseModel):
    assignment_type: AssignmentType = Field(..., description="PRIMARY, SECONDARY, SUBSTITUTE")
    priority: Optional[int] = Field(1, ge=1)
    weekly_periods: int = Field(..., ge=1, description="Number of periods per week")
    workload_percentage: Optional[float] = Field(0.00, ge=0.00, le=100.00)
    
    effective_from: date
    effective_to: Optional[date] = None
    
    is_class_teacher: bool = Field(default=False)
    room_id: Optional[uuid.UUID] = None
    maximum_students: Optional[int] = Field(None, ge=1)
    remarks: Optional[str] = Field(None, max_length=500)
    
    settings: Dict[str, Any] = Field(default_factory=dict)
    ai_metrics: Dict[str, Any] = Field(default_factory=dict)

class TeacherSubjectAssignmentCreate(TeacherSubjectAssignmentBase):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    teacher_id: uuid.UUID
    subject_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID

class TeacherSubjectAssignmentUpdate(BaseModel):
    assignment_type: Optional[AssignmentType] = None
    priority: Optional[int] = Field(None, ge=1)
    weekly_periods: Optional[int] = Field(None, ge=1)
    workload_percentage: Optional[float] = Field(None, ge=0.00, le=100.00)
    
    effective_from: Optional[date] = None
    effective_to: Optional[date] = None
    
    is_class_teacher: Optional[bool] = None
    room_id: Optional[uuid.UUID] = None
    maximum_students: Optional[int] = Field(None, ge=1)
    remarks: Optional[str] = Field(None, max_length=500)
    
    status: Optional[AssignmentStatus] = None
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

class TeacherSubjectAssignmentResponse(TeacherSubjectAssignmentBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    teacher_id: uuid.UUID
    subject_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    assigned_by: Optional[uuid.UUID] = None
    assigned_at: Optional[datetime] = None
    status: AssignmentStatus
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
