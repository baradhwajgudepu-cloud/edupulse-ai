import uuid
from datetime import date, time, datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field

from app.models.school_event import EventAudience, EventStatus

class SchoolEventCreate(BaseModel):
    event_name: str = Field(..., max_length=200, min_length=1)
    description: Optional[str] = None
    event_date: date
    start_time: time
    end_time: time
    venue: Optional[str] = Field(None, max_length=200)
    target_audience: EventAudience = EventAudience.ALL
    is_holiday: bool = False

class SchoolEventUpdate(BaseModel):
    event_name: Optional[str] = Field(None, max_length=200, min_length=1)
    description: Optional[str] = None
    event_date: Optional[date] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    venue: Optional[str] = Field(None, max_length=200)
    target_audience: Optional[EventAudience] = None
    status: Optional[EventStatus] = None
    is_holiday: Optional[bool] = None

class SchoolEventResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    academic_year_id: uuid.UUID
    event_name: str
    description: Optional[str] = None
    event_date: date
    start_time: time
    end_time: time
    venue: Optional[str] = None
    target_audience: EventAudience
    status: EventStatus
    is_holiday: bool
    is_active: bool
    version: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
