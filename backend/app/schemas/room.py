import uuid
from datetime import datetime
from typing import Optional, Dict, Any
from pydantic import BaseModel, ConfigDict, Field

class RoomBase(BaseModel):
    room_number: str = Field(..., min_length=1, max_length=50, description="e.g. 101, Lab-2, Aud-1")
    name: str = Field(..., min_length=1, max_length=100, description="e.g. Physics Lab, Room 101")
    room_type: str = Field(default="CLASSROOM", max_length=50, description="CLASSROOM, LAB, LIBRARY, AUDITORIUM, etc.")
    capacity: int = Field(default=40, ge=1, description="Maximum student capacity")
    floor: Optional[str] = Field(None, max_length=20, description="e.g. Ground, 1st Floor")
    building: Optional[str] = Field(None, max_length=100, description="e.g. Main Block, Science Wing")
    is_active: bool = Field(default=True)
    settings: Dict[str, Any] = Field(default_factory=dict)

class RoomCreate(RoomBase):
    school_id: uuid.UUID

class RoomUpdate(BaseModel):
    room_number: Optional[str] = Field(None, min_length=1, max_length=50)
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    room_type: Optional[str] = Field(None, max_length=50)
    capacity: Optional[int] = Field(None, ge=1)
    floor: Optional[str] = Field(None, max_length=20)
    building: Optional[str] = Field(None, max_length=100)
    is_active: Optional[bool] = None
    settings: Optional[Dict[str, Any]] = None

class RoomResponse(RoomBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)
