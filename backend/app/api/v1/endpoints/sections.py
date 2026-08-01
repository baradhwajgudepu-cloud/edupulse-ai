import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.section import get_section_service
from app.api.dependencies.auth import require_permission
from app.services.section import SectionService
from app.schemas.section import SectionCreate, SectionUpdate, SectionResponse
from app.models.section import SectionStatus
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[SectionResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new section",
    description="Creates a new academic section within a class, enforcing capacity and unique code constraints."
)
async def create_section(
    obj_in: SectionCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("section.create")),
    service: SectionService = Depends(get_section_service)
) -> APIResponse[SectionResponse]:
    db_obj = await service.create_section(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[SectionResponse](
        success=True,
        message="Section created successfully.",
        data=SectionResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[SectionResponse]],
    status_code=status.HTTP_200_OK,
    summary="List sections under school",
    description="Retrieves a paginated list of sections scoped by tenant, school, academic year, and class."
)
async def list_sections(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Filter by Academic Year ID"),
    class_id: Optional[uuid.UUID] = Query(None, description="Filter by Class ID"),
    status_filter: Optional[SectionStatus] = Query(None, alias="status", description="Filter by section status"),
    search: Optional[str] = Query(None, description="Fuzzy match search on name or code"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("section.read")),
    service: SectionService = Depends(get_section_service)
) -> APIResponse[List[SectionResponse]]:
    sections = await service.section_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        status=status_filter,
        search=search,
        skip=skip,
        limit=limit
    )
    responses = [SectionResponse.model_validate(s) for s in sections]
    return APIResponse[List[SectionResponse]](
        success=True,
        message="Sections fetched successfully.",
        data=responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[SectionResponse],
    status_code=status.HTTP_200_OK,
    summary="Get section details",
    description="Retrieves section attributes scoped by tenant and school."
)
async def get_section(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("section.read")),
    service: SectionService = Depends(get_section_service)
) -> APIResponse[SectionResponse]:
    db_obj = await service.section_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Section not found."
        )
    return APIResponse[SectionResponse](
        success=True,
        message="Section details fetched successfully.",
        data=SectionResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[SectionResponse],
    status_code=status.HTTP_200_OK,
    summary="Update section details",
    description="Modifies section properties scoped by tenant and school."
)
async def update_section(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: SectionUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("section.update")),
    service: SectionService = Depends(get_section_service)
) -> APIResponse[SectionResponse]:
    db_obj = await service.update_section(tenant_id, school_id, id, obj_in, updated_by=current_user.id)
    return APIResponse[SectionResponse](
        success=True,
        message="Section updated successfully.",
        data=SectionResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[SectionResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete section",
    description="Soft-deletes the section."
)
async def delete_section(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("section.delete")),
    service: SectionService = Depends(get_section_service)
) -> APIResponse[SectionResponse]:
    db_obj = await service.delete_section(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[SectionResponse](
        success=True,
        message="Section deleted successfully.",
        data=SectionResponse.model_validate(db_obj)
    )
