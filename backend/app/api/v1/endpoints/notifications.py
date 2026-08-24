import uuid
import logging
import traceback
from typing import List, Optional, Dict, Any
from datetime import date, datetime, timezone
from fastapi import APIRouter, Depends, status, HTTPException, Query
from sqlalchemy import select

from app.api.dependencies.auth import require_permission, get_current_user
from app.api.dependencies.notification import get_notification_service
from app.api.dependencies.common import get_tenant_id
from app.services.notification import NotificationService
from app.schemas.notification import (
    NotificationCreate, NotificationUpdate, NotificationResponse,
    NotificationPreferenceResponse, NotificationPreferenceUpdate, UnreadCountResponse,
    DeviceTokenCreate, DeviceTokenDeactivate, DeviceTokenResponse, NotificationDeliveryResponse
)
from app.schemas.response import APIResponse
from app.models.user import User
from app.models.notification import NotificationType, NotificationPriority, NotificationStatus, NotificationDelivery, NotificationTargetRole

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
        f"notification_type={obj_in.notification_type}, created_by={current_user.id}"
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

            created = await service.dispatch_event(
                tenant_id=tenant_id,
                school_id=school_id,
                event_type=obj_in.event_type or "GENERAL",
                payload=obj_in.model_dump(),
                created_by=current_user.id
            )
            if not created:
                logger.warning(f"Notification creation bypassed for user {obj_in.target_user_id} due to preferences.")
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Notification could not be created because target user has disabled this notification category."
                )
            
            refreshed = created[0]
        else:
            # Broadcast announcement
            created_list = await service.dispatch_event(
                tenant_id=tenant_id,
                school_id=school_id,
                event_type="ANNOUNCEMENT",
                payload=obj_in.model_dump(),
                created_by=current_user.id
            )
            if not created_list:
                logger.warning(f"No matching active users found in target role {obj_in.target_role}.")
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="No matching active users found in target role."
                )
            
            refreshed = created_list[0]

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
    "/deliveries",
    response_model=APIResponse[List[NotificationDeliveryResponse]],
    status_code=status.HTTP_200_OK,
    summary="Retrieve notification delivery tracking records"
)
async def list_deliveries(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    current_user: User = Depends(require_permission("notification.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[List[NotificationDeliveryResponse]]:
    """
    Returns delivery logs for monitoring.
    """
    stmt = select(NotificationDelivery).where(
        NotificationDelivery.tenant_id == tenant_id
    ).order_by(NotificationDelivery.created_at.desc()).offset(skip).limit(limit)
    res = await service.notification_repo.db.execute(stmt)
    deliveries = res.scalars().all()
    return APIResponse(
        success=True,
        message="Notification deliveries retrieved successfully.",
        data=[NotificationDeliveryResponse.model_validate(d) for d in deliveries]
    )


@router.get(
    "/tenant-preferences",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Get tenant-wide notification preferences/policies"
)
async def get_tenant_preferences(
    current_user: User = Depends(require_permission("settings.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[Dict[str, Any]]:
    from app.models.tenant import Tenant
    stmt = select(Tenant).where(Tenant.id == tenant_id)
    res = await service.notification_repo.db.execute(stmt)
    tenant = res.scalar_one_or_none()
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found.")
    return APIResponse(
        success=True,
        message="Tenant-wide notification preferences retrieved.",
        data=tenant.settings or {}
    )


@router.put(
    "/tenant-preferences",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Update tenant-wide notification preferences/policies"
)
async def update_tenant_preferences(
    payload: Dict[str, Any],
    current_user: User = Depends(require_permission("settings.update")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[Dict[str, Any]]:
    from app.models.tenant import Tenant
    stmt = select(Tenant).where(Tenant.id == tenant_id)
    res = await service.notification_repo.db.execute(stmt)
    tenant = res.scalar_one_or_none()
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found.")
    
    if tenant.settings is None:
        tenant.settings = {}
    
    for k, v in payload.items():
        tenant.settings[k] = v
        
    service.notification_repo.db.add(tenant)
    await service.notification_repo.db.commit()
    await service.notification_repo.db.refresh(tenant)
    return APIResponse(
        success=True,
        message="Tenant-wide notification preferences updated.",
        data=tenant.settings
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


@router.post(
    "/{id}/publish",
    response_model=APIResponse[NotificationResponse],
    status_code=status.HTTP_200_OK,
    summary="Publish a scheduled notification immediately"
)
async def publish_notification(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("notification.create")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[NotificationResponse]:
    notif = await service.notification_repo.get_by_id(id, tenant_id)
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found.")
    
    if notif.published_at is not None:
        raise HTTPException(status_code=400, detail="Notification is already published.")
        
    notif.published_at = datetime.now(timezone.utc)
    
    from app.models.tenant import Tenant
    stmt_t = select(Tenant).where(Tenant.id == tenant_id)
    res_t = await service.notification_repo.db.execute(stmt_t)
    tenant_obj = res_t.scalar_one_or_none()
    tenant_settings = tenant_obj.settings if tenant_obj else {}
    
    await service._dispatch_deliveries_for_notification(service.notification_repo.db, notif, tenant_settings)
    await service.notification_repo.db.commit()
    await service.notification_repo.db.refresh(notif)
    
    return APIResponse(
        success=True,
        message="Scheduled notification published immediately.",
        data=NotificationResponse.model_validate(notif)
    )


@router.post(
    "/{id}/cancel",
    response_model=APIResponse[NotificationResponse],
    status_code=status.HTTP_200_OK,
    summary="Cancel a scheduled notification"
)
async def cancel_notification(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("notification.delete")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[NotificationResponse]:
    notif = await service.notification_repo.get_by_id(id, tenant_id)
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found.")
        
    if notif.published_at is not None:
        raise HTTPException(status_code=400, detail="Cannot cancel an already published notification.")
        
    notif.deleted_at = datetime.now(timezone.utc)
    notif.updated_by = current_user.id
    
    await service.notification_repo.db.commit()
    await service.notification_repo.db.refresh(notif)
    
    return APIResponse(
        success=True,
        message="Scheduled notification cancelled.",
        data=NotificationResponse.model_validate(notif)
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


@router.post(
    "/device-tokens",
    response_model=APIResponse[DeviceTokenResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Register a new or update an existing user device token"
)
async def register_device_token(
    obj_in: DeviceTokenCreate,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[DeviceTokenResponse]:
    """
    Registers a device token for push notifications. Scoped to the authenticated user.
    """
    token = await service.register_device_token(
        tenant_id=tenant_id,
        user_id=current_user.id,
        device_token=obj_in.device_token,
        platform=obj_in.platform,
        app_type=obj_in.app_type
    )
    return APIResponse(
        success=True,
        message="Device token registered successfully.",
        data=DeviceTokenResponse.model_validate(token)
    )


@router.post(
    "/device-tokens/deactivate",
    response_model=APIResponse[Optional[DeviceTokenResponse]],
    status_code=status.HTTP_200_OK,
    summary="Deactivate a registered device token"
)
async def deactivate_device_token(
    obj_in: DeviceTokenDeactivate,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: NotificationService = Depends(get_notification_service)
) -> APIResponse[Optional[DeviceTokenResponse]]:
    """
    Deactivates a device token. Scoped to the authenticated user.
    """
    token = await service.deactivate_device_token(
        tenant_id=tenant_id,
        user_id=current_user.id,
        device_token=obj_in.device_token
    )
    return APIResponse(
        success=True,
        message="Device token deactivated successfully.",
        data=DeviceTokenResponse.model_validate(token) if token else None
    )
