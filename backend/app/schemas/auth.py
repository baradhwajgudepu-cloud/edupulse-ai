import re
import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, ConfigDict, Field, EmailStr, field_validator
from app.models.user import UserStatus

def validate_password_strength(password: str) -> str:
    """
    Enforces password complexity:
    - Min 8 characters
    - At least 1 uppercase letter
    - At least 1 lowercase letter
    - At least 1 digit
    - At least 1 special character
    """
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters long.")
    if not re.search(r"[A-Z]", password):
        raise ValueError("Password must contain at least one uppercase letter.")
    if not re.search(r"[a-z]", password):
        raise ValueError("Password must contain at least one lowercase letter.")
    if not re.search(r"[0-9]", password):
        raise ValueError("Password must contain at least one digit.")
    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        raise ValueError("Password must contain at least one special character.")
    return password

# --- AUTHENTICATION SCHEMAS ---

class LoginRequest(BaseModel):
    email: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def check_password(cls, v: str) -> str:
        return validate_password_strength(v)

class PasswordResetRequest(BaseModel):
    email: EmailStr

class PasswordResetConfirm(BaseModel):
    token: str = Field(..., description="The password reset token received by the user")
    new_password: str

    @field_validator("new_password")
    @classmethod
    def check_password(cls, v: str) -> str:
        return validate_password_strength(v)

# --- RBAC SCHEMAS ---

class PermissionResponse(BaseModel):
    id: uuid.UUID
    name: str
    code: str
    description: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class RoleBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    code: str = Field(..., min_length=1, max_length=50, pattern=r"^[A-Z0-9_-]+$")
    description: Optional[str] = Field(None, max_length=500)

class RoleCreate(RoleBase):
    permission_ids: Optional[List[uuid.UUID]] = Field(default_factory=list)

class RoleUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    code: Optional[str] = Field(None, min_length=1, max_length=50, pattern=r"^[A-Z0-9_-]+$")
    description: Optional[str] = Field(None, max_length=500)
    permission_ids: Optional[List[uuid.UUID]] = None

class RoleResponse(RoleBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    is_system: bool
    permissions: List[PermissionResponse] = Field(default_factory=list)
    version: int

    model_config = ConfigDict(from_attributes=True)

# --- USER SCHEMAS ---

class UserBase(BaseModel):
    email: EmailStr
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)

class UserCreate(UserBase):
    password: str
    school_ids: List[uuid.UUID] = Field(default_factory=list, description="Schools this user belongs to")
    role_ids: List[uuid.UUID] = Field(default_factory=list, description="Roles assigned to this user")

    @field_validator("password")
    @classmethod
    def check_password(cls, v: str) -> str:
        return validate_password_strength(v)

class UserUpdate(BaseModel):
    first_name: Optional[str] = Field(None, min_length=1, max_length=100)
    last_name: Optional[str] = Field(None, min_length=1, max_length=100)
    status: Optional[UserStatus] = None
    school_ids: Optional[List[uuid.UUID]] = None
    role_ids: Optional[List[uuid.UUID]] = None

class SchoolStub(BaseModel):
    id: uuid.UUID
    name: str
    code: str

    model_config = ConfigDict(from_attributes=True)

class UserResponse(UserBase):
    id: uuid.UUID
    tenant_id: Optional[uuid.UUID] = None
    login_id: Optional[str] = None
    status: UserStatus
    is_superuser: bool
    must_change_password: bool = False
    schools: List[SchoolStub] = Field(default_factory=list)
    roles: List[RoleResponse] = Field(default_factory=list)
    version: int
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)

class BootstrapRequest(BaseModel):
    email: EmailStr = Field("admin@edupulse.com")
    password: str = Field("Admin@123")
    first_name: str = Field("System")
    last_name: str = Field("Administrator")

    @field_validator("password")
    @classmethod
    def check_password(cls, v: str) -> str:
        return validate_password_strength(v)

class BootstrapResponse(BaseModel):
    message: str = "System initialized successfully."
    admin_email: str

class ProvisioningCredentialResponse(BaseModel):
    user_id: uuid.UUID
    login_id: Optional[str] = None
    email: str
    temporary_password: Optional[str] = None
    role: str

