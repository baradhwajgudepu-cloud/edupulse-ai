import uuid
from datetime import datetime, date
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from app.models.import_job import ImportType, ImportJobStatus

class ImportJobCreate(BaseModel):
    school_id: uuid.UUID
    import_type: ImportType
    source_filename: str = Field(..., max_length=255)
    file_checksum: Optional[str] = Field(None, max_length=64)
    total_rows: int = Field(0, ge=0)
    job_metadata: Dict[str, Any] = Field(default_factory=dict)

class ImportJobResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    import_type: ImportType
    status: ImportJobStatus
    source_filename: str
    file_checksum: Optional[str] = None
    
    total_rows: int
    processed_rows: int
    successful_rows: int
    failed_rows: int
    skipped_rows: int
    
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    error_summary: Optional[str] = None
    job_metadata: Dict[str, Any]
    
    created_at: datetime
    updated_at: datetime
    created_by: Optional[uuid.UUID] = None

    model_config = ConfigDict(from_attributes=True)

class ImportJobRowCreate(BaseModel):
    row_number: int = Field(..., ge=1)
    status: str = Field(..., max_length=50)
    error_code: Optional[str] = Field(None, max_length=100)
    error_message: Optional[str] = Field(None, max_length=1000)
    source_identifier: Optional[str] = Field(None, max_length=255)
    entity_id: Optional[uuid.UUID] = None
    row_metadata: Dict[str, Any] = Field(default_factory=dict)

class ImportJobRowResponse(BaseModel):
    id: uuid.UUID
    import_job_id: uuid.UUID
    row_number: int
    status: str
    error_code: Optional[str] = None
    error_message: Optional[str] = None
    source_identifier: Optional[str] = None
    entity_id: Optional[uuid.UUID] = None
    row_metadata: Dict[str, Any]
    
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class ImportJobRowCreateBulk(BaseModel):
    rows: List[ImportJobRowCreate]

class StudentImportRowResponse(BaseModel):
    id: uuid.UUID
    import_job_id: uuid.UUID
    row_number: int
    first_name: str
    last_name: str
    gender: str
    date_of_birth: date
    admission_number: str
    roll_number: str
    admission_date: date
    validation_status: str
    validation_error_code: Optional[str] = None
    validation_error_message: Optional[str] = None
    created_student_id: Optional[uuid.UUID] = None
    
    model_config = ConfigDict(from_attributes=True)

class StudentImportValidationResult(BaseModel):
    job_id: uuid.UUID
    status: ImportJobStatus
    total_rows: int
    valid_rows: int
    invalid_rows: int
    duplicate_rows: int

class StudentImportExecutionResult(BaseModel):
    job_id: uuid.UUID
    status: ImportJobStatus
    processed_rows: int
    successful_rows: int
    failed_rows: int
    skipped_rows: int

class AcademicSetupImportRowResponse(BaseModel):
    id: uuid.UUID
    import_job_id: uuid.UUID
    row_number: int

    # Academic Year fields
    academic_year_name: str
    academic_year_code: str
    start_date: date
    end_date: date

    # Class fields
    class_name: str
    class_code: str
    class_level: int
    class_category: str
    class_capacity: int

    # Section fields
    section_name: str
    section_code: str
    section_capacity: int

    # Resolved IDs
    school_id: Optional[uuid.UUID] = None
    academic_year_id: Optional[uuid.UUID] = None
    class_id: Optional[uuid.UUID] = None
    section_id: Optional[uuid.UUID] = None

    # Validation tracking
    validation_status: str
    validation_error_code: Optional[str] = None
    validation_error_message: Optional[str] = None

    # Execution fields
    created_academic_year_id: Optional[uuid.UUID] = None
    created_class_id: Optional[uuid.UUID] = None
    created_section_id: Optional[uuid.UUID] = None

    model_config = ConfigDict(from_attributes=True)


class GuardianImportRowResponse(BaseModel):
    id: uuid.UUID
    import_job_id: uuid.UUID
    row_number: int
    source_identifier: str

    guardian_type: str
    first_name: str
    middle_name: Optional[str] = None
    last_name: str
    gender: str
    date_of_birth: date
    aadhaar_number: Optional[str] = None
    pan_number: Optional[str] = None
    occupation: Optional[str] = None
    qualification: Optional[str] = None
    organization: Optional[str] = None
    annual_income: Optional[float] = None
    mobile: str
    alternate_mobile: Optional[str] = None
    email: Optional[str] = None
    emergency_contact_name: Optional[str] = None
    emergency_contact_mobile: Optional[str] = None
    photo_url: Optional[str] = None
    address: Optional[str] = None

    school_id: Optional[uuid.UUID] = None
    validation_status: str
    validation_error_code: Optional[str] = None
    validation_error_message: Optional[str] = None
    resolved_guardian_id: Optional[uuid.UUID] = None
    created_guardian_id: Optional[uuid.UUID] = None

    model_config = ConfigDict(from_attributes=True)


class StudentGuardianImportRowResponse(BaseModel):
    id: uuid.UUID
    import_job_id: uuid.UUID
    row_number: int

    student_admission_number: str
    guardian_id: str
    relationship: str
    is_primary: Optional[bool] = False
    can_pickup_student: Optional[bool] = True
    receives_notifications: Optional[bool] = True

    school_id: Optional[uuid.UUID] = None
    validation_status: str
    validation_error_code: Optional[str] = None
    validation_error_message: Optional[str] = None
    resolved_student_id: Optional[uuid.UUID] = None
    resolved_guardian_id: Optional[uuid.UUID] = None
    created_mapping_id: Optional[uuid.UUID] = None

    model_config = ConfigDict(from_attributes=True)


