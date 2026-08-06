import uuid
import logging
from datetime import date, datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import HTTPException, status

from app.models.homework import Homework, HomeworkStatus, HomeworkPriority
from app.models.timetable import Timetable
from app.models.user import User
from app.repositories.homework import HomeworkRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.timetable import TimetableRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.schemas.homework import HomeworkCreate, HomeworkUpdate, HomeworkCreateFromTimetable
from app.services.notification import NotificationService

logger = logging.getLogger(__name__)

class HomeworkService:
    """
    Service Layer implementing business validations and productivity workflows for Homework.
    """
    def __init__(
        self,
        homework_repo: HomeworkRepository,
        teacher_repo: TeacherRepository,
        subject_repo: SubjectRepository,
        class_repo: ClassRepository,
        section_repo: SectionRepository,
        timetable_repo: TimetableRepository,
        tsa_repo: TeacherSubjectAssignmentRepository,
        notification_service: NotificationService
    ) -> None:
        self.homework_repo = homework_repo
        self.teacher_repo = teacher_repo
        self.subject_repo = subject_repo
        self.class_repo = class_repo
        self.section_repo = section_repo
        self.timetable_repo = timetable_repo
        self.tsa_repo = tsa_repo
        self.notification_service = notification_service

    async def create_homework(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: HomeworkCreate, current_user: User
    ) -> Homework:
        # 1. Date Validation
        if obj_in.due_date < date.today():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Homework due date cannot be in the past."
            )

        # 2. Existential checks
        teacher = await self.teacher_repo.get_by_id(obj_in.teacher_id, school_id, tenant_id)
        if not teacher or not teacher.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active teacher not found."
            )

        subject = await self.subject_repo.get_by_id(obj_in.subject_id, school_id, tenant_id)
        if not subject or not subject.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active subject not found."
            )

        class_obj = await self.class_repo.get_by_id(obj_in.class_id, school_id, tenant_id)
        if not class_obj or not class_obj.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active class not found."
            )

        section = await self.section_repo.get_by_id(obj_in.section_id, school_id, tenant_id)
        if not section or not section.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active section not found."
            )

        if section.class_id != class_obj.id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Target section does not belong to the selected class."
            )

        # 3. TSA assignment check
        tsa = await self.tsa_repo.get_by_id(obj_in.teacher_subject_assignment_id, school_id, tenant_id)
        if not tsa or not tsa.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active teacher subject assignment not found."
            )

        if (
            tsa.teacher_id != obj_in.teacher_id
            or tsa.subject_id != obj_in.subject_id
            or tsa.class_id != obj_in.class_id
            or tsa.section_id != obj_in.section_id
        ):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Teacher subject assignment details do not match the class/section/subject mapping."
            )

        # 4. Duplicate Check
        dup = await self.homework_repo.get_duplicate_homework(
            teacher_id=obj_in.teacher_id,
            subject_id=obj_in.subject_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            due_date=obj_in.due_date,
            title=obj_in.title,
            tenant_id=tenant_id
        )
        if dup:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Homework with this title, subject, and due date already exists for this class/section."
            )

        # 5. Populate notification settings
        settings_dict = dict(obj_in.settings or {})
        if obj_in.status == HomeworkStatus.PUBLISHED:
            settings_dict["notification_status"] = "PENDING"
            settings_dict["notification_sent_at"] = None
        else:
            settings_dict["notification_status"] = "DRAFT"
            settings_dict["notification_sent_at"] = None
        obj_in.settings = settings_dict

        db_obj = await self.homework_repo.create(tenant_id, obj_in, created_by=current_user.id)
        await self.homework_repo.db.commit()

        # Trigger notification if published
        if obj_in.status == HomeworkStatus.PUBLISHED:
            try:
                await self.notification_service.notify_homework(tenant_id, school_id, db_obj.id)
            except Exception as ne:
                logger.error(f"Failed to send homework notification: {str(ne)}", exc_info=True)

        return await self.homework_repo.get_by_id(db_obj.id, school_id, tenant_id)

    async def create_homework_from_timetable(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        timetable_id: uuid.UUID,
        obj_in: HomeworkCreateFromTimetable,
        current_user: User
    ) -> Homework:
        # Load timetable entry
        timetable = await self.timetable_repo.get_by_id(timetable_id, school_id, tenant_id)
        if not timetable or not timetable.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Timetable slot not found or inactive."
            )

        if not timetable.teacher_subject_assignment_id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Timetable slot does not have an active teacher subject assignment."
            )

        # Resolve other keys from timetable entry
        full_create = HomeworkCreate(
            school_id=school_id,
            academic_year_id=timetable.academic_year_id,
            teacher_id=timetable.teacher_id,
            teacher_subject_assignment_id=timetable.teacher_subject_assignment_id,
            subject_id=timetable.subject_id,
            class_id=timetable.class_id,
            section_id=timetable.section_id,
            timetable_id=timetable.id,
            title=obj_in.title,
            description=obj_in.description,
            due_date=obj_in.due_date,
            priority=obj_in.priority,
            status=obj_in.status,
            attachment_url=obj_in.attachment_url,
            estimated_minutes=obj_in.estimated_minutes
        )

        return await self.create_homework(tenant_id, school_id, full_create, current_user)

    async def update_homework(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        homework_id: uuid.UUID,
        obj_in: HomeworkUpdate,
        current_user: User
    ) -> Homework:
        db_obj = await self.homework_repo.get_by_id(homework_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Homework assignment not found."
            )

        update_data = obj_in.model_dump(exclude_unset=True)

        if "due_date" in update_data and update_data["due_date"] < date.today():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Homework due date cannot be in the past."
            )

        # Update notification settings if status changes to published
        if "status" in update_data:
            settings_dict = dict(db_obj.settings or {})
            if update_data["status"] == HomeworkStatus.PUBLISHED:
                settings_dict["notification_status"] = "PENDING"
                settings_dict["notification_sent_at"] = None
            update_data["settings"] = settings_dict

        await self.homework_repo.update(db_obj, update_data, updated_by=current_user.id)
        await self.homework_repo.db.commit()

        # Trigger notification if updated status is published
        if update_data.get("status") == HomeworkStatus.PUBLISHED:
            try:
                await self.notification_service.notify_homework(tenant_id, school_id, homework_id)
            except Exception as ne:
                logger.error(f"Failed to send homework notification: {str(ne)}", exc_info=True)

        return await self.homework_repo.get_by_id(homework_id, school_id, tenant_id)

    async def delete_homework(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, homework_id: uuid.UUID, current_user: User
    ) -> Homework:
        db_obj = await self.homework_repo.get_by_id(homework_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Homework assignment not found."
            )

        await self.homework_repo.soft_delete(db_obj, deleted_by=current_user.id)
        await self.homework_repo.db.commit()
        await self.homework_repo.db.refresh(db_obj)
        return db_obj

    async def publish_homework(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, homework_id: uuid.UUID, current_user: User
    ) -> Homework:
        db_obj = await self.homework_repo.get_by_id(homework_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Homework assignment not found."
            )

        settings_dict = dict(db_obj.settings or {})
        settings_dict["notification_status"] = "PENDING"
        settings_dict["notification_sent_at"] = None

        update_data = {
            "status": HomeworkStatus.PUBLISHED,
            "settings": settings_dict
        }

        await self.homework_repo.update(db_obj, update_data, updated_by=current_user.id)
        await self.homework_repo.db.commit()

        # Trigger notification
        try:
            await self.notification_service.notify_homework(tenant_id, school_id, homework_id)
        except Exception as ne:
            logger.error(f"Failed to send homework notification: {str(ne)}", exc_info=True)

        return await self.homework_repo.get_by_id(homework_id, school_id, tenant_id)

    async def copy_homework_to_sections(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        homework_id: uuid.UUID,
        target_section_ids: List[uuid.UUID],
        current_user: User
    ) -> List[Homework]:
        source_homework = await self.homework_repo.get_by_id(homework_id, school_id, tenant_id)
        if not source_homework:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Source homework assignment not found."
            )

        copies = []
        for section_id in target_section_ids:
            # Skip copying to same section as source
            if section_id == source_homework.section_id:
                continue

            section = await self.section_repo.get_by_id(section_id, school_id, tenant_id)
            if not section or not section.is_active:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Target section {section_id} not found or inactive."
                )

            # Check if teacher teaches this subject in target section
            tsa = await self.tsa_repo.get_duplicate_assignment(
                teacher_id=source_homework.teacher_id,
                subject_id=source_homework.subject_id,
                class_id=section.class_id,
                section_id=section.id,
                academic_year_id=source_homework.academic_year_id,
                tenant_id=tenant_id
            )
            if not tsa:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Teacher is not assigned to teach this subject in target class/section {section.name}."
                )

            # Duplicate prevention check
            dup = await self.homework_repo.get_duplicate_homework(
                teacher_id=source_homework.teacher_id,
                subject_id=source_homework.subject_id,
                class_id=section.class_id,
                section_id=section.id,
                due_date=source_homework.due_date,
                title=source_homework.title,
                tenant_id=tenant_id
            )
            if dup:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Homework already exists in class/section {section.name}."
                )

            # Construct copy payload
            copied_payload = HomeworkCreate(
                school_id=school_id,
                academic_year_id=source_homework.academic_year_id,
                teacher_id=source_homework.teacher_id,
                teacher_subject_assignment_id=tsa.id,
                subject_id=source_homework.subject_id,
                class_id=section.class_id,
                section_id=section.id,
                timetable_id=None,
                title=source_homework.title,
                description=source_homework.description,
                due_date=source_homework.due_date,
                priority=source_homework.priority,
                status=source_homework.status,
                attachment_url=source_homework.attachment_url,
                estimated_minutes=source_homework.estimated_minutes
            )

            # Set copy meta in settings/ai_metrics
            copied_payload.ai_metrics["copied_from_previous"] = True

            db_obj = await self.homework_repo.create(tenant_id, copied_payload, created_by=current_user.id)
            copies.append(db_obj)

        await self.homework_repo.db.commit()

        # Reload all copies to populate relationships
        result_copies = []
        for copy_obj in copies:
            reloaded = await self.homework_repo.get_by_id(copy_obj.id, school_id, tenant_id)
            if reloaded:
                result_copies.append(reloaded)
        return result_copies

    async def get_templates(
        self, subject_id: Optional[uuid.UUID], school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[str]:
        # Helper returns standard templates
        if subject_id:
            subject = await self.subject_repo.get_by_id(subject_id, school_id, tenant_id)
            if subject:
                name_lower = subject.subject_name.lower()
                if "math" in name_lower or "algebra" in name_lower or "geometry" in name_lower:
                    return ["Solve Exercise", "Practice Problems", "Learn Formula"]
                elif "english" in name_lower or "literature" in name_lower or "grammar" in name_lower:
                    return ["Read Chapter", "Grammar Exercise", "Essay Writing"]
                elif "science" in name_lower or "physics" in name_lower or "chemistry" in name_lower or "biology" in name_lower:
                    return ["Draw Diagram", "Project Work"]

        # Default fallback
        return ["Read Chapter", "Solve Exercise", "Revise Notes", "Practice Problems"]
