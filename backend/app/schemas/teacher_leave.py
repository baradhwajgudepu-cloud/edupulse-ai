import uuid
from datetime import date, datetime
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict, field_validator
from app.models.teacher_leave import LeaveType, LeaveStatus
from app.schemas.teacher import TeacherResponse

class TeacherLeaveCreateRequest(BaseModel):
    leave_type: LeaveType = Field(..., description="Type of leave (e.g. CASUAL, SICK)")
    start_date: date = Field(..., description="Leave start date")
    end_date: date = Field(..., description="Leave end date")
    reason: str = Field(..., min_length=3, max_length=500, description="Reason for leave request")
    remarks: Optional[str] = Field(None, max_length=500, description="Optional extra remarks")

    @field_validator("end_date")
    @classmethod
    def validate_date_range(cls, end_date: date, info) -> date:
        start_date = info.data.get("start_date")
        if start_date and end_date < start_date:
            raise ValueError("Start date must be before or equal to end date.")
        return end_date

class TeacherLeaveReviewRequest(BaseModel):
    decision: str = Field(..., description="Review decision, must be 'APPROVE' or 'REJECT'")
    reviewer_remarks: Optional[str] = Field(None, max_length=500, description="Optional remarks from the reviewer")

    @field_validator("decision")
    @classmethod
    def validate_decision(cls, decision: str) -> str:
        upper_decision = decision.upper()
        if upper_decision not in ("APPROVE", "REJECT"):
            raise ValueError("Decision must be either 'APPROVE' or 'REJECT'.")
        return upper_decision

class TeacherLeaveCancelRequest(BaseModel):
    cancellation_reason: str = Field(..., min_length=3, max_length=500, description="Reason for cancellation")

class TeacherLeaveResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    teacher_id: uuid.UUID
    leave_type: LeaveType
    start_date: date
    end_date: date
    reason: str
    remarks: Optional[str] = None
    status: LeaveStatus
    requested_at: datetime
    reviewed_at: Optional[datetime] = None
    reviewed_by: Optional[uuid.UUID] = None
    reviewer_remarks: Optional[str] = None
    cancelled_at: Optional[datetime] = None
    cancellation_reason: Optional[str] = None
    teacher: Optional[TeacherResponse] = None

    model_config = ConfigDict(from_attributes=True)
