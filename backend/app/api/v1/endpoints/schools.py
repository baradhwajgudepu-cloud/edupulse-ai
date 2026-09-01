import os
import uuid
from typing import List, Optional, Any
from fastapi import APIRouter, Depends, Query, UploadFile, File, HTTPException, status
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.school import get_school_service
from app.api.dependencies.auth import require_permission
from app.services.school import SchoolService
from app.services.storage import get_storage_service, StorageService
from app.schemas.school import SchoolCreate, SchoolUpdate, SchoolResponse
from app.models.school import SchoolBoard, SchoolStatus
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[SchoolResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new school campus",
    description="Registers a new school campus scoped under the active tenant, with composite uniqueness validation."
)
async def create_school(
    obj_in: SchoolCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(require_permission("school.create")),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolResponse]:
    """
    Registers a new school campus in the active tenant.
    """
    school = await service.create_school(tenant_id, obj_in)
    school_response = SchoolResponse.model_validate(school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School created successfully.",
        data=school_response
    )

@router.get(
    "",
    response_model=APIResponse[List[SchoolResponse]],
    status_code=status.HTTP_200_OK,
    summary="List all schools under active tenant",
    description="Retrieves a list of school campuses scoped by tenant with pagination and optional filters."
)
async def list_schools(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=100, description="Limit count of records returned"),
    status: Optional[SchoolStatus] = Query(None, description="Filter by status (ACTIVE/INACTIVE/SUSPENDED)"),
    board: Optional[SchoolBoard] = Query(None, description="Filter by board Affiliation"),
    is_active: Optional[bool] = Query(None, description="Filter by active switch"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(require_permission("school.read")),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[List[SchoolResponse]]:
    """
    Lists active schools matching page filters scoped by tenant.
    """
    schools = await service.list_schools(
        tenant_id=tenant_id,
        skip=skip,
        limit=limit,
        status_filter=status,
        board=board,
        is_active=is_active
    )
    school_responses = [SchoolResponse.model_validate(s) for s in schools]
    return APIResponse[List[SchoolResponse]](
        success=True,
        message="Schools fetched successfully.",
        data=school_responses
    )

@router.get(
    "/{id}",
    response_model=APIResponse[SchoolResponse],
    status_code=status.HTTP_200_OK,
    summary="Get school details",
    description="Retrieves details of a specific active school campus by UUID scoped by tenant."
)
async def get_school(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(require_permission("school.read")),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolResponse]:
    """
    Fetches details of a single active school by UUID.
    """
    school = await service.get_school(id, tenant_id)
    school_response = SchoolResponse.model_validate(school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School details fetched successfully.",
        data=school_response
    )

@router.put(
    "/{id}",
    response_model=APIResponse[SchoolResponse],
    status_code=status.HTTP_200_OK,
    summary="Update school details",
    description="Modifies school attributes scoped by tenant, verifying unique constraints."
)
async def update_school(
    id: uuid.UUID,
    obj_in: SchoolUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(require_permission("school.update", "school.write")),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolResponse]:
    """
    Updates properties of an existing school campus.
    """
    school = await service.update_school(tenant_id, id, obj_in)
    school_response = SchoolResponse.model_validate(school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School updated successfully.",
        data=school_response
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[SchoolResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete school",
    description="Soft-deletes the selected school scoped by tenant."
)
async def delete_school(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(require_permission("school.delete")),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolResponse]:
    """
    Performs soft-delete operations on the selected school.
    """
    school = await service.delete_school(tenant_id, id)
    school_response = SchoolResponse.model_validate(school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School deleted successfully.",
        data=school_response
    )

@router.post(
    "/{id}/logo",
    response_model=APIResponse[SchoolResponse],
    status_code=status.HTTP_200_OK,
    summary="Upload or update school logo",
    description="Uploads a new branding image (PNG, JPG, JPEG, WebP) for the school within tenant scope."
)
async def upload_school_logo(
    id: uuid.UUID,
    file: UploadFile = File(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(require_permission("school.update", "school.write")),
    service: SchoolService = Depends(get_school_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> APIResponse[SchoolResponse]:
    """
    Uploads and replaces a school's branding logo image with format and size validation.
    """
    # 1. Verify school exists under tenant scope
    school = await service.get_school(id, tenant_id)

    # 2. Validate file size (max 5MB)
    contents = await file.read()
    file_size = len(contents)
    max_size = 5 * 1024 * 1024
    if file_size > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File size exceeds the maximum allowed limit of 5MB."
        )
    if file_size == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty."
        )

    # 3. Validate file extension and MIME type
    filename = file.filename or "logo.png"
    ext = os.path.splitext(filename)[1].lower().strip(".")
    allowed_exts = {"png", "jpg", "jpeg", "webp"}
    if ext not in allowed_exts:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file format '.{ext}'. Allowed formats: PNG, JPG, JPEG, WebP."
        )

    allowed_mimes = {"image/png", "image/jpeg", "image/pjpeg", "image/webp"}
    if file.content_type and file.content_type.lower() not in allowed_mimes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported content type '{file.content_type}'. Allowed types: image/png, image/jpeg, image/webp."
        )

    # 4. Cleanup existing logo from storage if it is a storage path
    if school.logo_url and not school.logo_url.startswith("http"):
        try:
            await storage_service.delete(school.logo_url)
        except Exception:
            pass

    # 5. Upload new logo to storage path
    storage_path = f"tenants/{tenant_id}/schools/{id}/branding/{uuid.uuid4().hex}.{ext}"
    await storage_service.upload(contents, storage_path, content_type=file.content_type or f"image/{ext}")

    # 6. Update school record
    updated_school = await service.update_logo(tenant_id, id, storage_path)
    school_response = SchoolResponse.model_validate(updated_school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School branding logo uploaded successfully.",
        data=school_response
    )

@router.delete(
    "/{id}/logo",
    response_model=APIResponse[SchoolResponse],
    status_code=status.HTTP_200_OK,
    summary="Remove school logo",
    description="Deletes the branding logo associated with the school."
)
async def delete_school_logo(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(require_permission("school.update", "school.write")),
    service: SchoolService = Depends(get_school_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> APIResponse[SchoolResponse]:
    """
    Deletes the branding logo of a school.
    """
    # 1. Verify school exists under tenant scope
    school = await service.get_school(id, tenant_id)

    # 2. Cleanup from storage
    if school.logo_url and not school.logo_url.startswith("http"):
        try:
            await storage_service.delete(school.logo_url)
        except Exception:
            pass

    # 3. Update school record
    updated_school = await service.update_logo(tenant_id, id, None)
    school_response = SchoolResponse.model_validate(updated_school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School branding logo removed successfully.",
        data=school_response
    )
