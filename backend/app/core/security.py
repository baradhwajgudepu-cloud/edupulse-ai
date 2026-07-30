import uuid
from typing import List, Optional
from datetime import datetime, timedelta, timezone

# Password hashing placeholders
def hash_password(password: str) -> str:
    """
    Placeholder for hashing a plaintext password.
    To be implemented using passlib[bcrypt].
    """
    raise NotImplementedError("Password hashing is not implemented in this foundation module.")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Placeholder for verifying a plaintext password against its hash.
    """
    raise NotImplementedError("Password verification is not implemented in this foundation module.")

# JWT Token placeholders
def create_access_token(subject: str | uuid.UUID, expires_delta: Optional[timedelta] = None) -> str:
    """
    Placeholder for generating a JWT access token.
    """
    raise NotImplementedError("JWT Access Token generation is not implemented in this foundation module.")

def decode_access_token(token: str) -> dict:
    """
    Placeholder for decoding and verifying a JWT access token.
    """
    raise NotImplementedError("JWT Access Token decoding is not implemented in this foundation module.")

# Role Based Access Control (RBAC) placeholders
class RoleChecker:
    """
    Placeholder class for enforcing Role Based Access Control (RBAC).
    Usage example in route dependencies: Depends(RoleChecker(["admin", "teacher"]))
    """
    def __init__(self, allowed_roles: List[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, token_data: dict) -> bool:
        """
        Validates if the user's role satisfies the allowed roles.
        """
        raise NotImplementedError("Role-based access control is not implemented in this foundation module.")
