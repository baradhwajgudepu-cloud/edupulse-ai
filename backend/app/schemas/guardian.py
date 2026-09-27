import uuid
from datetime import date, datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, ConfigDict, Field, model_validator

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

from app.schemas.auth import ProvisioningCredentialResponse

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
    login_id: Optional[str] = None
    credentials: Optional[ProvisioningCredentialResponse] = None

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

class LinkedStudentSummary(BaseModel):
    id: uuid.UUID
    first_name: str
    middle_name: Optional[str] = None
    last_name: str
    admission_number: str
    roll_number: str
    status: str
    photo_url: Optional[str] = None
    academic_year_id: uuid.UUID
    academic_year_name: Optional[str] = None
    class_id: uuid.UUID
    class_name: Optional[str] = None
    section_id: uuid.UUID
    section_name: Optional[str] = None
    class_teacher_id: Optional[uuid.UUID] = None
    class_teacher_name: Optional[str] = None
    class_teacher_photo_url: Optional[str] = None
    admission_date: Optional[date] = None

    model_config = ConfigDict(from_attributes=True)


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
    student: Optional[LinkedStudentSummary] = None
    guardian: Optional[GuardianResponse] = None

    model_config = ConfigDict(from_attributes=True)

    @model_validator(mode="before")
    @classmethod
    def handle_orm_mapping(cls, data: Any) -> Any:
        if isinstance(data, dict):
            return data
        
        # When coming from SQLAlchemy ORM StudentGuardian
        student_val = getattr(data, "student_summary", None)
        guardian_val = getattr(data, "guardian_summary", None)

        if hasattr(data, "_sa_instance_state"):
            from sqlalchemy import inspect
            ins = inspect(data)
            loaded = ins.dict if ins else {}
            if student_val is None and "student" in loaded and loaded["student"] is not None:
                st = loaded["student"]
                if isinstance(st, LinkedStudentSummary):
                    student_val = st
                elif hasattr(st, "id"):
                    st_ins = inspect(st)
                    st_dict = st_ins.dict if st_ins else {}
                    ay_name = st_dict.get("academic_year").name if "academic_year" in st_dict and st_dict["academic_year"] else None
                    cls_name = st_dict.get("class_obj").name if "class_obj" in st_dict and st_dict["class_obj"] else None
                    sec_name = st_dict.get("section").name if "section" in st_dict and st_dict["section"] else None
                    status_str = st.status.value if hasattr(st.status, "value") else str(st.status)
                    student_val = LinkedStudentSummary(
                        id=st.id,
                        first_name=st.first_name,
                        middle_name=st.middle_name,
                        last_name=st.last_name,
                        admission_number=st.admission_number,
                        roll_number=st.roll_number,
                        status=status_str,
                        photo_url=st.photo_url,
                        academic_year_id=st.academic_year_id,
                        academic_year_name=ay_name,
                        class_id=st.class_id,
                        class_name=cls_name,
                        section_id=st.section_id,
                        section_name=sec_name,
                        class_teacher_id=getattr(st, "class_teacher_id", None),
                        class_teacher_name=getattr(st, "class_teacher_name", None),
                        class_teacher_photo_url=getattr(st, "class_teacher_photo_url", None),
                        admission_date=st.admission_date,
                    )

            if guardian_val is None and "guardian" in loaded and loaded["guardian"] is not None:
                gu = loaded["guardian"]
                if isinstance(gu, GuardianResponse):
                    guardian_val = gu
                elif hasattr(gu, "id") and not getattr(gu, "deleted_at", None):
                    guardian_val = GuardianResponse.model_validate(gu)
        else:
            if student_val is None and isinstance(getattr(data, "student", None), LinkedStudentSummary):
                student_val = data.student
            if guardian_val is None and isinstance(getattr(data, "guardian", None), GuardianResponse):
                guardian_val = data.guardian

        return {
            "id": getattr(data, "id", None),
            "tenant_id": getattr(data, "tenant_id", None),
            "school_id": getattr(data, "school_id", None),
            "student_id": getattr(data, "student_id", None),
            "guardian_id": getattr(data, "guardian_id", None),
            "relationship": getattr(data, "relationship", None),
            "is_primary": getattr(data, "is_primary", False),
            "can_pickup_student": getattr(data, "can_pickup_student", True),
            "receives_notifications": getattr(data, "receives_notifications", True),
            "version": getattr(data, "version", 1),
            "created_at": getattr(data, "created_at", None),
            "updated_at": getattr(data, "updated_at", None),
            "deleted_at": getattr(data, "deleted_at", None),
            "student": student_val,
            "guardian": guardian_val,
        }


