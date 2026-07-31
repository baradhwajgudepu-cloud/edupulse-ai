import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.academic_year import get_academic_year_service
from app.api.dependencies.auth import require_permission
from app.services.academic_year import AcademicYearService
from app.schemas.academic_year import AcademicYearCreate, AcademicYearUpdate, AcademicYearResponse
from app.models.academic_year import AcademicYearStatus
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[AcademicYearResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new academic year",
    description="Registers a new academic year under the specified school, checking duplicate constraints and date overlaps."
)
async def create_academic_year(
    school_id: uuid.UUID,
    obj_in: AcademicYearCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: AcademicYearService = Depends(get_academic_year_service),
    current_user = Depends(require_permission("academic_year.create"))
) -> APIResponse[AcademicYearResponse]:
    ay = await service.create_academic_year(tenant_id, school_id, obj_in)
    return APIResponse[AcademicYearResponse](
        success=True,
        message="Academic year created successfully.",
        data=AcademicYearResponse.model_validate(ay)
    )

@router.get(
    "",
    response_model=APIResponse[List[AcademicYearResponse]],
    status_code=status.HTTP_200_OK,
    summary="List academic years under school",
    description="Retrieves a paginated list of academic years scoped by tenant and school."
)
async def list_academic_years(
    school_id: uuid.UUID,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    status: Optional[AcademicYearStatus] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: AcademicYearService = Depends(get_academic_year_service),
    current_user = Depends(require_permission("academic_year.read"))
) -> APIResponse[List[AcademicYearResponse]]:
    academic_years = await service.list_academic_years(
        school_id=school_id,
        tenant_id=tenant_id,
        skip=skip,
        limit=limit,
        status_filter=status
    )
    responses = [AcademicYearResponse.model_validate(ay) for ay in academic_years]
    return APIResponse[List[AcademicYearResponse]](
        success=True,
        message="Academic years fetched successfully.",
        data=responses
    )

@router.get(
    "/current",
    response_model=APIResponse[AcademicYearResponse],
    status_code=status.HTTP_200_OK,
    summary="Get current academic year",
    description="Fetches details of the year marked current under the school."
)
async def get_current_academic_year(
    school_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: AcademicYearService = Depends(get_academic_year_service),
    current_user = Depends(require_permission("academic_year.read"))
) -> APIResponse[AcademicYearResponse]:
    ay = await service.get_current_academic_year(school_id, tenant_id)
    return APIResponse[AcademicYearResponse](
        success=True,
        message="Current academic year fetched successfully.",
        data=AcademicYearResponse.model_validate(ay)
    )

@router.get(
    "/{id}",
    response_model=APIResponse[AcademicYearResponse],
    status_code=status.HTTP_200_OK,
    summary="Get academic year details",
    description="Retrieves details of a specific active academic year by UUID scoped by tenant and school."
)
async def get_academic_year(
    school_id: uuid.UUID,
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: AcademicYearService = Depends(get_academic_year_service),
    current_user = Depends(require_permission("academic_year.read"))
) -> APIResponse[AcademicYearResponse]:
    ay = await service.get_academic_year(id, school_id, tenant_id)
    return APIResponse[AcademicYearResponse](
        success=True,
        message="Academic year details fetched successfully.",
        data=AcademicYearResponse.model_validate(ay)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[AcademicYearResponse],
    status_code=status.HTTP_200_OK,
    summary="Update academic year details",
    description="Modifies academic year attributes scoped by tenant and school."
)
async def update_academic_year(
    school_id: uuid.UUID,
    id: uuid.UUID,
    obj_in: AcademicYearUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: AcademicYearService = Depends(get_academic_year_service),
    current_user = Depends(require_permission("academic_year.update"))
) -> APIResponse[AcademicYearResponse]:
    ay = await service.update_academic_year(tenant_id, school_id, id, obj_in)
    return APIResponse[AcademicYearResponse](
        success=True,
        message="Academic year updated successfully.",
        data=AcademicYearResponse.model_validate(ay)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[AcademicYearResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete academic year",
    description="Soft-deletes the selected year scoped by tenant and school, blocking deletes on current years."
)
async def delete_academic_year(
    school_id: uuid.UUID,
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: AcademicYearService = Depends(get_academic_year_service),
    current_user = Depends(require_permission("academic_year.delete"))
) -> APIResponse[AcademicYearResponse]:
    ay = await service.delete_academic_year(tenant_id, school_id, id)
    return APIResponse[AcademicYearResponse](
        success=True,
        message="Academic year deleted successfully.",
        data=AcademicYearResponse.model_validate(ay)
    )

@router.post(
    "/{id}/activate",
    response_model=APIResponse[AcademicYearResponse],
    status_code=status.HTTP_200_OK,
    summary="Activate academic year",
    description="Transitions status to ACTIVE."
)
async def activate_academic_year(
    school_id: uuid.UUID,
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: AcademicYearService = Depends(get_academic_year_service),
    current_user = Depends(require_permission("academic_year.update"))
) -> APIResponse[AcademicYearResponse]:
    ay = await service.activate_academic_year(tenant_id, school_id, id)
    return APIResponse[AcademicYearResponse](
        success=True,
        message="Academic year activated successfully.",
        data=AcademicYearResponse.model_validate(ay)
    )

@router.post(
    "/{id}/archive",
    response_model=APIResponse[AcademicYearResponse],
    status_code=status.HTTP_200_OK,
    summary="Archive academic year",
    description="Transitions status to ARCHIVED."
)
async def archive_academic_year(
    school_id: uuid.UUID,
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: AcademicYearService = Depends(get_academic_year_service),
    current_user = Depends(require_permission("academic_year.update"))
) -> APIResponse[AcademicYearResponse]:
    ay = await service.archive_academic_year(tenant_id, school_id, id)
    return APIResponse[AcademicYearResponse](
        success=True,
        message="Academic year archived successfully.",
        data=AcademicYearResponse.model_validate(ay)
    )
