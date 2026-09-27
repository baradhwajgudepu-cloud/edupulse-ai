import uuid
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from fastapi import HTTPException, status
from sqlalchemy import select, and_, or_, func

from app.models.syllabus import Syllabus
from app.models.syllabus_coverage import SyllabusCoverageProgress
from app.models.user import User
from app.schemas.syllabus import (
    SyllabusCreate, SyllabusUpdate, SyllabusReorderItem,
    SubjectCoverageSummary, ChapterCoverageItem,
    SyllabusCoverageProgressUpdate, SyllabusCoverageProgressRead
)
from app.repositories.syllabus import SyllabusRepository
from app.repositories.syllabus_coverage import SyllabusCoverageRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.subject import SubjectRepository

class SyllabusService:
    """
    Service Layer implementing business rules and hierarchy validations for Syllabus management.
    Handles hierarchy editing, sequence reordering, section-level coverage tracking, and coverage summaries.
    """
    def __init__(
        self,
        syllabus_repo: SyllabusRepository,
        school_repo: SchoolRepository,
        academic_year_repo: AcademicYearRepository,
        class_repo: ClassRepository,
        subject_repo: SubjectRepository,
        coverage_repo: Optional[SyllabusCoverageRepository] = None
    ) -> None:
        self.syllabus_repo = syllabus_repo
        self.school_repo = school_repo
        self.academic_year_repo = academic_year_repo
        self.class_repo = class_repo
        self.subject_repo = subject_repo
        self.coverage_repo = coverage_repo or SyllabusCoverageRepository(syllabus_repo.db)

    async def create_syllabus_entry(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        obj_in: SyllabusCreate,
        current_user: User
    ) -> Syllabus:
        """
        Validates references hierarchy and uniqueness, and creates a Syllabus record.
        """
        school = await self.school_repo.get_by_id(school_id, tenant_id)
        if not school or not school.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active school entity not found."
            )

        ay = await self.academic_year_repo.get_by_id(academic_year_id, school_id, tenant_id)
        if not ay or ay.status.value != "ACTIVE":
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active academic year entity not found."
            )

        class_obj = await self.class_repo.get_by_id(obj_in.class_id, school_id, tenant_id)
        if not class_obj or class_obj.academic_year_id != academic_year_id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Class not found or academic year mismatch."
            )

        subject_obj = await self.subject_repo.get_by_id(obj_in.subject_id, school_id, tenant_id)
        if not subject_obj or subject_obj.academic_year_id != academic_year_id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Subject not found or academic year mismatch."
            )

        dup = await self.syllabus_repo.get_by_code(
            syllabus_code=obj_in.syllabus_code,
            academic_year_id=academic_year_id,
            class_id=obj_in.class_id,
            subject_id=obj_in.subject_id,
            tenant_id=tenant_id
        )
        if dup:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Syllabus entry with code '{obj_in.syllabus_code}' already exists for this class and subject in this academic year."
            )

        db_obj = await self.syllabus_repo.create(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            obj_in=obj_in,
            created_by=current_user.id
        )
        await self.syllabus_repo.db.commit()
        await self.syllabus_repo.db.refresh(db_obj)
        return db_obj

    async def update_syllabus_entry(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        syllabus_id: uuid.UUID,
        obj_in: SyllabusUpdate,
        current_user: User
    ) -> Syllabus:
        """
        Updates details of a Syllabus entry.
        """
        db_obj = await self.syllabus_repo.get_by_id(syllabus_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Syllabus entry not found."
            )

        updated_obj = await self.syllabus_repo.update(db_obj, obj_in, updated_by=current_user.id)
        await self.syllabus_repo.db.commit()
        await self.syllabus_repo.db.refresh(updated_obj)
        return updated_obj

    async def delete_syllabus_entry(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        syllabus_id: uuid.UUID,
        current_user: User
    ) -> Syllabus:
        """
        Soft deletes a Syllabus entry.
        """
        db_obj = await self.syllabus_repo.get_by_id(syllabus_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Syllabus entry not found."
            )

        deleted_obj = await self.syllabus_repo.soft_delete(db_obj, deleted_by=current_user.id)
        await self.syllabus_repo.db.commit()
        await self.syllabus_repo.db.refresh(deleted_obj)
        return deleted_obj

    async def reorder_entries(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        items: List[SyllabusReorderItem],
        current_user: User
    ) -> int:
        """
        Batch updates sequence orders for topics/chapters.
        """
        updated_count = 0
        now = datetime.now(timezone.utc)
        for item in items:
            entry = await self.syllabus_repo.get_by_id(item.id, school_id, tenant_id)
            if entry:
                entry.sequence_order = item.sequence_order
                entry.updated_at = now
                entry.updated_by = current_user.id
                self.syllabus_repo.db.add(entry)
                updated_count += 1

        await self.syllabus_repo.db.commit()
        return updated_count

    async def update_coverage(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        syllabus_id: uuid.UUID,
        coverage_status: str,
        current_user: User
    ) -> Syllabus:
        """
        Updates coverage status (PENDING, ONGOING, COMPLETED) of a topic.
        """
        normalized_status = coverage_status.strip().upper()
        if normalized_status not in ["PENDING", "ONGOING", "COMPLETED"]:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Invalid coverage status. Must be PENDING, ONGOING, or COMPLETED."
            )

        db_obj = await self.syllabus_repo.get_by_id(syllabus_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Syllabus entry not found."
            )

        db_obj.coverage_status = normalized_status
        now = datetime.now(timezone.utc)
        if normalized_status == "COMPLETED":
            db_obj.completed_at = now
            db_obj.lifecycle_status = "COMPLETED"
        elif normalized_status == "ONGOING":
            db_obj.completed_at = None
            db_obj.lifecycle_status = "IN_PROGRESS"
        else:
            db_obj.completed_at = None
            db_obj.lifecycle_status = "PLANNED"

        db_obj.updated_at = now
        db_obj.updated_by = current_user.id
        self.syllabus_repo.db.add(db_obj)
        await self.syllabus_repo.db.commit()
        await self.syllabus_repo.db.refresh(db_obj)
        return db_obj

    async def update_lifecycle_status(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        syllabus_id: uuid.UUID,
        lifecycle_status: str,
        current_user: User
    ) -> Syllabus:
        """
        Updates lifecycle status: PLANNED, IN_PROGRESS, COMPLETED, DEFERRED, REOPENED.
        """
        normalized = lifecycle_status.strip().upper()
        valid_states = ["PLANNED", "IN_PROGRESS", "COMPLETED", "DEFERRED", "REOPENED"]
        if normalized not in valid_states:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Invalid lifecycle status. Must be one of: {', '.join(valid_states)}"
            )

        db_obj = await self.syllabus_repo.get_by_id(syllabus_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Syllabus entry not found.")

        now = datetime.now(timezone.utc)
        db_obj.lifecycle_status = normalized
        if normalized == "COMPLETED":
            db_obj.completed_at = now
            db_obj.coverage_status = "COMPLETED"
        elif normalized == "IN_PROGRESS":
            db_obj.completed_at = None
            db_obj.coverage_status = "ONGOING"
        elif normalized == "REOPENED":
            db_obj.completed_at = None
            db_obj.coverage_status = "ONGOING"
        else:
            db_obj.completed_at = None
            db_obj.coverage_status = "PENDING"

        db_obj.updated_at = now
        db_obj.updated_by = current_user.id
        self.syllabus_repo.db.add(db_obj)
        await self.syllabus_repo.db.commit()
        await self.syllabus_repo.db.refresh(db_obj)
        return db_obj

    async def record_section_progress(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        section_id: uuid.UUID,
        syllabus_id: uuid.UUID,
        obj_in: SyllabusCoverageProgressUpdate,
        current_user: User,
        teacher_id: Optional[uuid.UUID] = None
    ) -> SyllabusCoverageProgress:
        """
        Records or updates section-specific and teacher-specific syllabus coverage progress.
        """
        syll = await self.syllabus_repo.get_by_id(syllabus_id, school_id, tenant_id)
        if not syll:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Syllabus entry not found.")

        normalized_status = obj_in.status.strip().upper()
        valid_states = ["PLANNED", "IN_PROGRESS", "COMPLETED", "DEFERRED", "REOPENED"]
        if normalized_status not in valid_states:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Invalid status. Must be one of: {', '.join(valid_states)}"
            )

        completed_at = obj_in.completed_at
        if normalized_status == "COMPLETED" and not completed_at:
            completed_at = datetime.now(timezone.utc)

        pct = obj_in.completion_percentage
        if normalized_status == "COMPLETED" and (pct is None or pct == 0.0):
            pct = 100.0

        started_at = obj_in.started_at
        if normalized_status in ["IN_PROGRESS", "COMPLETED"] and not started_at:
            started_at = datetime.now(timezone.utc)

        progress = await self.coverage_repo.upsert_progress(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=syll.class_id,
            section_id=section_id,
            subject_id=syll.subject_id,
            syllabus_id=syllabus_id,
            status=normalized_status,
            completion_percentage=pct,
            teacher_id=teacher_id,
            started_at=started_at,
            completed_at=completed_at,
            remarks=obj_in.remarks,
            user_id=current_user.id
        )
        await self.syllabus_repo.db.commit()
        await self.syllabus_repo.db.refresh(progress)
        return progress

    async def get_section_progress_list(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        section_id: uuid.UUID,
        subject_id: Optional[uuid.UUID] = None
    ) -> List[SyllabusCoverageProgress]:
        return await self.coverage_repo.get_section_progress(
            school_id=school_id,
            academic_year_id=academic_year_id,
            section_id=section_id,
            subject_id=subject_id
        )

    async def get_coverage_summary(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        subject_id: Optional[uuid.UUID] = None
    ) -> List[SubjectCoverageSummary]:
        """
        Calculates syllabus completion percentage, estimated teaching periods, timetable allocation, and chapter breakdowns.
        """
        from app.models.class_entity import Class
        from app.models.subject import Subject
        from app.models.section import Section
        from app.models.timetable import Timetable

        section_name = None
        if section_id:
            sec_res = await self.syllabus_repo.db.execute(select(Section.name).where(Section.id == section_id))
            section_name = sec_res.scalar_one_or_none()

        filters = [
            Syllabus.school_id == school_id,
            Syllabus.tenant_id == tenant_id,
            Syllabus.deleted_at.is_(None)
        ]
        if academic_year_id:
            filters.append(Syllabus.academic_year_id == academic_year_id)
        if class_id:
            filters.append(Syllabus.class_id == class_id)
        if section_id:
            filters.append(or_(Syllabus.section_id == section_id, Syllabus.section_id.is_(None)))
        if subject_id:
            filters.append(Syllabus.subject_id == subject_id)

        stmt = select(
            Syllabus, Class.name.label("class_name"), Subject.subject_name
        ).join(Class, Class.id == Syllabus.class_id)\
         .join(Subject, Subject.id == Syllabus.subject_id)\
         .where(and_(*filters))\
         .order_by(Class.name, Subject.subject_name, Syllabus.sequence_order)

        res = await self.syllabus_repo.db.execute(stmt)
        rows = res.all()

        # Timetable weekly period allocations
        tt_filters = [
            Timetable.school_id == school_id,
            Timetable.tenant_id == tenant_id,
            Timetable.deleted_at.is_(None)
        ]
        if academic_year_id:
            tt_filters.append(Timetable.academic_year_id == academic_year_id)
        if class_id:
            tt_filters.append(Timetable.class_id == class_id)
        if section_id:
            tt_filters.append(Timetable.section_id == section_id)
        if subject_id:
            tt_filters.append(Timetable.subject_id == subject_id)

        stmt_tt = select(
            Timetable.subject_id,
            Timetable.class_id,
            func.count(Timetable.id).label("weekly_slots")
        ).where(and_(*tt_filters))\
         .group_by(Timetable.subject_id, Timetable.class_id)

        res_tt = await self.syllabus_repo.db.execute(stmt_tt)
        tt_map = {(row.subject_id, row.class_id): int(row.weekly_slots or 0) for row in res_tt.all()}

        grouped: Dict[Any, Dict[str, Any]] = {}
        for s_obj, c_name, sub_name in rows:
            key = (s_obj.subject_id, s_obj.class_id)
            if key not in grouped:
                grouped[key] = {
                    "subject_id": s_obj.subject_id,
                    "subject_name": sub_name,
                    "class_id": s_obj.class_id,
                    "class_name": c_name,
                    "topics": [],
                    "chapters": {}
                }
            grouped[key]["topics"].append(s_obj)

            ch_name = s_obj.chapter_name or "General"
            if ch_name not in grouped[key]["chapters"]:
                grouped[key]["chapters"][ch_name] = []
            grouped[key]["chapters"][ch_name].append(s_obj)

        summaries = []
        for key, data in grouped.items():
            total = len(data["topics"])
            completed = sum(1 for t in data["topics"] if (t.coverage_status or "").upper() == "COMPLETED" or (t.lifecycle_status or "").upper() == "COMPLETED")
            ongoing = sum(1 for t in data["topics"] if (t.coverage_status or "").upper() == "ONGOING" or (t.lifecycle_status or "").upper() == "IN_PROGRESS")
            pending = total - completed - ongoing
            pct = round((completed / total * 100.0), 1) if total > 0 else 0.0
            total_periods = sum(getattr(t, "estimated_periods", 4) or 4 for t in data["topics"])
            completed_periods = sum(getattr(t, "estimated_periods", 4) or 4 for t in data["topics"] if (t.coverage_status or "").upper() == "COMPLETED" or (t.lifecycle_status or "").upper() == "COMPLETED")
            weekly_tt = tt_map.get(key, 0)

            chapter_items = []
            for ch_name, ch_topics in data["chapters"].items():
                ch_total = len(ch_topics)
                ch_comp = sum(1 for t in ch_topics if (t.coverage_status or "").upper() == "COMPLETED" or (t.lifecycle_status or "").upper() == "COMPLETED")
                ch_ong = sum(1 for t in ch_topics if (t.coverage_status or "").upper() == "ONGOING" or (t.lifecycle_status or "").upper() == "IN_PROGRESS")
                ch_pend = ch_total - ch_comp - ch_ong
                ch_pct = round((ch_comp / ch_total * 100.0), 1) if ch_total > 0 else 0.0
                ch_periods = sum(getattr(t, "estimated_periods", 4) or 4 for t in ch_topics)
                ch_comp_periods = sum(getattr(t, "estimated_periods", 4) or 4 for t in ch_topics if (t.coverage_status or "").upper() == "COMPLETED" or (t.lifecycle_status or "").upper() == "COMPLETED")

                ch_lifecycle = "COMPLETED" if ch_comp == ch_total else ("IN_PROGRESS" if (ch_comp > 0 or ch_ong > 0) else "PLANNED")

                chapter_items.append(ChapterCoverageItem(
                    chapter_name=ch_name,
                    total_topics=ch_total,
                    completed_topics=ch_comp,
                    ongoing_topics=ch_ong,
                    pending_topics=ch_pend,
                    coverage_percentage=ch_pct,
                    estimated_periods=ch_periods,
                    planned_periods=ch_periods,
                    completed_periods=ch_comp_periods,
                    lifecycle_status=ch_lifecycle
                ))

            summaries.append(SubjectCoverageSummary(
                subject_id=data["subject_id"],
                subject_name=data["subject_name"],
                class_id=data["class_id"],
                class_name=data["class_name"],
                section_id=section_id,
                section_name=section_name,
                total_topics=total,
                completed_topics=completed,
                ongoing_topics=ongoing,
                pending_topics=pending,
                coverage_percentage=pct,
                total_estimated_periods=total_periods,
                planned_periods=total_periods,
                completed_periods=completed_periods,
                weekly_timetable_periods=weekly_tt,
                chapters=chapter_items
            ))

        return summaries

    async def rename_unit(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        subject_id: uuid.UUID,
        old_unit_name: str,
        new_unit_name: str,
        current_user: User
    ) -> int:
        """
        Renames a unit across all its syllabus topics for a specific class and subject.
        Master curriculum is immutable; updates only the school campus copy.
        """
        stmt = select(Syllabus).where(
            Syllabus.tenant_id == tenant_id,
            Syllabus.school_id == school_id,
            Syllabus.academic_year_id == academic_year_id,
            Syllabus.class_id == class_id,
            Syllabus.subject_id == subject_id,
            Syllabus.unit_name == old_unit_name,
            Syllabus.deleted_at.is_(None)
        )
        res = await self.syllabus_repo.db.execute(stmt)
        entries = list(res.scalars().all())
        if not entries:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Unit '{old_unit_name}' not found for this class and subject."
            )

        now = datetime.now(timezone.utc)
        for e in entries:
            e.unit_name = new_unit_name
            e.updated_at = now
            e.updated_by = current_user.id
            self.syllabus_repo.db.add(e)

        await self.syllabus_repo.db.commit()
        return len(entries)

    async def delete_unit(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        subject_id: uuid.UUID,
        unit_name: str,
        current_user: User
    ) -> int:
        """
        Soft-deletes all chapters and topics belonging to a unit for a class and subject.
        """
        stmt = select(Syllabus).where(
            Syllabus.tenant_id == tenant_id,
            Syllabus.school_id == school_id,
            Syllabus.academic_year_id == academic_year_id,
            Syllabus.class_id == class_id,
            Syllabus.subject_id == subject_id,
            Syllabus.unit_name == unit_name,
            Syllabus.deleted_at.is_(None)
        )
        res = await self.syllabus_repo.db.execute(stmt)
        entries = list(res.scalars().all())
        if not entries:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Unit '{unit_name}' not found for this class and subject."
            )

        now = datetime.now(timezone.utc)
        for e in entries:
            e.deleted_at = now
            e.is_active = False
            e.updated_at = now
            e.updated_by = current_user.id
            self.syllabus_repo.db.add(e)

        await self.syllabus_repo.db.commit()
        return len(entries)

    async def update_chapter(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        subject_id: uuid.UUID,
        old_chapter_name: str,
        new_chapter_name: str,
        current_user: User,
        unit_name: Optional[str] = None,
        estimated_periods: Optional[int] = None,
        lifecycle_status: Optional[str] = None,
        remarks: Optional[str] = None
    ) -> int:
        """
        Updates chapter name, estimated teaching periods, and lifecycle status for a chapter.
        """
        filters = [
            Syllabus.tenant_id == tenant_id,
            Syllabus.school_id == school_id,
            Syllabus.academic_year_id == academic_year_id,
            Syllabus.class_id == class_id,
            Syllabus.subject_id == subject_id,
            Syllabus.chapter_name == old_chapter_name,
            Syllabus.deleted_at.is_(None)
        ]
        if unit_name:
            filters.append(Syllabus.unit_name == unit_name)

        stmt = select(Syllabus).where(and_(*filters))
        res = await self.syllabus_repo.db.execute(stmt)
        entries = list(res.scalars().all())
        if not entries:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Chapter '{old_chapter_name}' not found for this class and subject."
            )

        now = datetime.now(timezone.utc)
        for e in entries:
            e.chapter_name = new_chapter_name
            if estimated_periods is not None:
                e.estimated_periods = estimated_periods
            if lifecycle_status is not None:
                norm_status = lifecycle_status.strip().upper()
                e.lifecycle_status = norm_status
                if norm_status == "COMPLETED":
                    e.coverage_status = "COMPLETED"
                    e.completed_at = now
                elif norm_status in ["IN_PROGRESS", "REOPENED"]:
                    e.coverage_status = "ONGOING"
                    e.completed_at = None
                else:
                    e.coverage_status = "PENDING"
                    e.completed_at = None
            if remarks is not None:
                e.description = remarks
            e.updated_at = now
            e.updated_by = current_user.id
            self.syllabus_repo.db.add(e)

        await self.syllabus_repo.db.commit()
        return len(entries)

    async def delete_chapter(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        subject_id: uuid.UUID,
        chapter_name: str,
        current_user: User,
        unit_name: Optional[str] = None
    ) -> int:
        """
        Soft-deletes all topics in a chapter for a class and subject.
        """
        filters = [
            Syllabus.tenant_id == tenant_id,
            Syllabus.school_id == school_id,
            Syllabus.academic_year_id == academic_year_id,
            Syllabus.class_id == class_id,
            Syllabus.subject_id == subject_id,
            Syllabus.chapter_name == chapter_name,
            Syllabus.deleted_at.is_(None)
        ]
        if unit_name:
            filters.append(Syllabus.unit_name == unit_name)

        stmt = select(Syllabus).where(and_(*filters))
        res = await self.syllabus_repo.db.execute(stmt)
        entries = list(res.scalars().all())
        if not entries:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Chapter '{chapter_name}' not found for this class and subject."
            )

        now = datetime.now(timezone.utc)
        for e in entries:
            e.deleted_at = now
            e.is_active = False
            e.updated_at = now
            e.updated_by = current_user.id
            self.syllabus_repo.db.add(e)

        await self.syllabus_repo.db.commit()
        return len(entries)

    async def delete_class_subject(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        subject_id: uuid.UUID,
        current_user: User
    ) -> int:
        """
        Soft-deletes all syllabus entries for a specific subject within a class.
        """
        stmt = select(Syllabus).where(
            Syllabus.tenant_id == tenant_id,
            Syllabus.school_id == school_id,
            Syllabus.academic_year_id == academic_year_id,
            Syllabus.class_id == class_id,
            Syllabus.subject_id == subject_id,
            Syllabus.deleted_at.is_(None)
        )
        res = await self.syllabus_repo.db.execute(stmt)
        entries = list(res.scalars().all())
        if not entries:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No syllabus items found for this subject in the specified class."
            )

        now = datetime.now(timezone.utc)
        for e in entries:
            e.deleted_at = now
            e.is_active = False
            e.updated_at = now
            e.updated_by = current_user.id
            self.syllabus_repo.db.add(e)

        await self.syllabus_repo.db.commit()
        return len(entries)

