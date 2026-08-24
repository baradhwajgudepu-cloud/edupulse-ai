import uuid
from typing import List, Optional
from fastapi import HTTPException, status

from app.models.class_entity import Class, ClassStatus
from app.models.academic_year import AcademicYearStatus
from app.repositories.class_entity import ClassRepository
from app.repositories.academic_year import AcademicYearRepository
from app.schemas.class_entity import ClassCreate, ClassUpdate

class ClassService:
    """
    Service Layer implementing business rules for Class management.
    """
    def __init__(
        self,
        class_repo: ClassRepository,
        ay_repo: AcademicYearRepository
    ) -> None:
        self.class_repo = class_repo
        self.ay_repo = ay_repo

    async def create_class(
        self,
        tenant_id: uuid.UUID,
        obj_in: ClassCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Creates a new class, performing academic year validations, code/name uniqueness checks,
        and capacity validation.
        """
        # 1. Validate Academic Year existence and status
        ay = await self.ay_repo.get_by_id(obj_in.academic_year_id, obj_in.school_id, tenant_id)
        if not ay:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Academic year not found or mismatch."
            )

        if ay.status == AcademicYearStatus.ARCHIVED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot create classes in an archived academic year."
            )

        # 2. Prevent duplicate codes within the same Academic Year
        existing_code = await self.class_repo.get_by_code(obj_in.code, obj_in.academic_year_id, tenant_id)
        if existing_code:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Class with code '{obj_in.code}' already exists in this academic year."
            )

        # 3. Prevent duplicate names within the same Academic Year
        existing_name = await self.class_repo.get_by_name(obj_in.name, obj_in.academic_year_id, tenant_id)
        if existing_name:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Class with name '{obj_in.name}' already exists in this academic year."
            )

        # 4. Enforce capacity bounds
        if obj_in.capacity <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Class capacity must be a positive integer."
            )

        # 5. Delegate to repository
        db_obj = await self.class_repo.create(tenant_id, obj_in, created_by=created_by)
        await self.class_repo.db.commit()
        return await self.class_repo.get_by_id(db_obj.id, obj_in.school_id, tenant_id)

    async def update_class(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        class_id: uuid.UUID,
        obj_in: ClassUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Modifies class attributes, verifying name and code uniqueness.
        """
        db_obj = await self.class_repo.get_by_id(class_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class not found."
            )

        # Name duplicate check
        if obj_in.name and obj_in.name != db_obj.name:
            dup_name = await self.class_repo.get_by_name(obj_in.name, db_obj.academic_year_id, tenant_id)
            if dup_name:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Class with name '{obj_in.name}' already exists in this academic year."
                )

        # Code duplicate check
        if obj_in.code and obj_in.code != db_obj.code:
            dup_code = await self.class_repo.get_by_code(obj_in.code, db_obj.academic_year_id, tenant_id)
            if dup_code:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Class with code '{obj_in.code}' already exists in this academic year."
                )

        # Capacity validation
        if obj_in.capacity is not None and obj_in.capacity <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Class capacity must be a positive integer."
            )

        await self.class_repo.update(db_obj, obj_in, updated_by=updated_by)
        await self.class_repo.db.commit()
        return await self.class_repo.get_by_id(class_id, school_id, tenant_id)

    async def delete_class(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        class_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Soft deletes the Class. Blocked if sections exist (mock placeholder checked via settings).
        """
        db_obj = await self.class_repo.get_by_id(class_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class not found."
            )

        # Check active sections count or mock settings validation check
        from sqlalchemy import func, select
        from app.models.section import Section
        stmt_sec = select(func.count(Section.id)).where(
            Section.class_id == class_id,
            Section.deleted_at.is_(None)
        )
        res_sec = await self.class_repo.db.execute(stmt_sec)
        sections_count = res_sec.scalar() or 0
        
        mock_check = db_obj.settings and db_obj.settings.get("sections_exist") is True
        if sections_count > 0 or mock_check:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot delete class because sections are currently assigned."
            )

        await self.class_repo.soft_delete(db_obj, deleted_by=deleted_by)
        await self.class_repo.db.commit()
        await self.class_repo.db.refresh(db_obj)
        return db_obj

    async def archive_class(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        class_id: uuid.UUID,
        updated_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Transitions class status to ARCHIVED.
        """
        db_obj = await self.class_repo.get_by_id(class_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class not found."
            )

        db_obj.status = ClassStatus.ARCHIVED
        db_obj.is_active = False
        db_obj.updated_by = updated_by
        
        await self.class_repo.db.commit()
        return await self.class_repo.get_by_id(class_id, school_id, tenant_id)

    async def promote_class(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        class_id: uuid.UUID,
        obj_in: "ClassPromote",
        preview: bool = False,
        updated_by: Optional[uuid.UUID] = None
    ) -> "ClassPromoteResponse":
        """
        Promotes all active students in the source class to the configured target class and sections,
        evaluating grades and attendance under transactional rules.
        """
        from datetime import timezone, datetime
        from app.models.student import Student, StudentStatus
        from app.models.academic_year import AcademicYearStatus
        from app.models.section import Section, SectionStatus
        from app.models.class_entity import ClassStatus
        from app.schemas.class_entity import ClassPromoteResponse, PromotedStudentInfo
        from sqlalchemy import select, func

        # 1. Fetch source class
        source_class = await self.class_repo.get_by_id(class_id, school_id, tenant_id)
        if not source_class:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Source class not found."
            )

        # 2. Fetch target academic year
        target_ay_id = obj_in.target_academic_year_id or source_class.academic_year_id
        target_ay = await self.ay_repo.get_by_id(target_ay_id, school_id, tenant_id)
        if not target_ay:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Target academic year not found or school mismatch."
            )
        if target_ay.status == AcademicYearStatus.ARCHIVED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot promote students into an archived academic year."
            )

        # 3. Handle next class configuration and resolution
        target_class = None
        has_next_class = source_class.next_class_id is not None
        if has_next_class:
            next_class_template = await self.class_repo.get_by_id(source_class.next_class_id, school_id, tenant_id)
            if not next_class_template:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Configured next class template not found."
                )
            
            target_class = await self.class_repo.get_by_code(next_class_template.code, target_ay_id, tenant_id)
            if not target_class:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Target class '{next_class_template.code}' not found in the target academic year."
                )
            if target_class.status != ClassStatus.ACTIVE:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Target class is not active."
                )

        detained_target_class = await self.class_repo.get_by_code(source_class.code, target_ay_id, tenant_id)

        # 4. Verify section mappings & load section objects
        section_objs = {}
        for source_sec_id_str, target_sec_id_str in obj_in.section_mappings.items():
            source_sec_id = uuid.UUID(source_sec_id_str)
            target_sec_id = uuid.UUID(target_sec_id_str)
            
            target_sec = await self.class_repo.db.get(Section, target_sec_id)
            if not target_sec or target_sec.school_id != school_id or target_sec.tenant_id != tenant_id:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Target section '{target_sec_id}' not found."
                )
            if target_sec.status != SectionStatus.ACTIVE:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Target section '{target_sec.name}' is not active."
                )
            section_objs[source_sec_id] = target_sec

        # 5. Fetch school and settings
        from app.models.school import School
        school = await self.class_repo.db.get(School, school_id)
        school_settings = school.settings if school else {}

        # 6. Fetch all active students in the source class
        stmt_stud = select(Student).where(
            Student.class_id == class_id,
            Student.status == StudentStatus.ACTIVE,
            Student.deleted_at.is_(None)
        )
        res_stud = await self.class_repo.db.execute(stmt_stud)
        students = res_stud.scalars().all()

        promoted_list = []
        eligible_cnt = 0
        conditional_cnt = 0
        detained_cnt = 0
        graduated_cnt = 0
        blocked_cnt = 0
        failures = []

        occupancy_counts = {}

        for student in students:
            eval_status = await self._evaluate_student_promotion(
                self.class_repo.db, student.id, school_id, tenant_id, school_settings
            )

            rec_status = eval_status
            new_sec_id = None
            
            if rec_status == "PROMOTED":
                eligible_cnt += 1
            elif rec_status == "CONDITIONALLY_PROMOTED":
                conditional_cnt += 1
            elif rec_status == "DETAINED":
                detained_cnt += 1

            if rec_status in ["PROMOTED", "CONDITIONALLY_PROMOTED"]:
                if has_next_class:
                    source_sec_id = student.section_id
                    target_sec = section_objs.get(source_sec_id)
                    if not target_sec:
                        rec_status = "BLOCKED"
                        blocked_cnt += 1
                        failures.append(f"Student {student.first_name} {student.last_name}: Missing section mapping.")
                    else:
                        new_sec_id = target_sec.id
                        if new_sec_id not in occupancy_counts:
                            stmt_c = select(func.count(Student.id)).where(
                                Student.section_id == new_sec_id,
                                Student.deleted_at.is_(None)
                            )
                            res_c = await self.class_repo.db.execute(stmt_c)
                            occupancy_counts[new_sec_id] = res_c.scalar() or 0

                        if occupancy_counts[new_sec_id] >= target_sec.capacity:
                            rec_status = "BLOCKED"
                            blocked_cnt += 1
                            failures.append(f"Student {student.first_name} {student.last_name}: Target section '{target_sec.name}' is full ({occupancy_counts[new_sec_id]}/{target_sec.capacity}).")
                        else:
                            occupancy_counts[new_sec_id] += 1
                else:
                    rec_status = "GRADUATED"
                    graduated_cnt += 1
            elif rec_status == "DETAINED":
                if detained_target_class:
                    source_sec_id = student.section_id
                    target_sec = section_objs.get(source_sec_id)
                    if not target_sec:
                        rec_status = "BLOCKED"
                        blocked_cnt += 1
                        failures.append(f"Student {student.first_name} {student.last_name} (Detained): Missing section mapping.")
                    else:
                        new_sec_id = target_sec.id
                        if new_sec_id not in occupancy_counts:
                            stmt_c = select(func.count(Student.id)).where(
                                Student.section_id == new_sec_id,
                                Student.deleted_at.is_(None)
                            )
                            res_c = await self.class_repo.db.execute(stmt_c)
                            occupancy_counts[new_sec_id] = res_c.scalar() or 0

                        if occupancy_counts[new_sec_id] >= target_sec.capacity:
                            rec_status = "BLOCKED"
                            blocked_cnt += 1
                            failures.append(f"Student {student.first_name} {student.last_name} (Detained): Target section is full.")
                        else:
                            occupancy_counts[new_sec_id] += 1
                else:
                    rec_status = "BLOCKED"
                    blocked_cnt += 1
                    failures.append(f"Student {student.first_name} {student.last_name}: Class repeater target not setup.")

            promoted_list.append(PromotedStudentInfo(
                student_id=student.id,
                name=f"{student.first_name} {student.last_name}",
                previous_section_id=student.section_id,
                new_section_id=new_sec_id,
                status=rec_status
            ))

            if not preview and rec_status != "BLOCKED":
                if rec_status == "GRADUATED":
                    student.status = StudentStatus.ALUMNI
                    student.is_active = False
                    student.graduated_at = datetime.now(timezone.utc)
                elif rec_status in ["PROMOTED", "CONDITIONALLY_PROMOTED"]:
                    student.academic_year_id = target_ay_id
                    student.class_id = target_class.id
                    student.section_id = new_sec_id
                    student.promoted_at = datetime.now(timezone.utc)
                elif rec_status == "DETAINED":
                    student.academic_year_id = target_ay_id
                    student.class_id = detained_target_class.id
                    student.section_id = new_sec_id
                    student.promoted_at = datetime.now(timezone.utc)

        # 7. Commit or Rollback
        if preview:
            await self.class_repo.db.rollback()
        else:
            try:
                source_class.settings["last_promotion_execution"] = str(datetime.now(timezone.utc))
                source_class.updated_by = updated_by
                await self.class_repo.db.commit()
            except Exception as e:
                await self.class_repo.db.rollback()
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Promotion failed during transaction commit: {str(e)}"
                )

        return ClassPromoteResponse(
            total_students=len(students),
            eligible=eligible_cnt,
            conditional=conditional_cnt,
            detained=detained_cnt,
            graduated=graduated_cnt,
            blocked=blocked_cnt,
            promoted_students=promoted_list,
            failures=failures,
            settings={"last_promotion_execution": str(datetime.now(timezone.utc))}
        )

    async def _evaluate_student_promotion(self, db, student_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID, school_settings: dict) -> str:
        from app.models.student import Student
        from app.models.examination import ExamSchedule
        from app.models.marks import Marks
        from app.models.attendance import Attendance, AttendanceSession, AttendanceStatus
        from sqlalchemy import select, func

        promotion_policy = school_settings.get("promotion_policy") if school_settings else None
        if not promotion_policy:
            promotion_policy = {
                "min_attendance_pct": 75.0,
                "min_overall_pct": 35.0,
                "max_failed_subjects": 0
            }

        student = await db.get(Student, student_id)
        if not student:
            return "DETAINED"

        stmt_sched = select(ExamSchedule).where(
            ExamSchedule.class_id == student.class_id,
            ExamSchedule.deleted_at.is_(None)
        )
        res_sched = await db.execute(stmt_sched)
        schedules = res_sched.scalars().all()

        total_max_marks = 0.0
        total_obtained_marks = 0.0
        failed_subjects_count = 0

        for sched in schedules:
            stmt_m = select(Marks).where(
                Marks.exam_schedule_id == sched.id,
                Marks.student_id == student_id,
                Marks.deleted_at.is_(None)
            )
            res_m = await db.execute(stmt_m)
            mark = res_m.scalar_one_or_none()

            if not mark or mark.status == "DRAFT":
                failed_subjects_count += 1
                continue

            obtained = float(mark.marks_obtained) if mark.marks_obtained is not None else None
            max_m = sched.max_marks
            total_max_marks += max_m

            res_status = mark.result_status.value
            if res_status in ["PRESENT", "EXEMPTED"] and obtained is not None:
                total_obtained_marks += obtained
                if obtained < max_m * 0.35:
                    failed_subjects_count += 1
            else:
                failed_subjects_count += 1

        overall_pct = (total_obtained_marks / total_max_marks) * 100 if total_max_marks > 0 else 0.0

        stmt_att = select(Attendance).where(
            Attendance.student_id == student_id,
            Attendance.deleted_at.is_(None)
        )
        res_att = await db.execute(stmt_att)
        att_logs = res_att.scalars().all()

        stmt_sess = select(AttendanceSession).where(
            AttendanceSession.class_id == student.class_id,
            AttendanceSession.section_id == student.section_id,
            AttendanceSession.deleted_at.is_(None)
        )
        res_sess = await db.execute(stmt_sess)
        att_sessions = res_sess.scalars().all()

        total_days = len(att_sessions)
        present_days = sum(1 for a in att_logs if a.attendance_status in [AttendanceStatus.PRESENT, AttendanceStatus.LATE])
        attendance_pct = (present_days / total_days) * 100 if total_days > 0 else 0.0

        if attendance_pct < promotion_policy.get("min_attendance_pct", 75.0):
            return "PROMOTION_UNDER_REVIEW"
        elif overall_pct < promotion_policy.get("min_overall_pct", 35.0) or failed_subjects_count > 1:
            return "DETAINED"
        elif failed_subjects_count == 1:
            return "CONDITIONALLY_PROMOTED"
        else:
            return "PROMOTED"
