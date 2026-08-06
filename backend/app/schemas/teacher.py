import uuid
from datetime import date, datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from app.models.student import StudentGender
from app.models.teacher import TeacherStatus, EmploymentType

class TeacherBase(BaseModel):
    employee_code: str = Field(..., min_length=1, max_length=50)
    staff_code: str = Field(..., min_length=1, max_length=50)
    first_name: str = Field(..., min_length=1, max_length=100)
    middle_name: Optional[str] = Field(None, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    gender: StudentGender = Field(..., description="MALE, FEMALE, OTHER")
    date_of_birth: date = Field(..., description="Date of birth")
    blood_group: Optional[str] = Field(None, max_length=10)
    aadhaar_number: Optional[str] = Field(None, pattern=r"^\d{12}$", description="12-digit Aadhaar number")
    pan_number: Optional[str] = Field(None, pattern=r"^[A-Z]{5}[0-9]{4}[A-Z]{1}$", description="Permanent Account Number")
    mobile: str = Field(..., min_length=1, max_length=20)
    alternate_mobile: Optional[str] = Field(None, max_length=20)
    official_email: str = Field(..., max_length=255)
    personal_email: Optional[str] = Field(None, max_length=255)
    
    emergency_contact_name: Optional[str] = Field(None, max_length=100)
    emergency_contact_mobile: Optional[str] = Field(None, max_length=20)
    emergency_contact_relation: Optional[str] = Field(None, max_length=50)
    photo_url: Optional[str] = Field(None, max_length=500)
    address: Dict[str, Any] = Field(default_factory=dict)
    
    qualification: Optional[str] = Field(None, max_length=200)
    specialization: Optional[str] = Field(None, max_length=200)
    experience_years: Optional[int] = Field(None, ge=0)
    
    joining_date: date
    date_of_confirmation: Optional[date] = None
    date_of_resignation: Optional[date] = None
    date_of_retirement: Optional[date] = None
    
    employment_type: EmploymentType = Field(..., description="FULL_TIME, PART_TIME, CONTRACT, VISITING")
    designation: Optional[str] = Field(None, max_length=150)
    department: Optional[str] = Field(None, max_length=150)
    salary: Optional[float] = Field(None, ge=0)
    
    settings: Dict[str, Any] = Field(default_factory=dict)
    ai_metrics: Dict[str, Any] = Field(default_factory=dict)

class TeacherCreate(TeacherBase):
    school_id: uuid.UUID

class TeacherUpdate(BaseModel):
    employee_code: Optional[str] = Field(None, min_length=1, max_length=50)
    staff_code: Optional[str] = Field(None, min_length=1, max_length=50)
    first_name: Optional[str] = Field(None, min_length=1, max_length=100)
    middle_name: Optional[str] = Field(None, max_length=100)
    last_name: Optional[str] = Field(None, min_length=1, max_length=100)
    gender: Optional[StudentGender] = None
    date_of_birth: Optional[date] = None
    blood_group: Optional[str] = Field(None, max_length=10)
    aadhaar_number: Optional[str] = Field(None, pattern=r"^\d{12}$")
    pan_number: Optional[str] = Field(None, pattern=r"^[A-Z]{5}[0-9]{4}[A-Z]{1}$")
    mobile: Optional[str] = Field(None, min_length=1, max_length=20)
    alternate_mobile: Optional[str] = Field(None, max_length=20)
    official_email: Optional[str] = Field(None, max_length=255)
    personal_email: Optional[str] = Field(None, max_length=255)
    
    emergency_contact_name: Optional[str] = Field(None, max_length=100)
    emergency_contact_mobile: Optional[str] = Field(None, max_length=20)
    emergency_contact_relation: Optional[str] = Field(None, max_length=50)
    photo_url: Optional[str] = Field(None, max_length=500)
    address: Optional[Dict[str, Any]] = None
    
    qualification: Optional[str] = Field(None, max_length=200)
    specialization: Optional[str] = Field(None, max_length=200)
    experience_years: Optional[int] = Field(None, ge=0)
    
    joining_date: Optional[date] = None
    date_of_confirmation: Optional[date] = None
    date_of_resignation: Optional[date] = None
    date_of_retirement: Optional[date] = None
    
    employment_type: Optional[EmploymentType] = None
    designation: Optional[str] = Field(None, max_length=150)
    department: Optional[str] = Field(None, max_length=150)
    salary: Optional[float] = Field(None, ge=0)
    
    status: Optional[TeacherStatus] = None
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

class TeacherResponse(TeacherBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    status: TeacherStatus
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
