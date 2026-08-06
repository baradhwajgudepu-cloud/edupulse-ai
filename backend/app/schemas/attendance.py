import uuid
from datetime import date, datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from app.models.attendance import AttendanceStatus, AttendanceSessionStatus, AttendanceSource, AttendanceReason

class AttendanceSessionCreate(BaseModel):
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    timetable_id: uuid.UUID
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

class BulkAttendanceMark(BaseModel):
    attendance_session_status: Optional[AttendanceSessionStatus] = AttendanceSessionStatus.SUBMITTED
    records: List[StudentAttendanceRecord]

class AttendanceCorrectionUpdate(BaseModel):
    attendance_status: AttendanceStatus
    attendance_source: Optional[AttendanceSource] = AttendanceSource.MANUAL
    attendance_reason: Optional[AttendanceReason] = AttendanceReason.UNKNOWN
    remarks: Optional[str] = Field(None, max_length=500)
    correction_reason: str = Field(..., max_length=500, min_length=1)

class AttendanceResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    attendance_session_id: uuid.UUID
    student_id: uuid.UUID
    timetable_id: uuid.UUID
    class_id: uuid.UUID
    section_id: uuid.UUID
    teacher_id: Optional[uuid.UUID] = None
    subject_id: Optional[uuid.UUID] = None
    
    attendance_date: date
    attendance_status: AttendanceStatus
    attendance_source: AttendanceSource
    attendance_reason: AttendanceReason
    remarks: Optional[str] = None
    
    parent_viewed: bool
    parent_viewed_at: Optional[datetime] = None
    
    is_active: bool
    settings: Dict[str, Any]
    ai_metrics: Dict[str, Any]
    
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

class AttendanceSessionResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    timetable_id: uuid.UUID
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
    
    attendances: List[AttendanceResponse] = []

    model_config = ConfigDict(from_attributes=True)
