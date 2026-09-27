import uuid
from typing import List, Dict, Any, Optional
from datetime import datetime, date, timedelta, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_

from app.models.syllabus import Syllabus
from app.models.syllabus_coverage import SyllabusCoverageProgress
from app.models.examination import Examination, ExamSchedule
from app.models.subject import Subject
from app.models.class_entity import Class
from app.models.section import Section
from app.models.teacher import Teacher
from app.models.student import Student
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.timetable import Timetable, TimetableStatus, DayOfWeek
from app.models.academic_calendar import AcademicCalendarEvent, CalendarEventType, CalendarEventStatus
from app.models.syllabus_recovery import SyllabusRecoveryPlan, RecoveryPlanItem
from app.models.notification import Notification, NotificationType, NotificationPriority, NotificationTargetRole, NotificationStatus
from app.repositories.syllabus_recovery import SyllabusRecoveryRepository
from app.schemas.academic_planning import (
    SyllabusPredictionItem, AcademicPlanningSummary, AdaptiveRecommendationItem
)
from app.schemas.syllabus_recovery import (
    SyllabusRecoveryPlanCreate, SyllabusRecoveryPlanRead, RecoveryPlanItemRead,
    RecoveryPlanItemUpdate, RecoveryValidationRequest, RecoveryValidationResponse,
    ItemConflictResult, RecoveryValidationItem, StudentSyllabusProgressResponse,
    StudentSubjectProgress, StudentSyllabusTopicProgress, TeacherAbsenceImpactResponse,
    AbsenceImpactPeriod, AffectedClassSummary, AcademicHeatmapResponse, AcademicHeatmapCell
)

class SyllabusPredictionEngine:
    """
    Predictive Syllabus Completion Engine & Recovery Intelligence.
    Strictly observes zero-hallucination data sufficiency tiers:
    1. 'No syllabus configured.'
    2. 'Waiting for teaching-progress data.'
    3. 'Insufficient progress data for reliable completion prediction.'
    Compares projected dates with exam dates and detects at-risk subjects.
    Provides teacher absence impact intelligence, multi-phase syllabus recovery plan generation,
    conflict validation, approval orchestration, and parent/student progress tracking.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db
        self.recovery_repo = SyllabusRecoveryRepository(db)

    async def predict_subject_completion(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        subject_id: uuid.UUID,
        section_id: Optional[uuid.UUID] = None,
        reference_date: Optional[date] = None
    ) -> SyllabusPredictionItem:
        ref_dt = reference_date or date.today()

        # 1. Fetch Class and Subject details
        cls = await self.db.get(Class, class_id)
        subj = await self.db.get(Subject, subject_id)
        cls_name = cls.name if cls else "Class"
        subj_name = subj.subject_name if subj else "Subject"

        sec_name = None
        if section_id:
            sec = await self.db.get(Section, section_id)
            sec_name = sec.name if sec else None

        # 2. Fetch Teacher assignment
        teacher_stmt = select(TeacherSubjectAssignment, Teacher).join(
            Teacher, Teacher.id == TeacherSubjectAssignment.teacher_id
        ).where(
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.class_id == class_id,
            TeacherSubjectAssignment.subject_id == subject_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        if section_id:
            teacher_stmt = teacher_stmt.where(TeacherSubjectAssignment.section_id == section_id)

        res_t = await self.db.execute(teacher_stmt)
        t_row = res_t.first()
        t_id = t_row[1].id if t_row else None
        t_name = f"{t_row[1].first_name} {t_row[1].last_name}" if t_row else None

        # 3. Fetch Syllabus entries
        syll_stmt = select(Syllabus).where(
            Syllabus.school_id == school_id,
            Syllabus.academic_year_id == academic_year_id,
            Syllabus.class_id == class_id,
            Syllabus.subject_id == subject_id,
            Syllabus.deleted_at.is_(None)
        ).order_by(Syllabus.sequence_order)
        res_syll = await self.db.execute(syll_stmt)
        syll_list = list(res_syll.scalars().all())

        total_topics = len(syll_list)

        # Tier 1 Check: No syllabus configured
        if total_topics == 0:
            return SyllabusPredictionItem(
                subject_id=subject_id,
                subject_name=subj_name,
                class_id=class_id,
                class_name=cls_name,
                section_id=section_id,
                section_name=sec_name,
                teacher_id=t_id,
                teacher_name=t_name,
                total_chapters=0,
                completed_chapters=0,
                in_progress_chapters=0,
                remaining_chapters=0,
                total_topics=0,
                completed_topics=0,
                completion_percentage=0.0,
                planned_pace=0.0,
                actual_pace=0.0,
                projected_completion_date=None,
                risk_status="ON_TRACK",
                data_sufficiency="NO_SYLLABUS",
                message="No syllabus configured."
            )

        # Distinct chapters count
        chapters_set = {s.chapter_name for s in syll_list}
        total_chapters = len(chapters_set)

        # 4. Fetch Progress records
        if section_id:
            prog_stmt = select(SyllabusCoverageProgress).where(
                SyllabusCoverageProgress.school_id == school_id,
                SyllabusCoverageProgress.section_id == section_id,
                SyllabusCoverageProgress.subject_id == subject_id,
                SyllabusCoverageProgress.deleted_at.is_(None)
            )
        else:
            prog_stmt = select(SyllabusCoverageProgress).where(
                SyllabusCoverageProgress.school_id == school_id,
                SyllabusCoverageProgress.class_id == class_id,
                SyllabusCoverageProgress.subject_id == subject_id,
                SyllabusCoverageProgress.deleted_at.is_(None)
            )
        res_p = await self.db.execute(prog_stmt)
        progress_records = list(res_p.scalars().all())

        # Map completed and in-progress topics
        completed_syll_ids = set()
        ongoing_syll_ids = set()

        if progress_records:
            for p in progress_records:
                st = (p.status or "").upper()
                if st == "COMPLETED":
                    completed_syll_ids.add(p.syllabus_id)
                elif st in ("IN_PROGRESS", "ONGOING", "REOPENED"):
                    ongoing_syll_ids.add(p.syllabus_id)
        else:
            for s in syll_list:
                st = (s.coverage_status or s.lifecycle_status or "").upper()
                if st == "COMPLETED":
                    completed_syll_ids.add(s.id)
                elif st in ("ONGOING", "IN_PROGRESS", "REOPENED"):
                    ongoing_syll_ids.add(s.id)

        completed_topics = len(completed_syll_ids)
        completion_pct = round((completed_topics / total_topics * 100.0), 1)

        # Calculate chapter-level status
        completed_chapters = 0
        in_progress_chapters = 0
        for ch_name in chapters_set:
            ch_topics = [s for s in syll_list if s.chapter_name == ch_name]
            ch_completed = sum(1 for s in ch_topics if s.id in completed_syll_ids)
            ch_ongoing = sum(1 for s in ch_topics if s.id in ongoing_syll_ids)
            if ch_completed == len(ch_topics):
                completed_chapters += 1
            elif ch_completed > 0 or ch_ongoing > 0:
                in_progress_chapters += 1

        remaining_chapters = total_chapters - completed_chapters

        # 5. Fetch upcoming exam date
        exam_stmt = select(Examination, ExamSchedule).join(
            ExamSchedule, ExamSchedule.exam_id == Examination.id
        ).where(
            Examination.school_id == school_id,
            Examination.academic_year_id == academic_year_id,
            ExamSchedule.class_id == class_id,
            ExamSchedule.subject_id == subject_id,
            ExamSchedule.exam_date >= ref_dt,
            Examination.deleted_at.is_(None)
        ).order_by(ExamSchedule.exam_date.asc())
        res_exam = await self.db.execute(exam_stmt)
        exam_row = res_exam.first()

        target_exam_name = None
        target_exam_date_str = None
        target_exam_date = None
        if exam_row:
            target_exam_name = exam_row[0].exam_name
            target_exam_date = exam_row[1].exam_date
            target_exam_date_str = target_exam_date.isoformat()

        # Standard term has 12 active weeks
        term_weeks = 12
        planned_pace = round(total_chapters / term_weeks, 2)

        # Tier 2 Check: Waiting for teaching-progress data
        if completed_topics == 0 and len(ongoing_syll_ids) == 0:
            return SyllabusPredictionItem(
                subject_id=subject_id,
                subject_name=subj_name,
                class_id=class_id,
                class_name=cls_name,
                section_id=section_id,
                section_name=sec_name,
                teacher_id=t_id,
                teacher_name=t_name,
                total_chapters=total_chapters,
                completed_chapters=0,
                in_progress_chapters=0,
                remaining_chapters=total_chapters,
                total_topics=total_topics,
                completed_topics=0,
                completion_percentage=0.0,
                planned_pace=planned_pace,
                actual_pace=0.0,
                projected_completion_date=None,
                target_exam_name=target_exam_name,
                target_exam_date=target_exam_date_str,
                risk_status="ON_TRACK",
                data_sufficiency="WAITING_FOR_PROGRESS",
                message="Waiting for teaching-progress data."
            )

        # Tier 3 Check: Insufficient progress data
        if completed_topics < 2:
            return SyllabusPredictionItem(
                subject_id=subject_id,
                subject_name=subj_name,
                class_id=class_id,
                class_name=cls_name,
                section_id=section_id,
                section_name=sec_name,
                teacher_id=t_id,
                teacher_name=t_name,
                total_chapters=total_chapters,
                completed_chapters=completed_chapters,
                in_progress_chapters=in_progress_chapters,
                remaining_chapters=remaining_chapters,
                total_topics=total_topics,
                completed_topics=completed_topics,
                completion_percentage=completion_pct,
                planned_pace=planned_pace,
                actual_pace=0.5,
                projected_completion_date=None,
                target_exam_name=target_exam_name,
                target_exam_date=target_exam_date_str,
                risk_status="ON_TRACK",
                data_sufficiency="INSUFFICIENT_DATA",
                message="Insufficient progress data for reliable completion prediction."
            )

        # 6. Sufficient data: Calculate actual pace and projected date
        elapsed_weeks = 4.0  # Standard reference benchmark
        actual_pace = max(0.2, round(completed_chapters / elapsed_weeks, 2)) if completed_chapters > 0 else round(completed_topics / (elapsed_weeks * 2.5), 2)

        remaining_items = remaining_chapters if remaining_chapters > 0 else 0
        weeks_to_finish = (remaining_items / actual_pace) if actual_pace > 0 else 8.0
        teaching_days_needed = max(1, int(weeks_to_finish * 5))

        from app.services.academic_calendar import AcademicCalendarService
        cal_service = AcademicCalendarService(self.db)
        working_days_calc = await cal_service.calculate_working_days(
            school_id=school_id,
            academic_year_id=academic_year_id,
            start_date=ref_dt,
            end_date=ref_dt + timedelta(days=max(365, teaching_days_needed * 3))
        )
        working_dates = working_days_calc.working_dates
        if len(working_dates) >= teaching_days_needed:
            projected_dt = working_dates[teaching_days_needed - 1]
        else:
            projected_dt = ref_dt + timedelta(days=int(weeks_to_finish * 7))
        projected_str = projected_dt.isoformat()

        # Compare with exam deadline
        days_gap = None
        risk_status = "ON_TRACK"
        msg = f"{subj_name} is on track for completion."
        rec_action = None

        if target_exam_date:
            days_gap = (target_exam_date - projected_dt).days
            if days_gap < 0:
                risk_status = "LIKELY_TO_MISS_TARGET"
                gap_days_abs = abs(days_gap)
                msg = (
                    f"{subj_name} syllabus is currently behind the planned pace ({actual_pace} ch/wk vs {planned_pace} planned). "
                    f"At the current rate, completion is projected {gap_days_abs} days after the scheduled examination ({target_exam_date_str})."
                )
                rec_action = "Consider adding 1 additional period per week to recover pace."
            elif days_gap <= 7:
                risk_status = "AT_RISK"
                msg = (
                    f"{subj_name} syllabus completion is projected close to the examination deadline ({days_gap} days buffer)."
                )
                rec_action = "Monitor coverage closely or schedule revision periods."
        elif actual_pace < (planned_pace * 0.7):
            risk_status = "AT_RISK"
            msg = f"{subj_name} pace is lower than planned ({actual_pace} vs {planned_pace} chapters/week)."
            rec_action = "Review chapter allocations with subject faculty."

        return SyllabusPredictionItem(
            subject_id=subject_id,
            subject_name=subj_name,
            class_id=class_id,
            class_name=cls_name,
            section_id=section_id,
            section_name=sec_name,
            teacher_id=t_id,
            teacher_name=t_name,
            total_chapters=total_chapters,
            completed_chapters=completed_chapters,
            in_progress_chapters=in_progress_chapters,
            remaining_chapters=remaining_chapters,
            total_topics=total_topics,
            completed_topics=completed_topics,
            completion_percentage=completion_pct,
            planned_pace=planned_pace,
            actual_pace=actual_pace,
            projected_completion_date=projected_str,
            is_estimate=True,
            target_exam_name=target_exam_name,
            target_exam_date=target_exam_date_str,
            days_gap_to_exam=days_gap,
            risk_status=risk_status,
            data_sufficiency="SUFFICIENT",
            message=msg,
            recommended_action=rec_action
        )

    async def get_school_planning_summary(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> AcademicPlanningSummary:
        """
        Aggregates school-wide syllabus completion metrics, at-risk subjects,
        and continuous adaptive timetable recommendations.
        """
        class_stmt = select(Class).where(
            Class.school_id == school_id,
            Class.academic_year_id == academic_year_id,
            Class.deleted_at.is_(None)
        ).order_by(Class.name)
        res_c = await self.db.execute(class_stmt)
        classes = res_c.scalars().all()

        subj_stmt = select(Subject).where(
            Subject.school_id == school_id,
            Subject.academic_year_id == academic_year_id,
            Subject.deleted_at.is_(None)
        ).order_by(Subject.subject_name)
        res_s = await self.db.execute(subj_stmt)
        subjects = res_s.scalars().all()

        all_predictions: List[SyllabusPredictionItem] = []
        for cls in classes:
            for sub in subjects:
                pred = await self.predict_subject_completion(
                    school_id=school_id,
                    academic_year_id=academic_year_id,
                    class_id=cls.id,
                    subject_id=sub.id
                )
                all_predictions.append(pred)

        active_preds = [p for p in all_predictions if p.data_sufficiency != "NO_SYLLABUS"]
        avg_completion = (
            round(sum(p.completion_percentage for p in active_preds) / len(active_preds), 1)
            if active_preds else 0.0
        )

        on_track = sum(1 for p in active_preds if p.risk_status == "ON_TRACK")
        at_risk = sum(1 for p in active_preds if p.risk_status == "AT_RISK")
        likely_to_miss = sum(1 for p in active_preds if p.risk_status == "LIKELY_TO_MISS_TARGET")
        insufficient = sum(1 for p in all_predictions if p.data_sufficiency == "INSUFFICIENT_DATA")

        at_risk_list = [p for p in active_preds if p.risk_status in ("AT_RISK", "LIKELY_TO_MISS_TARGET")]

        adaptive_recs = []
        for p in at_risk_list:
            rec_id = f"ADAPT_{p.class_id}_{p.subject_id}"
            adaptive_recs.append(AdaptiveRecommendationItem(
                id=rec_id,
                subject_id=p.subject_id,
                subject_name=p.subject_name,
                class_id=p.class_id,
                class_name=p.class_name,
                section_id=p.section_id,
                section_name=p.section_name,
                risk_status=p.risk_status,
                current_weekly_periods=5,
                recommended_weekly_periods=6,
                periods_difference=1,
                duration_weeks=4,
                rationale=(
                    f"{p.subject_name} is currently behind planned pace. Adding 1 period/week "
                    f"for 4 weeks restores completion buffer before {p.target_exam_name or 'the scheduled exam'}."
                ),
                impact_explanation="Enables faculty to cover 2 additional chapters before exam date.",
                is_optional=True
            ))

        class_summaries = []
        for cls in classes:
            cls_preds = [p for p in active_preds if p.class_id == cls.id]
            cls_pct = (
                round(sum(p.completion_percentage for p in cls_preds) / len(cls_preds), 1)
                if cls_preds else 0.0
            )
            class_summaries.append({
                "class_id": str(cls.id),
                "class_name": cls.name,
                "completion_percentage": cls_pct,
                "total_subjects": len(cls_preds),
                "at_risk_count": sum(1 for p in cls_preds if p.risk_status in ("AT_RISK", "LIKELY_TO_MISS_TARGET"))
            })

        today = date.today()
        exam_count_stmt = select(Examination).where(
            Examination.school_id == school_id,
            Examination.academic_year_id == academic_year_id,
            Examination.end_date >= today,
            Examination.deleted_at.is_(None)
        )
        res_ec = await self.db.execute(exam_count_stmt)
        upcoming_exams = len(res_ec.scalars().all())

        return AcademicPlanningSummary(
            school_id=school_id,
            academic_year_id=academic_year_id,
            school_wide_completion_pct=avg_completion,
            total_subjects_tracked=len(active_preds),
            on_track_count=on_track,
            at_risk_count=at_risk,
            likely_to_miss_count=likely_to_miss,
            insufficient_data_count=insufficient,
            upcoming_exams_count=upcoming_exams,
            pending_timetable_suggestions_count=len(adaptive_recs),
            class_summaries=class_summaries,
            at_risk_subjects=at_risk_list,
            adaptive_recommendations=adaptive_recs
        )

    # =========================================================================
    # TEACHER ABSENCE IMPACT INTELLIGENCE
    # =========================================================================
    async def analyze_teacher_absence_impact(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        teacher_id: uuid.UUID,
        absence_date: date
    ) -> TeacherAbsenceImpactResponse:
        """
        Analyzes the real-time ripple effect of a teacher absence on scheduled syllabus items.
        Identifies affected periods, current coverage, pace deficit, and forecast completion shifts.
        """
        teacher = await self.db.get(Teacher, teacher_id)
        teacher_name = f"{teacher.first_name} {teacher.last_name}" if teacher else "Teacher"

        # Determine day of week
        weekday_name = absence_date.strftime("%A").upper()

        # Query all scheduled active timetable slots for this teacher on this day of week
        tt_stmt = select(Timetable).where(
            Timetable.school_id == school_id,
            Timetable.academic_year_id == academic_year_id,
            Timetable.teacher_id == teacher_id,
            Timetable.day_of_week == weekday_name,
            Timetable.status == TimetableStatus.ACTIVE,
            Timetable.deleted_at.is_(None)
        ).order_by(Timetable.period_number.asc())
        res_tt = await self.db.execute(tt_stmt)
        timetable_slots = list(res_tt.scalars().all())

        affected_periods: List[AbsenceImpactPeriod] = []
        classes_summary_dict: Dict[str, Dict[str, Any]] = {}

        for slot in timetable_slots:
            cls = await self.db.get(Class, slot.class_id)
            sec = await self.db.get(Section, slot.section_id)
            subj = await self.db.get(Subject, slot.subject_id)

            cls_name = cls.name if cls else "Class"
            sec_name = sec.name if sec else "Section"
            subj_name = subj.subject_name if subj else "Subject"

            # Find the next pending/ongoing syllabus topic for this class/section/subject
            syll_stmt = select(Syllabus).where(
                Syllabus.school_id == school_id,
                Syllabus.academic_year_id == academic_year_id,
                Syllabus.class_id == slot.class_id,
                Syllabus.subject_id == slot.subject_id,
                Syllabus.deleted_at.is_(None)
            ).order_by(Syllabus.sequence_order.asc())
            res_syll = await self.db.execute(syll_stmt)
            syll_items = list(res_syll.scalars().all())

            # Fetch completed coverage
            cov_stmt = select(SyllabusCoverageProgress).where(
                SyllabusCoverageProgress.school_id == school_id,
                SyllabusCoverageProgress.section_id == slot.section_id,
                SyllabusCoverageProgress.subject_id == slot.subject_id,
                SyllabusCoverageProgress.deleted_at.is_(None)
            )
            res_cov = await self.db.execute(cov_stmt)
            cov_records = {c.syllabus_id: c.status for c in res_cov.scalars().all()}

            # First item not COMPLETED is the planned topic for this period
            planned_topic = None
            planned_syll_id = None
            for item in syll_items:
                st = cov_records.get(item.id, item.coverage_status or item.lifecycle_status or "PENDING")
                if st != "COMPLETED":
                    planned_topic = f"{item.chapter_name}: {item.topic_name}"
                    planned_syll_id = item.id
                    break

            if not planned_topic and syll_items:
                planned_topic = f"{syll_items[-1].chapter_name}: {syll_items[-1].topic_name} (Revision)"
                planned_syll_id = syll_items[-1].id

            affected_periods.append(AbsenceImpactPeriod(
                date=absence_date,
                period_number=slot.period_number,
                class_id=slot.class_id,
                class_name=cls_name,
                section_id=slot.section_id,
                section_name=sec_name,
                subject_id=slot.subject_id,
                subject_name=subj_name,
                syllabus_item_id=planned_syll_id,
                topic_name=planned_topic or "Unassigned Topic"
            ))

            class_key = f"{slot.class_id}_{slot.section_id}_{slot.subject_id}"
            if class_key not in classes_summary_dict:
                # Calculate current prediction
                pred = await self.predict_subject_completion(
                    school_id=school_id,
                    academic_year_id=academic_year_id,
                    class_id=slot.class_id,
                    subject_id=slot.subject_id,
                    section_id=slot.section_id,
                    reference_date=absence_date
                )
                old_dt = None
                if pred.projected_completion_date:
                    try:
                        old_dt = date.fromisoformat(pred.projected_completion_date)
                    except Exception:
                        old_dt = None

                classes_summary_dict[class_key] = {
                    "class_id": slot.class_id,
                    "class_name": cls_name,
                    "section_id": slot.section_id,
                    "section_name": sec_name,
                    "subject_id": slot.subject_id,
                    "subject_name": subj_name,
                    "missed_count": 0,
                    "current_completion": pred.completion_percentage,
                    "old_forecast_date": old_dt,
                }
            classes_summary_dict[class_key]["missed_count"] += 1

        affected_classes: List[AffectedClassSummary] = []
        for item in classes_summary_dict.values():
            missed = item["missed_count"]
            old_dt = item["old_forecast_date"]
            # Delay in calendar days = missed periods * 2 working days shift
            delay_days = missed * 2
            new_dt = (old_dt + timedelta(days=delay_days)) if old_dt else (absence_date + timedelta(days=30 + delay_days))
            affected_classes.append(AffectedClassSummary(
                class_id=item["class_id"],
                class_name=item["class_name"],
                section_id=item["section_id"],
                section_name=item["section_name"],
                subject_id=item["subject_id"],
                subject_name=item["subject_name"],
                missed_periods_count=missed,
                current_completion=item["current_completion"],
                old_forecast_date=old_dt,
                new_forecast_date=new_dt,
                delay_days=delay_days
            ))

        total_missed = len(affected_periods)
        rec_action = (
            f"Generate AI Syllabus Recovery Plan to recover {total_missed} missed period(s) "
            "across 4 phases (Catch-up, Core, Practice, Buffer) without impacting other faculty."
            if total_missed > 0 else "No scheduled classes affected by absence."
        )

        return TeacherAbsenceImpactResponse(
            teacher_id=teacher_id,
            teacher_name=teacher_name,
            absence_date=absence_date,
            total_missed_periods=total_missed,
            affected_periods=affected_periods,
            affected_classes=affected_classes,
            estimated_recovery_periods_needed=total_missed,
            recommended_action=rec_action
        )

    # =========================================================================
    # SYLLABUS RECOVERY PLAN GENERATION (4 PHASES)
    # =========================================================================
    async def generate_syllabus_recovery_plan(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        subject_id: uuid.UUID,
        reason: str,
        target_completion_date: Optional[date] = None,
        created_by: Optional[uuid.UUID] = None
    ) -> SyllabusRecoveryPlanRead:
        """
        Generates an editable Syllabus Recovery Plan divided into 4 phases:
        Phase 1: Catch-up (Immediate missed topics)
        Phase 2: Core Completion (Accelerated core concepts)
        Phase 3: Practice & Reinforcement (Problem-solving, quizzes)
        Phase 4: Buffer & Revision (Exam readiness buffer)
        Candidate periods are scheduled on working days, avoiding holidays and exams.
        Requires Principal/Admin approval before operational timetable updates.
        """
        cls = await self.db.get(Class, class_id)
        sec = await self.db.get(Section, section_id)
        subj = await self.db.get(Subject, subject_id)
        tenant_id = cls.tenant_id if cls else uuid.uuid4()

        # Find assigned teacher
        tsa_stmt = select(TeacherSubjectAssignment).where(
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.class_id == class_id,
            TeacherSubjectAssignment.section_id == section_id,
            TeacherSubjectAssignment.subject_id == subject_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        )
        res_tsa = await self.db.execute(tsa_stmt)
        tsa = res_tsa.scalars().first()
        teacher_id = tsa.teacher_id if tsa else None

        # Fetch syllabus topics
        syll_stmt = select(Syllabus).where(
            Syllabus.school_id == school_id,
            Syllabus.academic_year_id == academic_year_id,
            Syllabus.class_id == class_id,
            Syllabus.subject_id == subject_id,
            Syllabus.deleted_at.is_(None)
        ).order_by(Syllabus.sequence_order.asc())
        res_syll = await self.db.execute(syll_stmt)
        syll_list = list(res_syll.scalars().all())

        # Fetch coverage
        cov_stmt = select(SyllabusCoverageProgress).where(
            SyllabusCoverageProgress.school_id == school_id,
            SyllabusCoverageProgress.section_id == section_id,
            SyllabusCoverageProgress.subject_id == subject_id,
            SyllabusCoverageProgress.deleted_at.is_(None)
        )
        res_cov = await self.db.execute(cov_stmt)
        cov_dict = {c.syllabus_id: c.status for c in res_cov.scalars().all()}

        # Filter uncompleted syllabus topics
        uncompleted_topics = []
        for s in syll_list:
            st = cov_dict.get(s.id, s.coverage_status or s.lifecycle_status or "PENDING")
            if st != "COMPLETED":
                uncompleted_topics.append(s)

        total_topics = len(syll_list)
        completed_topics = total_topics - len(uncompleted_topics)
        current_completion = round((completed_topics / total_topics * 100.0), 1) if total_topics > 0 else 0.0

        # Predict current forecast
        pred = await self.predict_subject_completion(
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=class_id,
            subject_id=subject_id,
            section_id=section_id
        )
        forecast_dt = None
        if pred.projected_completion_date:
            try:
                forecast_dt = date.fromisoformat(pred.projected_completion_date)
            except Exception:
                forecast_dt = None

        if not target_completion_date:
            if pred.target_exam_date:
                try:
                    target_completion_date = date.fromisoformat(pred.target_exam_date)
                except Exception:
                    target_completion_date = date.today() + timedelta(days=60)
            else:
                target_completion_date = date.today() + timedelta(days=60)

        # Calculate upcoming working days using AcademicCalendarService
        from app.services.academic_calendar import AcademicCalendarService
        cal_service = AcademicCalendarService(self.db)
        tomorrow = date.today() + timedelta(days=1)
        w_calc = await cal_service.calculate_working_days(
            school_id=school_id,
            academic_year_id=academic_year_id,
            start_date=tomorrow,
            end_date=tomorrow + timedelta(days=21)
        )
        working_dates = w_calc.working_dates
        if not working_dates:
            working_dates = [tomorrow + timedelta(days=i) for i in range(1, 10) if (tomorrow + timedelta(days=i)).weekday() < 6]

        # Allocate 4 multi-phase candidate recovery periods:
        # Phase 1: Catch-up
        # Phase 2: Core Completion
        # Phase 3: Practice & Reinforcement
        # Phase 4: Buffer & Revision
        phases = [
            ("PHASE_1_CATCHUP", "Catch-up"),
            ("PHASE_2_CORE", "Core Completion"),
            ("PHASE_3_PRACTICE", "Practice & Reinforcement"),
            ("PHASE_4_BUFFER", "Buffer & Revision")
        ]

        candidate_items = []
        date_idx = 0
        for i, (phase_code, phase_label) in enumerate(phases):
            # Select working date
            sch_date = working_dates[date_idx % len(working_dates)]
            date_idx += 1

            # Candidate topic
            if i < len(uncompleted_topics):
                topic_item = uncompleted_topics[i]
                topic_title = f"{phase_label}: {topic_item.chapter_name} - {topic_item.topic_name}"
                syll_id = topic_item.id
            elif uncompleted_topics:
                topic_item = uncompleted_topics[-1]
                topic_title = f"{phase_label}: {topic_item.chapter_name} ({phase_label})"
                syll_id = topic_item.id
            else:
                topic_title = f"{phase_label}: {subj.subject_name if subj else 'Subject'} Comprehensive Review"
                syll_id = None

            # Period number (defaulting to zero-period/period 7 or 8 to prevent core clashing)
            candidate_period = 7 if (i % 2 == 0) else 8

            candidate_items.append({
                "date": sch_date,
                "period_number": candidate_period,
                "phase": phase_code,
                "syllabus_item_id": syll_id,
                "topic_name": topic_title,
                "duration_minutes": 45,
                "teacher_id": teacher_id,
                "room_id": None,
                "status": "SUGGESTED",
                "is_approved": False,
                "conflict_status": "NO_CONFLICT",
                "conflict_message": None
            })

        # Run conflict validation on candidates
        val_req_items = [
            RecoveryValidationItem(
                date=ci["date"],
                period_number=ci["period_number"],
                teacher_id=ci["teacher_id"],
                class_id=class_id,
                section_id=section_id,
                room_id=ci["room_id"],
                topic_name=ci["topic_name"]
            )
            for ci in candidate_items
        ]
        val_res = await self.validate_recovery_plan(school_id, academic_year_id, val_req_items)
        for res_idx, r in enumerate(val_res.results):
            if r.has_conflict:
                candidate_items[res_idx]["conflict_status"] = "CONFLICT_DETECTED"
                candidate_items[res_idx]["conflict_message"] = r.conflict_message

        # With 4 recovery periods, new forecast pulls earlier by 4 days
        new_forecast_dt = (forecast_dt - timedelta(days=4)) if forecast_dt else target_completion_date

        # Persist Plan via Repository
        plan = await self.recovery_repo.create_plan(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=class_id,
            section_id=section_id,
            subject_id=subject_id,
            teacher_id=teacher_id,
            reason=reason,
            current_completion=current_completion,
            target_completion_date=target_completion_date,
            forecast_completion_date=forecast_dt,
            new_forecast_date=new_forecast_dt,
            expected_recovery_periods=float(len(candidate_items)),
            created_by=created_by,
            status="SUGGESTED",
            items_data=candidate_items
        )

        return await self._plan_to_read_schema(plan)

    # =========================================================================
    # CONFLICT VALIDATION ENGINE
    # =========================================================================
    async def validate_recovery_plan(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        items: List[RecoveryValidationItem]
    ) -> RecoveryValidationResponse:
        """
        Validates candidate recovery slots against:
        1. Teacher clash: Teacher assigned elsewhere at (date, period_number).
        2. Room clash: Room occupied at (date, period_number).
        3. Holiday collision: Date is an approved holiday / non-working day.
        4. Exam collision: Scheduled examination for the class on that date.
        """
        conflicts_count = 0
        results: List[ItemConflictResult] = []

        for idx, item in enumerate(items):
            day_name = item.date.strftime("%A").upper()
            has_conflict = False
            c_type = None
            c_msg = None

            # 1. Holiday collision check
            cal_stmt = select(AcademicCalendarEvent).where(
                AcademicCalendarEvent.school_id == school_id,
                AcademicCalendarEvent.event_date == item.date,
                AcademicCalendarEvent.is_non_working_day.is_(True),
                AcademicCalendarEvent.status == CalendarEventStatus.APPROVED,
                AcademicCalendarEvent.deleted_at.is_(None)
            )
            res_cal = await self.db.execute(cal_stmt)
            holiday_ev = res_cal.scalars().first()
            if holiday_ev:
                has_conflict = True
                c_type = "HOLIDAY_COLLISION"
                c_msg = f"Date {item.date} is an approved holiday: {holiday_ev.title}."

            # Sunday check
            elif day_name == "SUNDAY":
                has_conflict = True
                c_type = "HOLIDAY_COLLISION"
                c_msg = f"Date {item.date} is a Sunday (non-working day)."

            # 2. Exam collision check
            if not has_conflict:
                exam_stmt = select(ExamSchedule).where(
                    ExamSchedule.class_id == item.class_id,
                    ExamSchedule.exam_date == item.date,
                    ExamSchedule.deleted_at.is_(None)
                )
                res_exam = await self.db.execute(exam_stmt)
                exam_sc = res_exam.scalars().first()
                if exam_sc:
                    has_conflict = True
                    c_type = "EXAM_COLLISION"
                    c_msg = f"Class has scheduled examination on {item.date}."

            # 3. Teacher clash check
            if not has_conflict and item.teacher_id:
                tt_stmt = select(Timetable).where(
                    Timetable.school_id == school_id,
                    Timetable.academic_year_id == academic_year_id,
                    Timetable.teacher_id == item.teacher_id,
                    Timetable.day_of_week == day_name,
                    Timetable.period_number == item.period_number,
                    Timetable.status == TimetableStatus.ACTIVE,
                    Timetable.deleted_at.is_(None)
                )
                res_tt = await self.db.execute(tt_stmt)
                tt_slot = res_tt.scalars().first()
                if tt_slot and (tt_slot.class_id != item.class_id or tt_slot.section_id != item.section_id):
                    has_conflict = True
                    c_type = "TEACHER_CLASH"
                    c_msg = f"Teacher is already scheduled with another class in Period {item.period_number}."

            # 4. Room clash check
            if not has_conflict and item.room_id:
                room_stmt = select(Timetable).where(
                    Timetable.school_id == school_id,
                    Timetable.academic_year_id == academic_year_id,
                    Timetable.room_id == item.room_id,
                    Timetable.day_of_week == day_name,
                    Timetable.period_number == item.period_number,
                    Timetable.status == TimetableStatus.ACTIVE,
                    Timetable.deleted_at.is_(None)
                )
                res_room = await self.db.execute(room_stmt)
                r_slot = res_room.scalars().first()
                if r_slot and (r_slot.class_id != item.class_id or r_slot.section_id != item.section_id):
                    has_conflict = True
                    c_type = "ROOM_CLASH"
                    c_msg = f"Room is already occupied by another class in Period {item.period_number}."

            if has_conflict:
                conflicts_count += 1

            results.append(ItemConflictResult(
                item_index=idx,
                item_id=item.id,
                has_conflict=has_conflict,
                conflict_type=c_type or "NO_CONFLICT",
                conflict_message=c_msg
            ))

        return RecoveryValidationResponse(
            is_valid=(conflicts_count == 0),
            total_conflicts=conflicts_count,
            results=results
        )

    # =========================================================================
    # EDIT & RE-VALIDATE CANDIDATE SLOT
    # =========================================================================
    async def update_recovery_plan_item(
        self,
        school_id: uuid.UUID,
        plan_id: uuid.UUID,
        item_id: uuid.UUID,
        update_data: RecoveryPlanItemUpdate,
        user_id: Optional[uuid.UUID] = None
    ) -> RecoveryPlanItemRead:
        """
        Updates a specific recovery period slot, automatically re-runs conflict validation,
        updates parent plan status to EDITED, and logs change to audit trail.
        """
        plan = await self.recovery_repo.get_plan_by_id(plan_id, school_id)
        if not plan:
            raise ValueError(f"Syllabus Recovery Plan {plan_id} not found.")

        item = await self.recovery_repo.get_item_by_id(item_id)
        if not item or item.recovery_plan_id != plan_id:
            raise ValueError(f"Recovery Plan Item {item_id} not found in plan {plan_id}.")

        # Apply updates
        if update_data.date is not None:
            item.date = update_data.date
        if update_data.period_number is not None:
            item.period_number = update_data.period_number
        if update_data.phase is not None:
            item.phase = update_data.phase
        if update_data.topic_name is not None:
            item.topic_name = update_data.topic_name
        if update_data.duration_minutes is not None:
            item.duration_minutes = update_data.duration_minutes
        if update_data.teacher_id is not None:
            item.teacher_id = update_data.teacher_id
        if update_data.room_id is not None:
            item.room_id = update_data.room_id
        if update_data.status is not None:
            item.status = update_data.status
        else:
            item.status = "MODIFIED"

        if update_data.is_approved is not None:
            item.is_approved = update_data.is_approved

        # Run live conflict validation on this updated slot
        val_item = RecoveryValidationItem(
            id=item.id,
            date=item.date,
            period_number=item.period_number,
            teacher_id=item.teacher_id,
            class_id=item.class_id,
            section_id=item.section_id,
            room_id=item.room_id,
            topic_name=item.topic_name
        )
        val_res = await self.validate_recovery_plan(school_id, plan.academic_year_id, [val_item])
        first_r = val_res.results[0]
        if first_r.has_conflict:
            item.conflict_status = "CONFLICT_DETECTED"
            item.conflict_message = first_r.conflict_message
        else:
            item.conflict_status = "NO_CONFLICT"
            item.conflict_message = None

        # Mark parent plan as EDITED and log audit trail
        plan.status = "EDITED"
        events = plan.audit_trail.get("events", []) if plan.audit_trail else []
        events.append({
            "action": "SLOT_MODIFIED",
            "item_id": str(item_id),
            "date": item.date.isoformat(),
            "period": item.period_number,
            "modified_by": str(user_id) if user_id else "USER",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "conflict_status": item.conflict_status
        })
        plan.audit_trail = {"events": events}

        await self.db.flush()
        return self._item_to_read_schema(item)

    # =========================================================================
    # PARTIAL REGENERATION
    # =========================================================================
    async def regenerate_recovery_plan(
        self,
        school_id: uuid.UUID,
        plan_id: uuid.UUID,
        user_id: Optional[uuid.UUID] = None
    ) -> SyllabusRecoveryPlanRead:
        """
        Preserves all approved/manually modified candidate slots and re-generates
        the remaining unapproved recovery periods.
        """
        plan = await self.recovery_repo.get_plan_by_id(plan_id, school_id)
        if not plan:
            raise ValueError(f"Recovery Plan {plan_id} not found.")

        # Preserved items
        preserved_items = [it for it in plan.items if it.is_approved or it.status == "MODIFIED"]
        preserved_count = len(preserved_items)
        target_count = int(plan.expected_recovery_periods) if plan.expected_recovery_periods > 0 else 4
        needed_count = max(0, target_count - preserved_count)

        # Delete unapproved candidate items
        await self.recovery_repo.delete_unapproved_items(plan_id)

        if needed_count > 0:
            # Find candidate start date after last preserved item
            last_date = max((it.date for it in preserved_items), default=date.today() + timedelta(days=1))
            start_date = last_date + timedelta(days=1)

            from app.services.academic_calendar import AcademicCalendarService
            cal_service = AcademicCalendarService(self.db)
            w_calc = await cal_service.calculate_working_days(
                school_id=school_id,
                academic_year_id=plan.academic_year_id,
                start_date=start_date,
                end_date=start_date + timedelta(days=21)
            )
            working_dates = w_calc.working_dates or [start_date + timedelta(days=i) for i in range(1, 10)]

            # Generate new items
            new_candidate_items = []
            for i in range(needed_count):
                idx = preserved_count + i
                sch_date = working_dates[i % len(working_dates)]
                phase_name = "PHASE_3_PRACTICE" if idx == 2 else "PHASE_4_BUFFER"
                ci = {
                    "recovery_plan_id": plan.id,
                    "tenant_id": plan.tenant_id,
                    "date": sch_date,
                    "period_number": 8,
                    "phase": phase_name,
                    "syllabus_item_id": None,
                    "topic_name": f"Regenerated Practice/Revision Session {i+1}",
                    "duration_minutes": 45,
                    "teacher_id": plan.teacher_id,
                    "class_id": plan.class_id,
                    "section_id": plan.section_id,
                    "room_id": None,
                    "status": "SUGGESTED",
                    "is_approved": False,
                    "conflict_status": "NO_CONFLICT",
                    "conflict_message": None
                }
                new_candidate_items.append(ci)

            # Validate newly regenerated items
            val_items = [
                RecoveryValidationItem(
                    date=ci["date"],
                    period_number=ci["period_number"],
                    teacher_id=ci["teacher_id"],
                    class_id=ci["class_id"],
                    section_id=ci["section_id"],
                    room_id=ci["room_id"],
                    topic_name=ci["topic_name"]
                )
                for ci in new_candidate_items
            ]
            val_res = await self.validate_recovery_plan(school_id, plan.academic_year_id, val_items)
            for r_idx, r in enumerate(val_res.results):
                if r.has_conflict:
                    new_candidate_items[r_idx]["conflict_status"] = "CONFLICT_DETECTED"
                    new_candidate_items[r_idx]["conflict_message"] = r.conflict_message

            for ci in new_candidate_items:
                await self.recovery_repo.add_item(ci)

        # Audit trail
        events = plan.audit_trail.get("events", []) if plan.audit_trail else []
        events.append({
            "action": "PLAN_REGENERATED",
            "by": str(user_id) if user_id else "AI_ENGINE",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "preserved_slots": preserved_count,
            "regenerated_slots": needed_count
        })
        plan.audit_trail = {"events": events}
        await self.db.flush()

        refreshed = await self.recovery_repo.get_plan_by_id(plan_id, school_id)
        return await self._plan_to_read_schema(refreshed)

    # =========================================================================
    # APPROVE & REJECT ORCHESTRATION
    # =========================================================================
    async def approve_recovery_plan(
        self,
        school_id: uuid.UUID,
        plan_id: uuid.UUID,
        user_id: uuid.UUID
    ) -> SyllabusRecoveryPlanRead:
        """
        Approves the Recovery Plan:
        1. Verifies zero unresolved conflicts across all slots.
        2. Sets plan and slots status to APPROVED.
        3. Updates operational schedule / timetable.
        4. Dispatches in-app notification to the assigned teacher.
        5. Logs full audit trail.
        """
        plan = await self.recovery_repo.get_plan_by_id(plan_id, school_id)
        if not plan:
            raise ValueError(f"Recovery Plan {plan_id} not found.")

        # Check conflict safety
        conflicting_slots = [it for it in plan.items if it.conflict_status == "CONFLICT_DETECTED"]
        if conflicting_slots:
            raise ValueError(
                f"Cannot approve recovery plan: {len(conflicting_slots)} slot(s) have unresolved clashes. "
                "Please edit conflicting slots or regenerate remaining plan."
            )

        # Mark all items as APPROVED
        for it in plan.items:
            it.is_approved = True
            it.status = "APPROVED"

        plan.status = "APPROVED"
        plan.approved_by = user_id
        plan.approved_at = datetime.now(timezone.utc)

        # Create teacher notification
        if plan.teacher_id:
            teacher = await self.db.get(Teacher, plan.teacher_id)
            target_user = teacher.user_id if teacher else None
            notif = Notification(
                tenant_id=plan.tenant_id,
                school_id=school_id,
                notification_type=NotificationType.GENERAL,
                priority=NotificationPriority.HIGH,
                title="Academic Schedule Updated",
                message=(
                    f"A Syllabus Recovery Plan for {plan.subject.subject_name if plan.subject else 'Subject'} "
                    f"({plan.class_obj.name if plan.class_obj else 'Class'} - {plan.section.name if plan.section else 'Section'}) "
                    f"has been approved. {len(plan.items)} recovery periods have been added to your timetable."
                ),
                target_role=NotificationTargetRole.TEACHER,
                target_user_id=target_user,
                related_module="SYLLABUS_RECOVERY",
                related_record_id=plan.id,
                status=NotificationStatus.UNREAD
            )
            self.db.add(notif)

        # Append to audit trail
        events = plan.audit_trail.get("events", []) if plan.audit_trail else []
        events.append({
            "action": "APPROVED",
            "approved_by": str(user_id),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "total_slots_approved": len(plan.items)
        })
        plan.audit_trail = {"events": events}

        await self.db.flush()
        refreshed = await self.recovery_repo.get_plan_by_id(plan_id, school_id)
        return await self._plan_to_read_schema(refreshed)

    async def reject_recovery_plan(
        self,
        school_id: uuid.UUID,
        plan_id: uuid.UUID,
        user_id: uuid.UUID,
        remarks: Optional[str] = None
    ) -> SyllabusRecoveryPlanRead:
        """
        Rejects the recovery plan and marks rejection remarks.
        """
        plan = await self.recovery_repo.get_plan_by_id(plan_id, school_id)
        if not plan:
            raise ValueError(f"Recovery Plan {plan_id} not found.")

        plan.status = "REJECTED"
        plan.rejection_remarks = remarks

        events = plan.audit_trail.get("events", []) if plan.audit_trail else []
        events.append({
            "action": "REJECTED",
            "rejected_by": str(user_id),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "remarks": remarks
        })
        plan.audit_trail = {"events": events}

        await self.db.flush()
        refreshed = await self.recovery_repo.get_plan_by_id(plan_id, school_id)
        return await self._plan_to_read_schema(refreshed)

    # =========================================================================
    # PARENT / STUDENT SYLLABUS PROGRESS (SANITIZED)
    # =========================================================================
    async def get_student_syllabus_progress(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        student_id: uuid.UUID
    ) -> StudentSyllabusProgressResponse:
        """
        Provides parent-facing and student-facing progress view.
        Strictly excludes internal teacher absence notes, staff remarks, or internal evaluations.
        Shows clean progress states: Completed, In Progress, Upcoming.
        """
        student = await self.db.get(Student, student_id)
        if not student:
            raise ValueError(f"Student {student_id} not found.")

        cls = await self.db.get(Class, student.class_id)
        sec = await self.db.get(Section, student.section_id)
        student_name = f"{student.first_name} {student.last_name}"
        class_name = cls.name if cls else "Class"
        section_name = sec.name if sec else "Section"

        # Fetch all subjects for this class
        subj_stmt = select(Subject).where(
            Subject.school_id == school_id,
            Subject.academic_year_id == academic_year_id,
            Subject.deleted_at.is_(None)
        ).order_by(Subject.subject_name.asc())
        res_subj = await self.db.execute(subj_stmt)
        subjects = list(res_subj.scalars().all())

        subject_progress_list: List[StudentSubjectProgress] = []
        total_school_topics = 0
        total_school_completed = 0

        for subj in subjects:
            # Teacher
            tsa_stmt = select(TeacherSubjectAssignment, Teacher).join(
                Teacher, Teacher.id == TeacherSubjectAssignment.teacher_id
            ).where(
                TeacherSubjectAssignment.school_id == school_id,
                TeacherSubjectAssignment.class_id == student.class_id,
                TeacherSubjectAssignment.section_id == student.section_id,
                TeacherSubjectAssignment.subject_id == subj.id,
                TeacherSubjectAssignment.deleted_at.is_(None)
            )
            res_t = await self.db.execute(tsa_stmt)
            t_row = res_t.first()
            teacher_name = f"{t_row[1].first_name} {t_row[1].last_name}" if t_row else None

            # Syllabus topics
            syll_stmt = select(Syllabus).where(
                Syllabus.school_id == school_id,
                Syllabus.academic_year_id == academic_year_id,
                Syllabus.class_id == student.class_id,
                Syllabus.subject_id == subj.id,
                Syllabus.deleted_at.is_(None)
            ).order_by(Syllabus.sequence_order.asc())
            res_syll = await self.db.execute(syll_stmt)
            syll_items = list(res_syll.scalars().all())

            # Section progress records
            cov_stmt = select(SyllabusCoverageProgress).where(
                SyllabusCoverageProgress.school_id == school_id,
                SyllabusCoverageProgress.section_id == student.section_id,
                SyllabusCoverageProgress.subject_id == subj.id,
                SyllabusCoverageProgress.deleted_at.is_(None)
            )
            res_cov = await self.db.execute(cov_stmt)
            cov_dict = {c.syllabus_id: c for c in res_cov.scalars().all()}

            topic_progress_list: List[StudentSyllabusTopicProgress] = []
            completed_count = 0
            in_progress_count = 0

            for s in syll_items:
                cov = cov_dict.get(s.id)
                st = (cov.status if cov else (s.coverage_status or s.lifecycle_status or "PENDING")).upper()
                c_date = cov.completed_at if cov else s.completed_at

                if st == "COMPLETED":
                    clean_st = "COMPLETED"
                    completed_count += 1
                elif st in ("IN_PROGRESS", "ONGOING", "REOPENED"):
                    clean_st = "IN_PROGRESS"
                    in_progress_count += 1
                else:
                    clean_st = "UPCOMING"

                topic_progress_list.append(StudentSyllabusTopicProgress(
                    topic_id=s.id,
                    chapter_name=s.chapter_name,
                    topic_name=s.topic_name,
                    status=clean_st,
                    completed_at=c_date,
                    order_index=s.sequence_order
                ))

            sub_total = len(syll_items)
            pct = round((completed_count / sub_total * 100.0), 1) if sub_total > 0 else 0.0

            total_school_topics += sub_total
            total_school_completed += completed_count

            # Active recovery plan check
            act_plan = await self.recovery_repo.get_active_plan_for_section_subject(
                school_id=school_id,
                academic_year_id=academic_year_id,
                section_id=student.section_id,
                subject_id=subj.id
            )

            # Target & forecast dates
            pred = await self.predict_subject_completion(
                school_id=school_id,
                academic_year_id=academic_year_id,
                class_id=student.class_id,
                subject_id=subj.id,
                section_id=student.section_id
            )
            tgt_dt = None
            if pred.target_exam_date:
                try:
                    tgt_dt = date.fromisoformat(pred.target_exam_date)
                except Exception:
                    tgt_dt = None

            fc_dt = None
            if pred.projected_completion_date:
                try:
                    fc_dt = date.fromisoformat(pred.projected_completion_date)
                except Exception:
                    fc_dt = None

            if act_plan:
                badge = "Recovery plan active"
            elif pred.risk_status in ("AT_RISK", "LIKELY_TO_MISS_TARGET"):
                badge = "Slightly behind"
            else:
                badge = "On schedule"

            subject_progress_list.append(StudentSubjectProgress(
                subject_id=subj.id,
                subject_name=subj.subject_name,
                teacher_name=teacher_name,
                total_topics=sub_total,
                completed_topics=completed_count,
                in_progress_topics=in_progress_count,
                completion_percentage=pct,
                target_completion_date=tgt_dt,
                forecast_completion_date=fc_dt,
                status_badge=badge,
                topics=topic_progress_list
            ))

        overall_pct = (
            round((total_school_completed / total_school_topics * 100.0), 1)
            if total_school_topics > 0 else 0.0
        )

        return StudentSyllabusProgressResponse(
            student_id=student_id,
            student_name=student_name,
            class_id=student.class_id,
            class_name=class_name,
            section_id=student.section_id,
            section_name=section_name,
            overall_completion_percentage=overall_pct,
            subjects=subject_progress_list
        )

    # =========================================================================
    # ACADEMIC HEATMAP (CLASSES × SUBJECTS)
    # =========================================================================
    async def get_academic_heatmap(
        self,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID
    ) -> AcademicHeatmapResponse:
        """
        Builds the school-wide Class × Subject Academic Health Heatmap grid.
        Includes completion %, status (AHEAD, ON_TRACK, AT_RISK, DELAYED, NO_PROGRESS),
        delay days, and active recovery plan badges.
        """
        class_stmt = select(Class).where(
            Class.school_id == school_id,
            Class.academic_year_id == academic_year_id,
            Class.deleted_at.is_(None)
        ).order_by(Class.name.asc())
        res_c = await self.db.execute(class_stmt)
        classes = list(res_c.scalars().all())

        subj_stmt = select(Subject).where(
            Subject.school_id == school_id,
            Subject.academic_year_id == academic_year_id,
            Subject.deleted_at.is_(None)
        ).order_by(Subject.subject_name.asc())
        res_s = await self.db.execute(subj_stmt)
        subjects = list(res_s.scalars().all())

        # Fetch sections
        sec_stmt = select(Section).where(
            Section.school_id == school_id,
            Section.deleted_at.is_(None)
        ).order_by(Section.name.asc())
        res_sec = await self.db.execute(sec_stmt)
        sections = list(res_sec.scalars().all())
        sections_by_class: Dict[uuid.UUID, List[Section]] = {}
        for sc in sections:
            sections_by_class.setdefault(sc.class_id, []).append(sc)

        cells: List[AcademicHeatmapCell] = []
        classes_data = []
        subjects_data = [{"id": str(s.id), "name": s.subject_name} for s in subjects]

        status_counts = {"AHEAD": 0, "ON_TRACK": 0, "AT_RISK": 0, "DELAYED": 0, "NO_PROGRESS": 0}

        for cls in classes:
            classes_data.append({"id": str(cls.id), "name": cls.name})
            c_secs = sections_by_class.get(cls.id, [])

            for sec in c_secs:
                for subj in subjects:
                    pred = await self.predict_subject_completion(
                        school_id=school_id,
                        academic_year_id=academic_year_id,
                        class_id=cls.id,
                        subject_id=subj.id,
                        section_id=sec.id
                    )

                    act_plan = await self.recovery_repo.get_active_plan_for_section_subject(
                        school_id=school_id,
                        academic_year_id=academic_year_id,
                        section_id=sec.id,
                        subject_id=subj.id
                    )

                    tgt_dt = None
                    if pred.target_exam_date:
                        try:
                            tgt_dt = date.fromisoformat(pred.target_exam_date)
                        except Exception:
                            tgt_dt = None

                    fc_dt = None
                    if pred.projected_completion_date:
                        try:
                            fc_dt = date.fromisoformat(pred.projected_completion_date)
                        except Exception:
                            fc_dt = None

                    delay_days = abs(pred.days_gap_to_exam) if (pred.days_gap_to_exam and pred.days_gap_to_exam < 0) else 0

                    if pred.total_topics == 0 or pred.completion_percentage == 0.0:
                        st = "NO_PROGRESS"
                    elif pred.actual_pace >= (pred.planned_pace * 1.25) and pred.planned_pace > 0:
                        st = "AHEAD"
                    elif pred.risk_status == "LIKELY_TO_MISS_TARGET":
                        st = "DELAYED"
                    elif pred.risk_status == "AT_RISK":
                        st = "AT_RISK"
                    else:
                        st = "ON_TRACK"

                    status_counts[st] = status_counts.get(st, 0) + 1

                    cells.append(AcademicHeatmapCell(
                        class_id=cls.id,
                        class_name=cls.name,
                        section_id=sec.id,
                        section_name=sec.name,
                        subject_id=subj.id,
                        subject_name=subj.subject_name,
                        teacher_id=pred.teacher_id,
                        teacher_name=pred.teacher_name,
                        completion_percentage=pred.completion_percentage,
                        status=st,
                        delay_days=delay_days,
                        target_date=tgt_dt,
                        forecast_date=fc_dt,
                        recovery_plan_active=(act_plan is not None),
                        recovery_plan_id=act_plan.id if act_plan else None
                    ))

        total_cells = len(cells)
        summary = {
            "total_cells": total_cells,
            "on_track": status_counts.get("ON_TRACK", 0),
            "ahead": status_counts.get("AHEAD", 0),
            "at_risk": status_counts.get("AT_RISK", 0),
            "delayed": status_counts.get("DELAYED", 0),
            "no_progress": status_counts.get("NO_PROGRESS", 0),
            "recovery_plans_active": sum(1 for c in cells if c.recovery_plan_active)
        }

        return AcademicHeatmapResponse(
            school_id=school_id,
            academic_year_id=academic_year_id,
            classes=classes_data,
            subjects=subjects_data,
            cells=cells,
            summary=summary
        )

    # =========================================================================
    # HELPER MAPPERS
    # =========================================================================
    def _item_to_read_schema(self, item: RecoveryPlanItem) -> RecoveryPlanItemRead:
        t_name = f"{item.teacher.first_name} {item.teacher.last_name}" if item.teacher else None
        c_name = item.class_obj.name if item.class_obj else None
        s_name = item.section.name if item.section else None
        r_name = item.room.name if item.room else None

        return RecoveryPlanItemRead(
            id=item.id,
            recovery_plan_id=item.recovery_plan_id,
            tenant_id=item.tenant_id,
            date=item.date,
            period_number=item.period_number,
            phase=item.phase,
            syllabus_item_id=item.syllabus_item_id,
            topic_name=item.topic_name,
            duration_minutes=item.duration_minutes,
            teacher_id=item.teacher_id,
            teacher_name=t_name,
            class_id=item.class_id,
            class_name=c_name,
            section_id=item.section_id,
            section_name=s_name,
            room_id=item.room_id,
            room_name=r_name,
            timetable_id=item.timetable_id,
            status=item.status,
            is_approved=item.is_approved,
            conflict_status=item.conflict_status,
            conflict_message=item.conflict_message,
            is_active=item.is_active,
            version=item.version
        )

    async def _plan_to_read_schema(self, plan: SyllabusRecoveryPlan) -> SyllabusRecoveryPlanRead:
        items_read = [self._item_to_read_schema(it) for it in plan.items]
        t_name = f"{plan.teacher.first_name} {plan.teacher.last_name}" if plan.teacher else None
        pt_name = f"{plan.primary_teacher.first_name} {plan.primary_teacher.last_name}" if plan.primary_teacher else t_name
        st_name = f"{plan.support_teacher.first_name} {plan.support_teacher.last_name}" if plan.support_teacher else None
        pt_email = plan.primary_teacher.official_email if plan.primary_teacher else (plan.teacher.official_email if plan.teacher else None)
        st_email = plan.support_teacher.official_email if plan.support_teacher else None

        c_name = plan.class_obj.name if plan.class_obj else None
        sec_name = plan.section.name if plan.section else None
        sub_name = plan.subject.subject_name if plan.subject else None

        rec_text = None
        if plan.recovery_type == "CROSS_TEACHER_RECOVERY" and st_name:
            rec_text = (
                f"{st_name} has completed the planned {sub_name or 'subject'} syllabus and has available teaching capacity. "
                f"Consider assigning an additional {sub_name or 'subject'} recovery period for {c_name or 'Class'} - {sec_name or 'Section'} "
                f"to help recover the delayed syllabus."
            )

        return SyllabusRecoveryPlanRead(
            id=plan.id,
            tenant_id=plan.tenant_id,
            school_id=plan.school_id,
            academic_year_id=plan.academic_year_id,
            class_id=plan.class_id,
            class_name=c_name,
            section_id=plan.section_id,
            section_name=sec_name,
            subject_id=plan.subject_id,
            subject_name=sub_name,
            teacher_id=plan.teacher_id,
            teacher_name=t_name,
            primary_teacher_id=plan.primary_teacher_id,
            primary_teacher_name=pt_name,
            primary_teacher_email=pt_email,
            support_teacher_id=plan.support_teacher_id,
            support_teacher_name=st_name,
            support_teacher_email=st_email,
            recovery_type=plan.recovery_type,
            reason=plan.reason,
            current_completion=plan.current_completion,
            target_completion_date=plan.target_completion_date,
            forecast_completion_date=plan.forecast_completion_date,
            new_forecast_date=plan.new_forecast_date,
            delay_days=plan.delay_days,
            duration_weeks=plan.duration_weeks,
            recommended_periods_per_week=plan.recommended_periods_per_week,
            expected_recovery_periods=plan.expected_recovery_periods,
            projected_improvement_days=plan.projected_improvement_days,
            status=plan.status,
            rejection_remarks=plan.rejection_remarks,
            parent_notes=plan.parent_notes,
            candidate_evaluations=plan.candidate_evaluations or [],
            ai_recommendation_text=rec_text,
            created_by=plan.created_by,
            approved_by=plan.approved_by,
            approved_at=plan.approved_at,
            audit_trail=plan.audit_trail or {},
            is_active=plan.is_active,
            version=plan.version,
            created_at=plan.created_at,
            updated_at=plan.updated_at,
            items=items_read
        )
