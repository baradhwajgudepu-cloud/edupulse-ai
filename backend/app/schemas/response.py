from typing import Generic, TypeVar, Any
from pydantic import BaseModel

T = TypeVar("T")

class APIResponse(BaseModel, Generic[T]):
    """
    Standardized API response envelope for all EduPulse AI endpoints.
    """
    success: bool
    message: str
    data: T | None = None
