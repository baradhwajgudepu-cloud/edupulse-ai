import io
import os
import uuid
from datetime import datetime, timezone
from typing import List, Optional, Any
from fastapi import APIRouter, Depends, Query, UploadFile, File, HTTPException, status, Response
from PIL import Image as PILImage
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.common import get_tenant_id, get_db
from app.api.dependencies.school import get_school_service
from app.api.dependencies.auth import get_current_user, require_permission, require_role, require_platform_admin
from app.models.user import User
from app.models.school import School, SchoolBoard, SchoolStatus
from app.services.school import SchoolService
from app.services.school_data_reset import SchoolDataResetService
from app.services.storage import get_storage_service, StorageService
from app.schemas.school import (
    SchoolCreate, SchoolUpdate, SchoolResponse, SchoolGeofenceUpdate, SchoolGeofenceResponse,
    SchoolDataSummaryResponse, SchoolDataResetRequest, SchoolDataResetResponse,
    QuickSchoolOnboardingRequest, QuickSchoolOnboardingResponse, SchoolSetupProgressResponse
)
from app.schemas.response import APIResponse

router = APIRouter()

async def verify_school_access(user: Any, school_id: uuid.UUID, db: AsyncSession) -> School:
    """
    Verifies that the requested school exists, is active, belongs to user's tenant,
    and that the user has authorization for this campus.
    """
    school_stmt = select(School).where(School.id == school_id)
    school_res = await db.execute(school_stmt)
    school = school_res.scalar_one_or_none()
    if not school:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="School not found."
        )

    if not getattr(user, "is_superuser", False) and str(school.tenant_id) != str(user.tenant_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="School not found."
        )

    if not school.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="School is currently inactive."
        )

    if getattr(user, "is_superuser", False):
        return school

    from app.models.role import school_users

    # Check assigned schools in school_users table
    stmt_su = select(school_users.c.school_id).where(school_users.c.user_id == user.id)
    res_su = await db.execute(stmt_su)
    assigned_school_ids = {row[0] for row in res_su.fetchall()}

    # Also include in-memory schools if already loaded in object dict
    if "schools" in user.__dict__:
        assigned_school_ids.update({s.id for s in user.schools})

    # If user has explicit campus assignments (e.g. Principal, Teacher), enforce campus scope
    if assigned_school_ids and school_id not in assigned_school_ids:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. User is not authorized to access this school campus."
        )

    return school


@router.post(
    "/onboard-quick",
    response_model=APIResponse[QuickSchoolOnboardingResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Flexible Quick School Onboarding",
    description="Atomically provisions Tenant, School, Principal User, PRINCIPAL role, and campus scope with minimum required fields."
)
@router.post(
    "/onboard/quick",
    response_model=APIResponse[QuickSchoolOnboardingResponse],
    status_code=status.HTTP_201_CREATED,
    include_in_schema=False
)
async def onboard_school_quick(
    obj_in: QuickSchoolOnboardingRequest,
    current_user: User = Depends(require_platform_admin),
    service: SchoolService = Depends(get_school_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> APIResponse[QuickSchoolOnboardingResponse]:
    """
    Executes atomic school onboarding:
    Minimum required: School Name, Principal Name, Principal Email, Password.
    Returns tenant, school, principal identity, and immediate access token.
    Requires Platform Admin / Super Admin authority (platform-scoped operation).
    """
    resp = await service.onboard_school_quick(obj_in, storage_service=storage_service)
    return APIResponse[QuickSchoolOnboardingResponse](
        success=True,
        message="School and Tenant onboarded successfully. Principal account activated.",
        data=resp
    )


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
    current_user: User = Depends(get_current_user),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[List[SchoolResponse]]:
    """
    Lists active schools matching page filters scoped by tenant.
    For platform super admins and tenant admins, lists tenant-wide schools.
    For school-scoped roles (Principals, Teachers, etc.), restricts strictly to their authorized assigned schools.
    """
    user_permissions = {p.code for r in current_user.roles for p in r.permissions}
    is_admin = current_user.is_superuser or any(
        r.code in ["SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN", "CHAIRMAN"] for r in current_user.roles
    )

    if is_admin or ("school.read" in user_permissions and not current_user.schools):
        schools = await service.list_schools(
            tenant_id=tenant_id,
            skip=skip,
            limit=limit,
            status_filter=status,
            board=board,
            is_active=is_active
        )
    else:
        # School-scoped users (PRINCIPAL, TEACHER, etc.) can ONLY access their authorized schools
        user_school_ids = {s.id for s in current_user.schools}
        if not user_school_ids and "school.read" not in user_permissions:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. User has no assigned schools."
            )
        schools = [
            s for s in current_user.schools
            if s.tenant_id == tenant_id and (is_active is None or s.is_active == is_active)
        ]

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
    current_user: User = Depends(get_current_user),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolResponse]:
    """
    Fetches details of a single active school by UUID.
    Enforces that non-admin users can only view schools they are authorized for.
    """
    is_admin = current_user.is_superuser or any(
        r.code in ["SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN", "CHAIRMAN"] for r in current_user.roles
    )
    if not is_admin and current_user.schools:
        user_school_ids = {s.id for s in current_user.schools}
        if id not in user_school_ids:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. User is not authorized to access this school campus."
            )

    school = await service.get_school(id, tenant_id)
    school_response = SchoolResponse.model_validate(school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School details fetched successfully.",
        data=school_response
    )


@router.get(
    "/{id}/setup-progress",
    response_model=APIResponse[SchoolSetupProgressResponse],
    status_code=status.HTTP_200_OK,
    summary="Get School Setup Progress",
    description="Evaluates dynamic completion status across the 8 progressive setup modules for a school campus."
)
async def get_school_setup_progress(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(require_permission("school.read")),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolSetupProgressResponse]:
    """
    Retrieves progressive setup status (completed count, total steps, itemized checklist).
    """
    await verify_school_access(current_user, id, service.repo.db)
    progress = await service.get_school_setup_progress(tenant_id, id)
    return APIResponse[SchoolSetupProgressResponse](
        success=True,
        message="School setup progress retrieved successfully.",
        data=progress
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
    await verify_school_access(current_user, id, service.repo.db)
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
    Uploads, normalizes, and replaces a school's branding logo image with format, integrity, and size validation.
    """
    # 1. Verify school exists under tenant scope and user has school access
    school = await verify_school_access(current_user, id, service.repo.db)

    # 2. Validate file size (max 5MB)
    contents = await file.read()
    file_size = len(contents)
    max_size = 5 * 1024 * 1024
    if file_size > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Logo image must be smaller than 5 MB."
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
            detail=f"Please upload a PNG, JPG, JPEG or WEBP image."
        )

    allowed_mimes = {"image/png", "image/jpeg", "image/pjpeg", "image/webp"}
    if file.content_type and file.content_type.lower() not in allowed_mimes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Please upload a PNG, JPG, JPEG or WEBP image."
        )

    # 4. Verify actual image integrity using Pillow
    try:
        verify_img = PILImage.open(io.BytesIO(contents))
        verify_img.verify()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image file or corrupted image data."
        )

    # 5. Image normalization (max 1024x1024, aspect-ratio preserved, transparency preserved)
    try:
        proc_img = PILImage.open(io.BytesIO(contents))
        max_dim = 1024
        if proc_img.width > max_dim or proc_img.height > max_dim:
            proc_img.thumbnail((max_dim, max_dim), PILImage.Resampling.LANCZOS)

        out_buf = io.BytesIO()
        ext_clean = ext.lower()
        if ext_clean == "png":
            proc_img.save(out_buf, format="PNG", optimize=True)
            upload_content_type = "image/png"
        elif ext_clean in ("jpg", "jpeg"):
            if proc_img.mode in ("RGBA", "LA", "P"):
                rgb_img = PILImage.new("RGB", proc_img.size, (255, 255, 255))
                mask = proc_img.split()[-1] if proc_img.mode == "RGBA" else None
                rgb_img.paste(proc_img, mask=mask)
                proc_img = rgb_img
            proc_img.save(out_buf, format="JPEG", quality=90, optimize=True)
            upload_content_type = "image/jpeg"
        elif ext_clean == "webp":
            proc_img.save(out_buf, format="WEBP", quality=90)
            upload_content_type = "image/webp"
        else:
            proc_img.save(out_buf, format="PNG", optimize=True)
            upload_content_type = "image/png"

        processed_bytes = out_buf.getvalue()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Image processing failed: {e}"
        )

    # 6. Cleanup existing logo from storage using logo_storage_key or legacy path
    old_key = None
    if school.settings and isinstance(school.settings, dict):
        old_key = school.settings.get("branding", {}).get("logo_storage_key")
    if not old_key and school.logo_url and not school.logo_url.startswith("http") and not school.logo_url.startswith("/api"):
        old_key = school.logo_url

    if old_key:
        try:
            await storage_service.delete(old_key)
        except Exception:
            pass

    # 7. Upload new logo to isolated storage path
    storage_path = f"tenants/{tenant_id}/schools/{id}/branding/{uuid.uuid4().hex}.{ext_clean}"
    await storage_service.upload(processed_bytes, storage_path, content_type=upload_content_type)

    # 8. Update school record with relative logo endpoint and internal storage key
    relative_url = f"/api/v1/schools/{id}/logo"
    updated_school = await service.update_logo(tenant_id, id, relative_url, logo_storage_key=storage_path)
    school_response = SchoolResponse.model_validate(updated_school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School logo uploaded successfully",
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
    Deletes the branding logo of a school and removes stored assets.
    """
    # 1. Verify school exists under tenant scope and user has school access
    school = await verify_school_access(current_user, id, service.repo.db)

    # 2. Cleanup from storage using logo_storage_key or legacy path
    old_key = None
    if school.settings and isinstance(school.settings, dict):
        old_key = school.settings.get("branding", {}).get("logo_storage_key")
    if not old_key and school.logo_url and not school.logo_url.startswith("http") and not school.logo_url.startswith("/api"):
        old_key = school.logo_url

    if old_key:
        try:
            await storage_service.delete(old_key)
        except Exception:
            pass

    # 3. Update school record
    updated_school = await service.update_logo(tenant_id, id, None, logo_storage_key=None)
    school_response = SchoolResponse.model_validate(updated_school)
    return APIResponse[SchoolResponse](
        success=True,
        message="School logo removed successfully",
        data=school_response
    )

@router.get(
    "/{id}/logo",
    summary="Get school logo",
    description="Retrieves the school branding logo image with authenticated access."
)
async def get_school_logo(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(get_current_user),
    service: SchoolService = Depends(get_school_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> Response:
    """
    Streams the school logo image with authenticated access, MIME detection, and caching headers.
    """
    # 1. Verify school exists under tenant scope and user has access
    school = await verify_school_access(current_user, id, service.repo.db)

    # 2. Locate internal storage key
    storage_key = None
    if school.settings and isinstance(school.settings, dict):
        storage_key = school.settings.get("branding", {}).get("logo_storage_key")
    if not storage_key and school.logo_url and not school.logo_url.startswith("http") and not school.logo_url.startswith("/api"):
        storage_key = school.logo_url

    if not storage_key:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="School does not have a branding logo."
        )

    # 3. Download bytes from storage
    try:
        logo_bytes = await storage_service.download(storage_key)
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="School logo file not found in storage."
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unable to read school logo: {e}"
        )

    # 4. Infer MIME type
    ext = os.path.splitext(storage_key)[1].lower().strip(".")
    mime_map = {
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "webp": "image/webp"
    }
    media_type = mime_map.get(ext, "image/png")

    branding_time = school.settings.get("branding", {}).get("logo_updated_at") if school.settings else None
    etag = f'"{hash(branding_time or storage_key)}"'

    return Response(
        content=logo_bytes,
        media_type=media_type,
        headers={
            "Cache-Control": "private, max-age=86400",
            "ETag": etag,
        }
    )


@router.get(
    "/{id}/geofence",
    response_model=APIResponse[SchoolGeofenceResponse],
    status_code=status.HTTP_200_OK,
    summary="Get school geofence configuration",
    description="Retrieves the active geofence and attendance location coordinates for the school."
)
async def get_school_geofence(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(get_current_user),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolGeofenceResponse]:
    """
    Returns the school geofence configuration scoped by tenant and campus authorization.
    """
    school = await verify_school_access(current_user, id, service.repo.db)
    gf_settings = (school.settings or {}).get("geofence", {}) if school.settings else {}
    enabled = gf_settings.get("enabled", True)
    is_configured = bool(
        school.latitude is not None and
        school.longitude is not None and
        school.geofence_radius_meters is not None and
        school.geofence_radius_meters > 0
    )

    updated_at = None
    if "updated_at" in gf_settings and gf_settings["updated_at"]:
        try:
            updated_at = datetime.fromisoformat(gf_settings["updated_at"])
        except Exception:
            updated_at = school.updated_at
    else:
        updated_at = school.updated_at

    updated_by = None
    if "updated_by" in gf_settings and gf_settings["updated_by"]:
        try:
            updated_by = uuid.UUID(gf_settings["updated_by"])
        except Exception:
            updated_by = school.updated_by
    else:
        updated_by = school.updated_by

    resp_data = SchoolGeofenceResponse(
        school_id=school.id,
        enabled=enabled,
        latitude=school.latitude,
        longitude=school.longitude,
        radius_meters=school.geofence_radius_meters or 100,
        is_configured=is_configured,
        updated_at=updated_at,
        updated_by=updated_by
    )
    return APIResponse[SchoolGeofenceResponse](
        success=True,
        message="School geofence configuration fetched successfully.",
        data=resp_data
    )


@router.patch(
    "/{id}/geofence",
    response_model=APIResponse[SchoolGeofenceResponse],
    status_code=status.HTTP_200_OK,
    summary="Update school geofence configuration",
    description="Configures school attendance geofence coordinates and radius within tenant scope."
)
@router.put(
    "/{id}/geofence",
    response_model=APIResponse[SchoolGeofenceResponse],
    status_code=status.HTTP_200_OK,
    summary="Update school geofence configuration (PUT alias)",
    description="Configures school attendance geofence coordinates and radius within tenant scope."
)
async def update_school_geofence(
    id: uuid.UUID,
    obj_in: SchoolGeofenceUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(require_permission("school.update", "school.write")),
    service: SchoolService = Depends(get_school_service)
) -> APIResponse[SchoolGeofenceResponse]:
    """
    Updates school geofence configuration and attendance boundaries.
    """
    await verify_school_access(current_user, id, service.repo.db)

    school = await service.update_geofence(
        tenant_id=tenant_id,
        school_id=id,
        enabled=obj_in.enabled,
        latitude=obj_in.latitude,
        longitude=obj_in.longitude,
        radius_meters=obj_in.radius_meters,
        updated_by=current_user.id
    )

    gf_settings = (school.settings or {}).get("geofence", {})
    updated_at = None
    if "updated_at" in gf_settings and gf_settings["updated_at"]:
        try:
            updated_at = datetime.fromisoformat(gf_settings["updated_at"])
        except Exception:
            updated_at = school.updated_at
    else:
        updated_at = school.updated_at

    updated_by = None
    if "updated_by" in gf_settings and gf_settings["updated_by"]:
        try:
            updated_by = uuid.UUID(gf_settings["updated_by"])
        except Exception:
            updated_by = school.updated_by
    else:
        updated_by = school.updated_by

    resp_data = SchoolGeofenceResponse(
        school_id=school.id,
        enabled=obj_in.enabled,
        latitude=school.latitude,
        longitude=school.longitude,
        radius_meters=school.geofence_radius_meters,
        is_configured=bool(school.latitude is not None and school.longitude is not None),
        updated_at=updated_at,
        updated_by=updated_by
    )
    return APIResponse[SchoolGeofenceResponse](
        success=True,
        message="School geofence updated successfully.",
        data=resp_data
    )


def get_school_data_reset_service(db: AsyncSession = Depends(get_db)) -> SchoolDataResetService:
    return SchoolDataResetService(db)


@router.get(
    "/{school_id}/data-summary",
    response_model=APIResponse[SchoolDataSummaryResponse],
    status_code=status.HTTP_200_OK,
    summary="Get school data summary before reset",
    description="Retrieves live record counts for all school-scoped child tables and preserved entities."
)
async def get_school_data_summary(
    school_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(require_role("SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN")),
    service: SchoolDataResetService = Depends(get_school_data_reset_service)
) -> APIResponse[SchoolDataSummaryResponse]:
    """
    Returns counts of all records that will be permanently deleted vs preserved
    prior to executing a destructive school reset.
    """
    summary = await service.get_school_data_summary(school_id, tenant_id, current_user)
    return APIResponse[SchoolDataSummaryResponse](
        success=True,
        message="School data summary retrieved successfully.",
        data=summary
    )


@router.post(
    "/{school_id}/reset-data",
    response_model=APIResponse[SchoolDataResetResponse],
    status_code=status.HTTP_200_OK,
    summary="Reset school operational and onboarding data",
    description="Permanently deletes all operational child data for the selected school within an atomic transaction, while preserving school identity, user accounts, and tenant access."
)
async def reset_school_data(
    school_id: uuid.UUID,
    payload: SchoolDataResetRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: Any = Depends(require_role("SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN")),
    service: SchoolDataResetService = Depends(get_school_data_reset_service)
) -> APIResponse[SchoolDataResetResponse]:
    """
    Safely purges all operational data belonging exclusively to the selected school.
    Executes in a single atomic transaction with full rollback on any failure.
    Requires exact case-sensitive school name confirmation and non-empty reason.
    """
    result = await service.reset_school_data(school_id, tenant_id, payload, current_user)
    return APIResponse[SchoolDataResetResponse](
        success=True,
        message="School operational and onboarding data reset successfully.",
        data=result
    )
