import uuid
from datetime import date, datetime, timezone
from typing import List, Optional
from fastapi import HTTPException, status

from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
from app.models.teacher import TeacherStatus
from app.models.subject import SubjectStatus
from app.models.class_entity import ClassStatus
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.academic_year import AcademicYearRepository
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate, TeacherSubjectAssignmentUpdate

class TeacherSubjectAssignmentService:
    """
    Service Layer implementing business validations and updates for TeacherSubjectAssignment mapping.
    """
    def __init__(
        self,
        assignment_repo: TeacherSubjectAssignmentRepository,
        teacher_repo: TeacherRepository,
        subject_repo: SubjectRepository,
        class_repo: ClassRepository,
        section_repo: SectionRepository,
        academic_year_repo: AcademicYearRepository
    ) -> None:
        self.assignment_repo = assignment_repo
        self.teacher_repo = teacher_repo
        self.subject_repo = subject_repo
        self.class_repo = class_repo
        self.section_repo = section_repo
        self.academic_year_repo = academic_year_repo

    async def create_assignment(
        self,
        tenant_id: uuid.UUID,
        obj_in: TeacherSubjectAssignmentCreate,
        assigned_by: Optional[uuid.UUID] = None
    ) -> TeacherSubjectAssignment:
        """
        Creates a new teacher assignment, validating entity statuses, overlaps, and workload thresholds.
        """
        # 1. Verify Academic Year
        ay = await self.academic_year_repo.get_by_id(obj_in.academic_year_id, obj_in.school_id, tenant_id)
        if not ay:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Academic year not found.")

        # 2. Verify Teacher and status ACTIVE
        teacher = await self.teacher_repo.get_by_id(obj_in.teacher_id, obj_in.school_id, tenant_id)
        if not teacher:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Teacher not found.")
        if teacher.status != TeacherStatus.ACTIVE or not teacher.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot assign teachers who are inactive, on leave, or retired."
            )

        # 3. Verify Subject and status ACTIVE
        subject = await self.subject_repo.get_by_id(obj_in.subject_id, obj_in.school_id, tenant_id)
        if not subject:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subject not found.")
        if subject.status != SubjectStatus.ACTIVE or not subject.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Subject must be ACTIVE to register assignments."
            )
        if subject.academic_year_id != obj_in.academic_year_id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Subject must belong to the selected academic year."
            )

        # 4. Verify Class and status ACTIVE
        class_obj = await self.class_repo.get_by_id(obj_in.class_id, obj_in.school_id, tenant_id)
        if not class_obj:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class not found.")
        if class_obj.status != ClassStatus.ACTIVE or not class_obj.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Class must be ACTIVE to register assignments."
            )
        if class_obj.academic_year_id != obj_in.academic_year_id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Class must belong to the selected academic year."
            )

        # 5. Verify Section and status ACTIVE
        section = await self.section_repo.get_by_id(obj_in.section_id, obj_in.school_id, tenant_id)
        if not section:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Section not found.")
        if not section.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Section must be ACTIVE to register assignments."
            )
        if section.class_id != obj_in.class_id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Section must belong to the selected class."
            )

        # Date validations
        if obj_in.effective_to and obj_in.effective_to < obj_in.effective_from:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="effective_to date cannot be before effective_from date."
            )

        # Overlapping check
        overlaps = await self.assignment_repo.get_overlapping_assignments(
            teacher_id=obj_in.teacher_id,
            subject_id=obj_in.subject_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            academic_year_id=obj_in.academic_year_id,
            effective_from=obj_in.effective_from,
            effective_to=obj_in.effective_to,
            tenant_id=tenant_id
        )
        if overlaps:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Assignment date range overlaps with another active assignment for this teacher."
            )

        # Workload validation (Max 40 periods per week)
        active_assignments = await self.assignment_repo.get_teacher_active_assignments(
            obj_in.teacher_id, obj_in.academic_year_id, tenant_id
        )
        total_periods = sum(a.weekly_periods for a in active_assignments)
        if total_periods + obj_in.weekly_periods > 40:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Workload limit exceeded. Teacher already has {total_periods} periods. Limit is 40."
            )

        # Class teacher validation (single class teacher per section)
        if obj_in.is_class_teacher:
            existing_ct = await self.assignment_repo.get_class_teacher_assignment(
                obj_in.class_id, obj_in.section_id, obj_in.academic_year_id, tenant_id
            )
            if existing_ct:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="A class teacher is already assigned to this section."
                )

        db_obj = await self.assignment_repo.create(tenant_id, obj_in, assigned_by=assigned_by)
        db_obj.status = AssignmentStatus.ACTIVE
        db_obj.is_active = True

        await self.assignment_repo.db.commit()
        return await self.assignment_repo.get_by_id(db_obj.id, obj_in.school_id, tenant_id)

    async def update_assignment(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        assignment_id: uuid.UUID,
        obj_in: TeacherSubjectAssignmentUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> TeacherSubjectAssignment:
        """
        Updates an existing teacher subject assignment, ensuring constraints are satisfied.
        """
        db_obj = await self.assignment_repo.get_by_id(assignment_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher assignment profile not found."
            )

        effective_from = obj_in.effective_from if obj_in.effective_from is not None else db_obj.effective_from
        effective_to = obj_in.effective_to if obj_in.effective_to is not None else db_obj.effective_to

        if effective_to and effective_to < effective_from:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="effective_to date cannot be before effective_from date."
            )

        # Date overlap checks
        if obj_in.effective_from is not None or obj_in.effective_to is not None:
            overlaps = await self.assignment_repo.get_overlapping_assignments(
                teacher_id=db_obj.teacher_id,
                subject_id=db_obj.subject_id,
                class_id=db_obj.class_id,
                section_id=db_obj.section_id,
                academic_year_id=db_obj.academic_year_id,
                effective_from=effective_from,
                effective_to=effective_to,
                tenant_id=tenant_id
            )
            # Filter out current mapping
            overlaps = [o for o in overlaps if o.id != db_obj.id]
            if overlaps:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Assignment date range overlaps with another active assignment for this teacher."
                )

        # Workload check
        if obj_in.weekly_periods is not None:
            active_assignments = await self.assignment_repo.get_teacher_active_assignments(
                db_obj.teacher_id, db_obj.academic_year_id, tenant_id
            )
            total_periods = sum(a.weekly_periods for a in active_assignments if a.id != db_obj.id)
            if total_periods + obj_in.weekly_periods > 40:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Workload limit exceeded. Teacher already has {total_periods} periods. Limit is 40."
                )

        # Class teacher validation
        if obj_in.is_class_teacher:
            existing_ct = await self.assignment_repo.get_class_teacher_assignment(
                db_obj.class_id, db_obj.section_id, db_obj.academic_year_id, tenant_id
            )
            if existing_ct and existing_ct.id != db_obj.id:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="A class teacher is already assigned to this section."
                )

        update_data = obj_in.model_dump(exclude_unset=True)
        if "status" in update_data:
            if update_data["status"] == AssignmentStatus.INACTIVE or update_data["status"] == AssignmentStatus.ARCHIVED:
                update_data["is_active"] = False
            else:
                update_data["is_active"] = True

        await self.assignment_repo.update(db_obj, update_data, updated_by=updated_by)
        await self.assignment_repo.db.commit()
        return await self.assignment_repo.get_by_id(assignment_id, school_id, tenant_id)

    async def delete_assignment(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        assignment_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> TeacherSubjectAssignment:
        """
        Soft deletes the assignment.
        """
        db_obj = await self.assignment_repo.get_by_id(assignment_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Assignment not found."
            )

        await self.assignment_repo.soft_delete(db_obj, deleted_by=deleted_by)
        await self.assignment_repo.db.commit()
        await self.assignment_repo.db.refresh(db_obj)
        return db_obj
