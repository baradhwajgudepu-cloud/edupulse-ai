import uuid
import logging
from datetime import date, datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy import select, and_

from app.models.teacher_leave import TeacherLeave, LeaveStatus, LeaveType
from app.models.teacher import Teacher
from app.models.user import User
from app.repositories.teacher_leave import TeacherLeaveRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.school import SchoolRepository
from app.schemas.teacher_leave import TeacherLeaveCreateRequest, TeacherLeaveReviewRequest, TeacherLeaveCancelRequest
from app.services.notification import NotificationService

logger = logging.getLogger(__name__)

class TeacherLeaveService:
    """
    Service Layer implementing business validations and logic for Teacher Leave Requests.
    """
    def __init__(
        self,
        leave_repo: TeacherLeaveRepository,
        teacher_repo: TeacherRepository,
        school_repo: SchoolRepository,
        notification_service: Optional[NotificationService] = None
    ) -> None:
        self.leave_repo = leave_repo
        self.teacher_repo = teacher_repo
        self.school_repo = school_repo
        self.notification_service = notification_service

    async def create_leave(
        self, tenant_id: uuid.UUID, user_id: uuid.UUID, payload: TeacherLeaveCreateRequest
    ) -> TeacherLeave:
        """
        Submits a new pending leave request for the authenticated teacher.
        """
        # Resolve teacher ID from user_id
        teacher = await self.teacher_repo.get_by_user_id(user_id, tenant_id)
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher profile not found for authenticated user."
            )

        # Date validations
        if payload.start_date > payload.end_date:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Start date must be before or equal to end date."
            )

        # Overlapping check (covers both PENDING and APPROVED requests)
        overlapping = await self.leave_repo.find_overlapping(
            teacher.id, payload.start_date, payload.end_date, tenant_id
        )
        if overlapping:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Leave request overlaps with an existing PENDING or APPROVED leave request."
            )

        db_obj = TeacherLeave(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            school_id=teacher.school_id,
            teacher_id=teacher.id,
            leave_type=payload.leave_type,
            start_date=payload.start_date,
            end_date=payload.end_date,
            reason=payload.reason,
            remarks=payload.remarks,
            status=LeaveStatus.PENDING,
            requested_at=datetime.now(timezone.utc),
            created_by=user_id,
            updated_by=user_id
        )

        await self.leave_repo.create(db_obj)
        await self.leave_repo.db.commit()
        await self.leave_repo.db.refresh(db_obj)

        # Send notification to Principal/Admin
        teacher_name = f"{teacher.first_name} {teacher.last_name}"
        await self._send_leave_submitted_notification(tenant_id, teacher.school_id, db_obj, teacher_name)

        return db_obj

    async def get_my_leave_requests(self, tenant_id: uuid.UUID, user_id: uuid.UUID) -> List[TeacherLeave]:
        """
        Lists leave requests for the authenticated teacher.
        """
        teacher = await self.teacher_repo.get_by_user_id(user_id, tenant_id)
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher profile not found for authenticated user."
            )
        return await self.leave_repo.get_by_teacher(teacher.id, tenant_id)

    async def get_leave(
        self, leave_id: uuid.UUID, tenant_id: uuid.UUID, user_id: uuid.UUID, user_roles: List[str]
    ) -> TeacherLeave:
        """
        Retrieves a leave request after verification of ownership or principal access.
        """
        db_obj = await self.leave_repo.get_by_id(leave_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Leave request not found."
            )

        # Check ownership
        teacher = await self.teacher_repo.get_by_user_id(user_id, tenant_id)
        is_owner = teacher and teacher.id == db_obj.teacher_id

        # Check Principal/Admin access
        is_reviewer = any(role in user_roles for role in ["PRINCIPAL", "ADMIN", "SUPER_ADMIN"])

        if not is_owner and not is_reviewer:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You are not authorized to view this leave request."
            )

        return db_obj

    async def cancel_leave(
        self, leave_id: uuid.UUID, tenant_id: uuid.UUID, user_id: uuid.UUID, payload: TeacherLeaveCancelRequest
    ) -> TeacherLeave:
        """
        Cancels a PENDING leave request (only by the request owner).
        """
        teacher = await self.teacher_repo.get_by_user_id(user_id, tenant_id)
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher profile not found for authenticated user."
            )

        db_obj = await self.leave_repo.get_by_id(leave_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Leave request not found."
            )

        if db_obj.teacher_id != teacher.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. You cannot cancel another teacher's leave request."
            )

        if db_obj.status != LeaveStatus.PENDING:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot cancel leave request. Current status: {db_obj.status.value}"
            )

        db_obj.status = LeaveStatus.CANCELLED
        db_obj.cancelled_at = datetime.now(timezone.utc)
        db_obj.cancellation_reason = payload.cancellation_reason
        db_obj.updated_by = user_id

        await self.leave_repo.update(db_obj)
        await self.leave_repo.db.commit()
        await self.leave_repo.db.refresh(db_obj)

        return db_obj

    async def review_leave(
        self,
        leave_id: uuid.UUID,
        tenant_id: uuid.UUID,
        reviewer_id: uuid.UUID,
        reviewer_school_id: uuid.UUID,
        payload: TeacherLeaveReviewRequest
    ) -> TeacherLeave:
        """
        Approves or Rejects a PENDING leave request (only by Principal/Admin with school scope mapping).
        """
        db_obj = await self.leave_repo.get_by_id(leave_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Leave request not found."
            )

        # School scope check: verify reviewer belongs to the same school as the leave request
        if db_obj.school_id != reviewer_school_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Leave request belongs to another school."
            )

        if db_obj.status != LeaveStatus.PENDING:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot review leave request. Current status: {db_obj.status.value}"
            )

        # Prevent self-review (Teacher reviewer reviews own leave)
        reviewer_teacher = await self.teacher_repo.get_by_user_id(reviewer_id, tenant_id)
        if reviewer_teacher and reviewer_teacher.id == db_obj.teacher_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot review your own leave request."
            )

        previous_status = db_obj.status
        new_status = LeaveStatus.APPROVED if payload.decision.upper() == "APPROVE" else LeaveStatus.REJECTED

        db_obj.status = new_status
        db_obj.reviewed_at = datetime.now(timezone.utc)
        db_obj.reviewed_by = reviewer_id
        db_obj.reviewer_remarks = payload.reviewer_remarks
        db_obj.updated_by = reviewer_id

        await self.leave_repo.update(db_obj)
        await self.leave_repo.db.commit()
        await self.leave_repo.db.refresh(db_obj)

        reviewer_uuid = uuid.UUID(reviewer_id) if isinstance(reviewer_id, str) else reviewer_id
        reviewer_user = await self.leave_repo.db.get(User, reviewer_uuid)
        reviewer_name = f"{reviewer_user.first_name} {reviewer_user.last_name}" if reviewer_user else "Principal"

        await self._send_leave_reviewed_notification(tenant_id, db_obj.school_id, db_obj, reviewer_name)

        return db_obj

    async def list_leave_requests(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        status_filter: Optional[LeaveStatus] = None,
        leave_type: Optional[LeaveType] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[TeacherLeave]:
        """
        Lists and filters leaves scoped to target school and tenant.
        """
        return await self.leave_repo.list_leaves(
            school_id=school_id,
            tenant_id=tenant_id,
            status=status_filter,
            leave_type=leave_type,
            start_date=start_date,
            end_date=end_date,
            skip=skip,
            limit=limit
        )

    async def is_teacher_on_approved_leave(
        self, tenant_id: uuid.UUID, teacher_id: uuid.UUID, attendance_date: date
    ) -> bool:
        """
        Returns True if the teacher is on an APPROVED leave on the given date.
        """
        stmt = select(TeacherLeave).where(
            and_(
                TeacherLeave.teacher_id == teacher_id,
                TeacherLeave.tenant_id == tenant_id,
                TeacherLeave.status == LeaveStatus.APPROVED,
                TeacherLeave.start_date <= attendance_date,
                TeacherLeave.end_date >= attendance_date,
                TeacherLeave.deleted_at.is_(None)
            )
        )
        res = await self.leave_repo.db.execute(stmt)
        record = res.scalar_one_or_none()
        return record is not None

    async def _send_leave_submitted_notification(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, leave_request: TeacherLeave, teacher_name: str
    ) -> None:
        if not self.notification_service:
            return

        try:
            # Resolve active principals/admins in this tenant
            principals = await self.notification_service._resolve_principals_admins(tenant_id)
            
            from app.schemas.notification import NotificationCreate
            from app.models.notification import NotificationType, NotificationPriority, NotificationTargetRole

            for p in principals:
                obj_in = NotificationCreate(
                    notification_type=NotificationType.GENERAL,
                    priority=NotificationPriority.NORMAL,
                    title="Teacher Leave Request Pending",
                    message=f"Teacher {teacher_name} has requested leave from {leave_request.start_date} to {leave_request.end_date}. Reason: {leave_request.reason}",
                    target_role=NotificationTargetRole.PRINCIPAL,
                    target_user_id=p.id,
                    school_id=school_id,
                    related_module="teacher_leave",
                    related_record_id=leave_request.id
                )
                await self.notification_service.notification_repo.create(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    obj_in=obj_in,
                    created_by=leave_request.created_by
                )
            
            if principals:
                await self.notification_service.notification_repo.db.commit()
        except Exception as e:
            logger.error(f"Failed to send submit leave notification: {e}")

    async def _send_leave_reviewed_notification(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, leave_request: TeacherLeave, reviewer_name: str
    ) -> None:
        if not self.notification_service:
            return

        try:
            # Resolve teacher user account to target
            teacher = await self.teacher_repo.get_by_id(leave_request.teacher_id, school_id, tenant_id)
            if not teacher or not teacher.user_id:
                return

            from app.schemas.notification import NotificationCreate
            from app.models.notification import NotificationType, NotificationPriority, NotificationTargetRole

            status_str = leave_request.status.value
            obj_in = NotificationCreate(
                notification_type=NotificationType.GENERAL,
                priority=NotificationPriority.HIGH if status_str == "APPROVED" else NotificationPriority.NORMAL,
                title=f"Leave Request {status_str.title()}",
                message=f"Your leave request from {leave_request.start_date} to {leave_request.end_date} has been {status_str.lower()} by {reviewer_name}.",
                target_role=NotificationTargetRole.TEACHER,
                target_user_id=teacher.user_id,
                school_id=school_id,
                related_module="teacher_leave",
                related_record_id=leave_request.id
            )
            await self.notification_service.notification_repo.create(
                tenant_id=tenant_id,
                school_id=school_id,
                obj_in=obj_in,
                created_by=leave_request.reviewed_by
            )
            await self.notification_service.notification_repo.db.commit()
        except Exception as e:
            logger.error(f"Failed to send reviewed leave notification: {e}")

    async def get_teacher_leave_history(
        self,
        tenant_id: uuid.UUID,
        teacher_id: uuid.UUID,
        status: Optional[LeaveStatus] = None,
        leave_type: Optional[LeaveType] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[TeacherLeave]:
        """
        Fetches leave history for a specific teacher, verifying that the teacher profile exists under this tenant context.
        """
        stmt = select(Teacher).where(
            Teacher.id == teacher_id,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        res = await self.leave_repo.db.execute(stmt)
        teacher = res.scalar_one_or_none()
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher profile not found."
            )

        return await self.leave_repo.get_teacher_leave_history(
            teacher_id=teacher_id,
            tenant_id=tenant_id,
            status=status,
            leave_type=leave_type,
            start_date=start_date,
            end_date=end_date,
            skip=skip,
            limit=limit
        )
