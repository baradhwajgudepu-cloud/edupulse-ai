import uuid
from datetime import time, datetime, timezone
from typing import List, Optional
from fastapi import HTTPException, status

from app.models.timetable import Timetable, TimetableStatus, PeriodType, DayOfWeek
from app.models.teacher import TeacherStatus
from app.models.subject import SubjectStatus
from app.models.class_entity import ClassStatus
from app.repositories.timetable import TimetableRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.schemas.timetable import TimetableCreate, TimetableUpdate

class TimetableService:
    """
    Service Layer implementing business validations and conflict detection for Timetable scheduling.
    """
    def __init__(
        self,
        timetable_repo: TimetableRepository,
        teacher_repo: TeacherRepository,
        subject_repo: SubjectRepository,
        class_repo: ClassRepository,
        section_repo: SectionRepository,
        academic_year_repo: AcademicYearRepository,
        assignment_repo: TeacherSubjectAssignmentRepository
    ) -> None:
        self.timetable_repo = timetable_repo
        self.teacher_repo = teacher_repo
        self.subject_repo = subject_repo
        self.class_repo = class_repo
        self.section_repo = section_repo
        self.academic_year_repo = academic_year_repo
        self.assignment_repo = assignment_repo

    async def create_timetable_entry(
        self,
        tenant_id: uuid.UUID,
        obj_in: TimetableCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Timetable:
        """
        Registers a new timetable slot after validating time ranges, assignments, period limits, and conflict schedules.
        """
        # Time validation
        if obj_in.start_time >= obj_in.end_time:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Start time must be strictly before end time."
            )

        # Scoping entities validation
        ay = await self.academic_year_repo.get_by_id(obj_in.academic_year_id, obj_in.school_id, tenant_id)
        if not ay:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Academic year not found.")

        cls = await self.class_repo.get_by_id(obj_in.class_id, obj_in.school_id, tenant_id)
        if not cls:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class not found.")
        if cls.status != ClassStatus.ACTIVE or not cls.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Class must be ACTIVE to configure timetable."
            )
        if cls.academic_year_id != obj_in.academic_year_id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Class must belong to the selected academic year."
            )

        sec = await self.section_repo.get_by_id(obj_in.section_id, obj_in.school_id, tenant_id)
        if not sec:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Section not found.")
        if not sec.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Section must be ACTIVE to configure timetable."
            )
        if sec.class_id != obj_in.class_id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Section must belong to the selected class."
            )

        teacher_id = None
        subject_id = None

        if obj_in.period_type != PeriodType.BREAK:
            if not obj_in.teacher_subject_assignment_id:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Teacher subject assignment ID is required for non-break periods."
                )

            # Load and verify assignment
            assignment = await self.assignment_repo.get_by_id(
                obj_in.teacher_subject_assignment_id, obj_in.school_id, tenant_id
            )
            if not assignment:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Teacher subject assignment not found."
                )

            # Extract IDs and match consistency boundaries
            if (assignment.class_id != obj_in.class_id or 
                assignment.section_id != obj_in.section_id or 
                assignment.academic_year_id != obj_in.academic_year_id):
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Selected Class, Section, or Academic Year does not match the assignment parameters."
                )

            teacher_id = assignment.teacher_id
            subject_id = assignment.subject_id

            # Verify teacher and subject are active
            teacher = await self.teacher_repo.get_by_id(teacher_id, obj_in.school_id, tenant_id)
            if not teacher or teacher.status != TeacherStatus.ACTIVE or not teacher.is_active:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Assigned teacher is not active."
                )

            subject = await self.subject_repo.get_by_id(subject_id, obj_in.school_id, tenant_id)
            if not subject or subject.status != SubjectStatus.ACTIVE or not subject.is_active:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Assigned subject is not active."
                )

            # Workload limit check: count of slots already registered for this assignment vs weekly_periods
            slots_count = await self.timetable_repo.get_assignment_slots_count(
                obj_in.teacher_subject_assignment_id, tenant_id
            )
            if slots_count >= assignment.weekly_periods:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Workload limit reached. This assignment cannot exceed {assignment.weekly_periods} weekly periods."
                )

        else:
            # For break periods, ensure assignment_id is ignored
            if obj_in.teacher_subject_assignment_id:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Teacher subject assignment should be empty for break periods."
                )

        # Conflict check for class/section slot (Period Number)
        class_conflict = await self.timetable_repo.get_conflicting_class(
            obj_in.class_id, obj_in.section_id, obj_in.day_of_week, obj_in.period_number, obj_in.academic_year_id, tenant_id
        )
        if class_conflict:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Class/Section already has a booked period at slot {obj_in.period_number} on {obj_in.day_of_week}."
            )

        # Conflict check for teacher (if teacher assigned)
        if teacher_id:
            teacher_conflict = await self.timetable_repo.get_conflicting_teacher(
                teacher_id, obj_in.day_of_week, obj_in.period_number, obj_in.academic_year_id, tenant_id
            )
            if teacher_conflict:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Teacher is already assigned to another class at period slot {obj_in.period_number} on {obj_in.day_of_week}."
                )

        # Time Overlap Check inside class/section on same day
        overlaps = await self.timetable_repo.get_overlapping_class_slots(
            obj_in.class_id, obj_in.section_id, obj_in.day_of_week, obj_in.start_time, obj_in.end_time, tenant_id
        )
        if overlaps:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Time slot overlaps with another scheduled slot for this Class/Section."
            )

        db_obj = await self.timetable_repo.create(
            tenant_id=tenant_id,
            obj_in=obj_in,
            teacher_id=teacher_id,
            subject_id=subject_id,
            created_by=created_by
        )
        db_obj.status = TimetableStatus.ACTIVE
        db_obj.is_active = True

        await self.timetable_repo.db.commit()
        return await self.timetable_repo.get_by_id(db_obj.id, obj_in.school_id, tenant_id)

    async def update_timetable_entry(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        timetable_id: uuid.UUID,
        obj_in: TimetableUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> Timetable:
        """
        Updates timetable slot parameters, checking overlapping intervals and booking double maps.
        """
        db_obj = await self.timetable_repo.get_by_id(timetable_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Timetable entry not found."
            )

        day_of_week = obj_in.day_of_week if obj_in.day_of_week is not None else db_obj.day_of_week
        period_number = obj_in.period_number if obj_in.period_number is not None else db_obj.period_number
        start_time = obj_in.start_time if obj_in.start_time is not None else db_obj.start_time
        end_time = obj_in.end_time if obj_in.end_time is not None else db_obj.end_time

        if start_time >= end_time:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Start time must be strictly before end time."
            )

        # Check slot double booking conflict for class
        if obj_in.day_of_week is not None or obj_in.period_number is not None:
            class_conflict = await self.timetable_repo.get_conflicting_class(
                db_obj.class_id, db_obj.section_id, day_of_week, period_number, db_obj.academic_year_id, tenant_id
            )
            if class_conflict and class_conflict.id != db_obj.id:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Class/Section already has a booked period at slot {period_number} on {day_of_week}."
                )

            # Check teacher conflict (if teacher assigned)
            if db_obj.teacher_id:
                teacher_conflict = await self.timetable_repo.get_conflicting_teacher(
                    db_obj.teacher_id, day_of_week, period_number, db_obj.academic_year_id, tenant_id
                )
                if teacher_conflict and teacher_conflict.id != db_obj.id:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Teacher is already assigned to another class at period slot {period_number} on {day_of_week}."
                    )

        # Time overlap check
        if obj_in.day_of_week is not None or obj_in.start_time is not None or obj_in.end_time is not None:
            overlaps = await self.timetable_repo.get_overlapping_class_slots(
                db_obj.class_id, db_obj.section_id, day_of_week, start_time, end_time, tenant_id
            )
            overlaps = [o for o in overlaps if o.id != db_obj.id]
            if overlaps:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Time slot overlaps with another scheduled slot for this Class/Section."
                )

        update_data = obj_in.model_dump(exclude_unset=True)
        if "status" in update_data:
            if update_data["status"] == TimetableStatus.INACTIVE or update_data["status"] == TimetableStatus.ARCHIVED:
                update_data["is_active"] = False
            else:
                update_data["is_active"] = True

        await self.timetable_repo.update(db_obj, update_data, updated_by=updated_by)
        await self.timetable_repo.db.commit()
        return await self.timetable_repo.get_by_id(timetable_id, school_id, tenant_id)

    async def delete_timetable_entry(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        timetable_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Timetable:
        """
        Soft deletes the timetable entry.
        """
        db_obj = await self.timetable_repo.get_by_id(timetable_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Timetable entry not found."
            )

        await self.timetable_repo.soft_delete(db_obj, deleted_by=deleted_by)
        await self.timetable_repo.db.commit()
        await self.timetable_repo.db.refresh(db_obj)
        return db_obj
