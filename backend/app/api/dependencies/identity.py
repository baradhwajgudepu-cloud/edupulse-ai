from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.services.identity_provisioning import IdentityProvisioningService

def get_identity_service(
    db: AsyncSession = Depends(get_db)
) -> IdentityProvisioningService:
    """
    Dependency provider returning the IdentityProvisioningService.
    """
    return IdentityProvisioningService(db)
