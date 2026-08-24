import uuid
from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import require_permission, get_current_user
from app.api.dependencies.school_event import get_school_event_service
from app.api.dependencies.notification import get_notification_service
from app.db.session import get_db
from app.models.user import User
from app.models.school_event import EventStatus, EventAudience
from app.schemas.school_event import SchoolEventCreate, SchoolEventUpdate, SchoolEventResponse
from app.schemas.response import APIResponse
from app.services.school_event import SchoolEventService
from app.services.notification import NotificationService

router = APIRouter()

async def verify_school_access(user_id: uuid.UUID, school_id: uuid.UUID, db: AsyncSession) -> None:
    from sqlalchemy import text, select
    from app.models.user import User
    from app.models.school import School

    # 1. Fetch user to check superuser and tenant
    user_stmt = select(User).where(User.id == user_id)
    user_res = await db.execute(user_stmt)
    user = user_res.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found."
        )

    # 2. Fetch selected school
    school_stmt = select(School).where(School.id == school_id)
    school_res = await db.execute(school_stmt)
    school = school_res.scalar_one_or_none()
    if not school:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="School not found."
        )

    # 3. Verify selected school belongs to user's tenant
    if not user.is_superuser and school.tenant_id != user.tenant_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. School belongs to a different tenant."
        )

    # 4. Selected school must be active
    if not school.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="School is inactive."
        )

    # 5. If superuser, allow access
    if user.is_superuser:
        return

    # 5. For standard users, check mapping
    stmt = text("SELECT 1 FROM school_users WHERE user_id = :uid AND school_id = :sid")
    res = await db.execute(stmt, {"uid": str(user_id), "sid": str(school_id)})
    if not res.fetchone():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You do not have permissions for this school."
        )


@router.post(
    "",
    response_model=APIResponse[SchoolEventResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new event"
)
async def create_event(
    obj_in: SchoolEventCreate,
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.create")),
    service: SchoolEventService = Depends(get_school_event_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SchoolEventResponse]:
    await verify_school_access(current_user.id, school_id, db)
    db_obj = await service.create_event(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        obj_in=obj_in,
        current_user=current_user
    )
    return APIResponse[SchoolEventResponse](
        success=True,
        message="School event created as draft.",
        data=SchoolEventResponse.model_validate(db_obj)
    )

@router.get(
    "",
    response_model=APIResponse[List[SchoolEventResponse]],
    status_code=status.HTTP_200_OK,
    summary="List school events"
)
async def list_events(
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    status_filter: Optional[EventStatus] = Query(None, alias="status"),
    target_audience: Optional[EventAudience] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.read")),
    service: SchoolEventService = Depends(get_school_event_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[SchoolEventResponse]]:
    await verify_school_access(current_user.id, school_id, db)
    events = await service.event_repo.get_multi(
        school_id=school_id,
        tenant_id=tenant_id,
        academic_year_id=academic_year_id,
        status=status_filter,
        target_audience=target_audience,
        start_date=start_date,
        end_date=end_date,
        skip=skip,
        limit=limit
    )
    return APIResponse[List[SchoolEventResponse]](
        success=True,
        message="School events retrieved successfully.",
        data=[SchoolEventResponse.model_validate(e) for e in events]
    )

@router.get(
    "/{id}",
    response_model=APIResponse[SchoolEventResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single event details"
)
async def get_event(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.read")),
    service: SchoolEventService = Depends(get_school_event_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SchoolEventResponse]:
    await verify_school_access(current_user.id, school_id, db)
    db_obj = await service.event_repo.get_by_id(id, school_id, tenant_id)
    if not db_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="School event not found."
        )
    return APIResponse[SchoolEventResponse](
        success=True,
        message="School event details retrieved.",
        data=SchoolEventResponse.model_validate(db_obj)
    )

@router.put(
    "/{id}",
    response_model=APIResponse[SchoolEventResponse],
    status_code=status.HTTP_200_OK,
    summary="Update school event"
)
async def update_event(
    id: uuid.UUID,
    obj_in: SchoolEventUpdate,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.update")),
    service: SchoolEventService = Depends(get_school_event_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SchoolEventResponse]:
    await verify_school_access(current_user.id, school_id, db)
    db_obj = await service.update_event(
        tenant_id=tenant_id,
        school_id=school_id,
        event_id=id,
        obj_in=obj_in,
        current_user=current_user
    )
    return APIResponse[SchoolEventResponse](
        success=True,
        message="School event updated successfully.",
        data=SchoolEventResponse.model_validate(db_obj)
    )

@router.delete(
    "/{id}",
    response_model=APIResponse[SchoolEventResponse],
    status_code=status.HTTP_200_OK,
    summary="Delete school event"
)
async def delete_event(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.delete")),
    service: SchoolEventService = Depends(get_school_event_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SchoolEventResponse]:
    await verify_school_access(current_user.id, school_id, db)
    db_obj = await service.delete_event(
        tenant_id=tenant_id,
        school_id=school_id,
        event_id=id,
        current_user=current_user
    )
    return APIResponse[SchoolEventResponse](
        success=True,
        message="School event deleted successfully.",
        data=SchoolEventResponse.model_validate(db_obj)
    )

@router.post(
    "/{id}/publish",
    response_model=APIResponse[SchoolEventResponse],
    status_code=status.HTTP_200_OK,
    summary="Publish school event"
)
async def publish_event(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("event.publish")),
    service: SchoolEventService = Depends(get_school_event_service),
    notification_service: NotificationService = Depends(get_notification_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SchoolEventResponse]:
    await verify_school_access(current_user.id, school_id, db)
    db_obj = await service.publish_event(
        tenant_id=tenant_id,
        school_id=school_id,
        event_id=id,
        current_user=current_user,
        notification_service=notification_service
    )
    return APIResponse[SchoolEventResponse](
        success=True,
        message="School event published and alerts dispatched.",
        data=SchoolEventResponse.model_validate(db_obj)
    )
