import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.timetable import get_timetable_service
from app.api.dependencies.auth import require_permission
from app.services.timetable import TimetableService
from app.schemas.timetable import TimetableCreate, TimetableUpdate, TimetableResponse
from app.models.timetable import TimetableStatus, DayOfWeek
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[TimetableResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new timetable entry",
    description="Registers a new period slot for a class, section, day of week, and time range after resolving conflicts."
)
async def create_timetable(
    obj_in: TimetableCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.create")),
    service: TimetableService = Depends(get_timetable_service)
) -> APIResponse[TimetableResponse]:
    db_obj = await service.create_timetable_entry(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[TimetableResponse](
        success=True,
        message="Timetable entry registered successfully.",
        data=TimetableResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[TimetableResponse]],
    status_code=status.HTTP_200_OK,
    summary="List timetable entries",
    description="Retrieves a paginated list of timetable slots, joining teachers, subjects, classes, and sections. Supports search."
)
async def list_timetables(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Filter by Academic Year ID"),
    teacher_id: Optional[uuid.UUID] = Query(None, description="Filter by Teacher ID"),
    subject_id: Optional[uuid.UUID] = Query(None, description="Filter by Subject ID"),
    class_id: Optional[uuid.UUID] = Query(None, description="Filter by Class ID"),
    section_id: Optional[uuid.UUID] = Query(None, description="Filter by Section ID"),
    day_of_week: Optional[DayOfWeek] = Query(None, description="Filter by Day of Week"),
    status_filter: Optional[TimetableStatus] = Query(None, alias="status", description="Filter by status"),
    search: Optional[str] = Query(None, description="Fuzzy match search on teacher names, subjects, classes/sections"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.read")),
    service: TimetableService = Depends(get_timetable_service)
) -> APIResponse[List[TimetableResponse]]:
    entries = await service.timetable_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        teacher_id=teacher_id,
        subject_id=subject_id,
        class_id=class_id,
        section_id=section_id,
        day_of_week=day_of_week,
        status=status_filter,
        search=search,
        skip=skip,
        limit=limit
    )
    responses = [TimetableResponse.model_validate(e) for e in entries]
    return APIResponse[List[TimetableResponse]](
        success=True,
        message="Timetable entries fetched successfully.",
        data=responses
    )

@router.get(
    "/teacher-schedule",
    response_model=APIResponse[List[TimetableResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get teacher timetable schedule",
    description="Retrieves active timetable slots mapped to a teacher in an academic year."
)
async def get_teacher_schedule(
    teacher_id: uuid.UUID = Query(..., description="Target teacher ID"),
    academic_year_id: uuid.UUID = Query(..., description="Target academic year ID"),
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.read")),
    service: TimetableService = Depends(get_timetable_service)
) -> APIResponse[List[TimetableResponse]]:
    # Validate school context
    entries = await service.timetable_repo.get_teacher_schedule(teacher_id, academic_year_id, tenant_id)
    responses = [TimetableResponse.model_validate(e) for e in entries if e.school_id == school_id]
    return APIResponse[List[TimetableResponse]](
        success=True,
        message="Teacher timetable schedule fetched successfully.",
        data=responses
    )

@router.get(
    "/class-schedule",
    response_model=APIResponse[List[TimetableResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get class timetable schedule",
    description="Retrieves active timetable slots mapped to a class in an academic year."
)
async def get_class_schedule(
    class_id: uuid.UUID = Query(..., description="Target class ID"),
    academic_year_id: uuid.UUID = Query(..., description="Target academic year ID"),
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.read")),
    service: TimetableService = Depends(get_timetable_service)
) -> APIResponse[List[TimetableResponse]]:
    entries = await service.timetable_repo.get_class_schedule(class_id, academic_year_id, tenant_id)
    responses = [TimetableResponse.model_validate(e) for e in entries if e.school_id == school_id]
    return APIResponse[List[TimetableResponse]](
        success=True,
        message="Class timetable schedule fetched successfully.",
        data=responses
    )

@router.get(
    "/section-schedule",
    response_model=APIResponse[List[TimetableResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get section timetable schedule",
    description="Retrieves active timetable slots mapped to a specific section in an academic year."
)
async def get_section_schedule(
    class_id: uuid.UUID = Query(..., description="Target class ID"),
    section_id: uuid.UUID = Query(..., description="Target section ID"),
    academic_year_id: uuid.UUID = Query(..., description="Target academic year ID"),
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.read")),
    service: TimetableService = Depends(get_timetable_service)
) -> APIResponse[List[TimetableResponse]]:
    entries = await service.timetable_repo.get_section_schedule(class_id, section_id, academic_year_id, tenant_id)
    responses = [TimetableResponse.model_validate(e) for e in entries if e.school_id == school_id]
    return APIResponse[List[TimetableResponse]](
        success=True,
        message="Section timetable schedule fetched successfully.",
        data=responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[TimetableResponse],
    status_code=status.HTTP_200_OK,
    summary="Get timetable slot details",
    description="Retrieves details of a specific scheduled timetable slot."
)
async def get_timetable(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.read")),
    service: TimetableService = Depends(get_timetable_service)
) -> APIResponse[TimetableResponse]:
    db_obj = await service.timetable_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Timetable slot not found."
        )
    return APIResponse[TimetableResponse](
        success=True,
        message="Timetable slot details fetched successfully.",
        data=TimetableResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[TimetableResponse],
    status_code=status.HTTP_200_OK,
    summary="Update timetable slot details",
    description="Modifies scheduling properties, times, availability status of an existing slot."
)
async def update_timetable(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: TimetableUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.update")),
    service: TimetableService = Depends(get_timetable_service)
) -> APIResponse[TimetableResponse]:
    db_obj = await service.update_timetable_entry(tenant_id, school_id, id, obj_in, updated_by=current_user.id)
    return APIResponse[TimetableResponse](
        success=True,
        message="Timetable slot updated successfully.",
        data=TimetableResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[TimetableResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete timetable slot",
    description="Soft-deletes the slot, modifying status to ARCHIVED."
)
async def delete_timetable(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.delete")),
    service: TimetableService = Depends(get_timetable_service)
) -> APIResponse[TimetableResponse]:
    db_obj = await service.delete_timetable_entry(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[TimetableResponse](
        success=True,
        message="Timetable slot deleted successfully.",
        data=TimetableResponse.model_validate(db_obj)
    )
