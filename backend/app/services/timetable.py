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
from app.schemas.timetable import (
    TimetableCreate,
    TimetableUpdate,
    TimetableResponse,
    TimetableCopyDayRequest,
    TimetableCopySectionRequest,
    TimetableClearDayRequest,
    TimetableBulkStatusRequest,
    TimetableConflictCheckRequest,
    TimetableConflictCheckResponse,
    TimetableMoveRequest,
    TimetableMoveResponse,
)


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

        # Conflict check for room (if room specified)
        if obj_in.room_id:
            room_conflict = await self.timetable_repo.get_conflicting_room(
                obj_in.room_id, obj_in.day_of_week, obj_in.period_number, obj_in.academic_year_id, tenant_id
            )
            if room_conflict:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Room is already booked for another class at period slot {obj_in.period_number} on {obj_in.day_of_week}."
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

            # Check room conflict (if room assigned)
            target_room_id = obj_in.room_id if obj_in.room_id is not None else db_obj.room_id
            if target_room_id:
                room_conflict = await self.timetable_repo.get_conflicting_room(
                    target_room_id, day_of_week, period_number, db_obj.academic_year_id, tenant_id
                )
                if room_conflict and room_conflict.id != db_obj.id:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Room is already booked for another class at period slot {period_number} on {day_of_week}."
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

    async def check_conflict(
        self,
        tenant_id: uuid.UUID,
        obj_in: TimetableConflictCheckRequest
    ) -> TimetableConflictCheckResponse:
        """
        Pre-validates slot conflict for teacher, class/section, room, or overlapping times.
        """
        # 1. Class conflict
        class_conflict = await self.timetable_repo.get_conflicting_class(
            obj_in.class_id, obj_in.section_id, obj_in.day_of_week, obj_in.period_number, obj_in.academic_year_id, tenant_id
        )
        if class_conflict and class_conflict.id != obj_in.exclude_timetable_id:
            return TimetableConflictCheckResponse(
                has_conflict=True,
                conflict_type="CLASS_SLOT_CONFLICT",
                conflict_message=f"Class/Section already has a booked period at slot {obj_in.period_number} on {obj_in.day_of_week}."
            )

        # 2. Teacher conflict
        if obj_in.teacher_id:
            teacher_conflict = await self.timetable_repo.get_conflicting_teacher(
                obj_in.teacher_id, obj_in.day_of_week, obj_in.period_number, obj_in.academic_year_id, tenant_id
            )
            if teacher_conflict and teacher_conflict.id != obj_in.exclude_timetable_id:
                return TimetableConflictCheckResponse(
                    has_conflict=True,
                    conflict_type="TEACHER_DOUBLE_BOOKING",
                    conflict_message=f"Teacher is already assigned to another class at period slot {obj_in.period_number} on {obj_in.day_of_week}."
                )

        # 3. Room conflict
        if obj_in.room_id:
            room_conflict = await self.timetable_repo.get_conflicting_room(
                obj_in.room_id, obj_in.day_of_week, obj_in.period_number, obj_in.academic_year_id, tenant_id
            )
            if room_conflict and room_conflict.id != obj_in.exclude_timetable_id:
                return TimetableConflictCheckResponse(
                    has_conflict=True,
                    conflict_type="ROOM_DOUBLE_BOOKING",
                    conflict_message=f"Room is already booked for another class at period slot {obj_in.period_number} on {obj_in.day_of_week}."
                )

        # 4. Overlapping time intervals
        overlaps = await self.timetable_repo.get_overlapping_class_slots(
            obj_in.class_id, obj_in.section_id, obj_in.day_of_week, obj_in.start_time, obj_in.end_time, tenant_id
        )
        overlaps = [o for o in overlaps if o.id != obj_in.exclude_timetable_id]
        if overlaps:
            return TimetableConflictCheckResponse(
                has_conflict=True,
                conflict_type="TIME_OVERLAP",
                conflict_message="Time slot overlaps with another scheduled slot for this Class/Section."
            )

        return TimetableConflictCheckResponse(has_conflict=False)

    async def copy_day_schedule(
        self,
        tenant_id: uuid.UUID,
        obj_in: TimetableCopyDayRequest,
        created_by: Optional[uuid.UUID] = None
    ) -> int:
        """
        Copies all timetable slots from source_day to target_day for a section.
        """
        source_slots = await self.timetable_repo.get_day_slots(
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            day_of_week=obj_in.source_day,
            tenant_id=tenant_id
        )
        if not source_slots:
            return 0

        await self.timetable_repo.clear_day_schedule(
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            day_of_week=obj_in.target_day,
            tenant_id=tenant_id,
            deleted_by=created_by
        )

        copied_count = 0
        for slot in source_slots:
            new_entry = TimetableCreate(
                day_of_week=obj_in.target_day,
                period_number=slot.period_number,
                period_id=slot.period_id,
                start_time=slot.start_time,
                end_time=slot.end_time,
                period_type=slot.period_type,
                room_id=slot.room_id,
                is_available=slot.is_available,
                settings=slot.settings or {},
                ai_metrics=slot.ai_metrics or {},
                school_id=obj_in.school_id,
                academic_year_id=obj_in.academic_year_id,
                teacher_subject_assignment_id=slot.teacher_subject_assignment_id,
                class_id=obj_in.class_id,
                section_id=obj_in.section_id
            )
            created_slot = await self.timetable_repo.create(
                tenant_id=tenant_id,
                obj_in=new_entry,
                teacher_id=slot.teacher_id,
                subject_id=slot.subject_id,
                created_by=created_by
            )
            created_slot.status = slot.status
            created_slot.is_active = slot.is_active
            copied_count += 1

        await self.timetable_repo.db.commit()
        return copied_count

    async def copy_section_schedule(
        self,
        tenant_id: uuid.UUID,
        obj_in: TimetableCopySectionRequest,
        created_by: Optional[uuid.UUID] = None
    ) -> int:
        """
        Copies all timetable slots from source section to target section.
        """
        source_slots = await self.timetable_repo.get_section_schedule(
            class_id=obj_in.source_class_id,
            section_id=obj_in.source_section_id,
            academic_year_id=obj_in.academic_year_id,
            tenant_id=tenant_id
        )
        if not source_slots:
            return 0

        existing_target_slots = await self.timetable_repo.get_section_schedule(
            class_id=obj_in.target_class_id,
            section_id=obj_in.target_section_id,
            academic_year_id=obj_in.academic_year_id,
            tenant_id=tenant_id
        )
        now = datetime.now(timezone.utc)
        for s in existing_target_slots:
            s.deleted_at = now
            s.status = TimetableStatus.ARCHIVED
            s.is_active = False
            s.updated_by = created_by
            self.timetable_repo.db.add(s)

        copied_count = 0
        for slot in source_slots:
            new_entry = TimetableCreate(
                day_of_week=slot.day_of_week,
                period_number=slot.period_number,
                period_id=slot.period_id,
                start_time=slot.start_time,
                end_time=slot.end_time,
                period_type=slot.period_type,
                room_id=slot.room_id,
                is_available=slot.is_available,
                settings=slot.settings or {},
                ai_metrics=slot.ai_metrics or {},
                school_id=obj_in.school_id,
                academic_year_id=obj_in.academic_year_id,
                teacher_subject_assignment_id=None,
                class_id=obj_in.target_class_id,
                section_id=obj_in.target_section_id
            )
            created_slot = await self.timetable_repo.create(
                tenant_id=tenant_id,
                obj_in=new_entry,
                teacher_id=slot.teacher_id,
                subject_id=slot.subject_id,
                created_by=created_by
            )
            created_slot.status = slot.status
            created_slot.is_active = slot.is_active
            copied_count += 1

        await self.timetable_repo.db.commit()
        return copied_count

    async def clear_day_schedule(
        self,
        tenant_id: uuid.UUID,
        obj_in: TimetableClearDayRequest,
        deleted_by: Optional[uuid.UUID] = None
    ) -> int:
        count = await self.timetable_repo.clear_day_schedule(
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            day_of_week=obj_in.day_of_week,
            tenant_id=tenant_id,
            deleted_by=deleted_by
        )
        await self.timetable_repo.db.commit()
        return count

    async def bulk_update_status(
        self,
        tenant_id: uuid.UUID,
        obj_in: TimetableBulkStatusRequest,
        updated_by: Optional[uuid.UUID] = None
    ) -> int:
        count = await self.timetable_repo.bulk_update_status(
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            status=obj_in.status,
            tenant_id=tenant_id,
            updated_by=updated_by
        )
        await self.timetable_repo.db.commit()
        return count

    async def _resolve_period_timings(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID,
        period_number: int
    ) -> tuple[time, time]:
        """
        Resolves start and end times for a period number based on existing slots, working hours, or defaults.
        """
        from sqlalchemy import select
        # 1. Existing slot matching this school, AY, and period number
        stmt = select(Timetable.start_time, Timetable.end_time).where(
            Timetable.school_id == school_id,
            Timetable.academic_year_id == academic_year_id,
            Timetable.period_number == period_number,
            Timetable.deleted_at.is_(None)
        ).limit(1)
        res = await self.timetable_repo.db.execute(stmt)
        row = res.first()
        if row and row[0] and row[1]:
            return row[0], row[1]

        # 2. Derive from ExtendedWorkingHour
        try:
            from app.models.extended_working_hour import ExtendedWorkingHour
            from app.services.extended_working_hour import calculate_period_timings_list
            wh_stmt = select(ExtendedWorkingHour).where(
                ExtendedWorkingHour.school_id == school_id,
                ExtendedWorkingHour.academic_year_id == academic_year_id,
                ExtendedWorkingHour.tenant_id == tenant_id,
                ExtendedWorkingHour.deleted_at.is_(None)
            ).limit(1)
            wh_res = await self.timetable_repo.db.execute(wh_stmt)
            wh = wh_res.scalar_one_or_none()
            if wh:
                settings_dict = wh.settings or {}
                timings = calculate_period_timings_list(
                    wh.normal_start_time,
                    wh.periods_per_day,
                    int(settings_dict.get("period_duration_minutes", 45)),
                    settings_dict.get("breaks", [])
                )
                for item in timings:
                    if item.get("type") == "PERIOD" and item.get("period_number") == period_number:
                        return item["start_time"], item["end_time"]
        except Exception:
            pass

        # 3. Standard fallback calculation: 8:30 + 45*(p-1)
        start_total_min = 8 * 60 + 30 + (period_number - 1) * 45
        end_total_min = start_total_min + 45
        s_h, s_m = divmod(start_total_min, 60)
        e_h, e_m = divmod(end_total_min, 60)
        return time(s_h % 24, s_m), time(e_h % 24, e_m)

    async def move_or_swap_timetable_slot(
        self,
        tenant_id: uuid.UUID,
        req: TimetableMoveRequest,
        updated_by: Optional[uuid.UUID] = None
    ) -> TimetableMoveResponse:
        """
        Moves or swaps a timetable period slot across days and period slots.
        Validates teacher, class/section, room, and time conflicts, saving valid moves immediately.
        """
        source = await self.timetable_repo.get_by_id(req.source_id, req.school_id, tenant_id)
        if not source:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Source timetable slot not found."
            )

        # If already at the requested destination, return no-op
        if (source.day_of_week == req.target_day_of_week and 
            source.period_number == req.target_period_number):
            return TimetableMoveResponse(
                moved_slot=TimetableResponse.model_validate(source),
                swapped_slot=None,
                message="Slot is already at target position."
            )

        # Check if an existing slot occupies the target (class_id, section_id, target_day, target_period)
        target_slot = await self.timetable_repo.get_conflicting_class(
            class_id=source.class_id,
            section_id=source.section_id,
            day_of_week=req.target_day_of_week,
            period_number=req.target_period_number,
            academic_year_id=req.academic_year_id,
            tenant_id=tenant_id
        )

        # Resolve timings for target period
        t_start, t_end = await self._resolve_period_timings(
            req.school_id, req.academic_year_id, tenant_id, req.target_period_number
        )

        if not target_slot:
            # Case 1: Simple Move to empty slot
            # Check teacher conflict at destination
            if source.teacher_id:
                t_conflict = await self.timetable_repo.get_conflicting_teacher(
                    source.teacher_id, req.target_day_of_week, req.target_period_number, req.academic_year_id, tenant_id
                )
                if t_conflict and t_conflict.id != source.id:
                    teacher = await self.teacher_repo.get_by_id(source.teacher_id, req.school_id, tenant_id)
                    t_name = f"{teacher.first_name} {teacher.last_name}" if teacher else "Assigned Teacher"
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Cannot move: Teacher {t_name} is already assigned to another class on {req.target_day_of_week.value} Period {req.target_period_number}."
                    )

            # Check room conflict at destination
            if source.room_id:
                r_conflict = await self.timetable_repo.get_conflicting_room(
                    source.room_id, req.target_day_of_week, req.target_period_number, req.academic_year_id, tenant_id
                )
                if r_conflict and r_conflict.id != source.id:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Cannot move: Room is already booked for another class on {req.target_day_of_week.value} Period {req.target_period_number}."
                    )

            source.day_of_week = req.target_day_of_week
            source.period_number = req.target_period_number
            source.start_time = t_start
            source.end_time = t_end
            await self.timetable_repo.db.commit()

            reloaded_source = await self.timetable_repo.get_by_id(source.id, req.school_id, tenant_id)
            return TimetableMoveResponse(
                moved_slot=TimetableResponse.model_validate(reloaded_source),
                swapped_slot=None,
                message=f"Moved slot to {req.target_day_of_week.value} Period {req.target_period_number} successfully."
            )

        else:
            # Case 2: Swap between source and target_slot
            # Check teacher conflicts for source at target position
            if source.teacher_id:
                t_conflict = await self.timetable_repo.get_conflicting_teacher(
                    source.teacher_id, req.target_day_of_week, req.target_period_number, req.academic_year_id, tenant_id
                )
                if t_conflict and t_conflict.id not in (source.id, target_slot.id):
                    teacher = await self.teacher_repo.get_by_id(source.teacher_id, req.school_id, tenant_id)
                    t_name = f"{teacher.first_name} {teacher.last_name}" if teacher else "Assigned Teacher"
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Cannot swap: Teacher {t_name} is already booked on {req.target_day_of_week.value} Period {req.target_period_number}."
                    )

            # Check teacher conflicts for target_slot at source position
            if target_slot.teacher_id:
                t2_conflict = await self.timetable_repo.get_conflicting_teacher(
                    target_slot.teacher_id, source.day_of_week, source.period_number, req.academic_year_id, tenant_id
                )
                if t2_conflict and t2_conflict.id not in (source.id, target_slot.id):
                    t2 = await self.teacher_repo.get_by_id(target_slot.teacher_id, req.school_id, tenant_id)
                    t2_name = f"{t2.first_name} {t2.last_name}" if t2 else "Assigned Teacher"
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Cannot swap: Teacher {t2_name} is already booked on {source.day_of_week.value} Period {source.period_number}."
                    )

            # Check room conflicts for source at target position
            if source.room_id:
                r_conflict = await self.timetable_repo.get_conflicting_room(
                    source.room_id, req.target_day_of_week, req.target_period_number, req.academic_year_id, tenant_id
                )
                if r_conflict and r_conflict.id not in (source.id, target_slot.id):
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Cannot swap: Room is already booked on {req.target_day_of_week.value} Period {req.target_period_number}."
                    )

            # Check room conflicts for target_slot at source position
            if target_slot.room_id:
                r2_conflict = await self.timetable_repo.get_conflicting_room(
                    target_slot.room_id, source.day_of_week, source.period_number, req.academic_year_id, tenant_id
                )
                if r2_conflict and r2_conflict.id not in (source.id, target_slot.id):
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Cannot swap: Room is already booked on {source.day_of_week.value} Period {source.period_number}."
                    )

            # Perform atomic swap avoiding unique constraint violation (uq_timetables_class_slot)
            orig_src_day = source.day_of_week
            orig_src_period = source.period_number
            orig_src_start = source.start_time
            orig_src_end = source.end_time

            tgt_day = target_slot.day_of_week
            tgt_period = target_slot.period_number
            tgt_start = target_slot.start_time
            tgt_end = target_slot.end_time

            # Step 1: Temporarily park source
            source.period_number = 9999
            await self.timetable_repo.db.flush()

            # Step 2: Move target_slot to source's original position
            target_slot.day_of_week = orig_src_day
            target_slot.period_number = orig_src_period
            target_slot.start_time = orig_src_start
            target_slot.end_time = orig_src_end
            await self.timetable_repo.db.flush()

            # Step 3: Move source to target's original position
            source.day_of_week = tgt_day
            source.period_number = tgt_period
            source.start_time = tgt_start
            source.end_time = tgt_end
            await self.timetable_repo.db.commit()

            reloaded_source = await self.timetable_repo.get_by_id(source.id, req.school_id, tenant_id)
            reloaded_target = await self.timetable_repo.get_by_id(target_slot.id, req.school_id, tenant_id)

            return TimetableMoveResponse(
                moved_slot=TimetableResponse.model_validate(reloaded_source),
                swapped_slot=TimetableResponse.model_validate(reloaded_target),
                message=f"Swapped Period {orig_src_period} ({orig_src_day.value}) with Period {tgt_period} ({tgt_day.value}) successfully."
            )

