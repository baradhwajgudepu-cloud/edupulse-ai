import uuid
from datetime import date, datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, ConfigDict, Field, EmailStr

from app.models.student import StudentGender, StudentStatus

class StudentBase(BaseModel):
    first_name: str = Field(..., min_length=1, max_length=100)
    middle_name: Optional[str] = Field(None, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    gender: StudentGender = Field(..., description="Student gender: MALE, FEMALE, OTHER")
    date_of_birth: date = Field(..., description="Date of birth")
    blood_group: Optional[str] = Field(None, max_length=10)
    aadhaar_number: Optional[str] = Field(None, pattern=r"^\d{12}$", description="12-digit Aadhaar number")
    emis_number: Optional[str] = Field(None, max_length=50)
    mobile: Optional[str] = Field(None, max_length=20)
    email: Optional[str] = Field(None, max_length=255)
    photo_url: Optional[str] = Field(None, max_length=500)
    address: Dict[str, Any] = Field(default_factory=dict, description="Address JSON data")
    medical_information: Dict[str, Any] = Field(default_factory=dict, description="Medical Info JSON data")
    
    admission_number: str = Field(..., min_length=1, max_length=50)
    roll_number: str = Field(..., min_length=1, max_length=30)
    admission_date: date = Field(..., description="Date of admission")
    
    settings: Dict[str, Any] = Field(default_factory=dict)
    ai_metrics: Dict[str, Any] = Field(default_factory=dict)

class StudentCreate(StudentBase):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID

class StudentUpdate(BaseModel):
    first_name: Optional[str] = Field(None, min_length=1, max_length=100)
    middle_name: Optional[str] = Field(None, max_length=100)
    last_name: Optional[str] = Field(None, min_length=1, max_length=100)
    gender: Optional[StudentGender] = None
    date_of_birth: Optional[date] = None
    blood_group: Optional[str] = Field(None, max_length=10)
    aadhaar_number: Optional[str] = Field(None, pattern=r"^\d{12}$")
    emis_number: Optional[str] = Field(None, max_length=50)
    mobile: Optional[str] = Field(None, max_length=20)
    email: Optional[str] = Field(None, max_length=255)
    photo_url: Optional[str] = Field(None, max_length=500)
    address: Optional[Dict[str, Any]] = None
    medical_information: Optional[Dict[str, Any]] = None
    
    admission_number: Optional[str] = Field(None, min_length=1, max_length=50)
    roll_number: Optional[str] = Field(None, min_length=1, max_length=30)
    admission_date: Optional[date] = None
    
    # Timeline audit fields (updatable during state shifts)
    admitted_at: Optional[datetime] = None
    promoted_at: Optional[datetime] = None
    transferred_at: Optional[datetime] = None
    withdrawn_at: Optional[datetime] = None
    graduated_at: Optional[datetime] = None
    
    status: Optional[StudentStatus] = None
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

class StudentResponse(StudentBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    
    admitted_at: Optional[datetime] = None
    promoted_at: Optional[datetime] = None
    transferred_at: Optional[datetime] = None
    withdrawn_at: Optional[datetime] = None
    graduated_at: Optional[datetime] = None
    
    status: StudentStatus
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
