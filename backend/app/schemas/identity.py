import uuid
from typing import Optional
from pydantic import BaseModel, EmailStr, ConfigDict

class IdentityProvisionStatusResponse(BaseModel):
    """
    Schema for checking provisioning status of a Teacher or Guardian profile.
    """
    is_provisioned: bool
    user_id: Optional[uuid.UUID] = None
    email: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)

class IdentityResetPasswordResponse(BaseModel):
    """
    Schema returned after triggering a password reset, providing the new temporary credentials.
    """
    email: str
    temporary_password: str

    model_config = ConfigDict(from_attributes=True)

class PrincipalProvisionRequest(BaseModel):
    """
    Schema for provisioning an authenticated Principal User account.
    """
    email: EmailStr
    first_name: str
    last_name: Optional[str] = ""
    phone: Optional[str] = None
    password: Optional[str] = None
    school_id: uuid.UUID

    model_config = ConfigDict(from_attributes=True)



from app.schemas.auth import UserResponse
from app.schemas.teacher import TeacherResponse

class IdentityMeResponse(BaseModel):
    user: UserResponse
    teacher: Optional[TeacherResponse] = None

    model_config = ConfigDict(from_attributes=True)
