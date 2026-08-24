import uuid
from datetime import date, datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field

class StaffCheckInRequest(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0, description="Latitude coordinate")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="Longitude coordinate")
    is_mocked: bool = Field(False, description="Flag indicating if location coordinates were mocked")
    remarks: Optional[str] = Field(None, max_length=500, description="Optional check-in remarks")

class StaffCheckOutRequest(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0, description="Latitude coordinate")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="Longitude coordinate")
    is_mocked: bool = Field(False, description="Flag indicating if location coordinates were mocked")
    remarks: Optional[str] = Field(None, max_length=500, description="Optional check-out remarks")

class StaffAttendanceResponse(BaseModel):
    id: Optional[uuid.UUID] = None
    tenant_id: uuid.UUID
    teacher_id: uuid.UUID
    school_id: uuid.UUID
    attendance_date: date

    check_in_time: Optional[datetime] = None
    check_in_latitude: Optional[float] = None
    check_in_longitude: Optional[float] = None
    check_in_distance_meters: Optional[float] = None

    check_out_time: Optional[datetime] = None
    check_out_latitude: Optional[float] = None
    check_out_longitude: Optional[float] = None
    check_out_distance_meters: Optional[float] = None

    is_mocked_location: bool = False
    remarks: Optional[str] = None
    duration_seconds: Optional[int] = None
    status: str

    model_config = ConfigDict(from_attributes=True)

class StaffDailyAttendanceReportItem(BaseModel):
    teacher_id: uuid.UUID
    teacher_name: str
    designation: Optional[str] = None
    department: Optional[str] = None
    attendance_status: str # PRESENT, ABSENT, LATE, HALF_DAY, ON_LEAVE
    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    remarks: Optional[str] = None

    check_in_latitude: Optional[float] = None
    check_in_longitude: Optional[float] = None
    check_in_distance_meters: Optional[float] = None

    check_out_latitude: Optional[float] = None
    check_out_longitude: Optional[float] = None
    check_out_distance_meters: Optional[float] = None

    is_mocked_location: bool = False

    model_config = ConfigDict(from_attributes=True)

class StaffDailyAttendanceSummary(BaseModel):
    date: date
    total_teachers: int
    present_count: int
    absent_count: int
    late_count: int
    half_day_count: int
    on_leave_count: int
    not_marked_count: int = 0
    attendance_rate: float
    records: List[StaffDailyAttendanceReportItem]

    model_config = ConfigDict(from_attributes=True)

