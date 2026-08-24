import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import require_permission, get_current_user
from app.api.dependencies.announcement import get_announcement_service
from app.api.dependencies.notification import get_notification_service
from app.db.session import get_db
from app.models.user import User
from app.models.announcement import AnnouncementStatus, AnnouncementAudienceType
from app.models.notification import NotificationTargetRole
from app.schemas.announcement import AnnouncementCreate, AnnouncementUpdate, AnnouncementResponse
from app.schemas.response import APIResponse
from app.services.announcement import AnnouncementService
from app.services.notification import NotificationService

router = APIRouter()

async def verify_school_access(user: User, school_id: uuid.UUID, db: AsyncSession) -> None:
    from sqlalchemy import select
    from app.models.school import School

    # 1. Fetch selected school
    school_stmt = select(School).where(School.id == school_id)
    school_res = await db.execute(school_stmt)
    school = school_res.scalar_one_or_none()
    if not school:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="School not found."
        )

    # 2. Verify selected school belongs to user's tenant
    if not user.is_superuser and school.tenant_id != user.tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. School belongs to a different tenant."
        )

    # 3. Selected school must be active
    if not school.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="School is inactive."
        )

    # 4. If superuser, allow access
    if user.is_superuser:
        return

    # Parents are not registered in the school_users table (reserved for staff/teachers)
    # but are authorized to access school resources scoped to their children.
    user_role_codes = [role.code for role in user.roles]
    if "PARENT" in user_role_codes:
        return

    from app.models.role import school_users
    stmt = select(1).select_from(school_users).where(
        school_users.c.user_id == user.id,
        school_users.c.school_id == school_id
    )
    res = await db.execute(stmt)
    if not res.fetchone():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You do not have permissions for this school."
        )


@router.post(
    "",
    response_model=APIResponse[AnnouncementResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new announcement"
)
async def create_announcement(
    obj_in: AnnouncementCreate,
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("announcement.create")),
    service: AnnouncementService = Depends(get_announcement_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[AnnouncementResponse]:
    await verify_school_access(current_user, school_id, db)
    db_obj = await service.create_announcement(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        obj_in=obj_in,
        current_user=current_user
    )
    return APIResponse[AnnouncementResponse](
        success=True,
        message="Announcement created as draft.",
        data=AnnouncementResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[AnnouncementResponse]],
    status_code=status.HTTP_200_OK,
    summary="List announcements"
)
async def list_announcements(
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    status_filter: Optional[AnnouncementStatus] = Query(None, alias="status"),
    audience_type: Optional[AnnouncementAudienceType] = Query(None),
    target_role: Optional[NotificationTargetRole] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("announcement.read")),
    service: AnnouncementService = Depends(get_announcement_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[AnnouncementResponse]]:
    await verify_school_access(current_user, school_id, db)
    announcements = await service.announcement_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        status=status_filter,
        audience_type=audience_type,
        target_role=target_role,
        class_id=class_id,
        section_id=section_id,
        skip=skip,
        limit=limit
    )
    return APIResponse[List[AnnouncementResponse]](
        success=True,
        message="Announcements retrieved successfully.",
        data=[AnnouncementResponse.model_validate(a) for a in announcements]
    )

@router.get(
    "/{id}",
    response_model=APIResponse[AnnouncementResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single announcement details"
)
async def get_announcement(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("announcement.read")),
    service: AnnouncementService = Depends(get_announcement_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[AnnouncementResponse]:
    await verify_school_access(current_user, school_id, db)
    db_obj = await service.announcement_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Announcement not found."
        )
    return APIResponse[AnnouncementResponse](
        success=True,
        message="Announcement details retrieved.",
        data=AnnouncementResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[AnnouncementResponse],
    status_code=status.HTTP_200_OK,
    summary="Update announcement"
)
async def update_announcement(
    id: uuid.UUID,
    obj_in: AnnouncementUpdate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("announcement.update")),
    service: AnnouncementService = Depends(get_announcement_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[AnnouncementResponse]:
    await verify_school_access(current_user, school_id, db)
    db_obj = await service.update_announcement(
        tenant_id=tenant_id,
        school_id=school_id,
        announcement_id=id,
        obj_in=obj_in,
        current_user=current_user
    )
    return APIResponse[AnnouncementResponse](
        success=True,
        message="Announcement updated successfully.",
        data=AnnouncementResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[AnnouncementResponse],
    status_code=status.HTTP_200_OK,
    summary="Delete announcement"
)
async def delete_announcement(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("announcement.delete")),
    service: AnnouncementService = Depends(get_announcement_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[AnnouncementResponse]:
    await verify_school_access(current_user, school_id, db)
    db_obj = await service.delete_announcement(
        tenant_id=tenant_id,
        school_id=school_id,
        announcement_id=id,
        current_user=current_user
    )
    return APIResponse[AnnouncementResponse](
        success=True,
        message="Announcement deleted successfully.",
        data=AnnouncementResponse.model_validate(db_obj)
    )

@router.post(
    "/{id}/publish",
    response_model=APIResponse[AnnouncementResponse],
    status_code=status.HTTP_200_OK,
    summary="Publish announcement"
)
async def publish_announcement(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("announcement.publish")),
    service: AnnouncementService = Depends(get_announcement_service),
    notification_service: NotificationService = Depends(get_notification_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[AnnouncementResponse]:
    await verify_school_access(current_user, school_id, db)
    db_obj = await service.publish_announcement(
        tenant_id=tenant_id,
        school_id=school_id,
        announcement_id=id,
        current_user=current_user,
        notification_service=notification_service
    )
    return APIResponse[AnnouncementResponse](
        success=True,
        message="Announcement published and notifications dispatched.",
        data=AnnouncementResponse.model_validate(db_obj)
    )
