from datetime import date, datetime
import uuid
from typing import Optional, Dict, Any
from pydantic import BaseModel, ConfigDict, Field, model_validator
from app.models.academic_year import AcademicYearStatus

class AcademicYearBase(BaseModel):
    """
    Base properties shared across Academic Year schemas.
    Enforces regex pattern for academic year codes.
    """
    name: str = Field(..., min_length=1, max_length=100, description="Name of the academic year (e.g. 2026-2027)")
    
    # Matches AY2026 or AY2026-2027
    code: str = Field(
        ...,
        pattern=r"^AY[0-9]{4}(?:-[0-9]{4})?$",
        description="Unique uppercase code format (e.g. AY2026, AY2026-2027)"
    )
    description: Optional[str] = Field(None, max_length=500)
    
    start_date: date = Field(..., description="Academic term start date")
    end_date: date = Field(..., description="Academic term end date")
    
    status: AcademicYearStatus = Field(AcademicYearStatus.UPCOMING, description="Status in state machine sequence")
    is_current: bool = Field(False, description="Whether this is the current active year")
    settings: Dict[str, Any] = Field(default_factory=dict, description="Custom configurations for the academic year")

    @model_validator(mode="after")
    def validate_dates(self) -> "AcademicYearBase":
        if self.start_date >= self.end_date:
            raise ValueError("start_date must be strictly before end_date")
        return self

class AcademicYearCreate(AcademicYearBase):
    """
    Schema for creating an Academic Year.
    """
    pass

class AcademicYearUpdate(BaseModel):
    """
    Schema for updating an Academic Year. All fields are optional.
    """
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    code: Optional[str] = Field(None, pattern=r"^AY[0-9]{4}(?:-[0-9]{4})?$")
    description: Optional[str] = Field(None, max_length=500)
    
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    
    status: Optional[AcademicYearStatus] = None
    is_current: Optional[bool] = None
    settings: Optional[Dict[str, Any]] = None

    @model_validator(mode="after")
    def validate_dates(self) -> "AcademicYearUpdate":
        if self.start_date is not None and self.end_date is not None:
            if self.start_date >= self.end_date:
                raise ValueError("start_date must be strictly before end_date")
        return self

class AcademicYearResponse(AcademicYearBase):
    """
    Schema representing the Academic Year details returned in API payloads.
    """
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None
    created_by: Optional[uuid.UUID] = None
    updated_by: Optional[uuid.UUID] = None

    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "example": {
                "id": "323e4567-e89b-12d3-a456-426614174000",
                "tenant_id": "123e4567-e89b-12d3-a456-426614174000",
                "school_id": "223e4567-e89b-12d3-a456-426614174000",
                "name": "2026-2027",
                "code": "AY2026",
                "description": "Standard academic year session 2026-2027",
                "start_date": "2026-06-01",
                "end_date": "2027-04-30",
                "status": "UPCOMING",
                "is_current": False,
                "settings": {
                    "grading_scale": "GPA_4",
                    "passing_percentage": 40.0,
                    "auto_promote_students": False
                },
                "version": 1,
                "created_at": "2026-07-31T12:00:00Z",
                "updated_at": "2026-07-31T12:00:00Z",
                "deleted_at": None,
                "created_by": None,
                "updated_by": None
            }
        }
    )
