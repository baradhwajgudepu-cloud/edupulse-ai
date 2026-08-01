import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.class_entity import get_class_service
from app.api.dependencies.auth import require_permission
from app.services.class_entity import ClassService
from app.schemas.class_entity import ClassCreate, ClassUpdate, ClassResponse
from app.models.class_entity import ClassStatus
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[ClassResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new class",
    description="Creates a new academic class within a school and academic year, enforcing capacity boundaries and duplicate checks."
)
async def create_class(
    obj_in: ClassCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("class.create")),
    service: ClassService = Depends(get_class_service)
) -> APIResponse[ClassResponse]:
    db_obj = await service.create_class(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[ClassResponse](
        success=True,
        message="Class created successfully.",
        data=ClassResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[ClassResponse]],
    status_code=status.HTTP_200_OK,
    summary="List classes under school",
    description="Retrieves a paginated list of classes scoped by tenant, school, and academic year."
)
async def list_classes(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Filter by Academic Year ID"),
    status_filter: Optional[ClassStatus] = Query(None, alias="status", description="Filter by class status"),
    search: Optional[str] = Query(None, description="Fuzzy match search on name or code"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("class.read")),
    service: ClassService = Depends(get_class_service)
) -> APIResponse[List[ClassResponse]]:
    classes = await service.class_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        status=status_filter,
        search=search,
        skip=skip,
        limit=limit
    )
    responses = [ClassResponse.model_validate(c) for c in classes]
    return APIResponse[List[ClassResponse]](
        success=True,
        message="Classes fetched successfully.",
        data=responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[ClassResponse],
    status_code=status.HTTP_200_OK,
    summary="Get class details",
    description="Retrieves class attributes scoped by tenant and school."
)
async def get_class(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("class.read")),
    service: ClassService = Depends(get_class_service)
) -> APIResponse[ClassResponse]:
    db_obj = await service.class_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Class not found."
        )
    return APIResponse[ClassResponse](
        success=True,
        message="Class details fetched successfully.",
        data=ClassResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[ClassResponse],
    status_code=status.HTTP_200_OK,
    summary="Update class details",
    description="Modifies class properties scoped by tenant and school."
)
async def update_class(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: ClassUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("class.update")),
    service: ClassService = Depends(get_class_service)
) -> APIResponse[ClassResponse]:
    db_obj = await service.update_class(tenant_id, school_id, id, obj_in, updated_by=current_user.id)
    return APIResponse[ClassResponse](
        success=True,
        message="Class updated successfully.",
        data=ClassResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[ClassResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete class",
    description="Soft-deletes the class if no assigned sections exist."
)
async def delete_class(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("class.delete")),
    service: ClassService = Depends(get_class_service)
) -> APIResponse[ClassResponse]:
    db_obj = await service.delete_class(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[ClassResponse](
        success=True,
        message="Class deleted successfully.",
        data=ClassResponse.model_validate(db_obj)
    )

@router.post(
    "/{id}/archive",
    response_model=APIResponse[ClassResponse],
    status_code=status.HTTP_200_OK,
    summary="Archive class",
    description="Archives class and disables it from active course mappings."
)
async def archive_class(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("class.archive")),
    service: ClassService = Depends(get_class_service)
) -> APIResponse[ClassResponse]:
    db_obj = await service.archive_class(tenant_id, school_id, id, updated_by=current_user.id)
    return APIResponse[ClassResponse](
        success=True,
        message="Class archived successfully.",
        data=ClassResponse.model_validate(db_obj)
    )

@router.post(
    "/{id}/promote",
    response_model=APIResponse[ClassResponse],
    status_code=status.HTTP_200_OK,
    summary="Promote class routine",
    description="Runs promotion sequence and maps class promotion paths."
)
async def promote_class(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("class.promote")),
    service: ClassService = Depends(get_class_service)
) -> APIResponse[ClassResponse]:
    db_obj = await service.promote_class(tenant_id, school_id, id, updated_by=current_user.id)
    return APIResponse[ClassResponse](
        success=True,
        message="Class promotion sequence initialized.",
        data=ClassResponse.model_validate(db_obj)
    )
