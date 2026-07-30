from datetime import datetime
import uuid
from typing import Optional, Dict, Any
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
from app.models.tenant import TenantStatus

class TenantBase(BaseModel):
    """
    Base properties shared across Tenant schemas for Indian Institutions.
    Enforces regex formats for Indian PIN Codes, PANs, GSTINs, and phone numbers.
    """
    name: str = Field(..., min_length=1, max_length=255, description="Tenant organization legal name")
    display_name: Optional[str] = Field(None, max_length=255, description="Tenant display name for UI rendering")
    code: str = Field(
        ...,
        min_length=2,
        max_length=100,
        pattern=r"^[a-z0-9\-]+$",
        description="Unique alphanumeric code (lowercase, numbers, dashes)"
    )
    subdomain: str = Field(
        ...,
        min_length=2,
        max_length=100,
        pattern=r"^[a-z0-9\-]+$",
        description="Unique subdomain prefix (lowercase, numbers, dashes)"
    )
    email: EmailStr = Field(..., description="Organization primary email contact")
    
    # Indian mobile number validation (optional +91/0 prefix and 10 digits starting with 6-9)
    phone: Optional[str] = Field(
        None,
        pattern=r"^(?:\+91|0)?[6-9]\d{9}$",
        description="Indian contact number (e.g. +919876543210)"
    )
    website: Optional[str] = Field(None, max_length=255)
    logo_url: Optional[str] = Field(None, max_length=1024)
    
    # Defaults configured for Indian settings
    timezone: str = Field("Asia/Kolkata", max_length=50)
    currency: str = Field("INR", max_length=10)
    
    address: Optional[str] = Field(None, max_length=255)
    city: Optional[str] = Field(None, max_length=100)
    state: Optional[str] = Field(None, max_length=100, description="Indian State/UT name (e.g. Telangana)")
    country: Optional[str] = Field("India", max_length=100)
    
    # 6-digit Indian PIN code validation (starts with 1-9 followed by 5 digits)
    postal_code: Optional[str] = Field(
        None,
        pattern=r"^[1-9][0-9]{5}$",
        description="6-digit Indian PIN Code (e.g. 500081)"
    )
    
    # Indian Tax Registration fields
    pan: Optional[str] = Field(
        None,
        pattern=r"^[A-Z]{5}[0-9]{4}[A-Z]$",
        description="10-character alphanumeric Indian PAN card number"
    )
    gstin: Optional[str] = Field(
        None,
        pattern=r"^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$",
        description="15-character alphanumeric Indian GST Identification Number"
    )
    
    # Toggle and Enum flags
    is_active: bool = Field(True, description="Quick enable/disable switch for the tenant")
    status: TenantStatus = Field(TenantStatus.ACTIVE, description="Current operational status of the tenant")
    
    # Custom configurations
    settings: Dict[str, Any] = Field(default_factory=dict, description="Custom JSON configurations")
    
    # SaaS subscription parameters
    plan: Optional[str] = Field(None, max_length=50, description="Subscription plan name")
    subscription_start: Optional[datetime] = Field(None, description="Subscription start timestamp")
    subscription_end: Optional[datetime] = Field(None, description="Subscription end timestamp")

class TenantCreate(TenantBase):
    """
    Schema for creating a Tenant record.
    """
    pass

class TenantUpdate(BaseModel):
    """
    Schema for updating a Tenant record. All fields are optional and support identical validations.
    """
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    display_name: Optional[str] = Field(None, max_length=255)
    code: Optional[str] = Field(None, min_length=2, max_length=100, pattern=r"^[a-z0-9\-]+$")
    subdomain: Optional[str] = Field(None, min_length=2, max_length=100, pattern=r"^[a-z0-9\-]+$")
    email: Optional[EmailStr] = None
    
    phone: Optional[str] = Field(None, pattern=r"^(?:\+91|0)?[6-9]\d{9}$")
    website: Optional[str] = Field(None, max_length=255)
    logo_url: Optional[str] = Field(None, max_length=1024)
    
    timezone: Optional[str] = Field(None, max_length=50)
    currency: Optional[str] = Field(None, max_length=10)
    
    address: Optional[str] = Field(None, max_length=255)
    city: Optional[str] = Field(None, max_length=100)
    state: Optional[str] = Field(None, max_length=100)
    country: Optional[str] = Field(None, max_length=100)
    postal_code: Optional[str] = Field(None, pattern=r"^[1-9][0-9]{5}$")
    
    pan: Optional[str] = Field(None, pattern=r"^[A-Z]{5}[0-9]{4}[A-Z]$")
    gstin: Optional[str] = Field(None, pattern=r"^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$")
    
    is_active: Optional[bool] = None
    status: Optional[TenantStatus] = None
    settings: Optional[Dict[str, Any]] = None
    
    plan: Optional[str] = Field(None, max_length=50)
    subscription_start: Optional[datetime] = None
    subscription_end: Optional[datetime] = None

class TenantResponse(TenantBase):
    """
    Schema representing the Tenant details returned in API payloads.
    """
    id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None
    created_by: Optional[uuid.UUID] = None
    updated_by: Optional[uuid.UUID] = None

    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "example": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "name": "Sri Chaitanya Educational Institutions Pvt Ltd",
                "display_name": "Sri Chaitanya",
                "code": "sri-chaitanya",
                "subdomain": "srichaitanya",
                "email": "info@srichaitanya.edu.in",
                "phone": "+91-40-5550199",
                "website": "https://srichaitanya.edu.in",
                "logo_url": "https://srichaitanya.edu.in/logo.png",
                "timezone": "Asia/Kolkata",
                "currency": "INR",
                "address": "Plot No. 12, Tech Park",
                "city": "Hyderabad",
                "state": "Telangana",
                "country": "India",
                "postal_code": "500081",
                "pan": "ABCDE1234F",
                "gstin": "36ABCDE1234F1Z5",
                "is_active": True,
                "status": "ACTIVE",
                "settings": {
                    "attendance": True,
                    "fees": True,
                    "transport": False,
                    "library": True
                },
                "plan": "enterprise",
                "subscription_start": "2026-07-29T12:00:00Z",
                "subscription_end": "2027-07-29T12:00:00Z",
                "version": 1,
                "created_at": "2026-07-29T12:00:00Z",
                "updated_at": "2026-07-29T12:00:00Z",
                "deleted_at": None,
                "created_by": None,
                "updated_by": None
            }
        }
    )
