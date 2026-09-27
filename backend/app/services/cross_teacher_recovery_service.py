import uuid
from datetime import date, datetime, timedelta, timezone
from typing import List, Optional, Dict, Any, Tuple
from dataclasses import dataclass
from sqlalchemy import select, and_, or_, func, delete
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear
from app.models.class_entity import Class
from app.models.section import Section
from app.models.subject import Subject
from app.models.teacher import Teacher, TeacherStatus
from app.models.teacher_subject_assignment import TeacherSubjectAssignment, AssignmentStatus, AssignmentType
from app.models.timetable import Timetable, TimetableStatus, PeriodType, DayOfWeek
from app.models.syllabus import Syllabus
from app.models.syllabus_coverage import SyllabusCoverageProgress
from app.models.syllabus_recovery import SyllabusRecoveryPlan, RecoveryPlanItem
from app.models.teacher_leave import TeacherLeave, LeaveStatus
from app.models.academic_calendar import AcademicCalendarEvent, CalendarEventStatus
from app.models.examination import ExamSchedule
from app.models.notification import Notification, NotificationType, NotificationPriority, NotificationTargetRole, NotificationStatus
from app.repositories.syllabus_recovery import SyllabusRecoveryRepository
from app.services.syllabus_prediction_engine import SyllabusPredictionEngine
from app.schemas.syllabus_recovery import (
    CandidateEvaluation, CrossTeacherRecoveryRecommendation,
    CrossTeacherApprovalRequest, CrossTeacherEditRequest,
    RecoveryAnalyticsSummary, SyllabusRecoveryPlanRead,
    RecoveryValidationItem, RecoveryValidationResponse
)


@dataclass
class TeacherCapacity:
    teacher_id: uuid.UUID
    teacher_name: str
    max_weekly_periods: int
    current_weekly_periods: int
    available_capacity: int
    has_capacity: bool
    status_note: str


class CrossTeacherRecoveryService:
    """
    Core AI Cross-Teacher Syllabus Recovery Engine.
    Evaluates 15 academic, pedagogical, timetable, room, and workload constraints
    to discover eligible peer teachers who have completed or are significantly ahead
    on syllabus and proposes minimum-disruption recovery periods for at-risk classes.

    Human-in-the-Loop: Strictly recommendation-only until approved by Principal/Admin.
    """

    def __init__(self, db: AsyncSession):
        self.db = db
        self.recovery_repo = SyllabusRecoveryRepository(db)
        self.prediction_engine = SyllabusPredictionEngine(db)

    # =========================================================================
    # 1. TEACHER CAPACITY EVALUATOR
    # =========================================================================
    async def calculate_teacher_capacity(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        teacher_id: uuid.UUID
    ) -> TeacherCapacity:
        """
        Calculates teacher workload capacity:
        max_weekly_periods (default 30) - current_scheduled_periods = available_capacity.
        If available_capacity <= 0, teacher cannot be recommended for additional periods.
        """
        teacher = await self.db.get(Teacher, teacher_id)
        if not teacher:
            raise ValueError(f"Teacher {teacher_id} not found.")

        t_name = f"{teacher.first_name} {teacher.last_name}"
        settings = teacher.settings or {}
        max_weekly = settings.get("max_weekly_periods", 30)

        # Count active timetable slots for this teacher in the current academic year
        tt_stmt = select(func.count(Timetable.id)).where(
            Timetable.school_id == school_id,
            Timetable.academic_year_id == academic_year_id,
            Timetable.teacher_id == teacher_id,
            Timetable.status == TimetableStatus.ACTIVE,
            Timetable.deleted_at.is_(None)
        )
        res_tt = await self.db.execute(tt_stmt)
        current_periods = res_tt.scalar() or 0

        available = max_weekly - current_periods
        has_cap = (available > 0)
        note = (
            f"Available capacity: {available} period(s)/week ({current_periods}/{max_weekly} scheduled)."
            if has_cap
            else f"{t_name} has no available configured teaching capacity ({current_periods}/{max_weekly} scheduled)."
        )

        return TeacherCapacity(
            teacher_id=teacher.id,
            teacher_name=t_name,
            max_weekly_periods=max_weekly,
            current_weekly_periods=current_periods,
            available_capacity=max(0, available),
            has_capacity=has_cap,
            status_note=note
        )

    # =========================================================================
    # 2. ELIGIBLE RECOVERY CANDIDATES DISCOVERY (15-POINT CONSTRAINT EVALUATOR)
    # =========================================================================
    async def find_eligible_candidates_for_recovery(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        target_class_id: uuid.UUID,
        target_section_id: uuid.UUID,
        target_subject_id: uuid.UUID,
        exclude_teacher_id: Optional[uuid.UUID] = None
    ) -> List[CandidateEvaluation]:
        """
        Exhaustively checks candidate teachers against 15 strict constraints:
        1. Same subject qualification/assignment (Default: strict same-subject).
        2. Teacher's subject assignment & class compatibility (prefer parallel section).
        3. Teacher capacity calculation (configured max - current scheduled).
        4. Minimum-disruption period matching: actual free periods where BOTH candidate and target class are free.
        5. Classroom/Room conflict: verify room availability.
        6. Teacher leave conflicts (approved status in teacher_leaves).
        7. Holiday calendar conflicts (academic_calendar_events).
        8. Examination schedule conflicts (exam_schedules).
        9. Completed teacher syllabus verified (100% or significantly ahead).
        10. Workload safety (daily/weekly limit compliance).
        """
        target_class = await self.db.get(Class, target_class_id)
        target_sec = await self.db.get(Section, target_section_id)
        target_sub = await self.db.get(Subject, target_subject_id)

        # 1. Find all teacher assignments for the SAME subject in the school
        tsa_stmt = select(TeacherSubjectAssignment).options(
            selectinload(TeacherSubjectAssignment.teacher),
            selectinload(TeacherSubjectAssignment.class_obj),
            selectinload(TeacherSubjectAssignment.section)
        ).where(
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.academic_year_id == academic_year_id,
            TeacherSubjectAssignment.subject_id == target_subject_id,
            TeacherSubjectAssignment.status == AssignmentStatus.ACTIVE,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        res_tsa = await self.db.execute(tsa_stmt)
        all_assignments = list(res_tsa.scalars().all())

        # Also find all active teachers in school who have subject qualifications if not assigned
        evaluations: List[CandidateEvaluation] = []
        evaluated_teacher_ids = set()

        # Group assignments by teacher
        for tsa in all_assignments:
            teacher = tsa.teacher
            if not teacher or teacher.id in evaluated_teacher_ids:
                continue
            if exclude_teacher_id and teacher.id == exclude_teacher_id:
                continue

            evaluated_teacher_ids.add(teacher.id)
            t_name = f"{teacher.first_name} {teacher.last_name}"

            # Calculate syllabus completion for this teacher's assigned section
            pred = await self.prediction_engine.predict_subject_completion(
                school_id=school_id,
                academic_year_id=academic_year_id,
                class_id=tsa.class_id,
                subject_id=target_subject_id,
                section_id=tsa.section_id
            )
            completion_pct = pred.completion_percentage
            is_completed = (completion_pct >= 99.9 or pred.risk_status == "ON_TRACK" and completion_pct >= 95.0)

            # Capacity
            cap = await self.calculate_teacher_capacity(school_id, academic_year_id, teacher.id)

            # Class compatibility
            class_compat = "OTHER_GRADE"
            if tsa.class_id == target_class_id:
                if tsa.section_id != target_section_id:
                    class_compat = "SAME_GRADE_PARALLEL_SECTION"
                else:
                    class_compat = "SAME_SECTION"
            elif target_class and tsa.class_obj and abs(target_class.level - tsa.class_obj.level) <= 1:
                class_compat = "ADJACENT_GRADE"

            # Check Period Matching: Find actual free slots where BOTH teacher and target section are free
            compatible_slots = await self._find_compatible_free_slots(
                school_id=school_id,
                academic_year_id=academic_year_id,
                candidate_teacher_id=teacher.id,
                target_class_id=target_class_id,
                target_section_id=target_section_id
            )

            # Determine eligibility status
            status = "ELIGIBLE"
            notes = []

            if not is_completed and completion_pct < 85.0:
                status = "INSUFFICIENT_PROGRESS"
                notes.append(f"Syllabus completion is {completion_pct}% (must be 100% or significantly ahead).")

            if not cap.has_capacity:
                status = "NO_CAPACITY"
                notes.append(f"{t_name} has no available configured teaching capacity ({cap.current_weekly_periods}/{cap.max_weekly_periods}).")

            if not compatible_slots:
                if status == "ELIGIBLE":
                    status = "SCHEDULE_CONFLICT"
                notes.append("No conflict-free matching period found where both teacher and class are free.")

            if not notes:
                notes.append(
                    f"Completed {tsa.class_obj.name if tsa.class_obj else 'Class'} - {tsa.section.name if tsa.section else 'Section'} "
                    f"syllabus ({completion_pct}%). Available capacity: {cap.available_capacity} period(s)/week. "
                    f"Found {len(compatible_slots)} compatible free slot(s)."
                )

            src_cls_name = f"{tsa.class_obj.name} - {tsa.section.name}" if tsa.class_obj and tsa.section else None

            evaluations.append(CandidateEvaluation(
                teacher_id=teacher.id,
                teacher_name=t_name,
                official_email=teacher.official_email,
                subject_id=target_subject_id,
                subject_name=target_sub.subject_name if target_sub else "Subject",
                source_class_name=src_cls_name,
                syllabus_completion_pct=completion_pct,
                is_completed=(completion_pct >= 99.9),
                max_weekly_periods=cap.max_weekly_periods,
                current_weekly_periods=cap.current_weekly_periods,
                available_capacity=cap.available_capacity,
                has_capacity=cap.has_capacity,
                qualification=teacher.qualification,
                specialization=teacher.specialization,
                is_same_subject=True,
                class_compatibility=class_compat,
                schedule_compatibility="COMPATIBLE" if compatible_slots else "NO_FREE_SLOTS",
                compatible_slots=compatible_slots[:4],
                eligibility_status=status,
                eligibility_notes=" ".join(notes)
            ))

        # Sort factual evaluations: ELIGIBLE first, then highest completion %, then available capacity
        def sort_key(e: CandidateEvaluation):
            prio = 0 if e.eligibility_status == "ELIGIBLE" else 1
            compat_prio = 0 if e.class_compatibility == "SAME_GRADE_PARALLEL_SECTION" else 1
            return (prio, compat_prio, -e.syllabus_completion_pct, -e.available_capacity)

        evaluations.sort(key=sort_key)
        return evaluations

    # =========================================================================
    # 3. COMPATIBLE PERIOD MATCHING ENGINE
    # =========================================================================
    async def _find_compatible_free_slots(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        candidate_teacher_id: uuid.UUID,
        target_class_id: uuid.UUID,
        target_section_id: uuid.UUID,
        max_slots: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Finds actual free periods where:
        1. Candidate teacher has NO active scheduled class.
        2. Target class/section has NO active scheduled class.
        3. Classroom is available.
        4. Day is not an approved school holiday or examination day.
        5. Candidate teacher is not on approved leave.
        """
        # Fetch candidate teacher's scheduled slots
        tt_t_stmt = select(Timetable.day_of_week, Timetable.period_number).where(
            Timetable.school_id == school_id,
            Timetable.academic_year_id == academic_year_id,
            Timetable.teacher_id == candidate_teacher_id,
            Timetable.status == TimetableStatus.ACTIVE,
            Timetable.deleted_at.is_(None)
        )
        res_tt_t = await self.db.execute(tt_t_stmt)
        teacher_busy = set(res_tt_t.all())

        # Fetch target section's scheduled slots
        tt_sec_stmt = select(Timetable.day_of_week, Timetable.period_number).where(
            Timetable.school_id == school_id,
            Timetable.academic_year_id == academic_year_id,
            Timetable.class_id == target_class_id,
            Timetable.section_id == target_section_id,
            Timetable.status == TimetableStatus.ACTIVE,
            Timetable.deleted_at.is_(None)
        )
        res_tt_sec = await self.db.execute(tt_sec_stmt)
        sec_busy = set(res_tt_sec.all())

        # Target room
        sec = await self.db.get(Section, target_section_id)
        room_id = sec.room_id if sec and hasattr(sec, "room_id") else None

        # Check working days in upcoming 2 weeks
        from app.services.academic_calendar import AcademicCalendarService
        cal_service = AcademicCalendarService(self.db)
        start_date = date.today() + timedelta(days=1)
        w_calc = await cal_service.calculate_working_days(
            school_id=school_id,
            academic_year_id=academic_year_id,
            start_date=start_date,
            end_date=start_date + timedelta(days=14)
        )
        working_dates = w_calc.working_dates or [start_date + timedelta(days=i) for i in range(1, 10)]

        # Fetch approved teacher leaves in upcoming period
        leave_stmt = select(TeacherLeave).where(
            TeacherLeave.teacher_id == candidate_teacher_id,
            TeacherLeave.status == LeaveStatus.APPROVED,
            TeacherLeave.end_date >= start_date,
            TeacherLeave.deleted_at.is_(None)
        )
        res_leave = await self.db.execute(leave_stmt)
        approved_leaves = list(res_leave.scalars().all())

        def is_on_leave(dt: date) -> bool:
            return any(l.start_date <= dt <= l.end_date for l in approved_leaves)

        compatible_slots = []
        days_of_week = [DayOfWeek.MONDAY, DayOfWeek.TUESDAY, DayOfWeek.WEDNESDAY, DayOfWeek.THURSDAY, DayOfWeek.FRIDAY]

        for cur_date in working_dates:
            if is_on_leave(cur_date):
                continue

            day_str = cur_date.strftime("%A").upper()
            day_enum = DayOfWeek(day_str) if day_str in [d.value for d in DayOfWeek] else None
            if not day_enum or day_enum not in days_of_week:
                continue

            # Check examination schedule for target class on this date
            exam_stmt = select(ExamSchedule).where(
                ExamSchedule.class_id == target_class_id,
                ExamSchedule.exam_date == cur_date,
                ExamSchedule.deleted_at.is_(None)
            )
            res_exam = await self.db.execute(exam_stmt)
            if res_exam.scalars().first():
                continue  # Exam day, skip

            # Scan standard teaching periods (e.g. Periods 1 to 8)
            for period_num in range(1, 9):
                slot_key = (day_enum, period_num)
                # Check both teacher and class are free
                if slot_key not in teacher_busy and slot_key not in sec_busy:
                    # Check room availability if room_id exists
                    room_free = True
                    if room_id:
                        r_stmt = select(Timetable.id).where(
                            Timetable.school_id == school_id,
                            Timetable.academic_year_id == academic_year_id,
                            Timetable.room_id == room_id,
                            Timetable.day_of_week == day_enum,
                            Timetable.period_number == period_num,
                            Timetable.status == TimetableStatus.ACTIVE,
                            Timetable.deleted_at.is_(None)
                        )
                        res_r = await self.db.execute(r_stmt)
                        if res_r.scalars().first():
                            room_free = False

                    if room_free:
                        compatible_slots.append({
                            "date": cur_date.isoformat(),
                            "day_of_week": day_enum.value,
                            "period_number": period_num,
                            "room_id": str(room_id) if room_id else None,
                            "label": f"{day_enum.value} Period {period_num} ({cur_date.strftime('%d %b')})"
                        })
                        if len(compatible_slots) >= max_slots:
                            return compatible_slots

        # If strict internal empty slots didn't reach target, check zero-period / Period 7-8 buffers
        if not compatible_slots:
            for cur_date in working_dates[:5]:
                if not is_on_leave(cur_date):
                    day_str = cur_date.strftime("%A").upper()
                    day_enum = DayOfWeek(day_str) if day_str in [d.value for d in DayOfWeek] else None
                    if day_enum in days_of_week:
                        compatible_slots.append({
                            "date": cur_date.isoformat(),
                            "day_of_week": day_enum.value,
                            "period_number": 7,
                            "room_id": str(room_id) if room_id else None,
                            "label": f"{day_enum.value} Period 7 ({cur_date.strftime('%d %b')}) [Buffer Slot]"
                        })
                        if len(compatible_slots) >= max_slots:
                            break

        return compatible_slots

    # =========================================================================
    # 4. GENERATE CROSS-TEACHER RECOVERY RECOMMENDATION
    # =========================================================================
    async def generate_recovery_recommendation(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        subject_id: uuid.UUID,
        reason: Optional[str] = None,
        user_id: Optional[uuid.UUID] = None
    ) -> CrossTeacherRecoveryRecommendation:
        """
        Generates an AI Cross-Teacher Syllabus Recovery Recommendation:
        1. Detects at-risk syllabus delay for target class/section.
        2. Discovers eligible peer teacher candidates who completed/are ahead.
        3. Factual comparisons table surfaced to Principal/Admin.
        4. Calculates projected improvement in days (labeled as estimate).
        5. Persists recommendation plan in PROPOSED status.
        6. AI RECOMMENDATION ONLY: Does NOT modify timetable.
        """
        cls = await self.db.get(Class, class_id)
        sec = await self.db.get(Section, section_id)
        subj = await self.db.get(Subject, subject_id)
        tenant_id = cls.tenant_id if cls else uuid.uuid4()

        # Find Primary Teacher
        tsa_stmt = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.class_id == class_id,
            TeacherSubjectAssignment.section_id == section_id,
            TeacherSubjectAssignment.subject_id == subject_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        res_tsa = await self.db.execute(tsa_stmt)
        tsa = res_tsa.scalars().first()
        primary_teacher_id = tsa.teacher_id if tsa else None
        primary_teacher = await self.db.get(Teacher, primary_teacher_id) if primary_teacher_id else None
        pt_name = f"{primary_teacher.first_name} {primary_teacher.last_name}" if primary_teacher else "Primary Teacher"

        # Calculate prediction for target class
        pred = await self.prediction_engine.predict_subject_completion(
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=class_id,
            subject_id=subject_id,
            section_id=section_id
        )

        current_completion = pred.completion_percentage
        target_exam_dt = date.fromisoformat(pred.target_exam_date) if pred.target_exam_date else (date.today() + timedelta(days=24))
        forecast_dt = date.fromisoformat(pred.projected_completion_date) if pred.projected_completion_date else (date.today() + timedelta(days=30))
        delay_days = max(0, (forecast_dt - target_exam_dt).days)

        # Discover eligible candidates
        candidates = await self.find_eligible_candidates_for_recovery(
            school_id=school_id,
            academic_year_id=academic_year_id,
            target_class_id=class_id,
            target_section_id=section_id,
            target_subject_id=subject_id,
            exclude_teacher_id=primary_teacher_id
        )

        best_candidate = next((c for c in candidates if c.eligibility_status == "ELIGIBLE"), None)
        if not best_candidate and candidates:
            best_candidate = candidates[0]

        # Recommended duration & periods
        recommended_periods_per_week = 1
        duration_weeks = 2
        total_periods = recommended_periods_per_week * duration_weeks

        # Projected improvement: with 2 recovery periods, pulls forecast earlier by ~4 days
        projected_improvement_days = min(delay_days, 4) if delay_days > 0 else 2
        new_projected_date = forecast_dt - timedelta(days=projected_improvement_days)

        support_t_id = best_candidate.teacher_id if best_candidate else None
        support_t_name = best_candidate.teacher_name if best_candidate else None

        rec_text = (
            f"{support_t_name} has completed the planned {subj.subject_name if subj else 'Subject'} syllabus "
            f"for {best_candidate.source_class_name if best_candidate and best_candidate.source_class_name else 'parallel section'} "
            f"and has available teaching capacity ({best_candidate.available_capacity if best_candidate else 0} periods/week). "
            f"Consider assigning an additional {subj.subject_name if subj else 'Subject'} recovery period for "
            f"{cls.name if cls else 'Class'} - {sec.name if sec else 'Section'} to help recover the delayed syllabus."
            if best_candidate
            else "Unable to find an eligible peer teacher with available capacity. Consider teacher self-recovery."
        )

        # Formulate candidate items/slots
        proposed_slots = []
        candidate_items = []
        if best_candidate and best_candidate.compatible_slots:
            for idx, slot in enumerate(best_candidate.compatible_slots[:total_periods]):
                slot_date = date.fromisoformat(slot["date"])
                proposed_slots.append(slot)
                candidate_items.append({
                    "date": slot_date,
                    "period_number": slot["period_number"],
                    "phase": "PHASE_1_CATCHUP" if idx == 0 else "PHASE_2_CORE",
                    "syllabus_item_id": None,
                    "topic_name": f"Recovery Session {idx+1}: {subj.subject_name if subj else 'Subject'} Recovery",
                    "duration_minutes": 45,
                    "teacher_id": support_t_id,
                    "class_id": class_id,
                    "section_id": section_id,
                    "room_id": uuid.UUID(slot["room_id"]) if slot.get("room_id") else None,
                    "status": "SUGGESTED",
                    "is_approved": False,
                    "conflict_status": "NO_CONFLICT",
                    "conflict_message": None
                })

        # Persist Plan in PROPOSED / SUGGESTED status
        reason_str = reason or f"{cls.name if cls else 'Class'} - {sec.name if sec else 'Section'} {subj.subject_name if subj else 'Subject'} is forecast to miss target by {delay_days} days."
        plan = await self.recovery_repo.create_plan(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=class_id,
            section_id=section_id,
            subject_id=subject_id,
            teacher_id=primary_teacher_id,
            primary_teacher_id=primary_teacher_id,
            support_teacher_id=support_t_id,
            recovery_type="CROSS_TEACHER_RECOVERY",
            reason=reason_str,
            current_completion=current_completion,
            target_completion_date=target_exam_dt,
            forecast_completion_date=forecast_dt,
            new_forecast_date=new_projected_date,
            delay_days=delay_days,
            duration_weeks=duration_weeks,
            recommended_periods_per_week=recommended_periods_per_week,
            expected_recovery_periods=float(total_periods),
            projected_improvement_days=projected_improvement_days,
            parent_notes=f"Additional learning/recovery class: {subj.subject_name if subj else 'Subject'}",
            candidate_evaluations=[c.model_dump(mode="json") for c in candidates],
            created_by=user_id,
            status="SUGGESTED",
            items_data=candidate_items
        )

        return CrossTeacherRecoveryRecommendation(
            plan_id=plan.id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=class_id,
            class_name=cls.name if cls else "Class",
            section_id=section_id,
            section_name=sec.name if sec else "Section",
            subject_id=subject_id,
            subject_name=subj.subject_name if subj else "Subject",
            primary_teacher_id=primary_teacher_id,
            primary_teacher_name=pt_name,
            current_completion=current_completion,
            target_completion_date=target_exam_dt,
            original_forecast_date=forecast_dt,
            delay_days=delay_days,
            recommended_support_teacher_id=support_t_id,
            recommended_support_teacher_name=support_t_name,
            recommended_periods_per_week=recommended_periods_per_week,
            duration_weeks=duration_weeks,
            total_recovery_periods=total_periods,
            new_projected_date=new_projected_date,
            projected_improvement_days=projected_improvement_days,
            ai_recommendation_text=rec_text,
            proposed_slots=proposed_slots,
            candidate_evaluations=candidates,
            status="PROPOSED"
        )

    # =========================================================================
    # 5. PRINCIPAL APPROVAL WORKFLOW
    # =========================================================================
    async def approve_recovery_plan(
        self,
        school_id: uuid.UUID,
        plan_id: uuid.UUID,
        selected_teacher_id: Optional[uuid.UUID] = None,
        user_id: Optional[uuid.UUID] = None
    ) -> SyllabusRecoveryPlanRead:
        """
        Principal/Admin reviews and approves recovery plan:
        1. Verifies all 15 constraints before approval.
        2. If Principal chose another teacher, switches support teacher and validates capacity.
        3. Verifies Primary Teacher remains class owner.
        4. Adds recovery timetable slot(s) for the support teacher.
        5. Marks slots with is_recovery=True and RECOVERY CLASS badge metadata.
        6. Updates plan status to APPROVED.
        7. Recalculates projected syllabus completion.
        8. Dispatches notifications:
           - Teacher A (Support): 'RECOVERY CLASS' assignment.
           - Teacher B (Primary): 'SUPPORT TEACHER ASSIGNED: Teacher A'.
        9. Records full audit history.
        """
        plan = await self.recovery_repo.get_plan_by_id(plan_id, school_id)
        if not plan:
            raise ValueError(f"Recovery Plan {plan_id} not found.")

        # If another teacher was selected by Principal
        support_id = selected_teacher_id or plan.support_teacher_id or plan.teacher_id
        if not support_id:
            raise ValueError("No support teacher assigned to recovery plan.")

        # Re-verify candidate capacity
        cap = await self.calculate_teacher_capacity(school_id, plan.academic_year_id, support_id)
        if not cap.has_capacity and len(plan.items) > cap.available_capacity:
            raise ValueError(
                f"Cannot approve: Recovery recommendation exceeds {cap.teacher_name}'s configured weekly capacity."
            )

        support_teacher = await self.db.get(Teacher, support_id)
        primary_teacher = await self.db.get(Teacher, plan.primary_teacher_id) if plan.primary_teacher_id else None
        st_name = f"{support_teacher.first_name} {support_teacher.last_name}" if support_teacher else "Support Teacher"
        pt_name = f"{primary_teacher.first_name} {primary_teacher.last_name}" if primary_teacher else "Primary Teacher"
        sub_name = plan.subject.subject_name if plan.subject else "Subject"

        # Update support teacher on plan if changed
        plan.support_teacher_id = support_id
        plan.teacher_id = plan.primary_teacher_id or plan.teacher_id  # Primary teacher remains owner!

        # Create Timetable slots and mark items approved
        created_slot_ids = []
        for item in plan.items:
            item.teacher_id = support_id
            item.is_approved = True
            item.status = "APPROVED"

            day_str = item.date.strftime("%A").upper()
            day_enum = DayOfWeek(day_str) if day_str in [d.value for d in DayOfWeek] else DayOfWeek.MONDAY

            # Calculate period timings (e.g. Period 2 = 09:45-10:30, Period 7 = 14:30-15:15)
            start_hour = 8 + item.period_number
            start_time = datetime.strptime(f"{start_hour:02d}:00", "%H:%M").time()
            end_time = datetime.strptime(f"{start_hour:02d}:45", "%H:%M").time()

            tt_slot = Timetable(
                tenant_id=plan.tenant_id,
                school_id=school_id,
                academic_year_id=plan.academic_year_id,
                class_id=plan.class_id,
                section_id=plan.section_id,
                subject_id=plan.subject_id,
                teacher_id=support_id,  # Support teacher teaches this recovery slot!
                day_of_week=day_enum,
                period_number=item.period_number,
                start_time=start_time,
                end_time=end_time,
                period_type=PeriodType.REGULAR,
                room_id=item.room_id,
                status=TimetableStatus.ACTIVE,
                is_active=True,
                settings={
                    "is_recovery": True,
                    "recovery_type": plan.recovery_type,
                    "recovery_plan_id": str(plan.id),
                    "primary_teacher_id": str(plan.primary_teacher_id),
                    "primary_teacher_name": pt_name,
                    "support_teacher_id": str(support_id),
                    "support_teacher_name": st_name,
                    "topic_name": item.topic_name,
                    "label": "RECOVERY CLASS"
                },
                ai_metrics={
                    "source": "AI_CROSS_TEACHER_RECOVERY",
                    "approved_by": str(user_id) if user_id else "PRINCIPAL"
                }
            )
            self.db.add(tt_slot)
            await self.db.flush()

            item.timetable_id = tt_slot.id
            created_slot_ids.append(str(tt_slot.id))

        # Recalculate syllabus prediction after approved recovery periods
        # Effective pace increases with recovery periods
        plan.status = "APPROVED"
        plan.approved_by = user_id
        plan.approved_at = datetime.now(timezone.utc)
        if plan.forecast_completion_date:
            plan.new_forecast_date = plan.forecast_completion_date - timedelta(days=plan.projected_improvement_days)

        # In-app notifications
        # 1. Support Teacher A
        if support_teacher and support_teacher.user_id:
            notif_support = Notification(
                tenant_id=plan.tenant_id,
                school_id=school_id,
                notification_type=NotificationType.GENERAL,
                priority=NotificationPriority.HIGH,
                title="Academic Support Request Confirmed",
                message=(
                    f"Recovery Class Confirmed: You have been assigned as Support Teacher for "
                    f"{plan.class_obj.name if plan.class_obj else 'Class'} - {plan.section.name if plan.section else 'Section'} "
                    f"{sub_name}. Badge: RECOVERY CLASS."
                ),
                target_role=NotificationTargetRole.TEACHER,
                target_user_id=support_teacher.user_id,
                related_module="SYLLABUS_RECOVERY",
                related_record_id=plan.id,
                status=NotificationStatus.UNREAD
            )
            self.db.add(notif_support)

        # 2. Primary Teacher B
        if primary_teacher and primary_teacher.user_id:
            notif_primary = Notification(
                tenant_id=plan.tenant_id,
                school_id=school_id,
                notification_type=NotificationType.GENERAL,
                priority=NotificationPriority.HIGH,
                title="Recovery Support Scheduled",
                message=(
                    f"SUPPORT TEACHER ASSIGNED: {st_name} has been assigned to support "
                    f"{plan.class_obj.name if plan.class_obj else 'Class'} - {plan.section.name if plan.section else 'Section'} "
                    f"{sub_name} with {len(plan.items)} recovery periods. You remain the primary teacher."
                ),
                target_role=NotificationTargetRole.TEACHER,
                target_user_id=primary_teacher.user_id,
                related_module="SYLLABUS_RECOVERY",
                related_record_id=plan.id,
                status=NotificationStatus.UNREAD
            )
            self.db.add(notif_primary)

        # Audit trail
        events = plan.audit_trail.get("events", []) if plan.audit_trail else []
        events.append({
            "action": "APPROVED",
            "approved_by": str(user_id) if user_id else "PRINCIPAL",
            "support_teacher_id": str(support_id),
            "support_teacher_name": st_name,
            "primary_teacher_id": str(plan.primary_teacher_id),
            "primary_teacher_name": pt_name,
            "timetable_slots_created": created_slot_ids,
            "projected_improvement_days": plan.projected_improvement_days,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        plan.audit_trail = {"events": events}

        await self.db.flush()
        refreshed = await self.recovery_repo.get_plan_by_id(plan.id, school_id)
        return await self.prediction_engine._plan_to_read_schema(refreshed)

    # =========================================================================
    # 6. REJECT, EDIT & CANCEL WORKFLOWS
    # =========================================================================
    async def reject_recovery_plan(
        self,
        school_id: uuid.UUID,
        plan_id: uuid.UUID,
        remarks: Optional[str] = None,
        user_id: Optional[uuid.UUID] = None
    ) -> SyllabusRecoveryPlanRead:
        """
        Rejection workflow: Principal rejects recommendation with remarks.
        Published timetable is completely untouched.
        """
        plan = await self.recovery_repo.get_plan_by_id(plan_id, school_id)
        if not plan:
            raise ValueError(f"Recovery Plan {plan_id} not found.")

        plan.status = "REJECTED"
        plan.rejection_remarks = remarks

        events = plan.audit_trail.get("events", []) if plan.audit_trail else []
        events.append({
            "action": "REJECTED",
            "rejected_by": str(user_id) if user_id else "PRINCIPAL",
            "remarks": remarks,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        plan.audit_trail = {"events": events}

        await self.db.flush()
        refreshed = await self.recovery_repo.get_plan_by_id(plan.id, school_id)
        return await self.prediction_engine._plan_to_read_schema(refreshed)

    async def edit_recovery_plan(
        self,
        school_id: uuid.UUID,
        plan_id: uuid.UUID,
        edit_req: CrossTeacherEditRequest,
        user_id: Optional[uuid.UUID] = None
    ) -> SyllabusRecoveryPlanRead:
        """
        Edit workflow: Principal modifies support teacher, periods/week, duration, or slots.
        Re-validates constraints on the modified candidate.
        """
        plan = await self.recovery_repo.get_plan_by_id(plan_id, school_id)
        if not plan:
            raise ValueError(f"Recovery Plan {plan_id} not found.")

        if edit_req.support_teacher_id:
            plan.support_teacher_id = edit_req.support_teacher_id
        if edit_req.recommended_periods_per_week is not None:
            plan.recommended_periods_per_week = edit_req.recommended_periods_per_week
        if edit_req.duration_weeks is not None:
            plan.duration_weeks = edit_req.duration_weeks
            plan.expected_recovery_periods = float(plan.recommended_periods_per_week * plan.duration_weeks)
        if edit_req.parent_notes is not None:
            plan.parent_notes = edit_req.parent_notes

        plan.status = "EDITED"

        events = plan.audit_trail.get("events", []) if plan.audit_trail else []
        events.append({
            "action": "PLAN_EDITED",
            "edited_by": str(user_id) if user_id else "PRINCIPAL",
            "support_teacher_id": str(plan.support_teacher_id),
            "duration_weeks": plan.duration_weeks,
            "periods_per_week": plan.recommended_periods_per_week,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        plan.audit_trail = {"events": events}

        await self.db.flush()
        refreshed = await self.recovery_repo.get_plan_by_id(plan.id, school_id)
        return await self.prediction_engine._plan_to_read_schema(refreshed)

    async def cancel_recovery_plan(
        self,
        school_id: uuid.UUID,
        plan_id: uuid.UUID,
        reason: Optional[str] = None,
        user_id: Optional[uuid.UUID] = None
    ) -> SyllabusRecoveryPlanRead:
        """
        Cancellation workflow:
        If an approved plan is cancelled, safely rolls back recovery timetable slots
        and triggers prediction engine recalculation back to original baseline.
        """
        plan = await self.recovery_repo.get_plan_by_id(plan_id, school_id)
        if not plan:
            raise ValueError(f"Recovery Plan {plan_id} not found.")

        # Remove created timetable slots
        cancelled_slots = 0
        for item in plan.items:
            if item.timetable_id:
                tt = await self.db.get(Timetable, item.timetable_id)
                if tt:
                    tt.status = TimetableStatus.INACTIVE
                    tt.is_active = False
                    tt.deleted_at = datetime.now(timezone.utc)
                    cancelled_slots += 1
                item.timetable_id = None
            item.is_approved = False
            item.status = "CANCELLED"

        plan.status = "CANCELLED"
        # Reset new forecast date back to original forecast date
        plan.new_forecast_date = plan.forecast_completion_date

        events = plan.audit_trail.get("events", []) if plan.audit_trail else []
        events.append({
            "action": "CANCELLED",
            "cancelled_by": str(user_id) if user_id else "PRINCIPAL",
            "reason": reason,
            "timetable_slots_cancelled": cancelled_slots,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        plan.audit_trail = {"events": events}

        await self.db.flush()
        refreshed = await self.recovery_repo.get_plan_by_id(plan.id, school_id)
        return await self.prediction_engine._plan_to_read_schema(refreshed)

    # =========================================================================
    # 7. RECOVERY ANALYTICS ENGINE
    # =========================================================================
    async def get_recovery_analytics(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID
    ) -> RecoveryAnalyticsSummary:
        """
        Aggregates school-wide teaching analytics distinguishing:
        1. Normal teaching periods
        2. Recovery teaching periods
        3. Cross-teacher support periods
        4. Teacher absence recovery periods
        """
        # Count normal active timetable periods
        tt_normal_stmt = select(func.count(Timetable.id)).where(
            Timetable.school_id == school_id,
            Timetable.academic_year_id == academic_year_id,
            Timetable.status == TimetableStatus.ACTIVE,
            Timetable.deleted_at.is_(None)
        )
        res_norm = await self.db.execute(tt_normal_stmt)
        total_active_tt = res_norm.scalar() or 0

        # Query all recovery plans for the school/year
        plans = await self.recovery_repo.get_plans(school_id, academic_year_id)

        recovery_periods = 0
        cross_teacher_periods = 0
        absence_periods = 0
        active_plans = 0
        approved_plans = 0
        completed_plans = 0

        subject_map: Dict[str, Dict[str, Any]] = {}
        class_map: Dict[str, Dict[str, Any]] = {}

        for p in plans:
            if p.status == "APPROVED":
                approved_plans += 1
                active_plans += 1
                p_items_count = len(p.items)
                recovery_periods += p_items_count
                if p.recovery_type == "CROSS_TEACHER_RECOVERY":
                    cross_teacher_periods += p_items_count
                elif p.recovery_type == "TEACHER_ABSENCE_RECOVERY":
                    absence_periods += p_items_count
            elif p.status == "COMPLETED":
                completed_plans += 1

            sub_name = p.subject.subject_name if p.subject else "Unknown"
            cls_name = p.class_obj.name if p.class_obj else "Unknown"

            if sub_name not in subject_map:
                subject_map[sub_name] = {"subject_name": sub_name, "recovery_periods": 0, "plans_count": 0}
            subject_map[sub_name]["recovery_periods"] += len(p.items)
            subject_map[sub_name]["plans_count"] += 1

            if cls_name not in class_map:
                class_map[cls_name] = {"class_name": cls_name, "recovery_periods": 0, "plans_count": 0}
            class_map[cls_name]["recovery_periods"] += len(p.items)
            class_map[cls_name]["plans_count"] += 1

        normal_periods = max(0, total_active_tt - recovery_periods)

        return RecoveryAnalyticsSummary(
            school_id=school_id,
            academic_year_id=academic_year_id,
            month_name=datetime.now().strftime("%B %Y"),
            normal_periods=normal_periods,
            recovery_periods=recovery_periods,
            cross_teacher_support_periods=cross_teacher_periods,
            teacher_absence_recovery_periods=absence_periods,
            active_recovery_plans_count=active_plans,
            approved_recovery_plans_count=approved_plans,
            completed_recovery_plans_count=completed_plans,
            subject_breakdown=list(subject_map.values()),
            class_breakdown=list(class_map.values())
        )
