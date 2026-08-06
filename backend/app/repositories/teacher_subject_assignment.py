import uuid
from typing import List, Optional
from datetime import date, datetime, timezone
from sqlalchemy import select, and_, or_, func
from sqlalchemy.orm import selectinload, joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus
from app.models.teacher import Teacher
from app.models.subject import Subject
from app.models.class_entity import Class
from app.models.section import Section
from app.schemas.teacher_subject_assignment import TeacherSubjectAssignmentCreate, TeacherSubjectAssignmentUpdate

class TeacherSubjectAssignmentRepository:
    """
    Repository layer for TeacherSubjectAssignment database operations.
    Enforces multi-tenancy boundaries, school boundaries, and soft deletions.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, assignment_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[TeacherSubjectAssignment]:
        """
        Retrieves a single assignment by ID scoped to school and tenant.
        """
        stmt = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.id == assignment_id,
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_duplicate_assignment(
        self,
        teacher_id: uuid.UUID,
        subject_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> Optional[TeacherSubjectAssignment]:
        """
        Check if active assignment exists for same teacher + subject + class + section + year.
        """
        stmt = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.teacher_id == teacher_id,
            TeacherSubjectAssignment.subject_id == subject_id,
            TeacherSubjectAssignment.class_id == class_id,
            TeacherSubjectAssignment.section_id == section_id,
            TeacherSubjectAssignment.academic_year_id == academic_year_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_class_teacher_assignment(
        self,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> Optional[TeacherSubjectAssignment]:
        """
        Checks if a class teacher is already mapped to class/section in the academic year.
        """
        stmt = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.class_id == class_id,
            TeacherSubjectAssignment.section_id == section_id,
            TeacherSubjectAssignment.academic_year_id == academic_year_id,
            TeacherSubjectAssignment.is_class_teacher == True,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_teacher_active_assignments(
        self,
        teacher_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> List[TeacherSubjectAssignment]:
        """
        Gets all active assignments for a teacher to sum workloads.
        """
        stmt = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.teacher_id == teacher_id,
            TeacherSubjectAssignment.academic_year_id == academic_year_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_overlapping_assignments(
        self,
        teacher_id: uuid.UUID,
        subject_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        effective_from: date,
        effective_to: Optional[date],
        tenant_id: uuid.UUID
    ) -> List[TeacherSubjectAssignment]:
        """
        Checks date range overlaps for active assignments mapped to same teacher + subject + class + section + year.
        """
        filters = [
            TeacherSubjectAssignment.teacher_id == teacher_id,
            TeacherSubjectAssignment.subject_id == subject_id,
            TeacherSubjectAssignment.class_id == class_id,
            TeacherSubjectAssignment.section_id == section_id,
            TeacherSubjectAssignment.academic_year_id == academic_year_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        ]

        # Overlap check logic:
        # (StartA <= EndB) AND (EndA >= StartB)
        # R.effective_from <= effective_to (if effective_to is not None)
        # AND (R.effective_to >= effective_from OR R.effective_to IS NULL)
        if effective_to is not None:
            filters.append(TeacherSubjectAssignment.effective_from <= effective_to)
        
        filters.append(
            or_(
                TeacherSubjectAssignment.effective_to >= effective_from,
                TeacherSubjectAssignment.effective_to.is_(None)
            )
        )

        stmt = select(TeacherSubjectAssignment).where(and_(*filters))
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        teacher_id: Optional[uuid.UUID] = None,
        subject_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        status: Optional[AssignmentStatus] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[TeacherSubjectAssignment]:
        """
        Retrieves paginated list of assignments, joining teachers, subjects, classes, and sections.
        Supports fuzzy searching on names, codes, designations, and statuses.
        """
        filters = [
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        ]

        if academic_year_id:
            filters.append(TeacherSubjectAssignment.academic_year_id == academic_year_id)
        if teacher_id:
            filters.append(TeacherSubjectAssignment.teacher_id == teacher_id)
        if subject_id:
            filters.append(TeacherSubjectAssignment.subject_id == subject_id)
        if class_id:
            filters.append(TeacherSubjectAssignment.class_id == class_id)
        if section_id:
            filters.append(TeacherSubjectAssignment.section_id == section_id)
        if status:
            filters.append(TeacherSubjectAssignment.status == status)

        stmt = select(TeacherSubjectAssignment).join(
            Teacher, TeacherSubjectAssignment.teacher_id == Teacher.id
        ).join(
            Subject, TeacherSubjectAssignment.subject_id == Subject.id
        ).join(
            Class, TeacherSubjectAssignment.class_id == Class.id
        ).join(
            Section, TeacherSubjectAssignment.section_id == Section.id
        )

        if search:
            search_clause = or_(
                Teacher.first_name.ilike(f"%{search}%"),
                Teacher.last_name.ilike(f"%{search}%"),
                Teacher.employee_code.ilike(f"%{search}%"),
                Teacher.staff_code.ilike(f"%{search}%"),
                Subject.subject_name.ilike(f"%{search}%"),
                Subject.subject_code.ilike(f"%{search}%"),
                Class.name.ilike(f"%{search}%"),
                Section.name.ilike(f"%{search}%")
            )
            filters.append(search_clause)

        stmt = (
            stmt.where(and_(*filters))
            .options(
                joinedload(TeacherSubjectAssignment.teacher),
                joinedload(TeacherSubjectAssignment.subject),
                joinedload(TeacherSubjectAssignment.class_obj),
                joinedload(TeacherSubjectAssignment.section)
            )
            .order_by(TeacherSubjectAssignment.priority, TeacherSubjectAssignment.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        obj_in: TeacherSubjectAssignmentCreate,
        assigned_by: Optional[uuid.UUID] = None
    ) -> TeacherSubjectAssignment:
        """
        Creates transient TeacherSubjectAssignment record.
        """
        db_obj = TeacherSubjectAssignment(
            assignment_type=obj_in.assignment_type,
            priority=obj_in.priority,
            weekly_periods=obj_in.weekly_periods,
            workload_percentage=obj_in.workload_percentage or 0.00,
            effective_from=obj_in.effective_from,
            effective_to=obj_in.effective_to,
            assigned_by=assigned_by,
            assigned_at=datetime.now(timezone.utc),
            is_class_teacher=obj_in.is_class_teacher,
            room_id=obj_in.room_id,
            maximum_students=obj_in.maximum_students,
            remarks=obj_in.remarks,
            settings=obj_in.settings,
            ai_metrics=obj_in.ai_metrics,
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            teacher_id=obj_in.teacher_id,
            subject_id=obj_in.subject_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            created_by=assigned_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: TeacherSubjectAssignment,
        obj_in: TeacherSubjectAssignmentUpdate | dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> TeacherSubjectAssignment:
        """
        Updates assignment.
        """
        if isinstance(obj_in, dict):
            update_data = obj_in
        else:
            update_data = obj_in.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            setattr(db_obj, field, value)

        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def soft_delete(
        self,
        db_obj: TeacherSubjectAssignment,
        deleted_by: Optional[uuid.UUID] = None
    ) -> TeacherSubjectAssignment:
        """
        Soft deletes assignment.
        """
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.status = AssignmentStatus.ARCHIVED
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj
