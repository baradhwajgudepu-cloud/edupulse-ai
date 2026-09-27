import io
import os
import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException, UploadFile, File, Response
from PIL import Image as PILImage

from app.api.dependencies.common import get_tenant_id, verify_school_access
from app.api.dependencies.guardian import get_guardian_service
from app.api.dependencies.auth import require_permission
from app.services.storage import StorageService, get_storage_service
from app.services.guardian import GuardianService
from app.schemas.guardian import GuardianCreate, GuardianUpdate, GuardianResponse
from app.models.guardian import GuardianStatus
from app.models.user import User
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[GuardianResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a new guardian profile",
    description="Registers a new parent/guardian profile, checking tenant boundary uniqueness."
)
async def create_guardian(
    obj_in: GuardianCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.create")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[GuardianResponse]:
    await verify_school_access(current_user, obj_in.school_id, service.guardian_repo.db)
    db_obj = await service.create_guardian(tenant_id, obj_in, created_by=current_user.id)
    return APIResponse[GuardianResponse](
        success=True,
        message="Guardian profile registered successfully.",
        data=GuardianResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[GuardianResponse]],
    status_code=status.HTTP_200_OK,
    summary="List guardian profiles under school",
    description="Retrieves a paginated list of guardians scoped by tenant and school."
)
async def list_guardians(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    status_filter: Optional[GuardianStatus] = Query(None, alias="status", description="Filter by status"),
    search: Optional[str] = Query(None, description="Fuzzy match search on names, mobile, email, Aadhaar, or PAN"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.read")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[List[GuardianResponse]]:
    await verify_school_access(current_user, school_id, service.guardian_repo.db)
    user_role_codes = [role.code for role in current_user.roles]
    if "PARENT" in user_role_codes and not current_user.is_superuser:
        # Secure Object-Level Restriction: A parent must only retrieve their own guardian profile
        from app.models.guardian import Guardian
        from sqlalchemy.orm import selectinload
        from sqlalchemy import select, or_
        
        stmt = select(Guardian).where(
            or_(Guardian.user_id == current_user.id, Guardian.email == current_user.email),
            Guardian.school_id == school_id,
            Guardian.tenant_id == tenant_id,
            Guardian.deleted_at.is_(None)
        ).options(
            selectinload(Guardian.students),
            selectinload(Guardian.user)
        )
        res = await service.guardian_repo.db.execute(stmt)
        guardians = list(res.scalars().all())
    else:
        guardians = await service.guardian_repo.get_multi(
            school_id=school_id,
            tenant_id=tenant_id,
            status=status_filter,
            search=search,
            skip=skip,
            limit=limit
        )
    responses = [GuardianResponse.model_validate(g) for g in guardians]
    return APIResponse[List[GuardianResponse]](
        success=True,
        message="Guardians fetched successfully.",
        data=responses
    )


@router.get(
    "/{id}",
    response_model=APIResponse[GuardianResponse],
    status_code=status.HTTP_200_OK,
    summary="Get guardian profile details",
    description="Retrieves guardian profile attributes scoped by tenant and school."
)
async def get_guardian(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.read")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[GuardianResponse]:
    await verify_school_access(current_user, school_id, service.guardian_repo.db)
    db_obj = await service.guardian_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guardian profile not found."
        )
        
    user_role_codes = [role.code for role in current_user.roles]
    if "PARENT" in user_role_codes and not current_user.is_superuser:
        # Secure Object-Level Restriction: Verifies matching user account link
        if db_obj.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You do not have permission to view this guardian profile."
            )
            
    return APIResponse[GuardianResponse](
        success=True,
        message="Guardian details fetched successfully.",
        data=GuardianResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[GuardianResponse],
    status_code=status.HTTP_200_OK,
    summary="Update guardian details",
    description="Modifies guardian parameters scoped by tenant and school."
)
async def update_guardian(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    obj_in: GuardianUpdate = ...,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.update")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[GuardianResponse]:
    await verify_school_access(current_user, school_id, service.guardian_repo.db)
    db_obj = await service.update_guardian(tenant_id, school_id, id, obj_in, updated_by=current_user.id)
    return APIResponse[GuardianResponse](
        success=True,
        message="Guardian updated successfully.",
        data=GuardianResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[GuardianResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft-delete guardian profile",
    description="Soft-deletes the guardian profile, updating status to INACTIVE."
)
async def delete_guardian(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.delete")),
    service: GuardianService = Depends(get_guardian_service)
) -> APIResponse[GuardianResponse]:
    await verify_school_access(current_user, school_id, service.guardian_repo.db)
    db_obj = await service.delete_guardian(tenant_id, school_id, id, deleted_by=current_user.id)
    return APIResponse[GuardianResponse](
        success=True,
        message="Guardian deleted successfully.",
        data=GuardianResponse.model_validate(db_obj)
    )


@router.post(
    "/{id}/photo",
    response_model=APIResponse[GuardianResponse],
    status_code=status.HTTP_200_OK,
    summary="Upload or update guardian profile photo",
    description="Uploads a guardian profile picture (PNG, JPG, JPEG, WebP) within tenant and school scope."
)
async def upload_guardian_photo(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    file: UploadFile = File(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.update")),
    service: GuardianService = Depends(get_guardian_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> APIResponse[GuardianResponse]:
    """
    Uploads, normalizes, and replaces a guardian's profile photo with format, integrity, and size validation.
    Photo upload is strictly optional.
    """
    await verify_school_access(current_user, school_id, service.guardian_repo.db)

    guardian = await service.guardian_repo.get_by_id(id, school_id, tenant_id)
    if not guardian:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guardian profile not found."
        )

    contents = await file.read()
    file_size = len(contents)
    max_size = 5 * 1024 * 1024
    if file_size > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Profile photo must be smaller than 5 MB."
        )
    if file_size == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty."
        )

    filename = file.filename or "photo.png"
    ext = os.path.splitext(filename)[1].lower().strip(".")
    allowed_exts = {"png", "jpg", "jpeg", "webp"}
    if ext not in allowed_exts:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please upload a PNG, JPG, JPEG or WEBP image."
        )

    allowed_mimes = {"image/png", "image/jpeg", "image/pjpeg", "image/webp"}
    if file.content_type and file.content_type.lower() not in allowed_mimes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please upload a PNG, JPG, JPEG or WEBP image."
        )

    try:
        verify_img = PILImage.open(io.BytesIO(contents))
        verify_img.verify()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image file or corrupted image data."
        )

    try:
        proc_img = PILImage.open(io.BytesIO(contents))
        max_dim = 512
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

    old_key = None
    if guardian.settings and isinstance(guardian.settings, dict):
        old_key = guardian.settings.get("photo_storage_key")
    if not old_key and guardian.photo_url and not guardian.photo_url.startswith("http") and not guardian.photo_url.startswith("/api"):
        old_key = guardian.photo_url

    if old_key:
        try:
            await storage_service.delete(old_key)
        except Exception:
            pass

    storage_path = f"tenants/{tenant_id}/schools/{school_id}/guardians/{id}/photo/{uuid.uuid4().hex}.{ext_clean}"
    await storage_service.upload(processed_bytes, storage_path, content_type=upload_content_type)

    relative_url = f"/api/v1/guardians/{id}/photo?school_id={school_id}"
    updated_guardian = await service.update_photo(
        tenant_id=tenant_id,
        school_id=school_id,
        guardian_id=id,
        photo_url=relative_url,
        photo_storage_key=storage_path
    )
    return APIResponse[GuardianResponse](
        success=True,
        message="Guardian photo uploaded successfully.",
        data=GuardianResponse.model_validate(updated_guardian)
    )


@router.delete(
    "/{id}/photo",
    response_model=APIResponse[GuardianResponse],
    status_code=status.HTTP_200_OK,
    summary="Remove guardian profile photo",
    description="Deletes the profile photo associated with the guardian."
)
async def delete_guardian_photo(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.update")),
    service: GuardianService = Depends(get_guardian_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> APIResponse[GuardianResponse]:
    """
    Deletes the profile photo of a guardian and removes stored assets.
    """
    await verify_school_access(current_user, school_id, service.guardian_repo.db)

    guardian = await service.guardian_repo.get_by_id(id, school_id, tenant_id)
    if not guardian:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guardian profile not found."
        )

    old_key = None
    if guardian.settings and isinstance(guardian.settings, dict):
        old_key = guardian.settings.get("photo_storage_key")
    if not old_key and guardian.photo_url and not guardian.photo_url.startswith("http") and not guardian.photo_url.startswith("/api"):
        old_key = guardian.photo_url

    if old_key:
        try:
            await storage_service.delete(old_key)
        except Exception:
            pass

    updated_guardian = await service.update_photo(
        tenant_id=tenant_id,
        school_id=school_id,
        guardian_id=id,
        photo_url=None,
        photo_storage_key=None
    )
    return APIResponse[GuardianResponse](
        success=True,
        message="Guardian photo removed successfully.",
        data=GuardianResponse.model_validate(updated_guardian)
    )


@router.get(
    "/{id}/photo",
    summary="Get guardian profile photo",
    description="Streams the guardian profile photo image with authenticated access, MIME detection, and caching headers."
)
async def get_guardian_photo(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("guardian.read")),
    service: GuardianService = Depends(get_guardian_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> Response:
    """
    Streams the guardian profile photo with authenticated access, MIME detection, and caching headers.
    """
    await verify_school_access(current_user, school_id, service.guardian_repo.db)

    guardian = await service.guardian_repo.get_by_id(id, school_id, tenant_id)
    if not guardian:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guardian profile not found."
        )

    storage_key = None
    if guardian.settings and isinstance(guardian.settings, dict):
        storage_key = guardian.settings.get("photo_storage_key")
    if not storage_key and guardian.photo_url and not guardian.photo_url.startswith("http") and not guardian.photo_url.startswith("/api"):
        storage_key = guardian.photo_url

    if not storage_key:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guardian does not have a profile photo."
        )

    try:
        photo_bytes = await storage_service.download(storage_key)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Guardian photo file not found in storage: {e}"
        )

    if not photo_bytes:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guardian photo file not found in storage."
        )

    ext = os.path.splitext(storage_key)[1].lower().strip(".")
    mime_map = {
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "webp": "image/webp",
    }
    media_type = mime_map.get(ext, "image/jpeg")

    photo_time = guardian.settings.get("photo_updated_at") if guardian.settings else None
    etag = f'"{hash(photo_time or storage_key)}"'

    return Response(
        content=photo_bytes,
        media_type=media_type,
        headers={
            "Cache-Control": "private, max-age=3600",
            "ETag": etag,
        }
    )

