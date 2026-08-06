import uuid
from datetime import date, datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, ConfigDict, Field

from app.models.student import StudentGender
from app.models.guardian import GuardianType, GuardianStatus, StudentGuardianRelationship

class GuardianBase(BaseModel):
    guardian_type: GuardianType = Field(..., description="FATHER, MOTHER, LEGAL_GUARDIAN, etc.")
    first_name: str = Field(..., min_length=1, max_length=100)
    middle_name: Optional[str] = Field(None, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    gender: StudentGender = Field(..., description="MALE, FEMALE, OTHER")
    date_of_birth: date = Field(..., description="Date of birth")
    aadhaar_number: Optional[str] = Field(None, pattern=r"^\d{12}$", description="12-digit Aadhaar number")
    pan_number: Optional[str] = Field(None, pattern=r"^[A-Z]{5}[0-9]{4}[A-Z]{1}$", description="Permanent Account Number")
    occupation: Optional[str] = Field(None, max_length=150)
    qualification: Optional[str] = Field(None, max_length=150)
    organization: Optional[str] = Field(None, max_length=200)
    annual_income: Optional[float] = Field(None, ge=0, description="Annual income")
    mobile: str = Field(..., min_length=1, max_length=20)
    alternate_mobile: Optional[str] = Field(None, max_length=20)
    email: Optional[str] = Field(None, max_length=255)
    
    emergency_contact_name: Optional[str] = Field(None, max_length=100)
    emergency_contact_mobile: Optional[str] = Field(None, max_length=20)
    photo_url: Optional[str] = Field(None, max_length=500)
    address: Dict[str, Any] = Field(default_factory=dict)
    communication_preferences: Dict[str, Any] = Field(default_factory=dict)
    settings: Dict[str, Any] = Field(default_factory=dict)
    ai_metrics: Dict[str, Any] = Field(default_factory=dict)

class GuardianCreate(GuardianBase):
    school_id: uuid.UUID

class GuardianUpdate(BaseModel):
    guardian_type: Optional[GuardianType] = None
    first_name: Optional[str] = Field(None, min_length=1, max_length=100)
    middle_name: Optional[str] = Field(None, max_length=100)
    last_name: Optional[str] = Field(None, min_length=1, max_length=100)
    gender: Optional[StudentGender] = None
    date_of_birth: Optional[date] = None
    aadhaar_number: Optional[str] = Field(None, pattern=r"^\d{12}$")
    pan_number: Optional[str] = Field(None, pattern=r"^[A-Z]{5}[0-9]{4}[A-Z]{1}$")
    occupation: Optional[str] = Field(None, max_length=150)
    qualification: Optional[str] = Field(None, max_length=150)
    organization: Optional[str] = Field(None, max_length=200)
    annual_income: Optional[float] = Field(None, ge=0)
    mobile: Optional[str] = Field(None, min_length=1, max_length=20)
    is_mobile_verified: Optional[bool] = None
    alternate_mobile: Optional[str] = Field(None, max_length=20)
    email: Optional[str] = Field(None, max_length=255)
    is_email_verified: Optional[bool] = None
    
    emergency_contact_name: Optional[str] = Field(None, max_length=100)
    emergency_contact_mobile: Optional[str] = Field(None, max_length=20)
    photo_url: Optional[str] = Field(None, max_length=500)
    address: Optional[Dict[str, Any]] = None
    communication_preferences: Optional[Dict[str, Any]] = None
    status: Optional[GuardianStatus] = None
    settings: Optional[Dict[str, Any]] = None
    ai_metrics: Optional[Dict[str, Any]] = None

class GuardianResponse(GuardianBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    is_mobile_verified: bool
    is_email_verified: bool
    status: GuardianStatus
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class StudentGuardianCreate(BaseModel):
    school_id: uuid.UUID
    student_id: uuid.UUID
    guardian_id: uuid.UUID
    relationship: StudentGuardianRelationship
    is_primary: bool = Field(default=False)
    can_pickup_student: bool = Field(default=True)
    receives_notifications: bool = Field(default=True)

class StudentGuardianUpdate(BaseModel):
    relationship: Optional[StudentGuardianRelationship] = None
    is_primary: Optional[bool] = None
    can_pickup_student: Optional[bool] = None
    receives_notifications: Optional[bool] = None

class StudentGuardianResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    student_id: uuid.UUID
    guardian_id: uuid.UUID
    relationship: StudentGuardianRelationship
    is_primary: bool
    can_pickup_student: bool
    receives_notifications: bool
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
