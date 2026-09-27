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
    
    # Code matching ^[A-Z0-9_-]{2,20}$ (auto-generated if omitted)
    code: Optional[str] = Field(
        None,
        pattern=r"^[A-Z0-9_-]{2,20}$",
        description="Unique uppercase alphanumeric identifier (auto-generated if omitted)"
    )
    
    board: Optional[SchoolBoard] = Field(None, description="Educational affiliation board (e.g. CBSE, ICSE)")
    school_type: Optional[SchoolType] = Field(None, description="Educational type classification (e.g. PRIMARY, HIGH_SCHOOL)")
    
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

    @computed_field
    @property
    def school_id(self) -> uuid.UUID:
        return self.id

    @computed_field
    @property
    def logo_updated_at(self) -> Optional[str]:
        if self.settings and isinstance(self.settings, dict):
            branding = self.settings.get("branding", {})
            if isinstance(branding, dict):
                return branding.get("logo_updated_at")
        return self.updated_at.isoformat() if self.updated_at else None

    @computed_field
    @property
    def logo_storage_key(self) -> Optional[str]:
        if self.settings and isinstance(self.settings, dict):
            branding = self.settings.get("branding", {})
            if isinstance(branding, dict):
                return branding.get("logo_storage_key")
        return None

    @computed_field
    @property
    def geofencing_enabled(self) -> bool:
        if self.settings and isinstance(self.settings, dict):
            gf = self.settings.get("geofence", {})
            if isinstance(gf, dict) and "enabled" in gf:
                return bool(gf["enabled"])
        return bool(self.latitude is not None and self.longitude is not None)

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


class SchoolLogoResponse(BaseModel):
    school_id: uuid.UUID
    logo_url: str
    logo_storage_key: Optional[str] = None
    logo_updated_at: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class SchoolGeofenceUpdate(BaseModel):
    """
    Schema for configuring school geofence coordinates and attendance radius.
    """
    enabled: bool = Field(True, description="Whether attendance geofencing is enforced for this school")
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0, description="School latitude (-90 to +90)")
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0, description="School longitude (-180 to +180)")
    radius_meters: int = Field(100, gt=0, le=10000, description="Geofence radius in meters (1 to 10,000m)")

    @model_validator(mode="before")
    @classmethod
    def map_radius(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if "geofence_radius" in data and "radius_meters" not in data:
                data["radius_meters"] = data["geofence_radius"]
            elif "geofence_radius_meters" in data and "radius_meters" not in data:
                data["radius_meters"] = data["geofence_radius_meters"]
        return data

    @model_validator(mode="after")
    def validate_coordinates(self) -> "SchoolGeofenceUpdate":
        if self.enabled:
            if self.latitude is None or self.longitude is None:
                raise ValueError("Latitude and Longitude are required when geofencing is enabled.")
        else:
            if (self.latitude is None and self.longitude is not None) or (self.latitude is not None and self.longitude is None):
                raise ValueError("Latitude and Longitude must both be provided, or both be null.")
        return self


class SchoolGeofenceResponse(BaseModel):
    """
    Schema representing active school geofence configuration.
    """
    school_id: uuid.UUID
    enabled: bool
    latitude: Optional[float]
    longitude: Optional[float]
    radius_meters: int
    is_configured: bool
    updated_at: Optional[datetime] = None
    updated_by: Optional[uuid.UUID] = None

    model_config = ConfigDict(from_attributes=True)


class SchoolDataSummaryResponse(BaseModel):
    """
    Schema for pre-reset data summary and dry-run counts.
    Includes verification tokens, query health checks, and blocking dependencies.
    """
    school_id: uuid.UUID
    school_name: str
    tenant_id: uuid.UUID
    tenant_name: str
    records_to_delete: Dict[str, int]
    total_records_to_delete: int = 0
    records_to_preserve: Dict[str, Any]
    eligible: bool = True
    blocking_dependencies: list[str] = []
    query_errors: list[str] = []
    warnings: list[str] = []
    confirmation_token: Optional[str] = None
    token_expires_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class SchoolDataResetRequest(BaseModel):
    """
    Schema for initiating a permanent school data reset.
    Requires exact case-sensitive school name, explicit confirmation, non-empty reason,
    and a valid, unexpired confirmation token generated from the pre-reset summary.
    """
    school_name: str = Field(..., min_length=1, description="Exact case-sensitive legal name of the school")
    confirm_destruction: bool = Field(..., description="Explicit acknowledgement of permanent operational data deletion")
    reason: str = Field(..., min_length=3, description="Justification/audit reason for the reset")
    confirmation_token: str = Field(..., min_length=10, description="Cryptographically signed confirmation token from pre-reset data summary")


class SchoolDataResetResponse(BaseModel):
    """
    Schema representing the outcome of a school data reset operation.
    """
    audit_id: str
    status: str = "COMPLETED"
    school_id: uuid.UUID
    school_name: str
    tenant_id: uuid.UUID
    deleted_counts: Dict[str, int]
    total_records_deleted: int
    timestamp: datetime
    message: str = "School operational and onboarding data reset successfully."

    model_config = ConfigDict(from_attributes=True)


class QuickSchoolOnboardingRequest(BaseModel):
    """
    Minimal schema for initial quick school creation.
    Requires ONLY: school_name, principal_name, principal_email, principal_password.
    Logo and advanced metadata are optional.
    """
    school_name: str = Field(..., min_length=2, max_length=255, description="Legal name of the school")
    principal_name: str = Field(..., min_length=2, max_length=255, description="Full name of the Principal / Head of Institution")
    principal_email: EmailStr = Field(..., description="Principal login email / ID")
    principal_password: str = Field(..., min_length=8, max_length=128, description="Secure account password")

    # Optional fields - never defaulted to CBSE/HIGH_SCHOOL
    logo_base64: Optional[str] = Field(None, description="Optional base64 or data URI of school logo")
    board: Optional[str] = Field(None, max_length=100, description="Optional affiliation board; remains Not Configured if omitted")
    school_type: Optional[str] = Field(None, max_length=100, description="Optional school type; remains Not Configured if omitted")
    school_code: Optional[str] = Field(None, max_length=20, description="Optional custom school code; globally auto-generated if omitted")
    phone: Optional[str] = Field(None, max_length=50, description="Contact phone number")
    address: Optional[str] = Field(None, max_length=255, description="Campus street address")
    city: Optional[str] = Field(None, max_length=100, description="City")
    state: Optional[str] = Field(None, max_length=100, description="State")
    postal_code: Optional[str] = Field(None, max_length=20, description="Postal / PIN code")
    website: Optional[str] = Field(None, max_length=255, description="School website URL")
    custom_fields: Optional[Dict[str, Any]] = Field(default_factory=dict, description="School custom metadata")


class QuickSchoolOnboardingResponse(BaseModel):
    """
    Response returned upon successful atomic school onboarding.
    Provides tenant context, school details, principal identity, and immediate access token.
    """
    tenant_id: str
    tenant_name: str
    tenant_code: str
    subdomain: str

    school_id: str
    school_name: str
    school_code: str
    board: str
    school_type: str
    logo_url: Optional[str] = None

    principal_id: str
    principal_name: str
    principal_email: str

    access_token: str
    token_type: str = "bearer"
    status: str = "ACTIVE"
    message: str = "School created and activated successfully. Principal account provisioned."

    model_config = ConfigDict(from_attributes=True)


class SetupStepItem(BaseModel):
    step_key: str
    title: str
    description: str
    is_completed: bool
    route: str
    action_label: str

    model_config = ConfigDict(from_attributes=True)


class SchoolSetupProgressResponse(BaseModel):
    school_id: str
    school_name: str
    completed_count: int
    total_steps: int
    progress_percentage: int
    steps: list[SetupStepItem]

    model_config = ConfigDict(from_attributes=True)

