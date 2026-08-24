import uuid
import logging
from datetime import datetime, timezone, timedelta
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy import select, and_, or_
from sqlalchemy.orm import joinedload

from app.models.communication import (
    CommunicationRequest, CommunicationMessage, CommunicationParticipant,
    CommunicationAttachment, CommunicationAuditLog, RequestStatus, RequestPriority,
    RequestCategory, RecipientType, Module
)
from app.models.student import Student
from app.models.guardian import Guardian, StudentGuardian
from app.models.teacher import Teacher
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.user import User, UserStatus
from app.models.role import Role
from app.repositories.communication import CommunicationRepository
from app.schemas.communication import (
    CommunicationRequestCreate, CommunicationRequestResponse, CommunicationRequestDetailResponse,
    CommunicationMessageSchema, CommunicationParticipantSchema, CommunicationAuditLogSchema,
    CommunicationAttachmentSchema, CommunicationAnalyticsResponse
)
from app.services.notification import NotificationService
from app.services.ai.service import AIService
from app.models.notification import NotificationType, NotificationPriority, NotificationTargetRole
from app.schemas.notification import NotificationCreate

logger = logging.getLogger(__name__)

# SLA Thresholds in hours
SLA_THRESHOLDS = {
    RequestPriority.LOW: 72,
    RequestPriority.NORMAL: 48,
    RequestPriority.HIGH: 24,
    RequestPriority.URGENT: 4
}

class CommunicationService:
    """
    Service Layer implementing business logic, permissions validation,
    notification triggering, and AI integrations for Communication Requests.
    """
    def __init__(
        self,
        repo: CommunicationRepository,
        notification_service: Optional[NotificationService] = None,
        ai_service: Optional[AIService] = None
    ) -> None:
        self.repo = repo
        self.notification_service = notification_service
        self.ai_service = ai_service

    async def _send_notification(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        target_user_id: uuid.UUID,
        target_role: str,
        title: str,
        message: str,
        request_id: uuid.UUID,
        creator_id: Optional[uuid.UUID]
    ) -> None:
        if not self.notification_service:
            return
        
        # Translate role to target role enum
        role_map = {
            "PARENT": NotificationTargetRole.PARENT,
            "TEACHER": NotificationTargetRole.TEACHER,
            "CLASS_TEACHER": NotificationTargetRole.TEACHER,
            "PRINCIPAL": NotificationTargetRole.PRINCIPAL,
            "ADMIN": NotificationTargetRole.ADMIN
        }
        r_role = role_map.get(target_role.upper(), NotificationTargetRole.STAFF)

        obj_in = NotificationCreate(
            notification_type=NotificationType.ANNOUNCEMENT,
            priority=NotificationPriority.NORMAL,
            title=title,
            message=message,
            target_role=r_role,
            school_id=school_id,
            target_user_id=target_user_id,
            related_module="COMMUNICATION",
            related_record_id=request_id
        )
        try:
            await self.notification_service._create_user_notification(
                tenant_id=tenant_id,
                school_id=school_id,
                obj_in=obj_in,
                created_by=creator_id
            )
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")

    async def _resolve_class_teacher(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, student: Student
    ) -> Optional[User]:
        stmt = select(User).join(Teacher, Teacher.user_id == User.id).join(
            TeacherSubjectAssignment, TeacherSubjectAssignment.teacher_id == Teacher.id
        ).where(
            TeacherSubjectAssignment.class_id == student.class_id,
            TeacherSubjectAssignment.section_id == student.section_id,
            TeacherSubjectAssignment.is_class_teacher == True,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.is_active == True,
            Teacher.is_active == True,
            Teacher.school_id == school_id,
            User.status == UserStatus.ACTIVE
        )
        res = await self.repo.db.execute(stmt)
        return res.scalar_one_or_none()

    async def _resolve_principal_or_admin(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID
    ) -> Optional[User]:
        from app.models.role import school_users
        stmt = select(User).join(User.roles).join(school_users).where(
            User.tenant_id == tenant_id,
            school_users.c.school_id == school_id,
            User.status == UserStatus.ACTIVE,
            Role.code == "PRINCIPAL"
        )
        res = await self.repo.db.execute(stmt)
        user = res.scalars().first()
        if not user:
            stmt = select(User).join(User.roles).join(school_users).where(
                User.tenant_id == tenant_id,
                school_users.c.school_id == school_id,
                User.status == UserStatus.ACTIVE,
                Role.code == "ADMIN"
            )
            res = await self.repo.db.execute(stmt)
            user = res.scalars().first()
        return user

    async def create_request(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        current_user: User,
        payload: CommunicationRequestCreate
    ) -> CommunicationRequest:
        # 1. Fetch and verify student
        stmt_student = select(Student).where(
            Student.id == payload.student_id,
            Student.school_id == school_id,
            Student.tenant_id == tenant_id,
            Student.deleted_at.is_(None)
        )
        res_student = await self.repo.db.execute(stmt_student)
        student = res_student.scalar_one_or_none()
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student record not found."
            )

        # 2. Verify permission (Parent can only create for their student)
        user_role_codes = {r.code for r in current_user.roles}
        is_parent = "PARENT" in user_role_codes
        
        if is_parent:
            stmt_guard = select(StudentGuardian).join(Guardian).where(
                StudentGuardian.student_id == student.id,
                Guardian.user_id == current_user.id,
                StudentGuardian.tenant_id == tenant_id
            )
            res_guard = await self.repo.db.execute(stmt_guard)
            if not res_guard.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied. You are not a registered guardian for this student."
                )

        # 3. Resolve assignee and target recipient role
        assigned_to_id = None
        recipient_role = "TEACHER"
        
        if payload.recipient_type == RecipientType.CLASS_TEACHER:
            teacher_user = await self._resolve_class_teacher(tenant_id, school_id, student)
            if teacher_user:
                assigned_to_id = teacher_user.id
                recipient_role = "CLASS_TEACHER"
            else:
                # Fallback to principal/admin
                principal_user = await self._resolve_principal_or_admin(tenant_id, school_id)
                if principal_user:
                    assigned_to_id = principal_user.id
                    recipient_role = "PRINCIPAL"
        elif payload.recipient_type == RecipientType.PRINCIPAL:
            principal_user = await self._resolve_principal_or_admin(tenant_id, school_id)
            if principal_user:
                assigned_to_id = principal_user.id
                recipient_role = "PRINCIPAL"
        elif payload.recipient_type == RecipientType.TEACHER:
            # Fallback to class teacher if a specific teacher isn't resolved
            teacher_user = await self._resolve_class_teacher(tenant_id, school_id, student)
            if teacher_user:
                assigned_to_id = teacher_user.id
                recipient_role = "TEACHER"
        elif payload.recipient_type == RecipientType.PARENT:
            # Resolve the primary guardian user ID for the student
            stmt_guard = select(User.id).join(Guardian, User.id == Guardian.user_id).join(StudentGuardian, Guardian.id == StudentGuardian.guardian_id).where(
                StudentGuardian.student_id == student.id,
                StudentGuardian.is_primary == True,
                StudentGuardian.tenant_id == tenant_id
            )
            res_guard = await self.repo.db.execute(stmt_guard)
            assigned_to_id = res_guard.scalar()
            recipient_role = "PARENT"

        # 4. Create CommunicationRequest
        db_request = CommunicationRequest(
            tenant_id=tenant_id,
            school_id=school_id,
            student_id=student.id,
            creator_id=current_user.id,
            assigned_to_id=assigned_to_id,
            recipient_type=payload.recipient_type,
            category=payload.category,
            module=payload.module,
            reference_type=payload.reference_type,
            reference_id=payload.reference_id,
            subject=payload.subject,
            priority=payload.priority,
            status=RequestStatus.OPEN
        )
        db_request = await self.repo.create_request(db_request)

        # 5. Create participants
        creator_role = "PARENT" if is_parent else ("TEACHER" if "TEACHER" in user_role_codes else "STAFF")
        creator_part = CommunicationParticipant(
            tenant_id=tenant_id,
            school_id=school_id,
            request_id=db_request.id,
            user_id=current_user.id,
            role=creator_role,
            last_read_at=datetime.now(timezone.utc)
        )
        await self.repo.create_participant(creator_part)

        if assigned_to_id and assigned_to_id != current_user.id:
            assignee_part = CommunicationParticipant(
                tenant_id=tenant_id,
                school_id=school_id,
                request_id=db_request.id,
                user_id=assigned_to_id,
                role=recipient_role,
                last_read_at=None
            )
            await self.repo.create_participant(assignee_part)

        # 6. Create initial message
        initial_msg = CommunicationMessage(
            tenant_id=tenant_id,
            school_id=school_id,
            request_id=db_request.id,
            sender_id=current_user.id,
            sender_role=creator_role,
            message=payload.message
        )
        await self.repo.create_message(initial_msg)

        # 7. Create audit log
        audit = CommunicationAuditLog(
            tenant_id=tenant_id,
            school_id=school_id,
            request_id=db_request.id,
            user_id=current_user.id,
            action="REQUEST_CREATED",
            details=f"Request created with priority {payload.priority.value} and category {payload.category.value}."
        )
        await self.repo.create_audit_log(audit)

        await self.repo.db.commit()
        await self.repo.db.refresh(db_request)

        # 8. Send notification to assignee
        if assigned_to_id and assigned_to_id != current_user.id:
            await self._send_notification(
                tenant_id=tenant_id,
                school_id=school_id,
                target_user_id=assigned_to_id,
                target_role=recipient_role,
                title="New Communication Request",
                message=f"A new request has been assigned to you regarding {student.first_name}: {payload.subject}",
                request_id=db_request.id,
                creator_id=current_user.id
            )

        return db_request

    async def reply_to_request(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        request_id: uuid.UUID,
        current_user: User,
        message: str
    ) -> CommunicationMessage:
        # Get request
        request = await self.repo.get_request_by_id(request_id, school_id, tenant_id)
        if not request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Request not found."
            )

        # Verify participant or admin/principal access
        user_role_codes = {r.code for r in current_user.roles}
        is_admin_or_principal = any(r in ["ADMIN", "PRINCIPAL", "SUPER_ADMIN"] for r in user_role_codes)
        
        participant = await self.repo.get_participant(request_id, current_user.id)
        if not participant and not is_admin_or_principal:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You are not a participant in this request thread."
            )

        # Resolve role code
        sender_role = "PARENT" if "PARENT" in user_role_codes else ("TEACHER" if "TEACHER" in user_role_codes else "STAFF")

        # If user is not participant but is admin, add them as participant
        if not participant:
            participant = CommunicationParticipant(
                tenant_id=tenant_id,
                school_id=school_id,
                request_id=request_id,
                user_id=current_user.id,
                role=sender_role,
                last_read_at=datetime.now(timezone.utc)
            )
            await self.repo.create_participant(participant)
        else:
            participant.last_read_at = datetime.now(timezone.utc)

        # Create message
        db_message = CommunicationMessage(
            tenant_id=tenant_id,
            school_id=school_id,
            request_id=request_id,
            sender_id=current_user.id,
            sender_role=sender_role,
            message=message
        )
        db_message = await self.repo.create_message(db_message)

        # Update request
        request.updated_at = datetime.now(timezone.utc)
        
        # State transitions based on reply
        # If parent replies and status is WAITING_FOR_PARENT -> set to IN_PROGRESS
        if sender_role == "PARENT" and request.status == RequestStatus.WAITING_FOR_PARENT:
            request.status = RequestStatus.IN_PROGRESS
        # If teacher replies and status is OPEN -> set to IN_PROGRESS
        elif sender_role in ["TEACHER", "CLASS_TEACHER", "PRINCIPAL", "STAFF"] and request.status == RequestStatus.OPEN:
            request.status = RequestStatus.IN_PROGRESS

        # Create audit log
        audit = CommunicationAuditLog(
            tenant_id=tenant_id,
            school_id=school_id,
            request_id=request_id,
            user_id=current_user.id,
            action="REPLY_ADDED",
            details="New reply added to thread."
        )
        await self.repo.create_audit_log(audit)

        await self.repo.db.commit()
        await self.repo.db.refresh(request)

        # Notify other participants
        stmt_parts = select(CommunicationParticipant).where(
            CommunicationParticipant.request_id == request.id,
            CommunicationParticipant.deleted_at.is_(None)
        )
        res_parts = await self.repo.db.execute(stmt_parts)
        participants = res_parts.scalars().all()
        for p in participants:
            if p.user_id != current_user.id:
                await self._send_notification(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    target_user_id=p.user_id,
                    target_role=p.role,
                    title="New Reply in Communication Request",
                    message=f"A new reply has been posted by {current_user.first_name} on: {request.subject}",
                    request_id=request.id,
                    creator_id=current_user.id
                )

        return db_message

    async def update_status(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        request_id: uuid.UUID,
        current_user: User,
        new_status: RequestStatus
    ) -> CommunicationRequest:
        request = await self.repo.get_request_by_id(request_id, school_id, tenant_id)
        if not request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Request not found."
            )

        # Verification of permissions
        # Only assigned teacher, school admin/principal, or superuser can change status (except parent closing their own request)
        user_role_codes = {r.code for r in current_user.roles}
        is_staff = any(r in ["ADMIN", "PRINCIPAL", "SUPER_ADMIN", "TEACHER"] for r in user_role_codes)
        is_creator = request.creator_id == current_user.id

        if not is_staff and not (is_creator and new_status == RequestStatus.RESOLVED):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You do not have permission to change the request status."
            )

        old_status = request.status
        
        # Enforce state machine transitions
        allowed = False
        if old_status == new_status:
            allowed = True
        elif old_status == RequestStatus.OPEN:
            allowed = new_status in [RequestStatus.ACKNOWLEDGED, RequestStatus.IN_PROGRESS, RequestStatus.RESOLVED]
        elif old_status == RequestStatus.ACKNOWLEDGED:
            allowed = new_status in [RequestStatus.IN_PROGRESS, RequestStatus.RESOLVED]
        elif old_status == RequestStatus.IN_PROGRESS:
            allowed = new_status in [RequestStatus.WAITING_FOR_PARENT, RequestStatus.RESOLVED, RequestStatus.ESCALATED]
        elif old_status == RequestStatus.WAITING_FOR_PARENT:
            allowed = new_status in [RequestStatus.IN_PROGRESS, RequestStatus.RESOLVED]
        elif old_status == RequestStatus.ESCALATED:
            allowed = new_status in [RequestStatus.PRINCIPAL_REVIEW, RequestStatus.RESOLVED]
        elif old_status == RequestStatus.PRINCIPAL_REVIEW:
            allowed = new_status in [RequestStatus.IN_PROGRESS, RequestStatus.RESOLVED]
        elif old_status == RequestStatus.RESOLVED:
            allowed = new_status == RequestStatus.REOPENED
        elif old_status == RequestStatus.REOPENED:
            allowed = new_status in [RequestStatus.IN_PROGRESS, RequestStatus.RESOLVED]

        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid transition from {old_status.value} to {new_status.value}."
            )

        request.status = new_status
        request.updated_at = datetime.now(timezone.utc)

        if new_status == RequestStatus.RESOLVED:
            request.resolved_at = datetime.now(timezone.utc)

        # Audit log
        audit = CommunicationAuditLog(
            tenant_id=tenant_id,
            school_id=school_id,
            request_id=request_id,
            user_id=current_user.id,
            action="STATUS_UPDATED",
            details=f"Status changed from {old_status.value} to {new_status.value}."
        )
        await self.repo.create_audit_log(audit)

        await self.repo.db.commit()
        await self.repo.db.refresh(request)

        # Notify participants
        stmt_parts = select(CommunicationParticipant).where(
            CommunicationParticipant.request_id == request.id,
            CommunicationParticipant.deleted_at.is_(None)
        )
        res_parts = await self.repo.db.execute(stmt_parts)
        participants = res_parts.scalars().all()
        for p in participants:
            if p.user_id != current_user.id:
                await self._send_notification(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    target_user_id=p.user_id,
                    target_role=p.role,
                    title="Communication Request Status Updated",
                    message=f"Request status has been updated to {new_status.value} on: {request.subject}",
                    request_id=request.id,
                    creator_id=current_user.id
                )

        return request

    async def assign_request(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        request_id: uuid.UUID,
        current_user: User,
        assignee_id: uuid.UUID
    ) -> CommunicationRequest:
        request = await self.repo.get_request_by_id(request_id, school_id, tenant_id)
        if not request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Request not found."
            )

        # Only admins, principals, or the current assignee can delegate/assign
        user_role_codes = {r.code for r in current_user.roles}
        is_admin_or_principal = any(r in ["ADMIN", "PRINCIPAL", "SUPER_ADMIN"] for r in user_role_codes)
        is_assignee = request.assigned_to_id == current_user.id

        if not is_admin_or_principal and not is_assignee:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You do not have permission to assign this request."
            )

        # Verify assignee belongs to the tenant and is active
        stmt_assignee = select(User).where(
            User.id == assignee_id,
            User.tenant_id == tenant_id,
            User.status == UserStatus.ACTIVE
        )
        res_assignee = await self.repo.db.execute(stmt_assignee)
        assignee = res_assignee.scalar_one_or_none()
        if not assignee:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Assignee user not found or inactive."
            )

        old_assignee_id = request.assigned_to_id
        request.assigned_to_id = assignee_id
        request.updated_at = datetime.now(timezone.utc)

        # Add new assignee as participant if not already
        p = await self.repo.get_participant(request_id, assignee_id)
        if not p:
            assignee_roles = {r.code for r in assignee.roles}
            role_str = "TEACHER" if "TEACHER" in assignee_roles else "STAFF"
            new_p = CommunicationParticipant(
                tenant_id=tenant_id,
                school_id=school_id,
                request_id=request_id,
                user_id=assignee_id,
                role=role_str,
                last_read_at=None
            )
            await self.repo.create_participant(new_p)

        # Audit log
        audit = CommunicationAuditLog(
            tenant_id=tenant_id,
            school_id=school_id,
            request_id=request_id,
            user_id=current_user.id,
            action="REQUEST_ASSIGNED",
            details=f"Assigned changed from {old_assignee_id} to {assignee_id}."
        )
        await self.repo.create_audit_log(audit)

        await self.repo.db.commit()
        await self.repo.db.refresh(request)

        # Notify new assignee
        await self._send_notification(
            tenant_id=tenant_id,
            school_id=school_id,
            target_user_id=assignee_id,
            target_role="TEACHER",
            title="Communication Request Assigned to You",
            message=f"You have been assigned to communication request: {request.subject}",
            request_id=request.id,
            creator_id=current_user.id
        )

        return request

    async def mark_as_read(
        self,
        tenant_id: uuid.UUID,
        request_id: uuid.UUID,
        user_id: uuid.UUID
    ) -> None:
        p = await self.repo.get_participant(request_id, user_id)
        if p:
            p.last_read_at = datetime.now(timezone.utc)
            await self.repo.db.commit()

    async def get_requests(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        current_user: User,
        status: Optional[RequestStatus] = None,
        category: Optional[RequestCategory] = None,
        priority: Optional[RequestPriority] = None,
        student_id: Optional[uuid.UUID] = None,
        creator_id: Optional[uuid.UUID] = None,
        assigned_to_id: Optional[uuid.UUID] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[CommunicationRequestResponse]:
        user_roles = [r.code for r in current_user.roles]
        requests = await self.repo.get_requests(
            tenant_id=tenant_id,
            school_id=school_id,
            user_id=current_user.id,
            user_roles=user_roles,
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

        response_list = []
        for req in requests:
            # Enrich response fields
            unread = await self.repo.get_request_unread_count(req.id, current_user.id)
            
            # Fetch names
            student_name = None
            student_class_section = None
            creator_name = None
            assigned_to_name = None

            # Student name
            stmt_s = select(Student).where(Student.id == req.student_id).options(
                joinedload(Student.class_obj),
                joinedload(Student.section)
            )
            res_s = await self.repo.db.execute(stmt_s)
            s = res_s.scalar_one_or_none()
            if s:
                student_name = f"{s.first_name} {s.last_name}"
                if s.class_obj and s.section:
                    student_class_section = f"{s.class_obj.name} - {s.section.name}"

            # Creator name
            stmt_c = select(User).where(User.id == req.creator_id)
            res_c = await self.repo.db.execute(stmt_c)
            c = res_c.scalar_one_or_none()
            if c:
                creator_name = f"{c.first_name} {c.last_name}"

            # Assigned to name
            if req.assigned_to_id:
                stmt_a = select(User).where(User.id == req.assigned_to_id)
                res_a = await self.repo.db.execute(stmt_a)
                a = res_a.scalar_one_or_none()
                if a:
                    assigned_to_name = f"{a.first_name} {a.last_name}"

            response_list.append(
                CommunicationRequestResponse(
                    id=req.id,
                    tenant_id=req.tenant_id,
                    school_id=req.school_id,
                    student_id=req.student_id,
                    creator_id=req.creator_id,
                    assigned_to_id=req.assigned_to_id,
                    recipient_type=req.recipient_type,
                    category=req.category,
                    module=req.module,
                    reference_type=req.reference_type,
                    reference_id=req.reference_id,
                    subject=req.subject,
                    priority=req.priority,
                    status=req.status,
                    created_at=req.created_at,
                    updated_at=req.updated_at,
                    resolved_at=req.resolved_at,
                    is_active=req.is_active,
                    version=req.version,
                    unread_messages_count=unread,
                    student_name=student_name,
                    student_class_section=student_class_section,
                    creator_name=creator_name,
                    assigned_to_name=assigned_to_name
                )
            )

        return response_list

    async def get_request_details(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        request_id: uuid.UUID,
        current_user: User
    ) -> CommunicationRequestDetailResponse:
        # Get request with selectinload collections
        request = await self.repo.get_request_by_id(request_id, school_id, tenant_id)
        if not request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Request not found."
            )

        # Permissions check
        user_roles = [r.code for r in current_user.roles]
        is_admin_or_principal = any(r in ["ADMIN", "PRINCIPAL", "SUPER_ADMIN"] for r in user_roles)
        
        participant = await self.repo.get_participant(request_id, current_user.id)
        if not participant and not is_admin_or_principal:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You are not authorized to view this request thread."
            )

        # Mark as read for current user
        if participant:
            participant.last_read_at = datetime.now(timezone.utc)
            await self.repo.db.commit()

        # Fetch names
        student_name = None
        student_class_section = None
        creator_name = None
        assigned_to_name = None

        stmt_s = select(Student).where(Student.id == request.student_id).options(
            joinedload(Student.class_obj),
            joinedload(Student.section)
        )
        res_s = await self.repo.db.execute(stmt_s)
        s = res_s.scalar_one_or_none()
        if s:
            student_name = f"{s.first_name} {s.last_name}"
            if s.class_obj and s.section:
                student_class_section = f"{s.class_obj.name} - {s.section.name}"

        stmt_c = select(User).where(User.id == request.creator_id)
        res_c = await self.repo.db.execute(stmt_c)
        c = res_c.scalar_one_or_none()
        if c:
            creator_name = f"{c.first_name} {c.last_name}"

        if request.assigned_to_id:
            stmt_a = select(User).where(User.id == request.assigned_to_id)
            res_a = await self.repo.db.execute(stmt_a)
            a = res_a.scalar_one_or_none()
            if a:
                assigned_to_name = f"{a.first_name} {a.last_name}"

        req_response = CommunicationRequestResponse(
            id=request.id,
            tenant_id=request.tenant_id,
            school_id=request.school_id,
            student_id=request.student_id,
            creator_id=request.creator_id,
            assigned_to_id=request.assigned_to_id,
            recipient_type=request.recipient_type,
            category=request.category,
            module=request.module,
            reference_type=request.reference_type,
            reference_id=request.reference_id,
            subject=request.subject,
            priority=request.priority,
            status=request.status,
            created_at=request.created_at,
            updated_at=request.updated_at,
            resolved_at=request.resolved_at,
            is_active=request.is_active,
            version=request.version,
            unread_messages_count=0,  # Just read, so 0
            student_name=student_name,
            student_class_section=student_class_section,
            creator_name=creator_name,
            assigned_to_name=assigned_to_name
        )

        messages_list = []
        for m in request.messages:
            attachments_list = [
                CommunicationAttachmentSchema.model_validate(att) for att in m.attachments
            ]
            messages_list.append(
                CommunicationMessageSchema(
                    id=m.id,
                    request_id=m.request_id,
                    sender_id=m.sender_id,
                    sender_role=m.sender_role,
                    message=m.message,
                    created_at=m.created_at,
                    attachments=attachments_list
                )
            )

        participants_list = [
            CommunicationParticipantSchema.model_validate(p) for p in request.participants
        ]

        audit_logs_list = [
            CommunicationAuditLogSchema.model_validate(al) for al in request.audit_logs
        ]

        return CommunicationRequestDetailResponse(
            request=req_response,
            messages=messages_list,
            participants=participants_list,
            audit_logs=audit_logs_list
        )

    async def get_analytics(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        current_user: User
    ) -> CommunicationAnalyticsResponse:
        # Check permissions: Admin/Principal/Superuser only
        user_roles = {r.code for r in current_user.roles}
        is_admin_or_principal = any(r in ["ADMIN", "PRINCIPAL", "SUPER_ADMIN"] for r in user_roles)
        if not is_admin_or_principal:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Analytics dashboards are restricted to administrators."
            )

        # Retrieve all active requests for school/tenant
        stmt = select(CommunicationRequest).where(
            CommunicationRequest.school_id == school_id,
            CommunicationRequest.tenant_id == tenant_id,
            CommunicationRequest.deleted_at.is_(None)
        )
        res = await self.repo.db.execute(stmt)
        requests = res.scalars().all()

        total = len(requests)
        counts = {
            RequestStatus.OPEN: 0,
            RequestStatus.ACKNOWLEDGED: 0,
            RequestStatus.IN_PROGRESS: 0,
            RequestStatus.WAITING_FOR_PARENT: 0,
            RequestStatus.ESCALATED: 0,
            RequestStatus.RESOLVED: 0
        }
        
        categories = {}
        priorities = {}
        schools = {}
        
        sla_breaches = 0
        total_res_time_hours = 0.0
        resolved_count = 0
        escalations = 0

        for req in requests:
            counts[req.status] = counts.get(req.status, 0) + 1
            
            cat_name = req.category.value
            categories[cat_name] = categories.get(cat_name, 0) + 1
            
            prio_name = req.priority.value
            priorities[prio_name] = priorities.get(prio_name, 0) + 1

            school_str = str(req.school_id)
            schools[school_str] = schools.get(school_str, 0) + 1

            if req.status == RequestStatus.ESCALATED:
                escalations += 1

            # Check SLA breach
            threshold_hours = SLA_THRESHOLDS.get(req.priority, 48)
            end_time = req.resolved_at or datetime.now(timezone.utc)
            duration = end_time - req.created_at.replace(tzinfo=timezone.utc)
            duration_hours = duration.total_seconds() / 3600.0
            
            if duration_hours > threshold_hours:
                sla_breaches += 1

            if req.resolved_at:
                resolved_count += 1
                total_res_time_hours += duration_hours

        avg_res_time = (total_res_time_hours / resolved_count) if resolved_count > 0 else 0.0
        escalation_rate = (escalations / total * 100.0) if total > 0 else 0.0
        resolution_rate = (resolved_count / total * 100.0) if total > 0 else 0.0

        # Requests over time (last 7 days counts)
        requests_over_time = []
        now = datetime.now(timezone.utc)
        for i in range(6, -1, -1):
            day = now - timedelta(days=i)
            day_str = day.strftime("%Y-%m-%d")
            day_count = sum(
                1 for req in requests
                if req.created_at.strftime("%Y-%m-%d") == day_str
            )
            requests_over_time.append({"date": day_str, "count": day_count})

        return CommunicationAnalyticsResponse(
            total_requests=total,
            open_count=counts[RequestStatus.OPEN],
            acknowledged_count=counts[RequestStatus.ACKNOWLEDGED],
            in_progress_count=counts[RequestStatus.IN_PROGRESS],
            waiting_for_parent_count=counts[RequestStatus.WAITING_FOR_PARENT],
            escalated_count=counts[RequestStatus.ESCALATED],
            resolved_count=counts[RequestStatus.RESOLVED],
            average_resolution_time_hours=round(avg_res_time, 2),
            sla_breaches_count=sla_breaches,
            requests_by_category=categories,
            requests_by_school=schools,
            requests_by_priority=priorities,
            requests_over_time=requests_over_time,
            escalation_rate=round(escalation_rate, 2),
            resolution_rate=round(resolution_rate, 2)
        )

    async def get_ai_insights(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        request_id: uuid.UUID,
        current_user: User
    ) -> Dict[str, Any]:
        if not self.ai_service:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI service is not configured."
            )

        # Get request details
        request = await self.repo.get_request_by_id(request_id, school_id, tenant_id)
        if not request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Request not found."
            )

        # Permissions check
        user_roles = [r.code for r in current_user.roles]
        is_admin_or_principal = any(r in ["ADMIN", "PRINCIPAL", "SUPER_ADMIN"] for r in user_roles)
        participant = await self.repo.get_participant(request_id, current_user.id)
        
        if not participant and not is_admin_or_principal:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied."
            )

        # Build message history for prompt
        messages_text = ""
        for m in request.messages:
            messages_text += f"{m.sender_role}: {m.message}\n"

        prompt = f"""
You are an educational assistant for school administrators and teachers.
Analyze this parent-school communication thread.

Subject: {request.subject}
Category: {request.category.value}
Message History:
{messages_text}

Provide sentiment analysis, escalation risk, and 3 constructive smart reply suggestions.
"""

        response_schema = {
            "type": "object",
            "properties": {
                "sentiment": {
                    "type": "string",
                    "enum": ["POSITIVE", "NEGATIVE", "NEUTRAL"],
                    "description": "Overall sentiment of the message thread"
                },
                "escalation_risk": {
                    "type": "string",
                    "enum": ["LOW", "MEDIUM", "HIGH"],
                    "description": "Probability of conflict escalation"
                },
                "reply_suggestions": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Constructive reply suggestions for the school staff"
                }
            },
            "required": ["sentiment", "escalation_risk", "reply_suggestions"]
        }

        try:
            result = await self.ai_service.generate_json(
                prompt=prompt,
                response_schema=response_schema,
                client_key=str(current_user.id),
                system_instruction="You are an expert school coordinator helping teachers communicate constructively with parents."
            )
            return result
        except Exception as e:
            logger.error(f"AI generation failed: {e}")
            # Safe fallback if AI service fails or is rate-limited
            return {
                "sentiment": "NEUTRAL",
                "escalation_risk": "LOW",
                "reply_suggestions": [
                    "Thank you for reaching out. We will look into this and get back to you shortly.",
                    "We appreciate your feedback. Let's work together to resolve this issue.",
                    "Let's schedule a brief call or meeting to discuss this further."
                ]
            }

    async def escalate_request(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        request_id: uuid.UUID,
        current_user: User
    ) -> CommunicationRequest:
        request = await self.repo.get_request_by_id(request_id, school_id, tenant_id)
        if not request:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Request not found."
            )
        
        # Teacher must be participant and status must be IN_PROGRESS
        user_role_codes = {r.code for r in current_user.roles}
        is_teacher = "TEACHER" in user_role_codes
        
        participant = await self.repo.get_participant(request_id, current_user.id)
        if not participant or not is_teacher:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Only an assigned teacher participating in the request can escalate it."
            )
            
        if request.status != RequestStatus.IN_PROGRESS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Only requests in progress can be escalated. Current status is {request.status.value}."
            )
            
        # Change status to ESCALATED
        request.status = RequestStatus.ESCALATED
        request.updated_at = datetime.now(timezone.utc)
        
        # Resolve active principal and add to participants
        principal_user = await self._resolve_principal_or_admin(tenant_id, school_id)
        if principal_user:
            principal_part = await self.repo.get_participant(request_id, principal_user.id)
            if not principal_part:
                new_part = CommunicationParticipant(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    request_id=request_id,
                    user_id=principal_user.id,
                    role="PRINCIPAL",
                    last_read_at=None
                )
                await self.repo.create_participant(new_part)
                
            request.assigned_to_id = principal_user.id
            
        # Create audit log
        audit = CommunicationAuditLog(
            tenant_id=tenant_id,
            school_id=school_id,
            request_id=request_id,
            user_id=current_user.id,
            action="ESCALATE",
            details="Request escalated to school principal."
        )
        await self.repo.create_audit_log(audit)
        
        await self.repo.db.commit()
        await self.repo.db.refresh(request)
        
        # Notify principal
        if principal_user:
            await self._send_notification(
                tenant_id=tenant_id,
                school_id=school_id,
                target_user_id=principal_user.id,
                target_role="PRINCIPAL",
                title="Request Escalated to Principal",
                message=f"Request regards {request.subject} has been escalated to you.",
                request_id=request.id,
                creator_id=current_user.id
            )
            
        return request

    async def upload_attachment(
        self,
        id: uuid.UUID,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        message_id: uuid.UUID,
        current_user: User,
        file_name: str,
        file_type: str,
        file_size: int,
        file_url: str
    ) -> CommunicationAttachment:
        stmt = select(CommunicationMessage).where(
            CommunicationMessage.id == message_id,
            CommunicationMessage.tenant_id == tenant_id,
            CommunicationMessage.school_id == school_id
        )
        res = await self.repo.db.execute(stmt)
        msg = res.scalar_one_or_none()
        if not msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Message not found."
            )
            
        part = await self.repo.get_participant(msg.request_id, current_user.id)
        user_roles = {r.code for r in current_user.roles}
        is_admin_or_principal = any(r in ["ADMIN", "PRINCIPAL", "SUPER_ADMIN"] for r in user_roles)
        if not part and not is_admin_or_principal:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You are not authorized to upload files for this thread."
            )
            
        attachment = CommunicationAttachment(
            id=id,
            tenant_id=tenant_id,
            school_id=school_id,
            message_id=message_id,
            file_name=file_name,
            file_type=file_type,
            file_size=file_size,
            file_url=file_url,
            uploaded_by_id=current_user.id
        )
        await self.repo.create_attachment(attachment)
        
        audit = CommunicationAuditLog(
            tenant_id=tenant_id,
            school_id=school_id,
            request_id=msg.request_id,
            user_id=current_user.id,
            action="ATTACHMENT_UPLOAD",
            details=f"Uploaded file {file_name}."
        )
        await self.repo.create_audit_log(audit)
        
        await self.repo.db.commit()
        return attachment

    async def get_attachment(
        self,
        tenant_id: uuid.UUID,
        attachment_id: uuid.UUID,
        current_user: User
    ) -> CommunicationAttachment:
        stmt = select(CommunicationAttachment).where(
            CommunicationAttachment.id == attachment_id,
            CommunicationAttachment.tenant_id == tenant_id
        )
        res = await self.repo.db.execute(stmt)
        attachment = res.scalar_one_or_none()
        if not attachment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attachment not found."
            )
            
        stmt_msg = select(CommunicationMessage).where(CommunicationMessage.id == attachment.message_id)
        res_msg = await self.repo.db.execute(stmt_msg)
        msg = res_msg.scalar_one_or_none()
        if not msg:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Message not found."
            )
            
        user_roles = {r.code for r in current_user.roles}
        is_admin_or_principal = any(r in ["ADMIN", "PRINCIPAL", "SUPER_ADMIN"] for r in user_roles)
        
        part = await self.repo.get_participant(msg.request_id, current_user.id)
        if not part and not is_admin_or_principal:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You are not authorized to access this attachment."
            )
            
        return attachment
