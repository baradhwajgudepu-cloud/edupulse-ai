import uuid
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone, timedelta
from sqlalchemy import select, and_, or_, func, desc
from sqlalchemy.orm import joinedload, selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.communication import (
    CommunicationRequest, CommunicationParticipant, CommunicationMessage,
    CommunicationAttachment, CommunicationAuditLog, RequestStatus, RequestPriority, RequestCategory
)
from app.models.student import Student
from app.models.user import User

class CommunicationRepository:
    """
    Repository layer for Communication database operations.
    Enforces multi-tenant scoping and soft deletion.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def create_request(self, db_obj: CommunicationRequest) -> CommunicationRequest:
        self.db.add(db_obj)
        await self.db.flush()
        return db_obj

    async def get_request_by_id(
        self, request_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[CommunicationRequest]:
        stmt = select(CommunicationRequest).where(
            CommunicationRequest.id == request_id,
            CommunicationRequest.school_id == school_id,
            CommunicationRequest.tenant_id == tenant_id,
            CommunicationRequest.deleted_at.is_(None)
        ).options(
            selectinload(CommunicationRequest.messages).selectinload(CommunicationMessage.attachments),
            selectinload(CommunicationRequest.participants),
            selectinload(CommunicationRequest.audit_logs)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_requests(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        user_id: uuid.UUID,
        user_roles: List[str],
        status: Optional[RequestStatus] = None,
        category: Optional[RequestCategory] = None,
        priority: Optional[RequestPriority] = None,
        student_id: Optional[uuid.UUID] = None,
        creator_id: Optional[uuid.UUID] = None,
        assigned_to_id: Optional[uuid.UUID] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[CommunicationRequest]:
        # Base statement
        stmt = select(CommunicationRequest).where(
            CommunicationRequest.tenant_id == tenant_id,
            CommunicationRequest.school_id == school_id,
            CommunicationRequest.deleted_at.is_(None)
        )

        # Filters
        if status:
            stmt = stmt.where(CommunicationRequest.status == status)
        if category:
            stmt = stmt.where(CommunicationRequest.category == category)
        if priority:
            stmt = stmt.where(CommunicationRequest.priority == priority)
        if student_id:
            stmt = stmt.where(CommunicationRequest.student_id == student_id)
        if creator_id:
            stmt = stmt.where(CommunicationRequest.creator_id == creator_id)
        if assigned_to_id:
            stmt = stmt.where(CommunicationRequest.assigned_to_id == assigned_to_id)

        # Role-based visibility scoping
        # - Superusers can see everything
        # - PRINCIPAL / ADMIN roles can see all requests for their school
        # - TEACHER can see requests where they are participant, creator, assigned_to, or is class teacher for student
        # - PARENT can see requests they created or where their student is involved
        is_admin_or_principal = any(r in ["ADMIN", "PRINCIPAL", "SUPER_ADMIN"] for r in user_roles)
        
        if not is_admin_or_principal:
            # For non-admin/principals, apply custom visibility limits:
            # 1. User is the creator
            # 2. User is assigned_to
            # 3. User is in the participants table
            # 4. For teachers, they are the class teacher for the student (handled via participant addition on create/assign)
            # Thus, checking if creator_id = user_id or assigned_to_id = user_id or user_id in participants
            subq = select(CommunicationParticipant.request_id).where(
                CommunicationParticipant.user_id == user_id,
                CommunicationParticipant.deleted_at.is_(None)
            )
            stmt = stmt.where(
                or_(
                    CommunicationRequest.creator_id == user_id,
                    CommunicationRequest.assigned_to_id == user_id,
                    CommunicationRequest.id.in_(subq)
                )
            )

        if search:
            stmt = stmt.where(
                or_(
                    CommunicationRequest.subject.ilike(f"%{search}%"),
                    CommunicationRequest.reference_type.ilike(f"%{search}%")
                )
            )

        stmt = stmt.order_by(desc(CommunicationRequest.created_at)).offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create_message(self, db_obj: CommunicationMessage) -> CommunicationMessage:
        self.db.add(db_obj)
        await self.db.flush()
        return db_obj

    async def create_participant(self, db_obj: CommunicationParticipant) -> CommunicationParticipant:
        self.db.add(db_obj)
        await self.db.flush()
        return db_obj

    async def get_participant(
        self, request_id: uuid.UUID, user_id: uuid.UUID
    ) -> Optional[CommunicationParticipant]:
        stmt = select(CommunicationParticipant).where(
            CommunicationParticipant.request_id == request_id,
            CommunicationParticipant.user_id == user_id,
            CommunicationParticipant.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def create_audit_log(self, db_obj: CommunicationAuditLog) -> CommunicationAuditLog:
        self.db.add(db_obj)
        await self.db.flush()
        return db_obj

    async def create_attachment(self, db_obj: CommunicationAttachment) -> CommunicationAttachment:
        self.db.add(db_obj)
        await self.db.flush()
        return db_obj

    async def get_unread_count(self, tenant_id: uuid.UUID, user_id: uuid.UUID) -> int:
        # Find all active requests the user is participant of
        participant_stmt = select(CommunicationParticipant).where(
            CommunicationParticipant.user_id == user_id,
            CommunicationParticipant.tenant_id == tenant_id,
            CommunicationParticipant.deleted_at.is_(None)
        )
        participants_res = await self.db.execute(participant_stmt)
        participants = participants_res.scalars().all()
        
        unread_total = 0
        for p in participants:
            # Query messages in this request created after last_read_at (or all if last_read_at is None)
            # excluding messages sent by the user themselves
            msg_stmt = select(func.count(CommunicationMessage.id)).where(
                CommunicationMessage.request_id == p.request_id,
                CommunicationMessage.sender_id != user_id,
                CommunicationMessage.deleted_at.is_(None)
            )
            if p.last_read_at:
                msg_stmt = msg_stmt.where(CommunicationMessage.created_at > p.last_read_at)
            
            res = await self.db.execute(msg_stmt)
            unread_total += res.scalar() or 0
            
        return unread_total

    async def get_request_unread_count(self, request_id: uuid.UUID, user_id: uuid.UUID) -> int:
        p = await self.get_participant(request_id, user_id)
        if not p:
            return 0
        stmt = select(func.count(CommunicationMessage.id)).where(
            CommunicationMessage.request_id == request_id,
            CommunicationMessage.sender_id != user_id,
            CommunicationMessage.deleted_at.is_(None)
        )
        if p.last_read_at:
            stmt = stmt.where(CommunicationMessage.created_at > p.last_read_at)
        res = await self.db.execute(stmt)
        return res.scalar() or 0
