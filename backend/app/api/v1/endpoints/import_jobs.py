import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException, UploadFile, File

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import require_permission
from app.api.dependencies.import_job import get_import_job_service
from app.services.import_job import ImportJobService
from app.schemas.import_job import (
    ImportJobCreate,
    ImportJobResponse,
    ImportJobRowCreateBulk,
    ImportJobRowResponse
)
from app.models.import_job import ImportType, ImportJobStatus
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[ImportJobResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Register a new Import/Migration Job",
    description="Registers a new migration job entry with default DRAFT state, enforcing active file checksum constraints."
)
async def create_import_job(
    obj_in: ImportJobCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("migration.create")),
    service: ImportJobService = Depends(get_import_job_service)
) -> APIResponse[ImportJobResponse]:
    db_obj = await service.create_job(tenant_id, obj_in, current_user.id)
    return APIResponse[ImportJobResponse](
        success=True,
        message="Import job registered successfully.",
        data=ImportJobResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[ImportJobResponse]],
    status_code=status.HTTP_200_OK,
    summary="List Import/Migration Jobs under school",
    description="Retrieves a paginated list of migration job metadata records scoped by tenant and school."
)
async def list_import_jobs(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    import_type: Optional[ImportType] = Query(None, description="Filter by import type"),
    job_status: Optional[ImportJobStatus] = Query(None, alias="status", description="Filter by job status"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("migration.read")),
    service: ImportJobService = Depends(get_import_job_service)
) -> APIResponse[List[ImportJobResponse]]:
    jobs = await service.list_jobs(
        tenant_id=tenant_id,
        school_id=school_id,
        import_type=import_type,
        job_status=job_status,
        skip=skip,
        limit=limit
    )
    responses = [ImportJobResponse.model_validate(j) for j in jobs]
    return APIResponse[List[ImportJobResponse]](
        success=True,
        message="Import jobs listed successfully.",
        data=responses
    )

@router.get(
    "/{job_id}",
    response_model=APIResponse[ImportJobResponse],
    status_code=status.HTTP_200_OK,
    summary="Get Import/Migration Job metadata details",
    description="Retrieves the detailed summary metadata of a specific migration job scoped by tenant."
)
async def get_import_job(
    job_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("migration.read")),
    service: ImportJobService = Depends(get_import_job_service)
) -> APIResponse[ImportJobResponse]:
    db_obj = await service.get_job_by_id(tenant_id, job_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Import job not found."
        )
    return APIResponse[ImportJobResponse](
        success=True,
        message="Import job metadata retrieved successfully.",
        data=ImportJobResponse.model_validate(db_obj)
    )

@router.post(
    "/{job_id}/start",
    response_model=APIResponse[ImportJobResponse],
    status_code=status.HTTP_200_OK,
    summary="Start validation or processing of Import Job",
    description="Shifts the import job state from VALIDATED to RUNNING, setting the started_at timestamp."
)
async def start_import_job(
    job_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("migration.execute")),
    service: ImportJobService = Depends(get_import_job_service)
) -> APIResponse[ImportJobResponse]:
    db_obj = await service.start_job(tenant_id, job_id)
    return APIResponse[ImportJobResponse](
        success=True,
        message="Import job started successfully.",
        data=ImportJobResponse.model_validate(db_obj)
    )

@router.post(
    "/{job_id}/cancel",
    response_model=APIResponse[ImportJobResponse],
    status_code=status.HTTP_200_OK,
    summary="Cancel active Import Job execution",
    description="Aborts/cancels the active validation or execution process, transitioning the job to CANCELLED state."
)
async def cancel_import_job(
    job_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("migration.cancel")),
    service: ImportJobService = Depends(get_import_job_service)
) -> APIResponse[ImportJobResponse]:
    db_obj = await service.cancel_job(tenant_id, job_id)
    return APIResponse[ImportJobResponse](
        success=True,
        message="Import job cancelled successfully.",
        data=ImportJobResponse.model_validate(db_obj)
    )

@router.post(
    "/{job_id}/rows",
    response_model=APIResponse[List[ImportJobRowResponse]],
    status_code=status.HTTP_201_CREATED,
    summary="Append row outcomes/results to Import Job",
    description="Allows import worker instances to report processing outcomes of single or batch rows of data."
)
async def create_import_job_rows(
    job_id: uuid.UUID,
    obj_in: ImportJobRowCreateBulk,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("migration.execute")),
    service: ImportJobService = Depends(get_import_job_service)
) -> APIResponse[List[ImportJobRowResponse]]:
    db_objs = await service.create_row_results(tenant_id, job_id, obj_in.rows)
    responses = [ImportJobRowResponse.model_validate(r) for r in db_objs]
    return APIResponse[List[ImportJobRowResponse]](
        success=True,
        message="Row results registered successfully.",
        data=responses
    )

@router.get(
    "/{job_id}/rows",
    response_model=APIResponse[List[ImportJobRowResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get paginated row-level results for Import Job",
    description="Retrieves a sorted list of row execution reports scoped by tenant."
)
async def get_import_job_rows(
    job_id: uuid.UUID,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("migration.read")),
    service: ImportJobService = Depends(get_import_job_service)
) -> APIResponse[List[ImportJobRowResponse]]:
    db_objs = await service.get_row_results(tenant_id, job_id, skip=skip, limit=limit)
    responses = [ImportJobRowResponse.model_validate(r) for r in db_objs]
    return APIResponse[List[ImportJobRowResponse]](
        success=True,
        message="Row results fetched successfully.",
        data=responses
    )

@router.post(
    "/{job_id}/validate",
    response_model=APIResponse[ImportJobResponse],
    status_code=status.HTTP_200_OK,
    summary="Validate student migration Import Job",
    description="Validates the CSV file headers, formats, scopes, section capacities, duplicates, and staging data."
)
async def validate_import_job(
    job_id: uuid.UUID,
    file: UploadFile = File(...),
    sheet_name: Optional[str] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("migration.create")),
    service: ImportJobService = Depends(get_import_job_service)
) -> APIResponse[ImportJobResponse]:
    content = await file.read()
    db_obj = await service.validate_job(tenant_id, job_id, content, sheet_name=sheet_name)
    return APIResponse[ImportJobResponse](
        success=True,
        message="Import job validated successfully.",
        data=ImportJobResponse.model_validate(db_obj)
    )

@router.post(
    "/parse",
    status_code=status.HTTP_200_OK,
    summary="Parse spreadsheet upload content",
    description="Reads a spreadsheet file (CSV, XLS, XLSX, XLSM, XLSB, ODS) and returns sheet names, normalized headers, and first 50 rows for validation previews."
)
async def parse_spreadsheet_file(
    file: UploadFile = File(...),
    sheet_name: Optional[str] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("migration.create"))
):
    from app.utils.spreadsheet_reader import read_spreadsheet, normalize_header
    content = await file.read()
    try:
        sheets, selected_sheet, rows = read_spreadsheet(content, file.filename, sheet_name)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to parse spreadsheet file: {str(e)}"
        )

    headers = [normalize_header(h) for h in rows[0]] if rows else []
    preview_limit = 50
    preview_rows = rows[:preview_limit]

    return {
        "success": True,
        "message": "File parsed successfully.",
        "data": {
            "filename": file.filename,
            "format": file.filename.split(".")[-1].upper() if "." in file.filename else "CSV",
            "sheets": sheets,
            "selected_sheet": selected_sheet,
            "columns": headers,
            "row_count": len(rows),
            "preview_rows": preview_rows
        }
    }

