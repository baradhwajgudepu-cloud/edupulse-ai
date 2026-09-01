from datetime import datetime
import uuid
from typing import Optional, Dict, Any
from pydantic import BaseModel, ConfigDict, EmailStr, Field, model_validator, computed_field
from app.models.school import SchoolBoard, SchoolType, SchoolStatus

class SchoolBase(BaseModel):
    """
    Base properties shared across School schemas.
    Enforces strict regex constraints matching school codes, Indian phones, PINs, and UDISE.
    """
    name: str = Field(..., min_length=1, max_length=255, description="Legal name of the school campus")
    display_name: Optional[str] = Field(None, max_length=255, description="Display name for branding/UI headers")
    
    # Code matching ^[A-Z0-9_-]{2,20}$
    code: str = Field(
        ...,
        pattern=r"^[A-Z0-9_-]{2,20}$",
        description="Unique uppercase alphanumeric identifier within the tenant (e.g. MAIN, CBSE_01)"
    )
    
    board: SchoolBoard = Field(..., description="Educational affiliation board (e.g. CBSE, ICSE)")
    school_type: SchoolType = Field(SchoolType.HIGH_SCHOOL, description="Educational type classification (e.g. PRIMARY, HIGH_SCHOOL)")
    
    email: EmailStr = Field(..., description="Primary school contact email address")
    
    # Indian mobile/landline check
    phone: Optional[str] = Field(
        None,
        pattern=r"^(?:\+91|0)?[6-9]\d{9}$",
        description="Indian phone contact number (e.g. +919876543210)"
    )
    
    website: Optional[str] = Field(None, max_length=255)
    principal_name: Optional[str] = Field(None, max_length=255)
    
    address: Optional[str] = Field(None, max_length=255)
    city: Optional[str] = Field(None, max_length=100)
    state: Optional[str] = Field(None, max_length=100)
    country: Optional[str] = Field("India", max_length=100, description="Configurable country boundary")
    
    # 6-digit Indian PIN code check
    postal_code: Optional[str] = Field(
        None,
        pattern=r"^[1-9][0-9]{5}$",
        description="6-digit Indian PIN Code (e.g. 500081)"
    )
    
    logo_url: Optional[str] = Field(None, max_length=1024, description="Persisted path or URL of the school logo")
    
    is_active: bool = Field(True, description="Enables/disables school operations")
    status: SchoolStatus = Field(SchoolStatus.ACTIVE, description="Operational status of the school campus")
    
    # Settings JSONB schema representation
    settings: Dict[str, Any] = Field(
        default_factory=dict,
        description="""
        Custom settings flags for school modules. Examples:
        {
          "attendance": true,
          "library": true,
          "transport": false,
          "hostel": false,
          "biometric": true
        }
        """
    )
    
    # UDISE Code (11-digit school registry number)
    udise_code: Optional[str] = Field(
        None,
        pattern=r"^[0-9]{11}$",
        description="11-digit Unified District Information System for Education code"
    )

    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0, description="School latitude coordinates")
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0, description="School longitude coordinates")
    geofence_radius_meters: int = Field(100, gt=0, le=10000, description="School geofence radius in meters (max 10,000m)")

    @model_validator(mode="before")
    @classmethod
    def map_geofence_radius(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if "geofence_radius" in data and "geofence_radius_meters" not in data:
                data["geofence_radius_meters"] = data["geofence_radius"]
        return data

    @model_validator(mode="after")
    def validate_geofence(self) -> "SchoolBase":
        lat = self.latitude
        lon = self.longitude
        if (lat is None and lon is not None) or (lat is not None and lon is None):
            raise ValueError("Latitude and Longitude must both be provided, or both be null.")
        return self

class SchoolCreate(SchoolBase):
    """
    Schema for creating a School record.
    """
    pass

class SchoolUpdate(BaseModel):
    """
    Schema for updating a School record. All fields are optional.
    """
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    display_name: Optional[str] = Field(None, max_length=255)
    code: Optional[str] = Field(None, pattern=r"^[A-Z0-9_-]{2,20}$")
    
    board: Optional[SchoolBoard] = None
    school_type: Optional[SchoolType] = None
    
    email: Optional[EmailStr] = None
    phone: Optional[str] = Field(None, pattern=r"^(?:\+91|0)?[6-9]\d{9}$")
    website: Optional[str] = Field(None, max_length=255)
    principal_name: Optional[str] = Field(None, max_length=255)
    
    address: Optional[str] = Field(None, max_length=255)
    city: Optional[str] = Field(None, max_length=100)
    state: Optional[str] = Field(None, max_length=100)
    country: Optional[str] = Field(None, max_length=100)
    postal_code: Optional[str] = Field(None, pattern=r"^[1-9][0-9]{5}$")
    
    logo_url: Optional[str] = Field(None, max_length=1024)
    is_active: Optional[bool] = None
    status: Optional[SchoolStatus] = None
    settings: Optional[Dict[str, Any]] = None
    udise_code: Optional[str] = Field(None, pattern=r"^[0-9]{11}$")

    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0)
    geofence_radius_meters: Optional[int] = Field(None, gt=0, le=10000)

    @model_validator(mode="before")
    @classmethod
    def map_geofence_radius(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if "geofence_radius" in data and "geofence_radius_meters" not in data:
                data["geofence_radius_meters"] = data["geofence_radius"]
        return data

    @model_validator(mode="after")
    def validate_geofence(self) -> "SchoolUpdate":
        fields = self.model_fields_set
        has_lat = "latitude" in fields
        has_lon = "longitude" in fields
        
        # If either is explicitly provided, BOTH must be provided
        if has_lat != has_lon:
            raise ValueError("Latitude and Longitude must both be updated together, or both be omitted.")
        
        if has_lat and has_lon:
            lat = self.latitude
            lon = self.longitude
            if (lat is None and lon is not None) or (lat is not None and lon is None):
                raise ValueError("Latitude and Longitude must both be values, or both be null.")
        return self

class SchoolResponse(SchoolBase):
    """
    Schema representing the School details returned in API payloads.
    """
    id: uuid.UUID
    tenant_id: uuid.UUID
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None
    created_by: Optional[uuid.UUID] = None
    updated_by: Optional[uuid.UUID] = None

    @computed_field
    @property
    def geofence_radius(self) -> int:
        return self.geofence_radius_meters

    @computed_field
    @property
    def branding_logo_url(self) -> Optional[str]:
        return self.logo_url

    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "example": {
                "id": "223e4567-e89b-12d3-a456-426614174000",
                "tenant_id": "123e4567-e89b-12d3-a456-426614174000",
                "name": "Sri Chaitanya High School - Madhapur",
                "display_name": "Sri Chaitanya Madhapur",
                "code": "HYD_MADHAPUR",
                "board": "CBSE",
                "school_type": "HIGH_SCHOOL",
                "email": "madhapur@srichaitanya.edu.in",
                "phone": "+919876543211",
                "website": "https://srichaitanya.edu.in/madhapur",
                "principal_name": "Dr. K. R. Rao",
                "address": "Plot 45, Hitec City Road",
                "city": "Hyderabad",
                "state": "Telangana",
                "country": "India",
                "postal_code": "500081",
                "logo_url": "schools/logos/hyd_madhapur.png",
                "is_active": True,
                "status": "ACTIVE",
                "settings": {
                    "attendance": True,
                    "library": True,
                    "transport": False,
                    "hostel": False,
                    "biometric": True
                },
                "udise_code": "36210512345",
                "version": 1,
                "created_at": "2026-07-29T12:00:00Z",
                "updated_at": "2026-07-29T12:00:00Z",
                "deleted_at": None,
                "created_by": None,
                "updated_by": None
            }
        }
    )
