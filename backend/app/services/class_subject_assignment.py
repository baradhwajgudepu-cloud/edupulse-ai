import uuid
from typing import List, Optional
from datetime import date
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.class_subject_assignment import ClassSubjectAssignment
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentType, AssignmentStatus
from app.models.class_entity import Class
from app.models.section import Section
from app.models.subject import Subject
from app.models.teacher import Teacher
from app.repositories.class_subject_assignment import ClassSubjectAssignmentRepository
from app.schemas.class_subject_assignment import (
    ClassSubjectAssignmentCreate,
    ClassSubjectAssignmentBatchCreate,
    ClassSubjectAssignmentUpdate,
    ClassSubjectAssignmentResponse
)

class ClassSubjectAssignmentService:
    def __init__(
        self,
        db: AsyncSession,
        assignment_repo: ClassSubjectAssignmentRepository
    ) -> None:
        self.db = db
        self.assignment_repo = assignment_repo

    async def _sync_teacher_subject_assignment(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: Optional[uuid.UUID],
        subject_id: uuid.UUID,
        teacher_id: Optional[uuid.UUID],
        weekly_periods: int,
        room_id: Optional[uuid.UUID] = None
    ) -> None:
        """
        Keeps core TeacherSubjectAssignment in sync so Teacher App & Teacher 360 work seamlessly.
        """
        if not teacher_id:
            return

        # Determine target sections
        target_section_ids: List[uuid.UUID] = []
        if section_id:
            target_section_ids.append(section_id)
        else:
            sec_stmt = select(Section.id).where(
                Section.class_id == class_id,
                Section.school_id == school_id,
                Section.deleted_at.is_(None)
            )
            sec_res = await self.db.execute(sec_stmt)
            target_section_ids = [r[0] for r in sec_res.all()]

        for s_id in target_section_ids:
            tsa_stmt = select(TeacherSubjectAssignment).where(
                TeacherSubjectAssignment.school_id == school_id,
                TeacherSubjectAssignment.academic_year_id == academic_year_id,
                TeacherSubjectAssignment.class_id == class_id,
                TeacherSubjectAssignment.section_id == s_id,
                TeacherSubjectAssignment.subject_id == subject_id,
                TeacherSubjectAssignment.deleted_at.is_(None)
            )
            tsa_res = await self.db.execute(tsa_stmt)
            existing_tsa = tsa_res.scalars().first()

            if existing_tsa:
                existing_tsa.teacher_id = teacher_id
                existing_tsa.weekly_periods = weekly_periods
                existing_tsa.room_id = room_id
                existing_tsa.is_active = True
                existing_tsa.status = AssignmentStatus.ACTIVE
            else:
                new_tsa = TeacherSubjectAssignment(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    academic_year_id=academic_year_id,
                    teacher_id=teacher_id,
                    subject_id=subject_id,
                    class_id=class_id,
                    section_id=s_id,
                    assignment_type=AssignmentType.PRIMARY,
                    weekly_periods=weekly_periods,
                    room_id=room_id,
                    effective_from=date.today(),
                    status=AssignmentStatus.ACTIVE,
                    is_active=True
                )
                self.db.add(new_tsa)
        await self.db.flush()

    def _to_response(self, csa: ClassSubjectAssignment) -> ClassSubjectAssignmentResponse:
        sub_name = csa.subject.subject_name if csa.subject else None
        sub_code = csa.subject.subject_code if csa.subject else None
        source_type = getattr(csa.subject, "source_type", "BOARD_OFFICIAL") if csa.subject else "BOARD_OFFICIAL"
        cls_name = csa.class_obj.name if csa.class_obj else None
        sec_name = csa.section.name if csa.section else "All Sections"
        teacher_name = f"{csa.teacher.first_name} {csa.teacher.last_name}" if csa.teacher else None

        return ClassSubjectAssignmentResponse(
            id=csa.id,
            tenant_id=csa.tenant_id,
            school_id=csa.school_id,
            academic_year_id=csa.academic_year_id,
            class_id=csa.class_id,
            section_id=csa.section_id,
            subject_id=csa.subject_id,
            teacher_id=csa.teacher_id,
            weekly_periods=csa.weekly_periods,
            period_duration_minutes=csa.period_duration_minutes,
            preferred_days=csa.preferred_days or [],
            preferred_time=csa.preferred_time,
            max_consecutive_periods=csa.max_consecutive_periods,
            min_gap_between_sessions=csa.min_gap_between_sessions,
            is_lab_required=csa.is_lab_required,
            room_id=csa.room_id,
            is_active=csa.is_active,
            settings=csa.settings or {},
            subject_name=sub_name,
            subject_code=sub_code,
            source_type=source_type,
            class_name=cls_name,
            section_name=sec_name,
            teacher_name=teacher_name,
            created_at=csa.created_at,
            updated_at=csa.updated_at,
            deleted_at=csa.deleted_at
        )

    async def create_assignment(
        self,
        tenant_id: uuid.UUID,
        obj_in: ClassSubjectAssignmentCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> ClassSubjectAssignmentResponse:
        # Check uniqueness
        existing = await self.assignment_repo.get_by_unique(
            academic_year_id=obj_in.academic_year_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            subject_id=obj_in.subject_id,
            tenant_id=tenant_id
        )
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This subject is already assigned to the selected class/section."
            )

        db_obj = ClassSubjectAssignment(
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            subject_id=obj_in.subject_id,
            teacher_id=obj_in.teacher_id,
            weekly_periods=obj_in.weekly_periods,
            period_duration_minutes=obj_in.period_duration_minutes,
            preferred_days=obj_in.preferred_days,
            preferred_time=obj_in.preferred_time,
            max_consecutive_periods=obj_in.max_consecutive_periods,
            min_gap_between_sessions=obj_in.min_gap_between_sessions,
            is_lab_required=obj_in.is_lab_required,
            room_id=obj_in.room_id,
            is_active=obj_in.is_active,
            settings=obj_in.settings,
            created_by=created_by
        )
        await self.assignment_repo.create(db_obj)

        # Sync TeacherSubjectAssignment
        if obj_in.teacher_id:
            await self._sync_teacher_subject_assignment(
                tenant_id=tenant_id,
                school_id=obj_in.school_id,
                academic_year_id=obj_in.academic_year_id,
                class_id=obj_in.class_id,
                section_id=obj_in.section_id,
                subject_id=obj_in.subject_id,
                teacher_id=obj_in.teacher_id,
                weekly_periods=obj_in.weekly_periods,
                room_id=obj_in.room_id
            )

        full_obj = await self.assignment_repo.get_by_id(db_obj.id, obj_in.school_id, tenant_id)
        return self._to_response(full_obj or db_obj)

    async def create_batch(
        self,
        tenant_id: uuid.UUID,
        batch_in: ClassSubjectAssignmentBatchCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> List[ClassSubjectAssignmentResponse]:
        created_list: List[ClassSubjectAssignmentResponse] = []
        for c_id in batch_in.class_ids:
            # If specific section_ids provided, map each; otherwise map class-wide (section_id=None)
            target_secs = batch_in.section_ids if batch_in.section_ids else [None]
            for s_id in target_secs:
                existing = await self.assignment_repo.get_by_unique(
                    academic_year_id=batch_in.academic_year_id,
                    class_id=c_id,
                    section_id=s_id,
                    subject_id=batch_in.subject_id,
                    tenant_id=tenant_id
                )
                if existing:
                    # Update existing periods/teacher
                    existing.weekly_periods = batch_in.weekly_periods
                    existing.period_duration_minutes = batch_in.period_duration_minutes
                    existing.preferred_days = batch_in.preferred_days
                    existing.preferred_time = batch_in.preferred_time
                    existing.room_id = batch_in.room_id
                    existing.is_lab_required = batch_in.is_lab_required
                    if batch_in.teacher_id:
                        existing.teacher_id = batch_in.teacher_id
                    await self.assignment_repo.update(existing)
                    full_obj = await self.assignment_repo.get_by_id(existing.id, batch_in.school_id, tenant_id)
                    created_list.append(self._to_response(full_obj or existing))
                else:
                    new_obj = ClassSubjectAssignment(
                        tenant_id=tenant_id,
                        school_id=batch_in.school_id,
                        academic_year_id=batch_in.academic_year_id,
                        class_id=c_id,
                        section_id=s_id,
                        subject_id=batch_in.subject_id,
                        teacher_id=batch_in.teacher_id,
                        weekly_periods=batch_in.weekly_periods,
                        period_duration_minutes=batch_in.period_duration_minutes,
                        preferred_days=batch_in.preferred_days,
                        preferred_time=batch_in.preferred_time,
                        room_id=batch_in.room_id,
                        is_lab_required=batch_in.is_lab_required,
                        is_active=True,
                        created_by=created_by
                    )
                    await self.assignment_repo.create(new_obj)
                    full_obj = await self.assignment_repo.get_by_id(new_obj.id, batch_in.school_id, tenant_id)
                    created_list.append(self._to_response(full_obj or new_obj))

                if batch_in.teacher_id:
                    await self._sync_teacher_subject_assignment(
                        tenant_id=tenant_id,
                        school_id=batch_in.school_id,
                        academic_year_id=batch_in.academic_year_id,
                        class_id=c_id,
                        section_id=s_id,
                        subject_id=batch_in.subject_id,
                        teacher_id=batch_in.teacher_id,
                        weekly_periods=batch_in.weekly_periods,
                        room_id=batch_in.room_id
                    )
        return created_list

    async def update_assignment(
        self,
        id: uuid.UUID,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        obj_in: ClassSubjectAssignmentUpdate
    ) -> ClassSubjectAssignmentResponse:
        db_obj = await self.assignment_repo.get_by_id(id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found.")

        update_dict = obj_in.model_dump(exclude_unset=True)
        for key, val in update_dict.items():
            setattr(db_obj, key, val)

        await self.assignment_repo.update(db_obj)

        if db_obj.teacher_id:
            await self._sync_teacher_subject_assignment(
                tenant_id=tenant_id,
                school_id=school_id,
                academic_year_id=db_obj.academic_year_id,
                class_id=db_obj.class_id,
                section_id=db_obj.section_id,
                subject_id=db_obj.subject_id,
                teacher_id=db_obj.teacher_id,
                weekly_periods=db_obj.weekly_periods,
                room_id=db_obj.room_id
            )

        full_obj = await self.assignment_repo.get_by_id(id, school_id, tenant_id)
        return self._to_response(full_obj or db_obj)

    async def delete_assignment(
        self,
        id: uuid.UUID,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> None:
        db_obj = await self.assignment_repo.get_by_id(id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found.")
        await self.assignment_repo.delete(db_obj)
