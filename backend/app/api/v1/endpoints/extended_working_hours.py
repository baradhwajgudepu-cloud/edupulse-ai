import uuid
from typing import Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.common import get_tenant_id, get_db
from app.api.dependencies.auth import require_permission
from app.repositories.extended_working_hour import ExtendedWorkingHourRepository
from app.services.extended_working_hour import ExtendedWorkingHourService
from app.schemas.extended_working_hour import (
    ExtendedWorkingHourUpdate,
    ExtendedWorkingHourResponse,
    TimetableCapacitySummary,
    TimetableRecalculationPreview,
    ApplyRecalculatedTimingsRequest
)
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

def get_working_hour_service(db: AsyncSession = Depends(get_db)) -> ExtendedWorkingHourService:
    repo = ExtendedWorkingHourRepository(db)
    return ExtendedWorkingHourService(db, repo)

@router.get(
    "",
    response_model=APIResponse[ExtendedWorkingHourResponse],
    status_code=status.HTTP_200_OK,
    summary="Get school working hours and timetable capacity configuration"
)
async def get_school_working_hours(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: uuid.UUID = Query(..., description="Target academic year ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.read")),
    service: ExtendedWorkingHourService = Depends(get_working_hour_service)
) -> APIResponse[ExtendedWorkingHourResponse]:
    res = await service.get_or_create(school_id, academic_year_id, tenant_id)
    return APIResponse[ExtendedWorkingHourResponse](
        success=True,
        message="School working hours retrieved successfully.",
        data=res
    )

@router.put(
    "",
    response_model=APIResponse[ExtendedWorkingHourResponse],
    status_code=status.HTTP_200_OK,
    summary="Configure school working hours and extended teaching hours",
    description="Updates normal school hours, periods per day, and optional extended teaching hours."
)
async def update_school_working_hours(
    obj_in: ExtendedWorkingHourUpdate,
    school_id: Optional[uuid.UUID] = Query(None, description="Target school ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Target academic year ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.update")),
    service: ExtendedWorkingHourService = Depends(get_working_hour_service)
) -> APIResponse[ExtendedWorkingHourResponse]:
    target_school_id = school_id or obj_in.school_id
    target_ay_id = academic_year_id or obj_in.academic_year_id
    if not target_school_id or not target_ay_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="school_id and academic_year_id must be provided in query parameters or payload body."
        )
    res = await service.update_working_hours(target_school_id, target_ay_id, tenant_id, obj_in)
    return APIResponse[ExtendedWorkingHourResponse](
        success=True,
        message="School working hours updated successfully.",
        data=res
    )

@router.get(
    "/capacity",
    response_model=APIResponse[TimetableCapacitySummary],
    status_code=status.HTTP_200_OK,
    summary="Calculate timetable period capacity and shortfall summary",
    description="Calculates available weekly periods vs required subject periods, detecting capacity shortfalls."
)
async def get_timetable_capacity_summary(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: uuid.UUID = Query(..., description="Target academic year ID"),
    class_id: Optional[uuid.UUID] = Query(None, description="Optional filter by class"),
    section_id: Optional[uuid.UUID] = Query(None, description="Optional filter by section"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.read")),
    service: ExtendedWorkingHourService = Depends(get_working_hour_service)
) -> APIResponse[TimetableCapacitySummary]:
    res = await service.calculate_capacity_summary(
        school_id=school_id,
        academic_year_id=academic_year_id,
        tenant_id=tenant_id,
        class_id=class_id,
        section_id=section_id
    )
    return APIResponse[TimetableCapacitySummary](
        success=True,
        message="Timetable capacity summary calculated successfully.",
        data=res
    )

@router.post(
    "/preview-recalculation",
    response_model=APIResponse[TimetableRecalculationPreview],
    status_code=status.HTTP_200_OK,
    summary="Preview timetable period shifting and school hours extension",
    description="Calculates sequential period start/end times and calculates if an extension is required."
)
async def preview_timetable_recalculation(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    academic_year_id: uuid.UUID = Query(..., description="Target academic year ID"),
    obj_in: Optional[ApplyRecalculatedTimingsRequest] = None,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.read")),
    service: ExtendedWorkingHourService = Depends(get_working_hour_service)
) -> APIResponse[TimetableRecalculationPreview]:
    breaks = obj_in.breaks if obj_in else None
    period_dur = obj_in.period_duration_minutes if obj_in else None
    preview = await service.preview_timetable_recalculation(
        school_id=school_id,
        academic_year_id=academic_year_id,
        tenant_id=tenant_id,
        breaks=breaks,
        period_duration_minutes=period_dur
    )
    return APIResponse[TimetableRecalculationPreview](
        success=True,
        message="Timetable recalculation preview generated successfully.",
        data=preview
    )

@router.post(
    "/apply-recalculated-timings",
    response_model=APIResponse[dict],
    status_code=status.HTTP_200_OK,
    summary="Apply recalculated period timings and approved school hours extension",
    description="Updates working hours configuration and synchronizes start/end times for all active slots."
)
async def apply_recalculated_timings(
    req: ApplyRecalculatedTimingsRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("timetable.update")),
    service: ExtendedWorkingHourService = Depends(get_working_hour_service)
) -> APIResponse[dict]:
    result = await service.apply_recalculated_timings(tenant_id, req)
    return APIResponse[dict](
        success=True,
        message=f"Applied recalculated timings across {result['updated_slots_count']} timetable slot(s).",
        data={
            "updated_slots_count": result["updated_slots_count"],
            "new_end_time": result["new_end_time"]
        }
    )
