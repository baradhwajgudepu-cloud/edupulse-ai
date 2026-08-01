from fastapi import APIRouter
from app.api.v1.endpoints import health, tenants, schools, academic_years, auth, classes, sections, students

api_router = APIRouter()

# Include system-level endpoints (e.g. system/health)
api_router.include_router(health.router, prefix="/system", tags=["system"])

# Include authentication & RBAC endpoints (no prefix, endpoints themselves have prefix)
api_router.include_router(auth.router, prefix="", tags=["auth"])

# Include tenants endpoints
api_router.include_router(tenants.router, prefix="/tenants", tags=["tenants"])

# Include schools endpoints
api_router.include_router(schools.router, prefix="/schools", tags=["schools"])

# Include academic_years endpoints (using school path parameters)
api_router.include_router(academic_years.router, prefix="/schools/{school_id}/academic-years", tags=["academic_years"])

# Include classes endpoints
api_router.include_router(classes.router, prefix="/classes", tags=["classes"])

# Include sections endpoints
api_router.include_router(sections.router, prefix="/sections", tags=["sections"])

# Include students endpoints
api_router.include_router(students.router, prefix="/students", tags=["students"])
