import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.subject import get_subject_service
from app.api.dependencies.auth import require_permission
from app.services.subject import SubjectService
from app.schemas.subject import SubjectCreate, SubjectUpdate, SubjectResponse
from app.models.subject import SubjectStatus, SubjectCategory
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[SubjectResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new academic subject",
    description="Registers a new subject in the academic year catalog, validating theory/practical marks boundaries."
)
async def create_subject(
    obj_in: SubjectCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("subject.create")),
    service: SubjectService = Depends(get_subject_service)
) -> APIResponse[SubjectResponse]:
    db_obj = await service.create_subject(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[SubjectResponse](
        success=True,
        message="Subject registered successfully.",
        data=SubjectResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[SubjectResponse]],
    status_code=status.HTTP_200_OK,
    summary="List subjects",
    description="Retrieves a paginated list of subjects scoped by tenant and school."
)
async def list_subjects(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Filter by Academic Year ID"),
    category: Optional[SubjectCategory] = Query(None, description="Filter by category"),
    status_filter: Optional[SubjectStatus] = Query(None, alias="status", description="Filter by subject status"),
    search: Optional[str] = Query(None, description="Fuzzy match search on subject name, code, and short name"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("subject.read")),
    service: SubjectService = Depends(get_subject_service)
) -> APIResponse[List[SubjectResponse]]:
    subjects = await service.subject_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        category=category,
        status=status_filter,
        search=search,
        skip=skip,
        limit=limit
    )
    responses = [SubjectResponse.model_validate(s) for s in subjects]
    return APIResponse[List[SubjectResponse]](
        success=True,
        message="Subjects fetched successfully.",
        data=responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[SubjectResponse],
    status_code=status.HTTP_200_OK,
    summary="Get subject profile details",
    description="Retrieves subject profile attributes scoped by tenant and school."
)
async def get_subject(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("subject.read")),
    service: SubjectService = Depends(get_subject_service)
) -> APIResponse[SubjectResponse]:
    db_obj = await service.subject_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Subject not found."
        )
    return APIResponse[SubjectResponse](
        success=True,
        message="Subject details fetched successfully.",
        data=SubjectResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[SubjectResponse],
    status_code=status.HTTP_200_OK,
    summary="Update subject details",
    description="Modifies subject parameters scoped by tenant and school."
)
async def update_subject(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: SubjectUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("subject.update")),
    service: SubjectService = Depends(get_subject_service)
) -> APIResponse[SubjectResponse]:
    db_obj = await service.update_subject(tenant_id, school_id, id, obj_in, updated_by=current_user.id)
    return APIResponse[SubjectResponse](
        success=True,
        message="Subject updated successfully.",
        data=SubjectResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[SubjectResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete subject profile",
    description="Soft-deletes the subject profile, updating status to ARCHIVED."
)
async def delete_subject(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("subject.delete")),
    service: SubjectService = Depends(get_subject_service)
) -> APIResponse[SubjectResponse]:
    db_obj = await service.delete_subject(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[SubjectResponse](
        success=True,
        message="Subject deleted successfully.",
        data=SubjectResponse.model_validate(db_obj)
    )
