import uuid
from datetime import date, datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field, field_validator, computed_field

from app.models.attendance import AttendanceStatus, AttendanceSessionStatus, AttendanceSource, AttendanceReason, AttendanceSessionType, AttendanceAction

class AttendanceSessionCreate(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    timetable_id: Optional[uuid.UUID] = None
    class_id: Optional[uuid.UUID] = None
    section_id: Optional[uuid.UUID] = None
    session_type: AttendanceSessionType = AttendanceSessionType.FULL_DAY
    attendance_date: date
    settings: Dict[str, Any] = Field(default_factory=dict)

class AttendanceSessionUpdate(BaseModel):
    status: Optional[AttendanceSessionStatus] = None
    settings: Optional[Dict[str, Any]] = None

class StudentAttendanceRecord(BaseModel):
    student_id: uuid.UUID
    attendance_status: AttendanceStatus
    attendance_source: AttendanceSource = AttendanceSource.MANUAL
    attendance_reason: AttendanceReason = AttendanceReason.UNKNOWN
    remarks: Optional[str] = Field(None, max_length=500)

    @field_validator("attendance_source", mode="before")
    @classmethod
    def normalize_attendance_source(cls, v: Any) -> Any:
        if isinstance(v, str):
            upper = v.strip().upper()
            if upper in ("BULK_IMPORT", "EXCEL_IMPORT"):
                return AttendanceSource.IMPORT
        return v

class BulkAttendanceMark(BaseModel):
    attendance_session_status: Optional[AttendanceSessionStatus] = AttendanceSessionStatus.SUBMITTED
    records: List[StudentAttendanceRecord]

class DailyAttendanceMarkRequest(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    attendance_date: date
    session_type: AttendanceSessionType = AttendanceSessionType.FULL_DAY
    attendance_source: AttendanceSource = AttendanceSource.MANUAL
    records: List[StudentAttendanceRecord]

    @field_validator("attendance_source", mode="before")
    @classmethod
    def normalize_attendance_source(cls, v: Any) -> Any:
        if isinstance(v, str):
            upper = v.strip().upper()
            if upper in ("BULK_IMPORT", "EXCEL_IMPORT"):
                return AttendanceSource.IMPORT
        return v

class AttendanceCorrectionUpdate(BaseModel):
    attendance_status: AttendanceStatus
    attendance_source: Optional[AttendanceSource] = AttendanceSource.MANUAL
    attendance_reason: Optional[AttendanceReason] = AttendanceReason.UNKNOWN
    remarks: Optional[str] = Field(None, max_length=500)
    correction_reason: str = Field(..., max_length=500, min_length=1)

    @field_validator("attendance_source", mode="before")
    @classmethod
    def normalize_attendance_source(cls, v: Any) -> Any:
        if isinstance(v, str):
            upper = v.strip().upper()
            if upper in ("BULK_IMPORT", "EXCEL_IMPORT"):
                return AttendanceSource.IMPORT
        return v

class AttendanceResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    attendance_session_id: uuid.UUID
    student_id: uuid.UUID
    timetable_id: Optional[uuid.UUID] = None
    session_type: AttendanceSessionType = AttendanceSessionType.FULL_DAY
    class_id: uuid.UUID
    section_id: uuid.UUID
    teacher_id: Optional[uuid.UUID] = None
    subject_id: Optional[uuid.UUID] = None
    
    attendance_date: date
    attendance_status: AttendanceStatus
    attendance_source: AttendanceSource
    attendance_reason: AttendanceReason
    remarks: Optional[str] = None
    
    parent_viewed: Optional[bool] = False
    parent_viewed_at: Optional[datetime] = None
    
    is_active: bool
    settings: Dict[str, Any]
    ai_metrics: Dict[str, Any]
    
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    # Enriched presentation fields
    student_name: Optional[str] = None
    admission_number: Optional[str] = None
    roll_number: Optional[str] = None
    class_name: Optional[str] = None
    section_name: Optional[str] = None
    marked_by_name: Optional[str] = None

    @computed_field
    @property
    def status(self) -> str:
        return self.attendance_status.value if hasattr(self.attendance_status, 'value') else str(self.attendance_status)

    model_config = ConfigDict(from_attributes=True)

class AttendanceSessionResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    timetable_id: Optional[uuid.UUID] = None
    session_type: AttendanceSessionType = AttendanceSessionType.FULL_DAY
    class_id: uuid.UUID
    section_id: uuid.UUID
    teacher_id: Optional[uuid.UUID] = None
    subject_id: Optional[uuid.UUID] = None
    
    attendance_date: date
    status: AttendanceSessionStatus
    marked_by: Optional[uuid.UUID] = None
    marked_at: Optional[datetime] = None
    
    is_active: bool
    settings: Dict[str, Any]
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None
    
    class_name: Optional[str] = None
    section_name: Optional[str] = None
    marked_by_name: Optional[str] = None

    attendances: List[AttendanceResponse] = []

    model_config = ConfigDict(from_attributes=True)

class AttendanceAuditLogResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    attendance_id: Optional[uuid.UUID] = None
    student_id: uuid.UUID
    student_name: Optional[str] = None
    admission_number: Optional[str] = None
    class_name: Optional[str] = None
    section_name: Optional[str] = None
    attendance_date: date
    session_type: str
    old_status: Optional[str] = None
    new_status: str
    action: str
    changed_by: Optional[uuid.UUID] = None
    changed_by_name: Optional[str] = None
    changed_by_role: Optional[str] = None
    timestamp: datetime
    source: str
    reason: Optional[str] = None
    audit_metadata: Dict[str, Any] = Field(default_factory=dict)

    model_config = ConfigDict(from_attributes=True)

class AttendanceDashboardStatsResponse(BaseModel):
    attendance_date: date
    attendance_percentage: float
    total_students: int
    present_count: int
    absent_count: int
    late_count: int
    excused_count: int
    half_day_count: int
    classes_marked: int
    classes_pending: int
    daily_trend: List[Dict[str, Any]] = Field(default_factory=list)
    class_wise_stats: List[Dict[str, Any]] = Field(default_factory=list)
    monthly_percentage: float = 0.0
    low_attendance_students: List[Dict[str, Any]] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)

class BulkValidateRowPreview(BaseModel):
    row_number: int
    admission_number: Optional[str] = None
    student_name: Optional[str] = None
    class_name: Optional[str] = None
    section_name: Optional[str] = None
    attendance_date: Optional[str] = None
    session: Optional[str] = None
    status: Optional[str] = None
    validation_status: str  # VALID, INVALID, DUPLICATE, CONFLICT
    error_message: Optional[str] = None
    conflict_existing_status: Optional[str] = None

class BulkAttendanceValidateResponse(BaseModel):
    job_id: uuid.UUID
    filename: str
    total_rows: int
    valid_rows: int
    invalid_rows: int
    duplicate_rows: int
    conflict_rows: int
    preview_rows: List[BulkValidateRowPreview] = Field(default_factory=list)
    errors: List[str] = Field(default_factory=list)

class BulkAttendanceImportRequest(BaseModel):
    job_id: uuid.UUID
    conflict_strategy: str = "SKIP_EXISTING"  # SKIP_EXISTING, REPLACE_EXISTING

class BulkAttendanceImportResponse(BaseModel):
    job_id: uuid.UUID
    status: str
    total_rows: int
    imported_rows: int
    skipped_rows: int
    failed_rows: int
    conflict_rows: int
    message: str

class BulkAttendanceRowChunkItem(BaseModel):
    row_number: int
    student_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    attendance_date: date
    session_type: str = "MORNING"
    attendance_status: str
    attendance_reason: Optional[str] = "UNKNOWN"
    remarks: Optional[str] = None

class BulkAttendanceChunkTiming(BaseModel):
    session_resolution_ms: float = 0.0
    attendance_lookup_ms: float = 0.0
    insert_update_ms: float = 0.0
    audit_ms: float = 0.0
    commit_ms: float = 0.0
    total_batch_ms: float = 0.0

class BulkAttendanceChunkRequest(BaseModel):
    import_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: Optional[uuid.UUID] = None
    conflict_strategy: str = "SKIP_EXISTING"  # SKIP_EXISTING, REPLACE_EXISTING
    batch_index: int
    total_batches: int
    total_rows: int
    idempotency_key: str
    filename: Optional[str] = "attendance.csv"
    records: List[BulkAttendanceRowChunkItem]

class BulkAttendanceChunkResponse(BaseModel):
    import_id: uuid.UUID
    batch_index: int
    total_batches: int
    total_rows: int
    imported_rows: int
    skipped_rows: int
    failed_rows: int
    status: str  # COMMITTED, ALREADY_COMMITTED, FAILED
    timing: Optional[BulkAttendanceChunkTiming] = None
    errors: List[str] = Field(default_factory=list)

class AttendanceImportJobResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    filename: str
    status: str
    total_rows: int
    successful_rows: int
    failed_rows: int
    skipped_rows: int
    date_range: Optional[str] = None
    uploaded_by: Optional[uuid.UUID] = None
    uploaded_by_name: Optional[str] = None
    uploaded_by_role: Optional[str] = None
    created_at: datetime
    completed_at: Optional[datetime] = None
    error_summary: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class AttendanceImportRowError(BaseModel):
    row_number: int
    admission_number: Optional[str] = None
    error_message: str
    error_code: Optional[str] = "IMPORT_ERROR"
    row_data: Dict[str, Any] = Field(default_factory=dict)

class AttendanceImportRecordRequest(BaseModel):
    school_id: uuid.UUID
    filename: str
    total_rows: int
    successful_rows: int
    failed_rows: int
    skipped_rows: int
    status: str = "COMPLETED"
    date_range: Optional[str] = None
    error_summary: Optional[str] = None
    errors: List[AttendanceImportRowError] = Field(default_factory=list)

class AttendanceAlertResponse(BaseModel):
    alert_type: str  # ABSENCE_STREAK, LOW_PERCENTAGE, UNMARKED_CLASS
    severity: str    # HIGH, MEDIUM, LOW
    title: str
    message: str
    entity_id: Optional[str] = None
    details: Dict[str, Any] = Field(default_factory=dict)
