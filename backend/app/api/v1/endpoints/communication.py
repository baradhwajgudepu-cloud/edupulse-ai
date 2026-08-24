import uuid
import logging
import os
import io
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, status, HTTPException, Query, UploadFile, File, Form
from fastapi.responses import FileResponse, StreamingResponse

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.communication import get_communication_service
from app.services.communication import CommunicationService
from app.services.storage import get_storage_service, StorageService
from app.schemas.communication import (
    CommunicationRequestCreate, CommunicationRequestResponse,
    CommunicationRequestDetailResponse, CommunicationMessageSchema,
    CommunicationAnalyticsResponse, CommunicationAttachmentSchema,
    UnreadCountResponse
)
from app.schemas.response import APIResponse
from app.models.user import User
from app.models.communication import RequestStatus, RequestCategory, RequestPriority

logger = logging.getLogger(__name__)

router = APIRouter()

UPLOAD_DIR = "storage/private/attachments"

@router.post(
    "/requests",
    response_model=APIResponse[CommunicationRequestResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new communication request thread"
)
async def create_request(
    payload: CommunicationRequestCreate,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[CommunicationRequestResponse]:
    """
    Creates a new communication request/ticket.
    Enforces that parents can only open requests for their own children.
    """
    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.student import Student
        stmt = select(Student.school_id).where(
            Student.id == payload.student_id,
            Student.tenant_id == tenant_id
        )
        res = await service.repo.db.execute(stmt)
        school_id = res.scalar_one_or_none()

    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found or not associated with any active school."
        )

    db_request = await service.create_request(
        tenant_id=tenant_id,
        school_id=school_id,
        current_user=current_user,
        payload=payload
    )

    reqs = await service.get_requests(
        tenant_id=tenant_id,
        school_id=school_id,
        current_user=current_user,
        student_id=payload.student_id,
        limit=1
    )
    enrich = next((r for r in reqs if r.id == db_request.id), None)
    if not enrich:
        enrich = CommunicationRequestResponse(
            id=db_request.id,
            tenant_id=db_request.tenant_id,
            school_id=db_request.school_id,
            student_id=db_request.student_id,
            creator_id=db_request.creator_id,
            assigned_to_id=db_request.assigned_to_id,
            recipient_type=db_request.recipient_type,
            category=db_request.category,
            module=db_request.module,
            reference_type=db_request.reference_type,
            reference_id=db_request.reference_id,
            subject=db_request.subject,
            priority=db_request.priority,
            status=db_request.status,
            created_at=db_request.created_at,
            updated_at=db_request.updated_at,
            resolved_at=db_request.resolved_at,
            is_active=db_request.is_active,
            version=db_request.version,
            unread_messages_count=0
        )

    return APIResponse(
        success=True,
        message="Communication request created successfully.",
        data=enrich
    )


@router.get(
    "/requests",
    response_model=APIResponse[List[CommunicationRequestResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get filtered list of communication requests"
)
async def get_requests(
    status: Optional[RequestStatus] = None,
    category: Optional[RequestCategory] = None,
    priority: Optional[RequestPriority] = None,
    student_id: Optional[uuid.UUID] = None,
    creator_id: Optional[uuid.UUID] = None,
    assigned_to_id: Optional[uuid.UUID] = None,
    search: Optional[str] = None,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[List[CommunicationRequestResponse]]:
    """
    Retrieves communication requests with RBAC.
    """
    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.school import School
        stmt = select(School.id).where(School.tenant_id == tenant_id, School.deleted_at.is_(None))
        res = await service.repo.db.execute(stmt)
        school_id = res.scalar_one_or_none()

    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active school not found for this tenant."
        )

    requests = await service.get_requests(
        tenant_id=tenant_id,
        school_id=school_id,
        current_user=current_user,
        status=status,
        category=category,
        priority=priority,
        student_id=student_id,
        creator_id=creator_id,
        assigned_to_id=assigned_to_id,
        search=search,
        skip=skip,
        limit=limit
    )

    return APIResponse(
        success=True,
        message="Communication requests retrieved successfully.",
        data=requests
    )


@router.get(
    "/requests/{request_id}",
    response_model=APIResponse[CommunicationRequestDetailResponse],
    status_code=status.HTTP_200_OK,
    summary="Get full details and messages of a communication request"
)
async def get_request_details(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[CommunicationRequestDetailResponse]:
    """
    Retrieves full details of a specific communication request including messages,
    participants, and audit logs. Marks the request as read for the current user.
    """
    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.communication import CommunicationRequest
        stmt = select(CommunicationRequest.school_id).where(
            CommunicationRequest.id == request_id,
            CommunicationRequest.tenant_id == tenant_id
        )
        res = await service.repo.db.execute(stmt)
        school_id = res.scalar_one_or_none()

    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Request not found or school could not be resolved."
        )

    details = await service.get_request_details(
        tenant_id=tenant_id,
        school_id=school_id,
        request_id=request_id,
        current_user=current_user
    )

    return APIResponse(
        success=True,
        message="Communication request details retrieved successfully.",
        data=details
    )


@router.post("/requests/{request_id}/messages", response_model=APIResponse[CommunicationMessageSchema], status_code=status.HTTP_201_CREATED)
@router.post("/requests/{request_id}/reply", response_model=APIResponse[CommunicationMessageSchema], status_code=status.HTTP_201_CREATED)
async def post_message(
    request_id: uuid.UUID,
    payload: Dict[str, str], # Expects {"message": "..."}
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[CommunicationMessageSchema]:
    """
    Posts a new message reply to the thread. Triggers notifications for other participants.
    """
    msg_text = payload.get("message")
    if not msg_text or not msg_text.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Message content cannot be empty."
        )

    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.communication import CommunicationRequest
        stmt = select(CommunicationRequest.school_id).where(
            CommunicationRequest.id == request_id,
            CommunicationRequest.tenant_id == tenant_id
        )
        res = await service.repo.db.execute(stmt)
        school_id = res.scalar_one_or_none()

    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Request not found or school could not be resolved."
        )

    db_msg = await service.reply_to_request(
        tenant_id=tenant_id,
        school_id=school_id,
        request_id=request_id,
        current_user=current_user,
        message=msg_text
    )

    # Convert messages list to schema formatting
    attachments_list = []

    return APIResponse(
        success=True,
        message="Reply posted successfully.",
        data=CommunicationMessageSchema(
            id=db_msg.id,
            request_id=db_msg.request_id,
            sender_id=db_msg.sender_id,
            sender_role=db_msg.sender_role,
            message=db_msg.message,
            created_at=db_msg.created_at,
            attachments=attachments_list
        )
    )


@router.patch("/requests/{request_id}/status", response_model=APIResponse[CommunicationRequestResponse], status_code=status.HTTP_200_OK)
async def update_status(
    request_id: uuid.UUID,
    payload: Dict[str, str], # Expects {"status": "RESOLVED"}
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[CommunicationRequestResponse]:
    """
    Updates the request status.
    """
    status_str = payload.get("status")
    if not status_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Status field is required."
        )
    try:
        new_status = RequestStatus(status_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status value. Must be one of: {[s.value for s in RequestStatus]}"
        )

    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.communication import CommunicationRequest
        stmt = select(CommunicationRequest.school_id).where(
            CommunicationRequest.id == request_id,
            CommunicationRequest.tenant_id == tenant_id
        )
        res = await service.repo.db.execute(stmt)
        school_id = res.scalar_one_or_none()

    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Request not found or school could not be resolved."
        )

    db_request = await service.update_status(
        tenant_id=tenant_id,
        school_id=school_id,
        request_id=request_id,
        current_user=current_user,
        new_status=new_status
    )

    reqs = await service.get_requests(
        tenant_id=tenant_id,
        school_id=school_id,
        current_user=current_user,
        student_id=db_request.student_id,
        limit=1
    )
    enrich = next((r for r in reqs if r.id == db_request.id), None)
    if not enrich:
        enrich = CommunicationRequestResponse.model_validate(db_request)

    return APIResponse(
        success=True,
        message="Status updated successfully.",
        data=enrich
    )


@router.post("/requests/{request_id}/assign", response_model=APIResponse[CommunicationRequestResponse], status_code=status.HTTP_200_OK)
@router.patch("/requests/{request_id}/assign", response_model=APIResponse[CommunicationRequestResponse], status_code=status.HTTP_200_OK)
async def assign_request(
    request_id: uuid.UUID,
    payload: Dict[str, str], # Expects {"assignee_id": "uuid"}
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[CommunicationRequestResponse]:
    """
    Re-assigns a request to another teacher or staff member.
    """
    assignee_str = payload.get("assignee_id")
    if not assignee_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="assignee_id is required."
        )
    try:
        assignee_id = uuid.UUID(assignee_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid UUID format for assignee_id."
        )

    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.communication import CommunicationRequest
        stmt = select(CommunicationRequest.school_id).where(
            CommunicationRequest.id == request_id,
            CommunicationRequest.tenant_id == tenant_id
        )
        res = await service.repo.db.execute(stmt)
        school_id = res.scalar_one_or_none()

    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Request not found or school could not be resolved."
        )

    # Assignment must only show teachers belonging to the same school
    from app.models.role import school_users
    from sqlalchemy import select
    stmt_check = select(User).join(school_users).where(
        User.id == assignee_id,
        school_users.c.school_id == school_id
    )
    res_check = await service.repo.db.execute(stmt_check)
    if not res_check.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The assigned user must belong to the same school."
        )

    db_request = await service.assign_request(
        tenant_id=tenant_id,
        school_id=school_id,
        request_id=request_id,
        current_user=current_user,
        assignee_id=assignee_id
    )

    reqs = await service.get_requests(
        tenant_id=tenant_id,
        school_id=school_id,
        current_user=current_user,
        student_id=db_request.student_id,
        limit=1
    )
    enrich = next((r for r in reqs if r.id == db_request.id), None)
    if not enrich:
        enrich = CommunicationRequestResponse.model_validate(db_request)

    return APIResponse(
        success=True,
        message="Request assigned successfully.",
        data=enrich
    )


@router.post(
    "/requests/{request_id}/escalate",
    response_model=APIResponse[CommunicationRequestResponse],
    status_code=status.HTTP_200_OK,
    summary="Escalate a request to the principal"
)
async def escalate_request(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[CommunicationRequestResponse]:
    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.communication import CommunicationRequest
        stmt = select(CommunicationRequest.school_id).where(
            CommunicationRequest.id == request_id,
            CommunicationRequest.tenant_id == tenant_id
        )
        res = await service.repo.db.execute(stmt)
        school_id = res.scalar_one_or_none()

    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Request not found or school could not be resolved."
        )

    db_request = await service.escalate_request(
        tenant_id=tenant_id,
        school_id=school_id,
        request_id=request_id,
        current_user=current_user
    )

    reqs = await service.get_requests(
        tenant_id=tenant_id,
        school_id=school_id,
        current_user=current_user,
        student_id=db_request.student_id,
        limit=1
    )
    enrich = next((r for r in reqs if r.id == db_request.id), None)
    if not enrich:
        enrich = CommunicationRequestResponse.model_validate(db_request)

    return APIResponse(
        success=True,
        message="Request escalated successfully.",
        data=enrich
    )


@router.post(
    "/requests/{request_id}/resolve",
    response_model=APIResponse[CommunicationRequestResponse],
    status_code=status.HTTP_200_OK,
    summary="Resolve a communication request"
)
async def resolve_request(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[CommunicationRequestResponse]:
    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.communication import CommunicationRequest
        stmt = select(CommunicationRequest.school_id).where(
            CommunicationRequest.id == request_id,
            CommunicationRequest.tenant_id == tenant_id
        )
        res = await service.repo.db.execute(stmt)
        school_id = res.scalar_one_or_none()

    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Request not found or school could not be resolved."
        )

    db_request = await service.update_status(
        tenant_id=tenant_id,
        school_id=school_id,
        request_id=request_id,
        current_user=current_user,
        new_status=RequestStatus.RESOLVED
    )

    reqs = await service.get_requests(
        tenant_id=tenant_id,
        school_id=school_id,
        current_user=current_user,
        student_id=db_request.student_id,
        limit=1
    )
    enrich = next((r for r in reqs if r.id == db_request.id), None)
    if not enrich:
        enrich = CommunicationRequestResponse.model_validate(db_request)

    return APIResponse(
        success=True,
        message="Request resolved successfully.",
        data=enrich
    )


@router.post(
    "/requests/{request_id}/reopen",
    response_model=APIResponse[CommunicationRequestResponse],
    status_code=status.HTTP_200_OK,
    summary="Reopen a communication request"
)
async def reopen_request(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[CommunicationRequestResponse]:
    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.communication import CommunicationRequest
        stmt = select(CommunicationRequest.school_id).where(
            CommunicationRequest.id == request_id,
            CommunicationRequest.tenant_id == tenant_id
        )
        res = await service.repo.db.execute(stmt)
        school_id = res.scalar_one_or_none()

    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Request not found or school could not be resolved."
        )

    db_request = await service.update_status(
        tenant_id=tenant_id,
        school_id=school_id,
        request_id=request_id,
        current_user=current_user,
        new_status=RequestStatus.REOPENED
    )

    reqs = await service.get_requests(
        tenant_id=tenant_id,
        school_id=school_id,
        current_user=current_user,
        student_id=db_request.student_id,
        limit=1
    )
    enrich = next((r for r in reqs if r.id == db_request.id), None)
    if not enrich:
        enrich = CommunicationRequestResponse.model_validate(db_request)

    return APIResponse(
        success=True,
        message="Request reopened successfully.",
        data=enrich
    )


@router.get(
    "/unread-count",
    response_model=APIResponse[UnreadCountResponse],
    status_code=status.HTTP_200_OK,
    summary="Get total unread messages count for active user"
)
async def get_unread_count(
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[UnreadCountResponse]:
    count = await service.repo.get_unread_count(tenant_id, current_user.id)
    return APIResponse(
        success=True,
        message="Unread count retrieved successfully.",
        data=UnreadCountResponse(unread_count=count)
    )


@router.get(
    "/analytics",
    response_model=APIResponse[CommunicationAnalyticsResponse],
    status_code=status.HTTP_200_OK,
    summary="Get aggregated metrics and SLA breach details"
)
async def get_analytics(
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[CommunicationAnalyticsResponse]:
    """
    Returns dashboard metrics for communication requests. Restricted to Admin/Principal.
    """
    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.school import School
        stmt = select(School.id).where(School.tenant_id == tenant_id, School.deleted_at.is_(None))
        res = await service.repo.db.execute(stmt)
        school_id = res.scalars().first()

    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active school not found for tenant."
        )

    analytics = await service.get_analytics(
        tenant_id=tenant_id,
        school_id=school_id,
        current_user=current_user
    )

    return APIResponse(
        success=True,
        message="Analytics retrieved successfully.",
        data=analytics
    )


@router.post(
    "/attachments",
    response_model=APIResponse[CommunicationAttachmentSchema],
    status_code=status.HTTP_201_CREATED,
    summary="Upload an attachment to a message"
)
async def upload_attachment(
    message_id: uuid.UUID = Form(...),
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> APIResponse[CommunicationAttachmentSchema]:
    contents = await file.read()
    file_size = len(contents)
    max_size = 10 * 1024 * 1024
    if file_size > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File size exceeds the 10MB limit."
        )
    await file.seek(0)
    
    filename = file.filename
    ext = os.path.splitext(filename)[1].lower().strip(".")
    allowed_exts = {"pdf", "png", "jpg", "jpeg", "doc", "docx", "xls", "xlsx", "txt"}
    if ext not in allowed_exts:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Extension .{ext} is not allowed."
        )
        
    allowed_mimes = {
        "application/pdf", "image/png", "image/jpeg", "image/pjpeg",
        "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "text/plain"
    }
    if file.content_type not in allowed_mimes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"MIME type {file.content_type} is not allowed."
        )
        
    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.communication import CommunicationMessage, CommunicationRequest
        stmt = select(CommunicationRequest.school_id).join(
            CommunicationMessage, CommunicationMessage.request_id == CommunicationRequest.id
        ).where(CommunicationMessage.id == message_id)
        res = await service.repo.db.execute(stmt)
        school_id = res.scalar_one_or_none()
        
    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_442_UNPROCESSABLE_ENTITY,
            detail="School could not be resolved."
        )
        
    attachment_id = uuid.uuid4()
    gcs_path = f"attachments/{attachment_id}"
    await storage_service.upload(contents, gcs_path, file.content_type)
        
    file_url = f"/api/v1/communication/attachments/{attachment_id}"
    attachment = await service.upload_attachment(
        id=attachment_id,
        tenant_id=tenant_id,
        school_id=school_id,
        message_id=message_id,
        current_user=current_user,
        file_name=filename,
        file_type=file.content_type,
        file_size=file_size,
        file_url=file_url
    )
    
    return APIResponse(
        success=True,
        message="Attachment uploaded successfully.",
        data=CommunicationAttachmentSchema.model_validate(attachment)
    )


@router.get(
    "/attachments/{attachment_id}",
    summary="Download message attachment"
)
async def download_attachment(
    attachment_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service),
    storage_service: StorageService = Depends(get_storage_service)
) -> StreamingResponse:
    attachment = await service.get_attachment(
        tenant_id=tenant_id,
        attachment_id=attachment_id,
        current_user=current_user
    )
    
    gcs_path = f"attachments/{attachment_id}"
    try:
        file_bytes = await storage_service.download(gcs_path)
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Physical file not found in storage."
        )
        
    return StreamingResponse(
        io.BytesIO(file_bytes),
        media_type=attachment.file_type,
        headers={"Content-Disposition": f'attachment; filename="{attachment.file_name}"'}
    )


@router.get(
    "/requests/{request_id}/ai-insights",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Get AI analysis (sentiment, escalation risk, reply suggestions) for a request thread"
)
async def get_ai_insights(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: CommunicationService = Depends(get_communication_service)
) -> APIResponse[Dict[str, Any]]:
    """
    Leverages Gemini LLM to return sentiment, risk category, and smart reply suggestions.
    """
    school_id = None
    if current_user.schools:
        school_id = current_user.schools[0].id
    else:
        from sqlalchemy import select
        from app.models.communication import CommunicationRequest
        stmt = select(CommunicationRequest.school_id).where(
            CommunicationRequest.id == request_id,
            CommunicationRequest.tenant_id == tenant_id
        )
        res = await service.repo.db.execute(stmt)
        school_id = res.scalar_one_or_none()

    if not school_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Request not found or school could not be resolved."
        )

    insights = await service.get_ai_insights(
        tenant_id=tenant_id,
        school_id=school_id,
        request_id=request_id,
        current_user=current_user
    )

    return APIResponse(
        success=True,
        message="AI insights generated successfully.",
        data=insights
    )
