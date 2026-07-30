from fastapi import APIRouter
from app.api.v1.endpoints import health, tenants, schools

api_router = APIRouter()

# Include system-level endpoints (e.g. system/health)
api_router.include_router(health.router, prefix="/system", tags=["system"])

# Include tenants endpoints
api_router.include_router(tenants.router, prefix="/tenants", tags=["tenants"])

# Include schools endpoints
api_router.include_router(schools.router, prefix="/schools", tags=["schools"])
