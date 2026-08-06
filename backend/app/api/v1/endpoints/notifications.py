import uuid
import logging
import traceback
from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, status, HTTPException, Query

from app.api.dependencies.auth import require_permission, get_current_user
from app.api.dependencies.notification import get_notification_service
from app.api.dependencies.common import get_tenant_id
from app.services.notification import NotificationService
from app.schemas.notification import (
    NotificationCreate, NotificationUpdate, NotificationResponse,
    NotificationPreferenceResponse, NotificationPreferenceUpdate, UnreadCountResponse
)
from app.schemas.response import APIResponse
from app.models.user import User
from app.models.notification import NotificationType, NotificationPriority, NotificationStatus

logger = logging.getLogger(__name__)

# Router for /notifications prefix
router = APIRouter()

# Router for /notification-preferences prefix
preferences_router = APIRouter()


@router.post(
    "",
    response_model=APIResponse[NotificationResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create custom notification or broadcast announcement"
)
async def create_notification(
    obj_in: NotificationCreate,
    current_user: User = Depends(require_permission("notification.create")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[NotificationResponse]:
    """
    Creates a notification. Scoped to tenants. Enforces notification.create permissions.
    """
    logger.info(
        f"create_notification endpoint called: tenant_id={tenant_id}, school_id={obj_in.school_id}, "
        f"target_user_id={obj_in.target_user_id}, target_role={obj_in.target_role}, "
        f"notification_type={obj_in.notification_type}, created_by={current_user.id}, "
        f"related_module={obj_in.related_module}, related_record_id={obj_in.related_record_id}"
    )

    try:
        school_id = obj_in.school_id
        if not school_id:
            if current_user.schools:
                school_id = current_user.schools[0].id
                logger.info(f"Resolved default school_id from user profile: {school_id}")
            else:
                from sqlalchemy import select
                from app.models.school import School
                stmt_s = select(School.id).where(School.tenant_id == tenant_id, School.deleted_at.is_(None))
                res_s = await service.notification_repo.db.execute(stmt_s)
                school_id = res_s.scalar_one_or_none()
                if school_id:
                    logger.info(f"Resolved default school_id from tenant schools: {school_id}")
                else:
                    logger.error("School ID is required but could not be resolved from user profile or tenant schools.")
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="School ID is required but could not be resolved."
                    )

        if obj_in.target_user_id:
            # Check that target user is in the same tenant
            from app.repositories.auth import UserRepository
            user_repo = UserRepository(service.notification_repo.db)
            target_user = await user_repo.get_by_id(obj_in.target_user_id, tenant_id)
            if not target_user:
                logger.warning(f"Target user {obj_in.target_user_id} not found in tenant {tenant_id}.")
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Target user not found in current tenant."
                )

            created = await service._create_user_notification(
                tenant_id=tenant_id,
                school_id=school_id,
                obj_in=obj_in,
                created_by=current_user.id
            )
            if not created:
                logger.warning(f"Notification creation bypassed for user {obj_in.target_user_id} due to preferences.")
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Notification could not be created because target user has disabled this notification category."
                )
            
            logger.info("Executing db.commit() for custom user notification...")
            await service.notification_repo.db.commit()
            logger.info("db.commit() completed successfully.")
            
            refreshed = await service.notification_repo.get_by_id(created.id, tenant_id)
        else:
            # Broadcast announcement
            created_list = await service.notify_announcement(
                tenant_id=tenant_id,
                school_id=school_id,
                title=obj_in.title,
                message=obj_in.message,
                target_role=obj_in.target_role
            )
            if not created_list:
                logger.warning(f"No matching active users found in target role {obj_in.target_role}.")
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="No matching active users found in target role."
                )
            
            logger.info("Executing db.commit() for broadcast announcement...")
            await service.notification_repo.db.commit()
            logger.info("db.commit() completed successfully.")
            
            # Refresh first item
            refreshed = await service.notification_repo.get_by_id(created_list[0].id, tenant_id)

        return APIResponse(
            success=True,
            message="Notification created successfully.",
            data=NotificationResponse.model_validate(refreshed)
        )

    except HTTPException:
        logger.info("Handling known HTTPException, rolling back transaction...")
        await service.notification_repo.db.rollback()
        raise
    except Exception as ex:
        logger.error(f"Unexpected error in create_notification: {str(ex)}")
        tb_str = traceback.format_exc()
        logger.error(f"Traceback:\n{tb_str}")
        await service.notification_repo.db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "error": str(ex),
                "traceback": tb_str
            }
        )


@router.get(
    "",
    response_model=APIResponse[List[NotificationResponse]],
    status_code=status.HTTP_200_OK,
    summary="Retrieve paginated list of user's own notifications"
)
async def list_notifications(
    notification_type: Optional[NotificationType] = None,
    priority: Optional[NotificationPriority] = None,
    notification_status: Optional[NotificationStatus] = Query(None, alias="status"),
    filter_date: Optional[date] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    current_user: User = Depends(require_permission("notification.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[List[NotificationResponse]]:
    """
    Returns list of notifications scoped to the current user and their active roles.
    """
    user_role_codes = [r.code for r in current_user.roles]
    results = await service.get_multi(
        tenant_id=tenant_id,
        user_id=current_user.id,
        user_roles=user_role_codes,
        notification_type=notification_type,
        priority=priority,
        status=notification_status,
        filter_date=filter_date,
        skip=skip,
        limit=limit
    )
    return APIResponse(
        success=True,
        message="Notifications retrieved successfully.",
        data=[NotificationResponse.model_validate(r) for r in results]
    )


@router.get(
    "/unread-count",
    response_model=APIResponse[UnreadCountResponse],
    status_code=status.HTTP_200_OK,
    summary="Get count of unread notifications"
)
async def get_unread_count(
    current_user: User = Depends(require_permission("notification.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[UnreadCountResponse]:
    """
    Retrieves unread notifications total count.
    """
    count = await service.count_unread(tenant_id, current_user)
    return APIResponse(
        success=True,
        message="Unread notification count retrieved.",
        data=UnreadCountResponse(unread_count=count)
    )


@router.get(
    "/{id}",
    response_model=APIResponse[NotificationResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single notification details"
)
async def get_notification(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("notification.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[NotificationResponse]:
    """
    Returns a single notification checking boundary mapping.
    """
    obj = await service.get_by_id(id, tenant_id, current_user)
    return APIResponse(
        success=True,
        message="Notification details retrieved.",
        data=NotificationResponse.model_validate(obj)
    )


@router.put(
    "/{id}/read",
    response_model=APIResponse[NotificationResponse],
    status_code=status.HTTP_200_OK,
    summary="Mark single notification as read"
)
async def mark_notification_read(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("notification.mark_read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[NotificationResponse]:
    """
    Marks a notification as read.
    """
    updated = await service.mark_read(id, tenant_id, current_user)
    return APIResponse(
        success=True,
        message="Notification marked as read.",
        data=NotificationResponse.model_validate(updated)
    )


@router.put(
    "/read-all",
    response_model=APIResponse[int],
    status_code=status.HTTP_200_OK,
    summary="Mark all unread notifications of current user as read"
)
async def mark_all_notifications_read(
    current_user: User = Depends(require_permission("notification.mark_read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[int]:
    """
    Marks all notifications targeting the user or their roles as read.
    """
    count = await service.mark_all_read(tenant_id, current_user)
    return APIResponse(
        success=True,
        message=f"All unread notifications marked as read.",
        data=count
    )


@router.delete(
    "/{id}",
    response_model=APIResponse[NotificationResponse],
    status_code=status.HTTP_200_OK,
    summary="Soft delete a notification"
)
async def delete_notification(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("notification.delete")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[NotificationResponse]:
    """
    Soft deletes a notification.
    """
    deleted = await service.delete_notification(id, tenant_id, current_user)
    return APIResponse(
        success=True,
        message="Notification deleted successfully.",
        data=NotificationResponse.model_validate(deleted)
    )


# --- PREFERENCES CONTROLLERS ---

@preferences_router.get(
    "",
    response_model=APIResponse[NotificationPreferenceResponse],
    status_code=status.HTTP_200_OK,
    summary="Get user's notification preferences"
)
async def get_notification_preferences(
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[NotificationPreferenceResponse]:
    """
    Retrieves user preferences config. Auto-creates defaults if none exist.
    """
    pref = await service.get_preferences(current_user.id, tenant_id)
    return APIResponse(
        success=True,
        message="Notification preferences retrieved.",
        data=NotificationPreferenceResponse.model_validate(pref)
    )


@preferences_router.put(
    "",
    response_model=APIResponse[NotificationPreferenceResponse],
    status_code=status.HTTP_200_OK,
    summary="Update user's notification preferences"
)
async def update_notification_preferences(
    obj_in: NotificationPreferenceUpdate,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[NotificationPreferenceResponse]:
    """
    Updates user preference settings.
    """
    updated = await service.update_preferences(current_user.id, tenant_id, obj_in)
    return APIResponse(
        success=True,
        message="Notification preferences updated successfully.",
        data=NotificationPreferenceResponse.model_validate(updated)
    )
