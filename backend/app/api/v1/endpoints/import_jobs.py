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
    description="Reads a spreadsheet file (CSV, XLS, XLSX, XLSM, XLSB, ODS) and returns sheet names, normalized headers, server-side validation summary, full dataset rows, and structured preview limits."
)
async def parse_spreadsheet_file(
    file: UploadFile = File(...),
    sheet_name: Optional[str] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("migration.create"))
):
    import re
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
    data_rows = rows[1:] if len(rows) > 1 else []
    total_data_rows = len(data_rows)
    preview_limit = 50
    preview_rows = rows[:preview_limit]

    # Server-Side Full Dataset Validation
    email_regex = re.compile(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$')
    phone_regex = re.compile(r'^\+?[0-9\s-]{10,15}$')
    date_regex = re.compile(r'^\d{4}-\d{2}-\d{2}$')

    validation_errors = []
    warning_count = 0
    valid_count = 0
    invalid_count = 0

    seen_primary_keys = set()

    for idx, r in enumerate(data_rows, start=2):
        row_dict = {headers[h_idx]: str(r[h_idx] or '').strip() for h_idx in range(min(len(headers), len(r)))}
        row_errors = []

        # Validate mandatory non-empty cells for common identifying fields
        for col_name, val in row_dict.items():
            if 'email' in col_name and val:
                if not email_regex.match(val):
                    row_errors.append({"row": idx, "column": col_name, "message": f"Invalid email format: '{val}'"})
            elif ('phone' in col_name or 'mobile' in col_name) and val:
                if not phone_regex.match(val):
                    row_errors.append({"row": idx, "column": col_name, "message": f"Invalid phone format: '{val}'"})
            elif ('date' in col_name or col_name.endswith('_at')) and val:
                if not date_regex.match(val):
                    row_errors.append({"row": idx, "column": col_name, "message": f"Invalid date format (expected YYYY-MM-DD): '{val}'"})

        # Check primary key duplication
        pk_col = next((c for c in headers if c.endswith('_code') or c == 'admission_number'), None)
        if pk_col and row_dict.get(pk_col):
            pk_val = row_dict[pk_col]
            if pk_val in seen_primary_keys:
                row_errors.append({"row": idx, "column": pk_col, "message": f"Duplicate primary key '{pk_val}' in row {idx}"})
            else:
                seen_primary_keys.add(pk_val)

        if row_errors:
            invalid_count += 1
            validation_errors.extend(row_errors)
        else:
            valid_count += 1

    validation_summary = {
        "total_rows": total_data_rows,
        "valid_rows": valid_count,
        "invalid_rows": invalid_count,
        "warnings_count": warning_count,
        "errors": validation_errors[:100],  # Return first 100 errors to prevent payload bloat
        "has_errors": invalid_count > 0
    }

    preview_payload = {
        "headers": headers,
        "rows": preview_rows,
        "limit": preview_limit,
        "total_rows": total_data_rows,
        "is_truncated": total_data_rows > (len(preview_rows) - 1 if preview_rows else 0)
    }

    return {
        "success": True,
        "message": "File parsed successfully.",
        "data": {
            "filename": file.filename,
            "format": file.filename.split(".")[-1].upper() if "." in file.filename else "CSV",
            "sheets": sheets,
            "selected_sheet": selected_sheet,
            "columns": headers,
            "row_count": total_data_rows,
            "total_records": total_data_rows,
            "validation_summary": validation_summary,
            "preview": preview_payload,
            "preview_rows": preview_rows,
            "rows": rows
        }
    }

