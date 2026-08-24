import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.syllabus import get_syllabus_service
from app.api.dependencies.auth import require_permission
from app.services.syllabus import SyllabusService
from app.schemas.syllabus import SyllabusCreate, SyllabusUpdate, SyllabusResponse
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new syllabus entry"
)
async def create_syllabus(
    obj_in: SyllabusCreate,
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.create")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    db_obj = await service.create_syllabus_entry(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        obj_in=obj_in,
        current_user=current_user
    )
    return APIResponse[SyllabusResponse](
        success=True,
        message="Syllabus entry created successfully.",
        data=SyllabusResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[SyllabusResponse]],
    status_code=status.HTTP_200_OK,
    summary="List syllabus entries"
)
async def list_syllabuses(
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    subject_id: Optional[uuid.UUID] = Query(None),
    search: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.read")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[List[SyllabusResponse]]:
    db_objs = await service.syllabus_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        subject_id=subject_id,
        search=search,
        skip=skip,
        limit=limit
    )
    return APIResponse[List[SyllabusResponse]](
        success=True,
        message="Syllabus entries listed successfully.",
        data=[SyllabusResponse.model_validate(s) for s in db_objs]
    )

@router.get(
    "/{id}",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single syllabus entry details"
)
async def get_syllabus(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.read")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    db_obj = await service.syllabus_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Syllabus entry not found."
        )
    return APIResponse[SyllabusResponse](
        success=True,
        message="Syllabus entry details fetched successfully.",
        data=SyllabusResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_200_OK,
    summary="Update syllabus entry"
)
async def update_syllabus(
    id: uuid.UUID,
    obj_in: SyllabusUpdate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.update")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    db_obj = await service.update_syllabus_entry(tenant_id, school_id, id, obj_in, current_user)
    return APIResponse[SyllabusResponse](
        success=True,
        message="Syllabus entry updated successfully.",
        data=SyllabusResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_200_OK,
    summary="Delete syllabus entry"
)
async def delete_syllabus(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("syllabus.delete")),
    service: SyllabusService = Depends(get_syllabus_service)
) -> APIResponse[SyllabusResponse]:
    db_obj = await service.delete_syllabus_entry(tenant_id, school_id, id, current_user)
    return APIResponse[SyllabusResponse](
        success=True,
        message="Syllabus entry deleted successfully.",
        data=SyllabusResponse.model_validate(db_obj)
    )
