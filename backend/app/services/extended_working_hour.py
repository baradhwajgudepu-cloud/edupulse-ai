import uuid
from typing import Optional, List, Dict, Any
from datetime import time
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func

from app.models.extended_working_hour import ExtendedWorkingHour
from app.models.subject import Subject
from app.models.class_subject_assignment import ClassSubjectAssignment
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.repositories.extended_working_hour import ExtendedWorkingHourRepository
from app.schemas.extended_working_hour import (
    ExtendedWorkingHourCreate,
    ExtendedWorkingHourUpdate,
    ExtendedWorkingHourResponse,
    TimetableCapacitySummary,
    TimetableRecalculationPreview,
    ApplyRecalculatedTimingsRequest
)

def _parse_time(val: Any) -> time:
    if isinstance(val, time):
        return val
    if isinstance(val, str):
        parts = val.split(":")
        return time(int(parts[0]), int(parts[1]))
    return time(8, 30)

def _format_time(val: Any) -> str:
    if isinstance(val, time):
        return val.strftime("%H:%M")
    if isinstance(val, str):
        return val
    return "08:30"

def calculate_period_timings_list(
    normal_start_time: Any,
    periods_per_day: int,
    period_duration_minutes: int = 45,
    breaks: Optional[List[Dict[str, Any]]] = None
) -> List[Dict[str, Any]]:
    """
    Computes sequential period and break start/end times based on school opening time.
    When a break is inserted or its duration changes, all subsequent periods shift dynamically.
    """
    if isinstance(normal_start_time, str):
        parts = normal_start_time.split(":")
        start_t = time(int(parts[0]), int(parts[1]))
    elif isinstance(normal_start_time, time):
        start_t = normal_start_time
    else:
        start_t = time(8, 30)

    current_min = start_t.hour * 60 + start_t.minute
    breaks_list = breaks if breaks is not None else []

    breaks_by_period: Dict[int, List[Dict[str, Any]]] = {}
    for b in breaks_list:
        after_p = int(b.get("after_period", 4))
        breaks_by_period.setdefault(after_p, []).append(b)

    results = []
    for p in range(1, periods_per_day + 1):
        p_start_min = current_min
        p_end_min = p_start_min + period_duration_minutes
        current_min = p_end_min

        s_h, s_m = divmod(p_start_min, 60)
        e_h, e_m = divmod(p_end_min, 60)
        p_start_time = time(s_h % 24, s_m)
        p_end_time = time(e_h % 24, e_m)

        results.append({
            "type": "PERIOD",
            "period_number": p,
            "start_time": p_start_time,
            "end_time": p_end_time,
            "start_time_str": p_start_time.strftime("%H:%M"),
            "end_time_str": p_end_time.strftime("%H:%M"),
            "duration_minutes": period_duration_minutes
        })

        if p in breaks_by_period:
            for b in breaks_by_period[p]:
                b_dur = int(b.get("duration_minutes", 30))
                b_start_min = current_min
                b_end_min = b_start_min + b_dur
                current_min = b_end_min

                bs_h, bs_m = divmod(b_start_min, 60)
                be_h, be_m = divmod(b_end_min, 60)
                b_start_time = time(bs_h % 24, bs_m)
                b_end_time = time(be_h % 24, be_m)

                results.append({
                    "type": "BREAK",
                    "id": b.get("id", f"break_{p}"),
                    "name": b.get("name", "Break"),
                    "break_type": b.get("break_type", "SHORT_BREAK"),
                    "after_period": p,
                    "duration_minutes": b_dur,
                    "start_time": b_start_time,
                    "end_time": b_end_time,
                    "start_time_str": b_start_time.strftime("%H:%M"),
                    "end_time_str": b_end_time.strftime("%H:%M"),
                })

    return results

class ExtendedWorkingHourService:
    def __init__(
        self,
        db: AsyncSession,
        working_hour_repo: ExtendedWorkingHourRepository
    ) -> None:
        self.db = db
        self.working_hour_repo = working_hour_repo

    def _to_response(self, obj: ExtendedWorkingHour) -> ExtendedWorkingHourResponse:
        w_days = obj.working_days or ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
        normal_periods = len(w_days) * obj.periods_per_day
        app_days = obj.applicable_days or []
        extended_periods = len(app_days) * obj.additional_periods if obj.is_extended_hours_enabled else 0
        total_capacity = normal_periods + extended_periods

        settings_dict = obj.settings or {}
        breaks_list = settings_dict.get("breaks")
        if breaks_list is None:
            breaks_list = [{
                "id": "lunch_break_default",
                "name": "Lunch Break",
                "break_type": "LUNCH_BREAK",
                "after_period": obj.lunch_period_number,
                "duration_minutes": 45
            }]
        p_dur = int(settings_dict.get("period_duration_minutes", 45))

        timings = calculate_period_timings_list(
            obj.normal_start_time,
            obj.periods_per_day,
            p_dur,
            breaks_list
        )

        calculated_end_str = timings[-1]["end_time_str"] if timings else _format_time(obj.normal_end_time)
        norm_end_str = _format_time(obj.normal_end_time)

        norm_parts = norm_end_str.split(":")
        norm_end_min = int(norm_parts[0]) * 60 + int(norm_parts[1])
        calc_parts = calculated_end_str.split(":")
        calc_end_min = int(calc_parts[0]) * 60 + int(calc_parts[1])
        extension_min = max(0, calc_end_min - norm_end_min)
        requires_extension = (calc_end_min > norm_end_min)

        return ExtendedWorkingHourResponse(
            id=obj.id,
            tenant_id=obj.tenant_id,
            school_id=obj.school_id,
            academic_year_id=obj.academic_year_id,
            normal_start_time=_format_time(obj.normal_start_time),
            normal_end_time=_format_time(obj.normal_end_time),
            periods_per_day=obj.periods_per_day,
            lunch_period_number=obj.lunch_period_number,
            working_days=w_days,
            is_extended_hours_enabled=obj.is_extended_hours_enabled,
            extended_start_time=_format_time(obj.extended_start_time) if obj.extended_start_time else None,
            extended_end_time=_format_time(obj.extended_end_time) if obj.extended_end_time else None,
            applicable_days=app_days,
            additional_periods=obj.additional_periods,
            activity_type=obj.activity_type,
            weekly_normal_periods=normal_periods,
            weekly_extended_periods=extended_periods,
            total_weekly_capacity=total_capacity,
            period_duration_minutes=p_dur,
            breaks=breaks_list,
            calculated_timings=timings,
            calculated_end_time=calculated_end_str,
            requires_extension=requires_extension,
            extension_minutes=extension_min,
            is_active=obj.is_active,
            created_at=obj.created_at,
            updated_at=obj.updated_at,
            deleted_at=obj.deleted_at
        )

    async def get_or_create(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> ExtendedWorkingHourResponse:
        obj = await self.working_hour_repo.get_by_school_and_ay(school_id, academic_year_id, tenant_id)
        if not obj:
            obj = ExtendedWorkingHour(
                tenant_id=tenant_id,
                school_id=school_id,
                academic_year_id=academic_year_id,
                normal_start_time=time(8, 30),
                normal_end_time=time(15, 30),
                periods_per_day=8,
                lunch_period_number=4,
                working_days=["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"],
                is_extended_hours_enabled=False,
                extended_start_time=time(15, 30),
                extended_end_time=time(16, 15),
                applicable_days=[],
                additional_periods=1,
                activity_type="ADDITIONAL_SUBJECT",
                is_active=True
            )
            await self.working_hour_repo.create(obj)
        return self._to_response(obj)

    async def update_working_hours(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID,
        obj_in: ExtendedWorkingHourUpdate
    ) -> ExtendedWorkingHourResponse:
        obj = await self.working_hour_repo.get_by_school_and_ay(school_id, academic_year_id, tenant_id)
        if not obj:
            # create default then update
            await self.get_or_create(school_id, academic_year_id, tenant_id)
            obj = await self.working_hour_repo.get_by_school_and_ay(school_id, academic_year_id, tenant_id)

        update_dict = obj_in.model_dump(exclude_unset=True)
        if "normal_start_time" in update_dict and update_dict["normal_start_time"]:
            obj.normal_start_time = _parse_time(update_dict["normal_start_time"])
        if "normal_end_time" in update_dict and update_dict["normal_end_time"]:
            obj.normal_end_time = _parse_time(update_dict["normal_end_time"])
        if "extended_start_time" in update_dict:
            obj.extended_start_time = _parse_time(update_dict["extended_start_time"]) if update_dict["extended_start_time"] else None
        if "extended_end_time" in update_dict:
            obj.extended_end_time = _parse_time(update_dict["extended_end_time"]) if update_dict["extended_end_time"] else None

        current_settings = dict(obj.settings or {})
        if "breaks" in update_dict and update_dict["breaks"] is not None:
            current_settings["breaks"] = update_dict["breaks"]
        if "period_duration_minutes" in update_dict and update_dict["period_duration_minutes"] is not None:
            current_settings["period_duration_minutes"] = update_dict["period_duration_minutes"]
        obj.settings = current_settings

        for field in ["periods_per_day", "lunch_period_number", "working_days", "is_extended_hours_enabled",
                      "applicable_days", "additional_periods", "activity_type", "is_active"]:
            if field in update_dict and update_dict[field] is not None:
                setattr(obj, field, update_dict[field])

        await self.working_hour_repo.update(obj)
        return self._to_response(obj)

    async def preview_timetable_recalculation(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID,
        breaks: Optional[List[Dict[str, Any]]] = None,
        period_duration_minutes: Optional[int] = None
    ) -> TimetableRecalculationPreview:
        wh = await self.working_hour_repo.get_by_school_and_ay(school_id, academic_year_id, tenant_id)
        if not wh:
            await self.get_or_create(school_id, academic_year_id, tenant_id)
            wh = await self.working_hour_repo.get_by_school_and_ay(school_id, academic_year_id, tenant_id)
        
        start_str = _format_time(wh.normal_start_time)
        norm_end_str = _format_time(wh.normal_end_time)
        settings_dict = wh.settings or {}
        p_dur = period_duration_minutes or int(settings_dict.get("period_duration_minutes", 45))
        b_list = breaks if breaks is not None else settings_dict.get("breaks", [{
            "id": "lunch_break_default",
            "name": "Lunch Break",
            "break_type": "LUNCH_BREAK",
            "after_period": wh.lunch_period_number,
            "duration_minutes": 45
        }])

        timings = calculate_period_timings_list(
            wh.normal_start_time,
            wh.periods_per_day,
            p_dur,
            b_list
        )
        calculated_end_str = timings[-1]["end_time_str"] if timings else norm_end_str

        norm_parts = norm_end_str.split(":")
        norm_end_min = int(norm_parts[0]) * 60 + int(norm_parts[1])
        calc_parts = calculated_end_str.split(":")
        calc_end_min = int(calc_parts[0]) * 60 + int(calc_parts[1])
        extension_min = max(0, calc_end_min - norm_end_min)
        requires_extension = (calc_end_min > norm_end_min)

        return TimetableRecalculationPreview(
            normal_start_time=start_str,
            original_end_time=norm_end_str,
            calculated_end_time=calculated_end_str,
            extension_minutes=extension_min,
            requires_extension=requires_extension,
            periods_per_day=wh.periods_per_day,
            period_duration_minutes=p_dur,
            breaks=b_list,
            period_timings=timings
        )

    async def apply_recalculated_timings(
        self,
        tenant_id: uuid.UUID,
        req: ApplyRecalculatedTimingsRequest
    ) -> Dict[str, Any]:
        wh = await self.working_hour_repo.get_by_school_and_ay(req.school_id, req.academic_year_id, tenant_id)
        if not wh:
            await self.get_or_create(req.school_id, req.academic_year_id, tenant_id)
            wh = await self.working_hour_repo.get_by_school_and_ay(req.school_id, req.academic_year_id, tenant_id)

        wh.settings = dict(wh.settings or {})
        if req.breaks is not None:
            wh.settings["breaks"] = req.breaks
        if req.period_duration_minutes is not None:
            wh.settings["period_duration_minutes"] = req.period_duration_minutes

        p_dur = int(wh.settings.get("period_duration_minutes", 45))
        b_list = wh.settings.get("breaks", [])

        timings = calculate_period_timings_list(
            wh.normal_start_time,
            wh.periods_per_day,
            p_dur,
            b_list
        )
        calculated_end_str = timings[-1]["end_time_str"] if timings else _format_time(wh.normal_end_time)

        if req.approve_extension and req.new_end_time:
            wh.normal_end_time = _parse_time(req.new_end_time)
        elif req.approve_extension and calculated_end_str:
            wh.normal_end_time = _parse_time(calculated_end_str)

        await self.working_hour_repo.update(wh)

        # Build mapping of period_number -> (start_time, end_time)
        period_map: Dict[int, tuple[time, time]] = {}
        for item in timings:
            if item.get("type") == "PERIOD":
                period_map[item["period_number"]] = (item["start_time"], item["end_time"])

        # Update all active timetable slots for this school and academic year
        from app.models.timetable import Timetable
        from sqlalchemy import update
        updated_count = 0
        for p_num, (s_time, e_time) in period_map.items():
            upd_stmt = (
                update(Timetable)
                .where(
                    Timetable.school_id == req.school_id,
                    Timetable.academic_year_id == req.academic_year_id,
                    Timetable.tenant_id == tenant_id,
                    Timetable.period_number == p_num,
                    Timetable.deleted_at.is_(None)
                )
                .values(
                    start_time=s_time,
                    end_time=e_time
                )
            )
            res = await self.db.execute(upd_stmt)
            updated_count += res.rowcount

        await self.db.commit()

        return {
            "updated_slots_count": updated_count,
            "new_end_time": _format_time(wh.normal_end_time),
            "working_hours": self._to_response(wh)
        }

    async def calculate_capacity_summary(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None
    ) -> TimetableCapacitySummary:
        # 1. Fetch working hours configuration
        wh = await self.get_or_create(school_id, academic_year_id, tenant_id)

        w_days = wh.working_days or ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
        working_days_count = len(w_days)
        periods_per_day = wh.periods_per_day
        available_capacity = working_days_count * periods_per_day

        # 2. Count subjects in catalog
        subj_stmt = select(Subject).where(
            Subject.school_id == school_id,
            Subject.academic_year_id == academic_year_id,
            Subject.is_active.is_(True),
            Subject.deleted_at.is_(None)
        )
        res_subj = await self.db.execute(subj_stmt)
        all_subjects = list(res_subj.scalars().all())

        official_count = sum(1 for s in all_subjects if getattr(s, "source_type", "BOARD_OFFICIAL") == "BOARD_OFFICIAL")
        school_added_count = sum(1 for s in all_subjects if getattr(s, "source_type", "BOARD_OFFICIAL") == "SCHOOL_ADDED")
        total_subjects = len(all_subjects)

        # 3. Calculate required weekly periods
        # If class_id (and section_id) given, calculate specifically for that class/section
        if class_id:
            csa_filters = [
                ClassSubjectAssignment.school_id == school_id,
                ClassSubjectAssignment.academic_year_id == academic_year_id,
                ClassSubjectAssignment.class_id == class_id,
                ClassSubjectAssignment.is_active.is_(True),
                ClassSubjectAssignment.deleted_at.is_(None)
            ]
            if section_id:
                csa_filters.append(
                    and_(
                        ClassSubjectAssignment.section_id.in_([section_id, None])
                    )
                )
            csa_stmt = select(ClassSubjectAssignment).where(and_(*csa_filters))
            csa_res = await self.db.execute(csa_stmt)
            assignments = list(csa_res.scalars().all())

            # If ClassSubjectAssignments exist, sum their weekly_periods
            if assignments:
                total_required = sum(a.weekly_periods for a in assignments)
            else:
                # Fallback to TSA
                tsa_stmt = select(TeacherSubjectAssignment).where(
                    TeacherSubjectAssignment.school_id == school_id,
                    TeacherSubjectAssignment.academic_year_id == academic_year_id,
                    TeacherSubjectAssignment.class_id == class_id,
                    TeacherSubjectAssignment.is_active.is_(True),
                    TeacherSubjectAssignment.deleted_at.is_(None)
                )
                if section_id:
                    tsa_stmt = tsa_stmt.where(TeacherSubjectAssignment.section_id == section_id)
                tsa_res = await self.db.execute(tsa_stmt)
                tsa_list = list(tsa_res.scalars().all())
                total_required = sum(t.weekly_periods for t in tsa_list) if tsa_list else sum(s.weekly_periods or 4 for s in all_subjects)
        else:
            # School-wide summary: check average/max required periods per class
            # or sum of all subjects' weekly periods
            csa_stmt = select(func.sum(ClassSubjectAssignment.weekly_periods)).where(
                ClassSubjectAssignment.school_id == school_id,
                ClassSubjectAssignment.academic_year_id == academic_year_id,
                ClassSubjectAssignment.is_active.is_(True),
                ClassSubjectAssignment.deleted_at.is_(None)
            )
            csa_res = await self.db.execute(csa_stmt)
            csa_sum = csa_res.scalar()
            if csa_sum and csa_sum > 0:
                # We can also compute per-class average or use the max demand across classes
                class_demands_stmt = select(
                    ClassSubjectAssignment.class_id,
                    func.sum(ClassSubjectAssignment.weekly_periods)
                ).where(
                    ClassSubjectAssignment.school_id == school_id,
                    ClassSubjectAssignment.academic_year_id == academic_year_id,
                    ClassSubjectAssignment.is_active.is_(True),
                    ClassSubjectAssignment.deleted_at.is_(None)
                ).group_by(ClassSubjectAssignment.class_id)
                cd_res = await self.db.execute(class_demands_stmt)
                class_demands = [r[1] for r in cd_res.all()]
                total_required = max(class_demands) if class_demands else sum(s.weekly_periods or 5 for s in all_subjects)
            else:
                total_required = sum(s.weekly_periods or 5 for s in all_subjects)

        remaining = available_capacity - total_required
        is_shortfall = total_required > available_capacity
        shortfall = (total_required - available_capacity) if is_shortfall else 0

        warning_msg = None
        if is_shortfall:
            warning_msg = (
                f"⚠ Timetable Capacity Shortfall: The current school timetable does not have enough "
                f"weekly periods to accommodate all configured subjects and activities. "
                f"Required: {total_required}, Available: {available_capacity}, Shortfall: {shortfall} periods."
            )

        extended_potential = len(wh.applicable_days) * wh.additional_periods if wh.is_extended_hours_enabled else 0
        remediation = [
            "Optimize Existing Timetable",
            "Add Working Hours",
            "Review Subject Periods",
            "Review Activities"
        ]

        return TimetableCapacitySummary(
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=class_id,
            section_id=section_id,
            working_days_count=working_days_count,
            periods_per_day=periods_per_day,
            available_weekly_capacity=available_capacity,
            total_subjects_configured=total_subjects,
            official_subjects_count=official_count,
            school_added_subjects_count=school_added_count,
            total_required_periods=total_required,
            remaining_capacity=remaining,
            is_shortfall=is_shortfall,
            shortfall_periods=shortfall,
            shortfall_warning_message=warning_msg,
            is_extended_hours_enabled=wh.is_extended_hours_enabled,
            extended_hours_potential_capacity=extended_potential,
            remediation_options=remediation
        )
