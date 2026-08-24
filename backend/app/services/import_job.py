import uuid
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy import select, func, and_, text
from sqlalchemy.orm import Session

from app.models.import_job import ImportJob, ImportJobRow, ImportType, ImportJobStatus
from app.schemas.import_job import ImportJobCreate, ImportJobRowCreate
import os
import csv
import io
from datetime import date
from app.models.academic_year import AcademicYear
from app.models.class_entity import Class
from app.models.section import Section
from app.models.student import Student
from app.models.student_import import StudentImportRow

class ImportJobService:
    def __init__(self, db: Session, storage_service = None) -> None:
        self.db = db
        from app.services.storage import get_storage_service
        self.storage_service = storage_service or get_storage_service()

    async def create_job(self, tenant_id: uuid.UUID, obj_in: ImportJobCreate, current_user_id: uuid.UUID) -> ImportJob:
        # Check active checksum duplicates (VALIDATING, VALIDATED, RUNNING)
        if obj_in.file_checksum:
            stmt = select(ImportJob).where(
                and_(
                    ImportJob.tenant_id == tenant_id,
                    ImportJob.school_id == obj_in.school_id,
                    ImportJob.import_type == obj_in.import_type,
                    ImportJob.file_checksum == obj_in.file_checksum,
                    ImportJob.status.in_([
                        ImportJobStatus.VALIDATING,
                        ImportJobStatus.VALIDATED,
                        ImportJobStatus.RUNNING
                    ]),
                    ImportJob.deleted_at.is_(None)
                )
            )
            res = await self.db.execute(stmt)
            active_job = res.scalar_one_or_none()
            if active_job:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"An active import job with checksum '{obj_in.file_checksum}' already exists: ID {active_job.id}"
                )

        # Create new DRAFT job
        db_job = ImportJob(
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            import_type=obj_in.import_type,
            status=ImportJobStatus.DRAFT,
            source_filename=obj_in.source_filename,
            file_checksum=obj_in.file_checksum,
            total_rows=obj_in.total_rows,
            job_metadata=obj_in.job_metadata,
            created_by=current_user_id
        )
        self.db.add(db_job)
        await self.db.commit()
        await self.db.refresh(db_job)
        return db_job

    async def get_job_by_id(self, tenant_id: uuid.UUID, job_id: uuid.UUID) -> Optional[ImportJob]:
        stmt = select(ImportJob).where(
            and_(
                ImportJob.id == job_id,
                ImportJob.tenant_id == tenant_id,
                ImportJob.deleted_at.is_(None)
            )
        )
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def list_jobs(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        import_type: Optional[ImportType] = None,
        job_status: Optional[ImportJobStatus] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[ImportJob]:
        filters = [
            ImportJob.tenant_id == tenant_id,
            ImportJob.school_id == school_id,
            ImportJob.deleted_at.is_(None)
        ]
        if import_type:
            filters.append(ImportJob.import_type == import_type)
        if job_status:
            filters.append(ImportJob.status == job_status)

        stmt = select(ImportJob).where(and_(*filters)).order_by(ImportJob.created_at.desc()).offset(skip).limit(limit)
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def start_job(self, tenant_id: uuid.UUID, job_id: uuid.UUID) -> ImportJob:
        job = await self.get_job_by_id(tenant_id, job_id)
        if not job:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Import job not found."
            )

        if job.status != ImportJobStatus.VALIDATED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot start execution. Import job must be in VALIDATED state, current state is '{job.status}'."
            )

        if job.import_type == ImportType.STUDENTS:
            return await self.execute_student_job(tenant_id, job_id, job=job)
        elif job.import_type == ImportType.ACADEMIC_SETUP:
            return await self.execute_academic_setup_job(tenant_id, job_id, job=job)
        elif job.import_type == ImportType.GUARDIANS:
            return await self.execute_guardian_job(tenant_id, job_id, job=job)
        elif job.import_type == ImportType.GUARDIAN_MAPPING:
            return await self.execute_guardian_mapping_job(tenant_id, job_id, job=job)
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Execution logic is not implemented for '{job.import_type}'."
            )

    async def execute_student_job(self, tenant_id: uuid.UUID, job_id: uuid.UUID, job: ImportJob) -> ImportJob:
        # Transition status to RUNNING
        job.status = ImportJobStatus.RUNNING
        job.started_at = datetime.now(timezone.utc)
        self.db.add(job)
        await self.db.commit()

        # Initialize repositories and services
        from app.repositories.student import StudentRepository
        from app.repositories.academic_year import AcademicYearRepository
        from app.repositories.class_entity import ClassRepository
        from app.repositories.section import SectionRepository
        from app.services.student import StudentService
        from app.schemas.student import StudentCreate

        student_repo = StudentRepository(self.db)
        ay_repo = AcademicYearRepository(self.db)
        class_repo = ClassRepository(self.db)
        section_repo = SectionRepository(self.db)

        student_service = StudentService(
            student_repo=student_repo,
            ay_repo=ay_repo,
            class_repo=class_repo,
            section_repo=section_repo
        )

        # Mock commit to avoid closing nested transactions
        original_commit = self.db.commit
        async def mock_commit():
            await self.db.flush()
        self.db.commit = mock_commit

        try:
            try:
                chunk_size = 100
                total_valid_executed = 0
                total_failed_executed = 0

                while True:
                    # Fetch next chunk of valid rows
                    stmt = select(StudentImportRow).where(
                        and_(
                            StudentImportRow.import_job_id == job_id,
                            StudentImportRow.validation_status == "valid",
                            StudentImportRow.tenant_id == tenant_id,
                            StudentImportRow.school_id == job.school_id
                        )
                    ).order_by(StudentImportRow.row_number.asc()).limit(chunk_size)

                    res = await self.db.execute(stmt)
                    chunk_rows = list(res.scalars().all())

                    if not chunk_rows:
                        break

                    for row in chunk_rows:
                        try:
                            # Row-level nested transaction (savepoint)
                            async with self.db.begin_nested():
                                student_in = StudentCreate(
                                    school_id=row.school_id,
                                    academic_year_id=row.academic_year_id,
                                    class_id=row.class_id,
                                    section_id=row.section_id,
                                    first_name=row.first_name,
                                    middle_name=row.middle_name,
                                    last_name=row.last_name,
                                    gender=row.gender,
                                    date_of_birth=row.date_of_birth,
                                    blood_group=row.blood_group,
                                    aadhaar_number=row.aadhaar_number,
                                    emis_number=row.emis_number,
                                    mobile=row.mobile,
                                    email=row.email,
                                    photo_url=row.photo_url,
                                    address=row.address,
                                    medical_information=row.medical_information,
                                    admission_number=row.admission_number,
                                    roll_number=row.roll_number,
                                    admission_date=row.admission_date,
                                    status="ACTIVE"
                                )

                                student_obj = await student_service.create_student(
                                    tenant_id=tenant_id,
                                    obj_in=student_in,
                                    created_by=job.created_by
                                )

                                row.validation_status = "success"
                                row.created_student_id = student_obj.id

                                stmt_audit = select(ImportJobRow).where(
                                    and_(
                                        ImportJobRow.import_job_id == job_id,
                                        ImportJobRow.row_number == row.row_number
                                    )
                                )
                                res_audit = await self.db.execute(stmt_audit)
                                audit_row = res_audit.scalar_one_or_none()
                                if audit_row:
                                    audit_row.status = "success"
                                    audit_row.entity_id = student_obj.id
                                    audit_row.error_code = None
                                    audit_row.error_message = None
                                    self.db.add(audit_row)

                                total_valid_executed += 1

                        except Exception as e:
                            error_code = "EXECUTION_FAILED"
                            error_msg = str(e)

                            if isinstance(e, HTTPException):
                                error_msg = e.detail
                                if "already exists" in error_msg.lower() or "admission number" in error_msg.lower():
                                    error_code = "STUDENT_ALREADY_EXISTS"
                                elif "roll number" in error_msg.lower():
                                    error_code = "DUPLICATE_ROLL_NUMBER"
                                elif "aadhaar" in error_msg.lower():
                                    error_code = "AADHAAR_ALREADY_EXISTS"
                                elif "capacity" in error_msg.lower():
                                    error_code = "SECTION_CAPACITY_EXCEEDED"
                                elif "academic year" in error_msg.lower():
                                    error_code = "ACADEMIC_YEAR_NOT_FOUND"
                                elif "class" in error_msg.lower():
                                    error_code = "CLASS_NOT_FOUND"
                                elif "section" in error_msg.lower():
                                    error_code = "SECTION_NOT_FOUND"
                                else:
                                    error_code = "EXECUTION_FAILED"
                            else:
                                err_str = str(e).lower()
                                if "uq_students_aadhaar" in err_str:
                                    error_code = "AADHAAR_ALREADY_EXISTS"
                                    error_msg = "Student with this Aadhaar number is already registered."
                                elif "uq_students_admission_school" in err_str or "students_admission_number_key" in err_str:
                                    error_code = "STUDENT_ALREADY_EXISTS"
                                    error_msg = f"Student with admission number '{row.admission_number}' already exists in this school."
                                elif "uq_students_roll_section" in err_str:
                                    error_code = "DUPLICATE_ROLL_NUMBER"
                                    error_msg = f"Student with roll number '{row.roll_number}' already exists in this section."
                                else:
                                    error_code = "EXECUTION_FAILED"

                            row.validation_status = "failed_execution"
                            row.validation_error_code = error_code
                            row.validation_error_message = error_msg

                            stmt_audit = select(ImportJobRow).where(
                                and_(
                                    ImportJobRow.import_job_id == job_id,
                                    ImportJobRow.row_number == row.row_number
                                )
                            )
                            res_audit = await self.db.execute(stmt_audit)
                            audit_row = res_audit.scalar_one_or_none()
                            if audit_row:
                                audit_row.status = "failed"
                                audit_row.error_code = error_code
                                audit_row.error_message = error_msg
                                audit_row.entity_id = None
                                self.db.add(audit_row)

                            total_failed_executed += 1

                        self.db.add(row)

                    # Commit chunk
                    await original_commit()
            finally:
                self.db.commit = original_commit

            # Finalize job state and counters
            stmt_val_fail = select(func.count(StudentImportRow.id)).where(
                and_(
                    StudentImportRow.import_job_id == job_id,
                    StudentImportRow.validation_status == "invalid"
                )
            )
            res_val_fail = await self.db.execute(stmt_val_fail)
            val_fail_count = res_val_fail.scalar() or 0

            stmt_exec_success = select(func.count(StudentImportRow.id)).where(
                and_(
                    StudentImportRow.import_job_id == job_id,
                    StudentImportRow.validation_status == "success"
                )
            )
            res_exec_success = await self.db.execute(stmt_exec_success)
            exec_success_count = res_exec_success.scalar() or 0

            stmt_exec_fail = select(func.count(StudentImportRow.id)).where(
                and_(
                    StudentImportRow.import_job_id == job_id,
                    StudentImportRow.validation_status == "failed_execution"
                )
            )
            res_exec_fail = await self.db.execute(stmt_exec_fail)
            exec_fail_count = res_exec_fail.scalar() or 0

            # Reload job to prevent stale state issues
            job = await self.get_job_by_id(tenant_id, job_id)
            job.processed_rows = job.total_rows
            job.successful_rows = exec_success_count
            job.failed_rows = val_fail_count + exec_fail_count
            job.skipped_rows = 0

            if job.failed_rows > 0:
                job.status = ImportJobStatus.COMPLETED_WITH_ERRORS
            else:
                job.status = ImportJobStatus.COMPLETED

            job.completed_at = datetime.now(timezone.utc)
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)
            return job

        except Exception as ex:
            job = await self.get_job_by_id(tenant_id, job_id)
            job.status = ImportJobStatus.FAILED
            job.error_summary = str(ex)
            job.completed_at = datetime.now(timezone.utc)
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)
            raise ex

    async def execute_academic_setup_job(self, tenant_id: uuid.UUID, job_id: uuid.UUID, job: ImportJob) -> ImportJob:
        # Transition status to RUNNING
        job.status = ImportJobStatus.RUNNING
        job.started_at = datetime.now(timezone.utc)
        self.db.add(job)
        await self.db.commit()

        # Initialize repositories and services
        from app.repositories.academic_year import AcademicYearRepository
        from app.repositories.class_entity import ClassRepository
        from app.repositories.section import SectionRepository
        from app.services.academic_year import AcademicYearService
        from app.services.class_entity import ClassService
        from app.services.section import SectionService
        from app.schemas.academic_year import AcademicYearCreate
        from app.schemas.class_entity import ClassCreate
        from app.schemas.section import SectionCreate
        from app.models.academic_year import AcademicYearStatus

        ay_repo = AcademicYearRepository(self.db)
        class_repo = ClassRepository(self.db)
        section_repo = SectionRepository(self.db)

        ay_service = AcademicYearService(ay_repo)
        class_service = ClassService(class_repo=class_repo, ay_repo=ay_repo)
        section_service = SectionService(section_repo=section_repo, ay_repo=ay_repo, class_repo=class_repo)

        # Mock commit to avoid closing nested transactions
        original_commit = self.db.commit
        async def mock_commit():
            await self.db.flush()
        self.db.commit = mock_commit

        try:
            try:
                chunk_size = 100
                total_valid_executed = 0
                total_failed_executed = 0

                from app.models.academic_setup_import import AcademicSetupImportRow

                while True:
                    # Fetch next chunk of valid rows
                    stmt = select(AcademicSetupImportRow).where(
                        and_(
                            AcademicSetupImportRow.import_job_id == job_id,
                            AcademicSetupImportRow.validation_status == "valid",
                            AcademicSetupImportRow.tenant_id == tenant_id,
                            AcademicSetupImportRow.school_id == job.school_id
                        )
                    ).order_by(AcademicSetupImportRow.row_number.asc()).limit(chunk_size)

                    res = await self.db.execute(stmt)
                    chunk_rows = list(res.scalars().all())

                    if not chunk_rows:
                        break

                    for row in chunk_rows:
                        resolved_ay_id = None
                        resolved_class_id = None
                        resolved_section_id = None

                        try:
                            # Row-level nested transaction (savepoint)
                            async with self.db.begin_nested():
                                # 1. Resolve or Create Academic Year
                                if row.academic_year_id:
                                    stmt_ay = select(AcademicYear).where(
                                        and_(
                                            AcademicYear.id == row.academic_year_id,
                                            AcademicYear.school_id == job.school_id,
                                            AcademicYear.tenant_id == tenant_id,
                                            AcademicYear.deleted_at.is_(None)
                                        )
                                    )
                                    res_ay = await self.db.execute(stmt_ay)
                                    existing_ay = res_ay.scalar_one_or_none()
                                    if existing_ay:
                                        resolved_ay_id = existing_ay.id

                                if not resolved_ay_id:
                                    stmt_ay = select(AcademicYear).where(
                                        and_(
                                            AcademicYear.code == row.academic_year_code,
                                            AcademicYear.school_id == job.school_id,
                                            AcademicYear.tenant_id == tenant_id,
                                            AcademicYear.deleted_at.is_(None)
                                        )
                                    )
                                    res_ay = await self.db.execute(stmt_ay)
                                    existing_ay = res_ay.scalar_one_or_none()
                                    if existing_ay:
                                        resolved_ay_id = existing_ay.id
                                    else:
                                        ay_in = AcademicYearCreate(
                                            name=row.academic_year_name,
                                            code=row.academic_year_code,
                                            start_date=row.start_date,
                                            end_date=row.end_date,
                                            status=AcademicYearStatus.UPCOMING,
                                            is_current=False,
                                            settings={}
                                        )
                                        ay_obj = await ay_service.create_academic_year(
                                            tenant_id=tenant_id,
                                            school_id=job.school_id,
                                            obj_in=ay_in,
                                            created_by=job.created_by
                                        )
                                        resolved_ay_id = ay_obj.id

                                # 2. Resolve or Create Class under resolved Academic Year
                                if row.class_id:
                                    stmt_cls = select(Class).where(
                                        and_(
                                            Class.id == row.class_id,
                                            Class.academic_year_id == resolved_ay_id,
                                            Class.school_id == job.school_id,
                                            Class.tenant_id == tenant_id,
                                            Class.deleted_at.is_(None)
                                        )
                                    )
                                    res_cls = await self.db.execute(stmt_cls)
                                    existing_cls = res_cls.scalar_one_or_none()
                                    if existing_cls:
                                        resolved_class_id = existing_cls.id

                                if not resolved_class_id:
                                    stmt_cls = select(Class).where(
                                        and_(
                                            Class.code == row.class_code,
                                            Class.academic_year_id == resolved_ay_id,
                                            Class.school_id == job.school_id,
                                            Class.tenant_id == tenant_id,
                                            Class.deleted_at.is_(None)
                                        )
                                    )
                                    res_cls = await self.db.execute(stmt_cls)
                                    existing_cls = res_cls.scalar_one_or_none()
                                    if existing_cls:
                                        resolved_class_id = existing_cls.id
                                    else:
                                        cls_in = ClassCreate(
                                            school_id=job.school_id,
                                            academic_year_id=resolved_ay_id,
                                            name=row.class_name,
                                            code=row.class_code,
                                            level=row.class_level,
                                            category=row.class_category,
                                            capacity=row.class_capacity,
                                            settings={},
                                            ai_metrics={}
                                        )
                                        cls_obj = await class_service.create_class(
                                            tenant_id=tenant_id,
                                            obj_in=cls_in,
                                            created_by=job.created_by
                                        )
                                        resolved_class_id = cls_obj.id

                                # 3. Resolve or Create Section under resolved Class
                                if row.section_id:
                                    stmt_sec = select(Section).where(
                                        and_(
                                            Section.id == row.section_id,
                                            Section.class_id == resolved_class_id,
                                            Section.school_id == job.school_id,
                                            Section.tenant_id == tenant_id,
                                            Section.deleted_at.is_(None)
                                        )
                                    )
                                    res_sec = await self.db.execute(stmt_sec)
                                    existing_sec = res_sec.scalar_one_or_none()
                                    if existing_sec:
                                        resolved_section_id = existing_sec.id

                                if not resolved_section_id:
                                    stmt_sec = select(Section).where(
                                        and_(
                                            Section.code == row.section_code,
                                            Section.class_id == resolved_class_id,
                                            Section.school_id == job.school_id,
                                            Section.tenant_id == tenant_id,
                                            Section.deleted_at.is_(None)
                                        )
                                    )
                                    res_sec = await self.db.execute(stmt_sec)
                                    existing_sec = res_sec.scalar_one_or_none()
                                    if existing_sec:
                                        resolved_section_id = existing_sec.id
                                    else:
                                        sec_in = SectionCreate(
                                            school_id=job.school_id,
                                            academic_year_id=resolved_ay_id,
                                            class_id=resolved_class_id,
                                            name=row.section_name,
                                            code=row.section_code,
                                            capacity=row.section_capacity,
                                            settings={},
                                            ai_metrics={}
                                        )
                                        sec_obj = await section_service.create_section(
                                            tenant_id=tenant_id,
                                            obj_in=sec_in,
                                            created_by=job.created_by
                                        )
                                        resolved_section_id = sec_obj.id

                                row.validation_status = "executed"
                                row.created_academic_year_id = resolved_ay_id
                                row.created_class_id = resolved_class_id
                                row.created_section_id = resolved_section_id
                                self.db.add(row)

                                stmt_audit = select(ImportJobRow).where(
                                    and_(
                                        ImportJobRow.import_job_id == job_id,
                                        ImportJobRow.row_number == row.row_number
                                    )
                                )
                                res_audit = await self.db.execute(stmt_audit)
                                audit_row = res_audit.scalar_one_or_none()
                                if audit_row:
                                    audit_row.status = "success"
                                    audit_row.entity_id = resolved_section_id
                                    audit_row.error_code = None
                                    audit_row.error_message = None
                                    self.db.add(audit_row)

                                total_valid_executed += 1

                        except Exception as e:
                            error_code = "ACADEMIC_SETUP_EXECUTION_ERROR"
                            error_msg = str(e)
                            if isinstance(e, HTTPException):
                                error_msg = e.detail

                            if not resolved_ay_id:
                                error_code = "ACADEMIC_YEAR_CREATION_FAILED"
                            elif not resolved_class_id:
                                error_code = "CLASS_CREATION_FAILED"
                            else:
                                error_code = "SECTION_CREATION_FAILED"

                            row.validation_status = "failed_execution"
                            row.validation_error_code = error_code
                            row.validation_error_message = error_msg
                            row.created_academic_year_id = None
                            row.created_class_id = None
                            row.created_section_id = None
                            self.db.add(row)

                            stmt_audit = select(ImportJobRow).where(
                                and_(
                                    ImportJobRow.import_job_id == job_id,
                                    ImportJobRow.row_number == row.row_number
                                )
                            )
                            res_audit = await self.db.execute(stmt_audit)
                            audit_row = res_audit.scalar_one_or_none()
                            if audit_row:
                                audit_row.status = "failed"
                                audit_row.error_code = error_code
                                audit_row.error_message = error_msg
                                audit_row.entity_id = None
                                self.db.add(audit_row)

                            total_failed_executed += 1

                    # Commit chunk
                    await original_commit()

            finally:
                self.db.commit = original_commit

            # Finalize counters
            stmt_val_fail = select(func.count(AcademicSetupImportRow.id)).where(
                and_(
                    AcademicSetupImportRow.import_job_id == job_id,
                    AcademicSetupImportRow.validation_status == "invalid"
                )
            )
            res_val_fail = await self.db.execute(stmt_val_fail)
            val_fail_count = res_val_fail.scalar() or 0

            stmt_exec_success = select(func.count(AcademicSetupImportRow.id)).where(
                and_(
                    AcademicSetupImportRow.import_job_id == job_id,
                    AcademicSetupImportRow.validation_status == "executed"
                )
            )
            res_exec_success = await self.db.execute(stmt_exec_success)
            exec_success_count = res_exec_success.scalar() or 0

            stmt_exec_fail = select(func.count(AcademicSetupImportRow.id)).where(
                and_(
                    AcademicSetupImportRow.import_job_id == job_id,
                    AcademicSetupImportRow.validation_status == "failed_execution"
                )
            )
            res_exec_fail = await self.db.execute(stmt_exec_fail)
            exec_fail_count = res_exec_fail.scalar() or 0

            job = await self.get_job_by_id(tenant_id, job_id)
            job.processed_rows = exec_success_count + exec_fail_count
            job.successful_rows = exec_success_count
            job.failed_rows = exec_fail_count
            job.skipped_rows = val_fail_count

            if exec_fail_count > 0:
                job.status = ImportJobStatus.COMPLETED_WITH_ERRORS
            else:
                job.status = ImportJobStatus.COMPLETED

            job.completed_at = datetime.now(timezone.utc)
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)
            return job

        except Exception as ex:
            job = await self.get_job_by_id(tenant_id, job_id)
            job.status = ImportJobStatus.FAILED
            job.error_summary = str(ex)
            job.completed_at = datetime.now(timezone.utc)
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)
            raise ex

    async def cancel_job(self, tenant_id: uuid.UUID, job_id: uuid.UUID) -> ImportJob:
        job = await self.get_job_by_id(tenant_id, job_id)
        if not job:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Import job not found."
            )

        # Terminal state protection
        if job.status in [
            ImportJobStatus.COMPLETED,
            ImportJobStatus.COMPLETED_WITH_ERRORS,
            ImportJobStatus.FAILED,
            ImportJobStatus.CANCELLED
        ]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot cancel job. Import job is already in a terminal state '{job.status}'."
            )

        job.status = ImportJobStatus.CANCELLED
        job.completed_at = datetime.now(timezone.utc)
        self.db.add(job)
        await self.db.commit()
        await self.db.refresh(job)
        return job

    async def update_status(self, tenant_id: uuid.UUID, job_id: uuid.UUID, new_status: ImportJobStatus, error_summary: Optional[str] = None) -> ImportJob:
        job = await self.get_job_by_id(tenant_id, job_id)
        if not job:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Import job not found."
            )

        # State transition validation mapping
        VALID_TRANSITIONS = {
            ImportJobStatus.DRAFT: {ImportJobStatus.VALIDATING, ImportJobStatus.CANCELLED},
            ImportJobStatus.VALIDATING: {ImportJobStatus.VALIDATED, ImportJobStatus.FAILED, ImportJobStatus.CANCELLED},
            ImportJobStatus.VALIDATED: {ImportJobStatus.RUNNING, ImportJobStatus.CANCELLED},
            ImportJobStatus.RUNNING: {ImportJobStatus.COMPLETED, ImportJobStatus.COMPLETED_WITH_ERRORS, ImportJobStatus.FAILED, ImportJobStatus.CANCELLED},
            ImportJobStatus.COMPLETED: set(),
            ImportJobStatus.COMPLETED_WITH_ERRORS: set(),
            ImportJobStatus.FAILED: set(),
            ImportJobStatus.CANCELLED: set(),
        }

        if new_status not in VALID_TRANSITIONS[job.status]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid transition from state '{job.status}' to '{new_status}'."
            )

        job.status = new_status
        if new_status in [ImportJobStatus.COMPLETED, ImportJobStatus.COMPLETED_WITH_ERRORS, ImportJobStatus.FAILED]:
            job.completed_at = datetime.now(timezone.utc)
            if error_summary:
                job.error_summary = error_summary
        
        self.db.add(job)
        await self.db.commit()
        await self.db.refresh(job)
        return job

    async def validate_student_job(
        self,
        tenant_id: uuid.UUID,
        job_id: uuid.UUID,
        file_content: bytes,
        sheet_name: Optional[str] = None
    ) -> ImportJob:
        job = await self.get_job_by_id(tenant_id, job_id)
        if not job:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Import job not found."
            )

        if job.status != ImportJobStatus.DRAFT:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot validate job in status '{job.status}'. Expected DRAFT."
            )

        if job.import_type != ImportType.STUDENTS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Validation logic only implemented for STUDENTS, current job is '{job.import_type}'."
            )

        # Transition state DRAFT -> VALIDATING
        job = await self.update_status(tenant_id, job_id, ImportJobStatus.VALIDATING)

        try:
            # 1. Save source file to GCS
            ext = os.path.splitext(job.source_filename)[1].lower() if job.source_filename else ".csv"
            gcs_path = f"imports/{job.import_type.value}/{job_id}{ext}"
            await self.storage_service.upload(file_content, gcs_path, "application/octet-stream")

            # Update job metadata with GCS path
            job_metadata = dict(job.job_metadata or {})
            job_metadata["source_file_path"] = gcs_path

            # 2. Parse Spreadsheet/CSV
            from app.utils.spreadsheet_reader import read_spreadsheet, normalize_header
            sheets, selected_sheet, rows = read_spreadsheet(file_content, job.source_filename, sheet_name=sheet_name)

            job_metadata["sheets"] = sheets
            job_metadata["selected_sheet"] = selected_sheet
            job.job_metadata = job_metadata
            self.db.add(job)
            await self.db.commit()

            # 3. Normalize headers
            headers = [normalize_header(h) for h in rows[0]] if rows else []

            # Required fields validation
            required_cols = [
                "first_name",
                "last_name",
                "gender",
                "date_of_birth",
                "admission_number",
                "roll_number",
                "admission_date"
            ]
            missing_cols = [col for col in required_cols if col not in headers]
            if missing_cols:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Missing required CSV column headers: {', '.join(missing_cols)}"
                )

            if not rows or len(rows) <= 1:
                # No data rows (only header or empty)
                job.total_rows = 0
                job = await self.update_status(tenant_id, job_id, ImportJobStatus.VALIDATED)
                return job

            # Resolve default/fallback academic year from metadata context if specified, otherwise ACTIVE year
            fallback_ay = None
            metadata_ay_id = job.job_metadata.get("academic_year_id") if job.job_metadata else None
            if metadata_ay_id:
                try:
                    ay_uuid = uuid.UUID(str(metadata_ay_id))
                    stmt_ay_meta = select(AcademicYear).where(
                        and_(
                            AcademicYear.id == ay_uuid,
                            AcademicYear.school_id == job.school_id,
                            AcademicYear.tenant_id == tenant_id,
                            AcademicYear.deleted_at.is_(None)
                        )
                    )
                    res_ay_meta = await self.db.execute(stmt_ay_meta)
                    fallback_ay = res_ay_meta.scalar_one_or_none()
                except ValueError:
                    pass

            if not fallback_ay:
                stmt_ay = select(AcademicYear).where(
                    and_(
                        AcademicYear.school_id == job.school_id,
                        AcademicYear.tenant_id == tenant_id,
                        AcademicYear.status == "ACTIVE"
                    )
                )
                res_ay = await self.db.execute(stmt_ay)
                fallback_ay = res_ay.scalar_one_or_none()

            # Track duplicates inside CSV
            seen_admissions = set()
            seen_rolls = set()  # (section_id, roll_number)

            total_valid = 0
            total_failed = 0

            today = date.today()

            for idx in range(1, len(rows)):
                raw_row = rows[idx]
                # Skip blank rows
                if not raw_row or all(cell.strip() == "" for cell in raw_row):
                    continue

                # Map headers to row cells
                row_data = {}
                for col_idx, h in enumerate(headers):
                    if col_idx < len(raw_row):
                        row_data[h] = raw_row[col_idx].strip()
                    else:
                        row_data[h] = ""

                # Initialize error variables
                error_code = None
                error_msg = None

                # Staging columns extraction
                first_name = row_data.get("first_name", "")
                last_name = row_data.get("last_name", "")
                gender = row_data.get("gender", "")
                dob_str = row_data.get("date_of_birth", "")
                adm_no = row_data.get("admission_number", "")
                roll_no = row_data.get("roll_number", "")
                adm_date_str = row_data.get("admission_date", "")

                middle_name = row_data.get("middle_name", None) or None
                blood_group = row_data.get("blood_group", None) or None
                aadhaar_number = row_data.get("aadhaar_number", None) or None
                emis_number = row_data.get("emis_number", None) or None
                mobile = row_data.get("mobile", None) or None
                email = row_data.get("email", None) or None
                photo_url = row_data.get("photo_url", None) or None

                # 1. Check missing mandatory fields
                if not first_name or not last_name or not gender or not dob_str or not adm_no or not roll_no or not adm_date_str:
                    error_code = "MISSING_REQUIRED_FIELD"
                    error_msg = "One or more required fields are empty."
                
                # 2. Check invalid gender
                if not error_code:
                    gender_upper = gender.upper()
                    if gender_upper not in ["MALE", "FEMALE", "OTHER"]:
                        error_code = "INVALID_GENDER"
                        error_msg = f"Gender '{gender}' must be MALE, FEMALE, or OTHER."
                    else:
                        gender = gender_upper

                # 3. Check invalid date formats
                dob = None
                adm_date = None
                if not error_code:
                    try:
                        dob = date.fromisoformat(dob_str)
                    except ValueError:
                        error_code = "INVALID_DATE"
                        error_msg = f"date_of_birth '{dob_str}' is not in YYYY-MM-DD format."

                if not error_code:
                    try:
                        adm_date = date.fromisoformat(adm_date_str)
                    except ValueError:
                        error_code = "INVALID_DATE"
                        error_msg = f"admission_date '{adm_date_str}' is not in YYYY-MM-DD format."

                # 4. Check date bounds
                if not error_code:
                    if dob >= today:
                        error_code = "INVALID_DATE"
                        error_msg = f"date_of_birth '{dob_str}' must be in the past."
                    elif adm_date > today:
                        error_code = "INVALID_DATE"
                        error_msg = f"admission_date '{adm_date_str}' cannot be in the future."

                # 5. Resolve academic year
                ay = None
                if not error_code:
                    csv_ay_id = row_data.get("academic_year_id", "")
                    if csv_ay_id:
                        try:
                            ay_uuid = uuid.UUID(csv_ay_id)
                            stmt_ay_chk = select(AcademicYear).where(
                                and_(
                                    AcademicYear.id == ay_uuid,
                                    AcademicYear.school_id == job.school_id,
                                    AcademicYear.tenant_id == tenant_id,
                                    AcademicYear.deleted_at.is_(None)
                                )
                            )
                            res_ay_chk = await self.db.execute(stmt_ay_chk)
                            ay = res_ay_chk.scalar_one_or_none()
                        except ValueError:
                            pass
                    else:
                        ay = fallback_ay

                    if not ay:
                        error_code = "ACADEMIC_YEAR_NOT_FOUND"
                        error_msg = "Academic year not found or school mismatch."
                    elif ay.status == "ARCHIVED":
                        error_code = "ACADEMIC_YEAR_NOT_FOUND"
                        error_msg = "Cannot register students in an archived academic year."

                # 6. Resolve class
                cls_obj = None
                if not error_code:
                    csv_class_id = row_data.get("class_id", "")
                    csv_class_code = row_data.get("class_code", "")
                    csv_class_name = row_data.get("class_name", "")

                    resolved_classes = []
                    if csv_class_id:
                        try:
                            class_uuid = uuid.UUID(csv_class_id)
                            stmt_cls = select(Class).where(
                                and_(
                                    Class.id == class_uuid,
                                    Class.school_id == job.school_id,
                                    Class.tenant_id == tenant_id,
                                    Class.deleted_at.is_(None)
                                )
                            )
                            res_cls = await self.db.execute(stmt_cls)
                            c = res_cls.scalar_one_or_none()
                            resolved_classes.append(c)
                        except ValueError:
                            resolved_classes.append(None)
                    
                    if csv_class_code:
                        stmt_cls = select(Class).where(
                            and_(
                                Class.code == csv_class_code,
                                Class.school_id == job.school_id,
                                Class.tenant_id == tenant_id,
                                Class.academic_year_id == ay.id,
                                Class.deleted_at.is_(None)
                            )
                        )
                        res_cls = await self.db.execute(stmt_cls)
                        c = res_cls.scalar_one_or_none()
                        resolved_classes.append(c)
                    
                    if csv_class_name:
                        stmt_cls = select(Class).where(
                            and_(
                                Class.name == csv_class_name,
                                Class.school_id == job.school_id,
                                Class.tenant_id == tenant_id,
                                Class.academic_year_id == ay.id,
                                Class.deleted_at.is_(None)
                            )
                        )
                        res_cls = await self.db.execute(stmt_cls)
                        c = res_cls.scalar_one_or_none()
                        resolved_classes.append(c)

                    if not resolved_classes:
                        error_code = "CLASS_NOT_FOUND"
                        error_msg = "Class not found or school mismatch."
                    elif all(c is None for c in resolved_classes):
                        error_code = "CLASS_NOT_FOUND"
                        error_msg = "Class not found or school mismatch."
                    elif any(c is None for c in resolved_classes):
                        error_code = "CLASS_SECTION_MISMATCH"
                        error_msg = "Supplied class identifiers resolve to different class entities."
                    else:
                        first_id = resolved_classes[0].id
                        if any(c.id != first_id for c in resolved_classes):
                            error_code = "CLASS_SECTION_MISMATCH"
                            error_msg = "Supplied class identifiers resolve to different class entities."
                        else:
                            cls_obj = resolved_classes[0]

                    if not error_code and cls_obj and cls_obj.academic_year_id != ay.id:
                        error_code = "CLASS_SECTION_MISMATCH"
                        error_msg = "Target class does not belong to specified academic year."

                # 7. Resolve section
                sec_obj = None
                if not error_code:
                    csv_sec_id = row_data.get("section_id", "")
                    csv_sec_code = row_data.get("section_code", "")
                    csv_sec_name = row_data.get("section_name", "")

                    resolved_sections = []
                    if csv_sec_id:
                        try:
                            sec_uuid = uuid.UUID(csv_sec_id)
                            stmt_sec = select(Section).where(
                                and_(
                                    Section.id == sec_uuid,
                                    Section.school_id == job.school_id,
                                    Section.tenant_id == tenant_id,
                                    Section.deleted_at.is_(None)
                                )
                            )
                            res_sec = await self.db.execute(stmt_sec)
                            s = res_sec.scalar_one_or_none()
                            resolved_sections.append(s)
                        except ValueError:
                            resolved_sections.append(None)
                    
                    if csv_sec_code:
                        stmt_sec = select(Section).where(
                            and_(
                                Section.code == csv_sec_code,
                                Section.school_id == job.school_id,
                                Section.tenant_id == tenant_id,
                                Section.class_id == cls_obj.id,
                                Section.deleted_at.is_(None)
                            )
                        )
                        res_sec = await self.db.execute(stmt_sec)
                        s = res_sec.scalar_one_or_none()
                        resolved_sections.append(s)
                    
                    if csv_sec_name:
                        stmt_sec = select(Section).where(
                            and_(
                                Section.name == csv_sec_name,
                                Section.school_id == job.school_id,
                                Section.tenant_id == tenant_id,
                                Section.class_id == cls_obj.id,
                                Section.deleted_at.is_(None)
                            )
                        )
                        res_sec = await self.db.execute(stmt_sec)
                        s = res_sec.scalar_one_or_none()
                        resolved_sections.append(s)

                    if not resolved_sections:
                        error_code = "SECTION_NOT_FOUND"
                        error_msg = "Section not found or school mismatch."
                    elif all(s is None for s in resolved_sections):
                        error_code = "SECTION_NOT_FOUND"
                        error_msg = "Section not found or school mismatch."
                    elif any(s is None for s in resolved_sections):
                        error_code = "CLASS_SECTION_MISMATCH"
                        error_msg = "Supplied section identifiers resolve to different section entities."
                    else:
                        first_id = resolved_sections[0].id
                        if any(s.id != first_id for s in resolved_sections):
                            error_code = "CLASS_SECTION_MISMATCH"
                            error_msg = "Supplied section identifiers resolve to different section entities."
                        else:
                            sec_obj = resolved_sections[0]

                    if not error_code and sec_obj and sec_obj.class_id != cls_obj.id:
                        error_code = "CLASS_SECTION_MISMATCH"
                        error_msg = "Target section does not belong to specified class."

                # 8. Check duplicate admission numbers inside the same CSV
                if not error_code:
                    if adm_no in seen_admissions:
                        error_code = "DUPLICATE_ADMISSION_NUMBER"
                        error_msg = f"Duplicate admission_number '{adm_no}' within this CSV."
                    else:
                        seen_admissions.add(adm_no)

                # 9. Check duplicate roll numbers inside the same CSV/section context
                if not error_code:
                    roll_sec_key = (sec_obj.id, roll_no)
                    if roll_sec_key in seen_rolls:
                        error_code = "DUPLICATE_ROLL_NUMBER"
                        error_msg = f"Duplicate roll_number '{roll_no}' in this section within this CSV."
                    else:
                        seen_rolls.add(roll_sec_key)

                # 10. Check active student conflicts (DB)
                if not error_code:
                    stmt_stud = select(Student).where(
                        and_(
                            Student.school_id == job.school_id,
                            Student.tenant_id == tenant_id,
                            Student.admission_number == adm_no,
                            Student.deleted_at.is_(None)
                        )
                    )
                    res_stud = await self.db.execute(stmt_stud)
                    active_stud = res_stud.scalar_one_or_none()
                    if active_stud:
                        error_code = "STUDENT_ALREADY_EXISTS"
                        error_msg = f"Student with admission number '{adm_no}' already exists in this school."

                # 11. Check soft-deleted student conflicts (DB)
                if not error_code:
                    stmt_stud_del = select(Student).where(
                        and_(
                            Student.school_id == job.school_id,
                            Student.tenant_id == tenant_id,
                            Student.admission_number == adm_no,
                            Student.deleted_at.isnot(None)
                        )
                    )
                    res_stud_del = await self.db.execute(stmt_stud_del)
                    deleted_stud = res_stud_del.scalar_one_or_none()
                    if deleted_stud:
                        error_code = "SOFT_DELETED_STUDENT_CONFLICT"
                        error_msg = f"A soft-deleted student with admission number '{adm_no}' exists."

                # 12. Check global Aadhaar conflict (DB)
                if not error_code and aadhaar_number:
                    # uq_students_aadhaar is globally unique
                    stmt_aadhaar = select(Student).where(
                        and_(
                            Student.aadhaar_number == aadhaar_number
                        )
                    )
                    res_aadhaar = await self.db.execute(stmt_aadhaar)
                    aadhaar_stud = res_aadhaar.scalar_one_or_none()
                    if aadhaar_stud:
                        error_code = "AADHAAR_ALREADY_EXISTS"
                        error_msg = f"Student with this Aadhaar number is already registered."

                # 13. Check section capacity
                if not error_code:
                    stmt_cap = select(func.count(Student.id)).where(
                        and_(
                            Student.section_id == sec_obj.id,
                            Student.deleted_at.is_(None)
                        )
                    )
                    res_cap = await self.db.execute(stmt_cap)
                    active_count = res_cap.scalar() or 0
                    
                    # Count how many successfully resolved valid rows are staging in this section so far
                    csv_sec_active = sum(1 for (s_id, _) in seen_rolls if s_id == sec_obj.id)
                    
                    if active_count + csv_sec_active > sec_obj.capacity:
                        error_code = "SECTION_CAPACITY_EXCEEDED"
                        error_msg = "Cannot register student because target section capacity has been reached."

                # Write Staging Row
                stg_row = StudentImportRow(
                    tenant_id=tenant_id,
                    import_job_id=job_id,
                    row_number=idx,
                    first_name=first_name,
                    middle_name=middle_name,
                    last_name=last_name,
                    gender=gender,
                    date_of_birth=dob or date(1900, 1, 1),
                    blood_group=blood_group,
                    aadhaar_number=aadhaar_number,
                    emis_number=emis_number,
                    mobile=mobile,
                    email=email,
                    photo_url=photo_url,
                    address={"line": row_data.get("address", "")} if row_data.get("address", "") else {},
                    medical_information={},
                    admission_number=adm_no,
                    roll_number=roll_no,
                    admission_date=adm_date or date(1900, 1, 1),
                    status="ACTIVE",
                    school_id=job.school_id,
                    academic_year_id=ay.id if ay else None,
                    class_id=cls_obj.id if cls_obj else None,
                    section_id=sec_obj.id if sec_obj else None,
                    validation_status="invalid" if error_code else "valid",
                    validation_error_code=error_code,
                    validation_error_message=error_msg
                )
                self.db.add(stg_row)

                # Write Audit Row
                audit_row = ImportJobRow(
                    import_job_id=job_id,
                    row_number=idx,
                    status="failed" if error_code else "success",
                    error_code=error_code,
                    error_message=error_msg,
                    source_identifier=adm_no or None,
                    row_metadata={}
                )
                self.db.add(audit_row)

                if error_code:
                    total_failed += 1
                else:
                    total_valid += 1

            # Update Job Counters
            job.total_rows = len(rows) - 1
            job.processed_rows = total_valid + total_failed
            job.successful_rows = total_valid
            job.failed_rows = total_failed

            # Shift state VALIDATING -> VALIDATED
            job.status = ImportJobStatus.VALIDATED
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)
            return job

        except Exception as ex:
            job.status = ImportJobStatus.FAILED
            job.error_summary = str(ex)
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)
            raise ex

    async def create_row_results(self, tenant_id: uuid.UUID, job_id: uuid.UUID, rows: List[ImportJobRowCreate]) -> List[ImportJobRow]:
        job = await self.get_job_by_id(tenant_id, job_id)
        if not job:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Import job not found."
            )

        # Allow row results writing only if job is in active processing state
        if job.status not in [ImportJobStatus.VALIDATING, ImportJobStatus.RUNNING]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot add row results. Import job is not in a writeable state (current: '{job.status}')."
            )

        db_rows = []
        successes = 0
        failures = 0
        skipped = 0

        for r in rows:
            # Check for existing row index to enforce uniqueness per job
            stmt_row_exist = select(ImportJobRow).where(
                and_(
                    ImportJobRow.import_job_id == job_id,
                    ImportJobRow.row_number == r.row_number
                )
            )
            res_row_exist = await self.db.execute(stmt_row_exist)
            exist_row = res_row_exist.scalar_one_or_none()
            if exist_row:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Row result at index {r.row_number} has already been reported for job {job_id}."
                )

            status_str = r.status.lower()
            if status_str == "success":
                successes += 1
            elif status_str == "failed":
                failures += 1
            elif status_str == "skipped":
                skipped += 1

            db_row = ImportJobRow(
                import_job_id=job_id,
                row_number=r.row_number,
                status=r.status,
                error_code=r.error_code,
                error_message=r.error_message,
                source_identifier=r.source_identifier,
                entity_id=r.entity_id,
                row_metadata=r.row_metadata
            )
            self.db.add(db_row)
            db_rows.append(db_row)

        # Update stats
        job.processed_rows += len(rows)
        job.successful_rows += successes
        job.failed_rows += failures
        job.skipped_rows += skipped

        self.db.add(job)
        await self.db.commit()
        
        # Refresh and return
        for db_row in db_rows:
            await self.db.refresh(db_row)
        return db_rows

    async def get_row_results(
        self,
        tenant_id: uuid.UUID,
        job_id: uuid.UUID,
        skip: int = 0,
        limit: int = 100
    ) -> List[ImportJobRow]:
        job = await self.get_job_by_id(tenant_id, job_id)
        if not job:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Import job not found."
            )

        stmt = select(ImportJobRow).where(
            ImportJobRow.import_job_id == job_id
        ).order_by(ImportJobRow.row_number.asc()).offset(skip).limit(limit)
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def validate_job(
        self,
        tenant_id: uuid.UUID,
        job_id: uuid.UUID,
        file_content: bytes,
        sheet_name: Optional[str] = None
    ) -> ImportJob:
        job = await self.get_job_by_id(tenant_id, job_id)
        if not job:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Import job not found."
            )

        if job.import_type == ImportType.STUDENTS:
            return await self.validate_student_job(tenant_id, job_id, file_content, sheet_name=sheet_name)
        elif job.import_type == ImportType.ACADEMIC_SETUP:
            return await self.validate_academic_setup_job(tenant_id, job_id, file_content, job=job, sheet_name=sheet_name)
        elif job.import_type == ImportType.GUARDIANS:
            return await self.validate_guardian_job(tenant_id, job_id, file_content, job=job, sheet_name=sheet_name)
        elif job.import_type == ImportType.GUARDIAN_MAPPING:
            return await self.validate_guardian_mapping_job(tenant_id, job_id, file_content, job=job, sheet_name=sheet_name)
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Validation logic is not implemented for {job.import_type}."
            )

    async def validate_academic_setup_job(
        self,
        tenant_id: uuid.UUID,
        job_id: uuid.UUID,
        file_content: bytes,
        job: Optional[ImportJob] = None,
        sheet_name: Optional[str] = None
    ) -> ImportJob:
        import re
        if not job:
            job = await self.get_job_by_id(tenant_id, job_id)
            if not job:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Import job not found."
                )

        if job.status != ImportJobStatus.DRAFT:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot validate job in status '{job.status}'. Expected DRAFT."
            )

        # Transition status to VALIDATING
        job = await self.update_status(tenant_id, job_id, ImportJobStatus.VALIDATING)

        try:
            # 1. Save source file to GCS
            ext = os.path.splitext(job.source_filename)[1].lower() if job.source_filename else ".csv"
            gcs_path = f"imports/{job.import_type.value}/{job_id}{ext}"
            await self.storage_service.upload(file_content, gcs_path, "application/octet-stream")

            # Update job metadata with GCS path
            job_metadata = dict(job.job_metadata or {})
            job_metadata["source_file_path"] = gcs_path

            # 2. Parse Spreadsheet/CSV
            from app.utils.spreadsheet_reader import read_spreadsheet, normalize_header
            sheets, selected_sheet, rows = read_spreadsheet(file_content, job.source_filename, sheet_name=sheet_name)

            job_metadata["sheets"] = sheets
            job_metadata["selected_sheet"] = selected_sheet
            job.job_metadata = job_metadata
            self.db.add(job)
            await self.db.commit()

            if not rows or len(rows) <= 1:
                # No data rows (only header or empty)
                job.total_rows = 0
                job.processed_rows = 0
                job.successful_rows = 0
                job.failed_rows = 0
                job.skipped_rows = 0
                job = await self.update_status(tenant_id, job_id, ImportJobStatus.VALIDATED)
                return job

            # 3. Normalize headers
            headers = [normalize_header(h) for h in rows[0]]

            # Required fields validation
            required_cols = [
                "academic_year_name",
                "academic_year_code",
                "start_date",
                "end_date",
                "class_name",
                "class_code",
                "class_level",
                "class_capacity",
                "section_name",
                "section_code",
                "section_capacity"
            ]
            missing_cols = [col for col in required_cols if col not in headers]
            if missing_cols:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Missing required CSV column headers: {', '.join(missing_cols)}"
                )

            # Remove existing staging rows for this job if any (should not exist in DRAFT, but safe)
            await self.db.execute(
                text("DELETE FROM academic_setup_import_rows WHERE import_job_id = :job_id").bindparams(job_id=job_id)
            )
            # Remove existing audit rows for this job if any
            await self.db.execute(
                text("DELETE FROM import_job_rows WHERE import_job_id = :job_id").bindparams(job_id=job_id)
            )
            await self.db.commit()

            total_rows_count = 0
            failed_rows_count = 0

            # Keep track of unique exact leaf hierarchies inside the CSV to identify duplicate rows
            # Key: (academic_year_code, class_code, section_code)
            seen_leaves = set()

            from app.models.academic_setup_import import AcademicSetupImportRow

            # Process rows one by one
            for index, row in enumerate(rows[1:], start=1):
                # Skip blank/empty rows
                if not row or all(cell.strip() == "" for cell in row):
                    continue

                total_rows_count += 1

                row_data = {}
                for col_idx, header in enumerate(headers):
                    if col_idx < len(row):
                        row_data[header] = row[col_idx].strip()
                    else:
                        row_data[header] = ""

                # Initialize staging record variables
                ay_name = row_data.get("academic_year_name", "")
                ay_code = row_data.get("academic_year_code", "")
                ay_start_str = row_data.get("start_date", "")
                ay_end_str = row_data.get("end_date", "")

                cls_name = row_data.get("class_name", "")
                cls_code = row_data.get("class_code", "")
                cls_level_str = row_data.get("class_level", "")
                cls_category = row_data.get("class_category", "PRIMARY")
                cls_capacity_str = row_data.get("class_capacity", "")

                sec_name = row_data.get("section_name", "")
                sec_code = row_data.get("section_code", "")
                sec_capacity_str = row_data.get("section_capacity", "")

                source_ident = f"{ay_code}/{cls_code}/{sec_code}"

                val_status = "valid"
                val_error_code = None
                val_error_message = None

                resolved_ay_id = None
                resolved_class_id = None
                resolved_section_id = None

                # 1. Missing required field in row validation
                required_fields = [
                    "academic_year_name", "academic_year_code", "start_date", "end_date",
                    "class_name", "class_code", "class_level", "class_capacity",
                    "section_name", "section_code", "section_capacity"
                ]
                missing_in_row = [f for f in required_fields if row_data.get(f) == ""]

                if missing_in_row:
                    val_status = "invalid"
                    val_error_code = "MISSING_REQUIRED_FIELD"
                    val_error_message = f"Row is missing required field(s): {', '.join(missing_in_row)}"

                # 2. Check duplicate leaf inside the CSV itself
                if val_status == "valid":
                    leaf_key = (ay_code.upper(), cls_code.upper(), sec_code.upper())
                    if leaf_key in seen_leaves:
                        val_status = "invalid"
                        val_error_code = "DUPLICATE_ROW"
                        val_error_message = f"Duplicate row in CSV: identical hierarchy leaf {source_ident} already defined."
                    else:
                        seen_leaves.add(leaf_key)

                # 3. Code format validations
                if val_status == "valid":
                    if not re.match(r"^AY[0-9]{4}(?:-[0-9]{4})?$", ay_code):
                        val_status = "invalid"
                        val_error_code = "INVALID_CODE_FORMAT"
                        val_error_message = f"Academic Year code '{ay_code}' must match pattern AYxxxx or AYxxxx-xxxx (e.g. AY2026)."
                    elif not re.match(r"^[A-Z0-9_]+$", cls_code) or len(cls_code) < 2 or len(cls_code) > 50:
                        val_status = "invalid"
                        val_error_code = "INVALID_CODE_FORMAT"
                        val_error_message = f"Class code '{cls_code}' must contain only uppercase letters, numbers, and underscores, and be between 2 and 50 characters."
                    elif not re.match(r"^[A-Z0-9_]+$", sec_code) or len(sec_code) < 1 or len(sec_code) > 50:
                        val_status = "invalid"
                        val_error_code = "INVALID_CODE_FORMAT"
                        val_error_message = f"Section code '{sec_code}' must contain only uppercase letters, numbers, and underscores, and be between 1 and 50 characters."

                # 4. Date validations
                ay_start_date = None
                ay_end_date = None
                if val_status == "valid":
                    try:
                        ay_start_date = date.fromisoformat(ay_start_str)
                        ay_end_date = date.fromisoformat(ay_end_str)
                        if ay_start_date >= ay_end_date:
                            val_status = "invalid"
                            val_error_code = "INVALID_ACADEMIC_PERIOD"
                            val_error_message = "start_date must be strictly before end_date."
                    except ValueError:
                        val_status = "invalid"
                        val_error_code = "INVALID_ACADEMIC_PERIOD"
                        val_error_message = f"Dates must be in YYYY-MM-DD format. Got start_date: '{ay_start_str}', end_date: '{ay_end_str}'."

                # 5. Class Level validations
                cls_level = None
                if val_status == "valid":
                    try:
                        cls_level = int(cls_level_str)
                        if cls_level < 0:
                            val_status = "invalid"
                            val_error_code = "INVALID_LEVEL_FORMAT"
                            val_error_message = "Class level must be a non-negative integer."
                    except ValueError:
                        val_status = "invalid"
                        val_error_code = "INVALID_LEVEL_FORMAT"
                        val_error_message = f"Class level must be an integer. Got: '{cls_level_str}'."

                # 6. Class Capacity validations
                cls_capacity = None
                if val_status == "valid":
                    try:
                        cls_capacity = int(cls_capacity_str)
                        if cls_capacity < 1:
                            val_status = "invalid"
                            val_error_code = "INVALID_CAPACITY"
                            val_error_message = "Class capacity must be a positive integer."
                    except ValueError:
                        val_status = "invalid"
                        val_error_code = "INVALID_CAPACITY"
                        val_error_message = f"Class capacity must be an integer. Got: '{cls_capacity_str}'."

                # 7. Section Capacity validations
                sec_capacity = None
                if val_status == "valid":
                    try:
                        sec_capacity = int(sec_capacity_str)
                        if sec_capacity < 1:
                            val_status = "invalid"
                            val_error_code = "INVALID_CAPACITY"
                            val_error_message = "Section capacity must be a positive integer."
                    except ValueError:
                        val_status = "invalid"
                        val_error_code = "INVALID_CAPACITY"
                        val_error_message = f"Section capacity must be an integer. Got: '{sec_capacity_str}'."

                # 8. Database resolutions & isolation
                if val_status == "valid":
                    # Resolve Academic Year by code/name
                    stmt_ay_code = select(AcademicYear).where(
                        and_(
                            AcademicYear.code == ay_code,
                            AcademicYear.school_id == job.school_id,
                            AcademicYear.tenant_id == tenant_id,
                            AcademicYear.deleted_at.is_(None)
                        )
                    )
                    res_ay_code = await self.db.execute(stmt_ay_code)
                    existing_ay_code = res_ay_code.scalar_one_or_none()

                    stmt_ay_name = select(AcademicYear).where(
                        and_(
                            AcademicYear.name == ay_name,
                            AcademicYear.school_id == job.school_id,
                            AcademicYear.tenant_id == tenant_id,
                            AcademicYear.deleted_at.is_(None)
                        )
                    )
                    res_ay_name = await self.db.execute(stmt_ay_name)
                    existing_ay_name = res_ay_name.scalar_one_or_none()

                    resolved_ay = None
                    if existing_ay_code or existing_ay_name:
                        if existing_ay_code and existing_ay_name and existing_ay_code.id != existing_ay_name.id:
                            val_status = "invalid"
                            val_error_code = "ACADEMIC_YEAR_CODE_CONFLICT"
                            val_error_message = f"Academic Year code '{ay_code}' and name '{ay_name}' resolve to different academic years."
                        else:
                            resolved_ay = existing_ay_code or existing_ay_name

                        if val_status == "valid" and resolved_ay:
                            if resolved_ay.start_date != ay_start_date or resolved_ay.end_date != ay_end_date:
                                val_status = "invalid"
                                val_error_code = "ACADEMIC_YEAR_DATE_MISMATCH"
                                val_error_message = f"Conflict: Academic Year '{resolved_ay.name}' already exists but with different dates ({resolved_ay.start_date} to {resolved_ay.end_date})."
                            else:
                                resolved_ay_id = resolved_ay.id

                    # Resolve Class
                    if val_status == "valid" and resolved_ay_id:
                        stmt_cls_code = select(Class).where(
                            and_(
                                Class.code == cls_code,
                                Class.academic_year_id == resolved_ay_id,
                                Class.school_id == job.school_id,
                                Class.tenant_id == tenant_id,
                                Class.deleted_at.is_(None)
                            )
                        )
                        res_cls_code = await self.db.execute(stmt_cls_code)
                        existing_cls_code = res_cls_code.scalar_one_or_none()

                        stmt_cls_name = select(Class).where(
                            and_(
                                Class.name == cls_name,
                                Class.academic_year_id == resolved_ay_id,
                                Class.school_id == job.school_id,
                                Class.tenant_id == tenant_id,
                                Class.deleted_at.is_(None)
                            )
                        )
                        res_cls_name = await self.db.execute(stmt_cls_name)
                        existing_cls_name = res_cls_name.scalar_one_or_none()

                        resolved_class = None
                        if existing_cls_code or existing_cls_name:
                            if existing_cls_code and existing_cls_name and existing_cls_code.id != existing_cls_name.id:
                                val_status = "invalid"
                                val_error_code = "CLASS_CODE_CONFLICT"
                                val_error_message = f"Class code '{cls_code}' and name '{cls_name}' resolve to different classes under the academic year."
                            else:
                                resolved_class = existing_cls_code or existing_cls_name
                                resolved_class_id = resolved_class.id

                    # Resolve Section
                    if val_status == "valid" and resolved_class_id:
                        stmt_sec_code = select(Section).where(
                            and_(
                                Section.code == sec_code,
                                Section.class_id == resolved_class_id,
                                Section.school_id == job.school_id,
                                Section.tenant_id == tenant_id,
                                Section.deleted_at.is_(None)
                            )
                        )
                        res_sec_code = await self.db.execute(stmt_sec_code)
                        existing_sec_code = res_sec_code.scalar_one_or_none()

                        stmt_sec_name = select(Section).where(
                            and_(
                                Section.name == sec_name,
                                Section.class_id == resolved_class_id,
                                Section.school_id == job.school_id,
                                Section.tenant_id == tenant_id,
                                Section.deleted_at.is_(None)
                            )
                        )
                        res_sec_name = await self.db.execute(stmt_sec_name)
                        existing_sec_name = res_sec_name.scalar_one_or_none()

                        if existing_sec_code or existing_sec_name:
                            if existing_sec_code and existing_sec_name and existing_sec_code.id != existing_sec_name.id:
                                val_status = "invalid"
                                val_error_code = "SECTION_CODE_CONFLICT"
                                val_error_message = f"Section code '{sec_code}' and name '{sec_name}' resolve to different sections under the class."
                            else:
                                resolved_section = existing_sec_code or existing_sec_name
                                resolved_section_id = resolved_section.id

                # Save staging row
                staging_row = AcademicSetupImportRow(
                    tenant_id=tenant_id,
                    school_id=job.school_id,
                    import_job_id=job_id,
                    row_number=index,
                    
                    academic_year_name=ay_name,
                    academic_year_code=ay_code,
                    start_date=ay_start_date or date(2000, 1, 1),
                    end_date=ay_end_date or date(2000, 1, 1),
                    
                    class_name=cls_name,
                    class_code=cls_code,
                    class_level=cls_level or 0,
                    class_category=cls_category,
                    class_capacity=cls_capacity or 0,
                    
                    section_name=sec_name,
                    section_code=sec_code,
                    section_capacity=sec_capacity or 0,
                    
                    academic_year_id=resolved_ay_id,
                    class_id=resolved_class_id,
                    section_id=resolved_section_id,
                    
                    validation_status=val_status,
                    validation_error_code=val_error_code,
                    validation_error_message=val_error_message
                )

                if val_status == "invalid":
                    failed_rows_count += 1

                self.db.add(staging_row)

                # Write Audit Row
                audit_row = ImportJobRow(
                    import_job_id=job_id,
                    row_number=index,
                    status="failed" if val_status == "invalid" else "success",
                    error_code=val_error_code,
                    error_message=val_error_message,
                    source_identifier=source_ident,
                    row_metadata={}
                )
                self.db.add(audit_row)

            # Update job statistics
            job.total_rows = total_rows_count
            job.processed_rows = total_rows_count
            job.successful_rows = total_rows_count - failed_rows_count
            job.failed_rows = failed_rows_count
            job.skipped_rows = 0
            job.status = ImportJobStatus.VALIDATED
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)
            
            return job

        except Exception as e:
            await self.db.rollback()
            job.status = ImportJobStatus.DRAFT
            job.error_summary = str(e)
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)
            raise

    async def validate_guardian_job(
        self,
        tenant_id: uuid.UUID,
        job_id: uuid.UUID,
        file_content: bytes,
        job: Optional[ImportJob] = None,
        sheet_name: Optional[str] = None
    ) -> ImportJob:
        import re
        import csv
        import io
        from app.models.guardian_import import GuardianImportRow
        from app.models.guardian import Guardian, GuardianType, GuardianStatus
        from app.models.student import StudentGender

        if not job:
            job = await self.get_job_by_id(tenant_id, job_id)
            if not job:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Import job not found."
                )

        if job.status != ImportJobStatus.DRAFT:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot validate job in status '{job.status}'. Expected DRAFT."
            )

        # Transition status to VALIDATING
        job = await self.update_status(tenant_id, job_id, ImportJobStatus.VALIDATING)

        try:
            # 1. Save source file to GCS
            ext = os.path.splitext(job.source_filename)[1].lower() if job.source_filename else ".csv"
            gcs_path = f"imports/{job.import_type.value}/{job_id}{ext}"
            await self.storage_service.upload(file_content, gcs_path, "application/octet-stream")

            # Update job metadata with GCS path
            job_metadata = dict(job.job_metadata or {})
            job_metadata["source_file_path"] = gcs_path

            # 2. Parse Spreadsheet/CSV
            from app.utils.spreadsheet_reader import read_spreadsheet, normalize_header
            sheets, selected_sheet, rows = read_spreadsheet(file_content, job.source_filename, sheet_name=sheet_name)

            job_metadata["sheets"] = sheets
            job_metadata["selected_sheet"] = selected_sheet
            job.job_metadata = job_metadata
            self.db.add(job)
            await self.db.commit()

            if not rows or len(rows) <= 1:
                # No data rows (only header or empty)
                job.total_rows = 0
                job.processed_rows = 0
                job.successful_rows = 0
                job.failed_rows = 0
                job.skipped_rows = 0
                job = await self.update_status(tenant_id, job_id, ImportJobStatus.VALIDATED)
                return job

            # 3. Normalize headers
            headers = [normalize_header(h) for h in rows[0]]

            # Required fields validation
            required_cols = [
                "guardian_id",
                "guardian_type",
                "first_name",
                "last_name",
                "gender",
                "date_of_birth",
                "mobile"
            ]
            missing_cols = [col for col in required_cols if col not in headers]
            if missing_cols:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Missing required CSV column headers: {', '.join(missing_cols)}"
                )

            # Remove existing staging rows for this job if any
            await self.db.execute(
                text("DELETE FROM guardian_import_rows WHERE import_job_id = :job_id").bindparams(job_id=job_id)
            )
            # Remove existing audit rows for this job if any
            await self.db.execute(
                text("DELETE FROM import_job_rows WHERE import_job_id = :job_id").bindparams(job_id=job_id)
            )
            await self.db.commit()

            total_rows_count = 0
            failed_rows_count = 0

            # Keep track of unique identifiers inside the CSV to identify duplicate rows
            seen_ids = set()
            seen_mobiles = set()
            seen_emails = set()
            seen_aadhaars = set()
            seen_pans = set()

            # Regex pattern for basic phone check
            phone_pattern = re.compile(r"^[+0-9()\s-]{1,20}$")
            # Regex pattern for Indian PAN check
            pan_pattern = re.compile(r"^[A-Z]{5}[0-9]{4}[A-Z]{1}$")
            # Regex pattern for Aadhaar check
            aadhaar_pattern = re.compile(r"^\d{12}$")

            # Process rows one by one
            for index, raw_row in enumerate(rows[1:], start=1):
                # Skip blank rows
                if not raw_row or all(cell.strip() == "" for cell in raw_row):
                    continue

                total_rows_count += 1

                # Map headers to row cells
                row_data = {}
                for col_idx, h in enumerate(headers):
                    if col_idx < len(raw_row):
                        row_data[h] = raw_row[col_idx].strip()
                    else:
                        row_data[h] = ""

                # Extract and clean values
                guardian_id = row_data.get("guardian_id", "")
                guardian_type_raw = row_data.get("guardian_type", "")
                first_name = row_data.get("first_name", "")
                middle_name = row_data.get("middle_name", None) or None
                last_name = row_data.get("last_name", "")
                gender_raw = row_data.get("gender", "")
                dob_str = row_data.get("date_of_birth", "")
                aadhaar_number = row_data.get("aadhaar_number", None) or None
                pan_number = row_data.get("pan_number", None) or None
                occupation = row_data.get("occupation", None) or None
                qualification = row_data.get("qualification", None) or None
                organization = row_data.get("organization", None) or None
                annual_income_str = row_data.get("annual_income", None) or None
                mobile = row_data.get("mobile", "")
                alternate_mobile = row_data.get("alternate_mobile", None) or None
                email = row_data.get("email", None) or None
                emergency_contact_name = row_data.get("emergency_contact_name", None) or None
                emergency_contact_mobile = row_data.get("emergency_contact_mobile", None) or None
                photo_url = row_data.get("photo_url", None) or None
                address = row_data.get("address", None) or None

                # Email case normalization
                if email:
                    email = email.lower()

                # Identifier casing normalization
                if guardian_id:
                    guardian_id = guardian_id.upper()
                if pan_number:
                    pan_number = pan_number.upper()

                val_status = "valid"
                val_error_code = None
                val_error_message = None
                resolved_guardian_id = None

                # A. Required field check
                if not guardian_id or not guardian_type_raw or not first_name or not last_name or not gender_raw or not dob_str or not mobile:
                    val_status = "invalid"
                    val_error_code = "MISSING_REQUIRED_FIELD"
                    val_error_message = "One or more required fields are missing."

                # B. Enum guardian_type validation
                guardian_type = None
                if val_status == "valid":
                    try:
                        guardian_type = GuardianType(guardian_type_raw.upper())
                    except ValueError:
                        val_status = "invalid"
                        val_error_code = "INVALID_GUARDIAN_TYPE"
                        val_error_message = f"Invalid guardian_type '{guardian_type_raw}'."

                # C. Enum gender validation
                gender = None
                if val_status == "valid":
                    try:
                        gender = StudentGender(gender_raw.upper())
                    except ValueError:
                        val_status = "invalid"
                        val_error_code = "INVALID_GENDER"
                        val_error_message = f"Invalid gender '{gender_raw}'."

                # D. Date of Birth format validation
                dob_val = None
                if val_status == "valid":
                    try:
                        dob_val = date.fromisoformat(dob_str)
                        if dob_val >= date.today():
                            val_status = "invalid"
                            val_error_code = "INVALID_FIELD_FORMAT"
                            val_error_message = "Date of birth must be in the past."
                    except ValueError:
                        val_status = "invalid"
                        val_error_code = "INVALID_FIELD_FORMAT"
                        val_error_message = f"Invalid date_of_birth format '{dob_str}'. Expected YYYY-MM-DD."

                # E. Phone validations
                if val_status == "valid":
                    if not phone_pattern.match(mobile):
                        val_status = "invalid"
                        val_error_code = "INVALID_PHONE"
                        val_error_message = f"Invalid mobile number format '{mobile}'."
                    elif alternate_mobile and not phone_pattern.match(alternate_mobile):
                        val_status = "invalid"
                        val_error_code = "INVALID_PHONE"
                        val_error_message = f"Invalid alternate_mobile format '{alternate_mobile}'."
                    elif emergency_contact_mobile and not phone_pattern.match(emergency_contact_mobile):
                        val_status = "invalid"
                        val_error_code = "INVALID_PHONE"
                        val_error_message = f"Invalid emergency_contact_mobile format '{emergency_contact_mobile}'."

                # F. Email format validation
                if val_status == "valid" and email:
                    if "@" not in email or "." not in email:
                        val_status = "invalid"
                        val_error_code = "INVALID_EMAIL"
                        val_error_message = f"Invalid email format '{email}'."

                # G. Aadhaar & PAN validations
                if val_status == "valid" and aadhaar_number:
                    if not aadhaar_pattern.match(aadhaar_number):
                        val_status = "invalid"
                        val_error_code = "INVALID_FIELD_FORMAT"
                        val_error_message = f"Invalid Aadhaar number '{aadhaar_number}'. Must be a 12-digit number."
                if val_status == "valid" and pan_number:
                    if not pan_pattern.match(pan_number):
                        val_status = "invalid"
                        val_error_code = "INVALID_FIELD_FORMAT"
                        val_error_message = f"Invalid PAN number '{pan_number}'. Must match pattern."

                # H. Annual income validation
                annual_income_val = None
                if val_status == "valid" and annual_income_str:
                    try:
                        annual_income_val = float(annual_income_str)
                        if annual_income_val < 0:
                            val_status = "invalid"
                            val_error_code = "INVALID_FIELD_FORMAT"
                            val_error_message = "Annual income must be non-negative."
                    except ValueError:
                        val_status = "invalid"
                        val_error_code = "INVALID_FIELD_FORMAT"
                        val_error_message = f"Invalid annual_income value '{annual_income_str}'."

                # I. Duplicate checks inside CSV
                if val_status == "valid":
                    if guardian_id in seen_ids:
                        val_status = "invalid"
                        val_error_code = "DUPLICATE_ROW"
                        val_error_message = f"Duplicate guardian_id '{guardian_id}' in CSV."
                    elif mobile in seen_mobiles:
                        val_status = "invalid"
                        val_error_code = "DUPLICATE_ROW"
                        val_error_message = f"Duplicate mobile '{mobile}' in CSV."
                    elif email and email in seen_emails:
                        val_status = "invalid"
                        val_error_code = "DUPLICATE_ROW"
                        val_error_message = f"Duplicate email '{email}' in CSV."
                    elif aadhaar_number and aadhaar_number in seen_aadhaars:
                        val_status = "invalid"
                        val_error_code = "DUPLICATE_ROW"
                        val_error_message = f"Duplicate Aadhaar number '{aadhaar_number}' in CSV."
                    elif pan_number and pan_number in seen_pans:
                        val_status = "invalid"
                        val_error_code = "DUPLICATE_ROW"
                        val_error_message = f"Duplicate PAN number '{pan_number}' in CSV."
                    else:
                        seen_ids.add(guardian_id)
                        seen_mobiles.add(mobile)
                        if email:
                            seen_emails.add(email)
                        if aadhaar_number:
                            seen_aadhaars.add(aadhaar_number)
                        if pan_number:
                            seen_pans.add(pan_number)

                # J. Database duplicates checks
                if val_status == "valid":
                    # Check Mobile
                    stmt_dup = select(Guardian).where(
                        and_(
                            Guardian.tenant_id == tenant_id,
                            Guardian.mobile == mobile
                        )
                    )
                    res_dup = await self.db.execute(stmt_dup)
                    g_dup = res_dup.scalar_one_or_none()
                    if g_dup:
                        if g_dup.deleted_at is not None:
                            val_status = "invalid"
                            val_error_code = "SOFT_DELETED_GUARDIAN_CONFLICT"
                            val_error_message = f"A soft-deleted guardian with mobile number '{mobile}' already exists."
                        else:
                            val_status = "invalid"
                            val_error_code = "GUARDIAN_ALREADY_EXISTS"
                            val_error_message = f"An active guardian with mobile number '{mobile}' already exists."
                            resolved_guardian_id = g_dup.id

                    # Check Email
                    if val_status == "valid" and email:
                        stmt_dup = select(Guardian).where(
                            and_(
                                Guardian.tenant_id == tenant_id,
                                Guardian.email == email
                            )
                        )
                        res_dup = await self.db.execute(stmt_dup)
                        g_dup = res_dup.scalar_one_or_none()
                        if g_dup:
                            if g_dup.deleted_at is not None:
                                val_status = "invalid"
                                val_error_code = "SOFT_DELETED_GUARDIAN_CONFLICT"
                                val_error_message = f"A soft-deleted guardian with email '{email}' already exists."
                            else:
                                val_status = "invalid"
                                val_error_code = "GUARDIAN_ALREADY_EXISTS"
                                val_error_message = f"An active guardian with email '{email}' already exists."
                                resolved_guardian_id = g_dup.id

                    # Check Aadhaar
                    if val_status == "valid" and aadhaar_number:
                        stmt_dup = select(Guardian).where(
                            and_(
                                Guardian.tenant_id == tenant_id,
                                Guardian.aadhaar_number == aadhaar_number
                            )
                        )
                        res_dup = await self.db.execute(stmt_dup)
                        g_dup = res_dup.scalar_one_or_none()
                        if g_dup:
                            if g_dup.deleted_at is not None:
                                val_status = "invalid"
                                val_error_code = "SOFT_DELETED_GUARDIAN_CONFLICT"
                                val_error_message = "A soft-deleted guardian with this Aadhaar number already exists."
                            else:
                                val_status = "invalid"
                                val_error_code = "GUARDIAN_ALREADY_EXISTS"
                                val_error_message = "An active guardian with this Aadhaar number already exists."
                                resolved_guardian_id = g_dup.id

                    # Check PAN
                    if val_status == "valid" and pan_number:
                        stmt_dup = select(Guardian).where(
                            and_(
                                Guardian.tenant_id == tenant_id,
                                Guardian.pan_number == pan_number
                            )
                        )
                        res_dup = await self.db.execute(stmt_dup)
                        g_dup = res_dup.scalar_one_or_none()
                        if g_dup:
                            if g_dup.deleted_at is not None:
                                val_status = "invalid"
                                val_error_code = "SOFT_DELETED_GUARDIAN_CONFLICT"
                                val_error_message = "A soft-deleted guardian with this PAN number already exists."
                            else:
                                val_status = "invalid"
                                val_error_code = "GUARDIAN_ALREADY_EXISTS"
                                val_error_message = "An active guardian with this PAN number already exists."
                                resolved_guardian_id = g_dup.id

                # Save GuardianImportRow
                staging_row = GuardianImportRow(
                    import_job_id=job_id,
                    row_number=index,
                    source_identifier=guardian_id if guardian_id else f"ROW_{index}",
                    guardian_type=guardian_type_raw,
                    first_name=first_name,
                    middle_name=middle_name,
                    last_name=last_name,
                    gender=gender_raw,
                    date_of_birth=dob_val if dob_val else date(1970, 1, 1),
                    aadhaar_number=aadhaar_number,
                    pan_number=pan_number,
                    occupation=occupation,
                    qualification=qualification,
                    organization=organization,
                    annual_income=annual_income_val,
                    mobile=mobile,
                    alternate_mobile=alternate_mobile,
                    email=email,
                    emergency_contact_name=emergency_contact_name,
                    emergency_contact_mobile=emergency_contact_mobile,
                    photo_url=photo_url,
                    address=address,
                    school_id=job.school_id,
                    tenant_id=tenant_id,
                    validation_status=val_status,
                    validation_error_code=val_error_code,
                    validation_error_message=val_error_message,
                    resolved_guardian_id=resolved_guardian_id
                )

                if val_status == "invalid":
                    failed_rows_count += 1

                self.db.add(staging_row)

                # Write Audit Row
                audit_row = ImportJobRow(
                    import_job_id=job_id,
                    row_number=index,
                    status="failed" if val_status == "invalid" else "success",
                    error_code=val_error_code,
                    error_message=val_error_message,
                    source_identifier=guardian_id if guardian_id else f"ROW_{index}",
                    row_metadata={}
                )
                self.db.add(audit_row)

            # Update job statistics
            job.total_rows = total_rows_count
            job.processed_rows = total_rows_count
            job.successful_rows = total_rows_count - failed_rows_count
            job.failed_rows = failed_rows_count
            job.skipped_rows = 0
            job.status = ImportJobStatus.VALIDATED
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)

            return job

        except Exception as e:
            await self.db.rollback()
            job.status = ImportJobStatus.DRAFT
            job.error_summary = str(e)
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)
            raise

    async def execute_guardian_job(
        self,
        tenant_id: uuid.UUID,
        job_id: uuid.UUID,
        job: Optional[ImportJob] = None
    ) -> ImportJob:
        if not job:
            job = await self.get_job_by_id(tenant_id, job_id)
            if not job:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Import job not found."
                )

        if job.status != ImportJobStatus.VALIDATED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot start execution. Import job must be in VALIDATED state, current state is '{job.status}'."
            )

        # Transition status to RUNNING
        job.status = ImportJobStatus.RUNNING
        job.started_at = datetime.now(timezone.utc)
        self.db.add(job)
        await self.db.commit()

        # Initialize repositories and services
        from app.repositories.guardian import GuardianRepository, StudentGuardianRepository
        from app.repositories.student import StudentRepository
        from app.repositories.school import SchoolRepository
        from app.services.guardian import GuardianService
        from app.schemas.guardian import GuardianCreate
        from app.models.guardian import Guardian, GuardianStatus
        from app.models.guardian_import import GuardianImportRow

        g_repo = GuardianRepository(self.db)
        sg_repo = StudentGuardianRepository(self.db)
        stud_repo = StudentRepository(self.db)
        school_repo = SchoolRepository(self.db)
        
        g_service = GuardianService(
            guardian_repo=g_repo,
            student_guardian_repo=sg_repo,
            student_repo=stud_repo,
            school_repo=school_repo
        )

        # Mock commit to prevent nested transaction closure in GuardianService
        original_commit = self.db.commit
        async def mock_commit():
            await self.db.flush()
        self.db.commit = mock_commit

        try:
            try:
                chunk_size = 100
                total_successful = 0
                total_failed = 0

                # Remove existing audit row results if any (so we can rewrite them cleanly during execution)
                await self.db.execute(
                    text("DELETE FROM import_job_rows WHERE import_job_id = :job_id").bindparams(job_id=job_id)
                )
                await self.db.commit()

                # Get all rows that are validation-invalid to count them as skipped
                stmt_invalid = select(GuardianImportRow).where(
                    and_(
                        GuardianImportRow.import_job_id == job_id,
                        GuardianImportRow.validation_status == "invalid",
                        GuardianImportRow.tenant_id == tenant_id
                    )
                )
                res_invalid = await self.db.execute(stmt_invalid)
                invalid_rows = list(res_invalid.scalars().all())
                total_skipped = len(invalid_rows)

                # Write audit rows for skipped items
                for inv_row in invalid_rows:
                    audit_row = ImportJobRow(
                        import_job_id=job_id,
                        row_number=inv_row.row_number,
                        status="skipped",
                        error_code=inv_row.validation_error_code,
                        error_message=inv_row.validation_error_message,
                        source_identifier=inv_row.source_identifier,
                        row_metadata={}
                    )
                    self.db.add(audit_row)
                await self.db.commit()

                while True:
                    # Fetch next chunk of valid rows that are not yet executed or failed execution
                    stmt = select(GuardianImportRow).where(
                        and_(
                            GuardianImportRow.import_job_id == job_id,
                            GuardianImportRow.validation_status == "valid",
                            GuardianImportRow.tenant_id == tenant_id
                        )
                    ).order_by(GuardianImportRow.row_number.asc()).limit(chunk_size)

                    res = await self.db.execute(stmt)
                    chunk_rows = list(res.scalars().all())

                    if not chunk_rows:
                        break

                    for row in chunk_rows:
                        created_id = None
                        row_error_code = None
                        row_error_message = None

                        try:
                            # Row-level nested transaction (savepoint)
                            async with self.db.begin_nested():
                                # 1. Re-check unique constraints against active database state (race conditions check)
                                if row.resolved_guardian_id:
                                    stmt_chk = select(Guardian).where(
                                        and_(
                                            Guardian.id == row.resolved_guardian_id,
                                            Guardian.tenant_id == tenant_id,
                                            Guardian.deleted_at.is_(None)
                                        )
                                    )
                                    res_chk = await self.db.execute(stmt_chk)
                                    existing_g = res_chk.scalar_one_or_none()
                                    if existing_g:
                                        created_id = existing_g.id
                                    else:
                                        raise Exception("RESOLVED_GUARDIAN_NOT_FOUND: The pre-resolved guardian no longer exists or is inactive.")
                                else:
                                    # Check Mobile
                                    stmt_chk = select(Guardian).where(
                                        and_(
                                            Guardian.tenant_id == tenant_id,
                                            Guardian.mobile == row.mobile
                                        )
                                    )
                                    res_chk = await self.db.execute(stmt_chk)
                                    existing_g = res_chk.scalar_one_or_none()
                                    if existing_g:
                                        if existing_g.deleted_at is not None:
                                            raise Exception("SOFT_DELETED_GUARDIAN_CONFLICT: A soft-deleted guardian with this mobile already exists.")
                                        else:
                                            raise Exception("GUARDIAN_ALREADY_EXISTS: A guardian with this mobile already exists.")

                                    # Check Email
                                    if row.email:
                                        stmt_chk = select(Guardian).where(
                                            and_(
                                                Guardian.tenant_id == tenant_id,
                                                Guardian.email == row.email
                                            )
                                        )
                                        res_chk = await self.db.execute(stmt_chk)
                                        existing_g = res_chk.scalar_one_or_none()
                                        if existing_g:
                                            if existing_g.deleted_at is not None:
                                                raise Exception("SOFT_DELETED_GUARDIAN_CONFLICT: A soft-deleted guardian with this email already exists.")
                                            else:
                                                raise Exception("GUARDIAN_ALREADY_EXISTS: A guardian with this email already exists.")

                                    # Check Aadhaar
                                    if row.aadhaar_number:
                                        stmt_chk = select(Guardian).where(
                                            and_(
                                                Guardian.tenant_id == tenant_id,
                                                Guardian.aadhaar_number == row.aadhaar_number
                                            )
                                        )
                                        res_chk = await self.db.execute(stmt_chk)
                                        existing_g = res_chk.scalar_one_or_none()
                                        if existing_g:
                                            if existing_g.deleted_at is not None:
                                                raise Exception("SOFT_DELETED_GUARDIAN_CONFLICT: A soft-deleted guardian with this Aadhaar already exists.")
                                            else:
                                                raise Exception("GUARDIAN_ALREADY_EXISTS: A guardian with this Aadhaar already exists.")

                                    # Check PAN
                                    if row.pan_number:
                                        stmt_chk = select(Guardian).where(
                                            and_(
                                                Guardian.tenant_id == tenant_id,
                                                Guardian.pan_number == row.pan_number
                                            )
                                        )
                                        res_chk = await self.db.execute(stmt_chk)
                                        existing_g = res_chk.scalar_one_or_none()
                                        if existing_g:
                                            if existing_g.deleted_at is not None:
                                                raise Exception("SOFT_DELETED_GUARDIAN_CONFLICT: A soft-deleted guardian with this PAN already exists.")
                                            else:
                                                raise Exception("GUARDIAN_ALREADY_EXISTS: A guardian with this PAN already exists.")

                                if not created_id:
                                    # Create new Guardian via service
                                    g_in = GuardianCreate(
                                        school_id=row.school_id,
                                        guardian_type=row.guardian_type,
                                        first_name=row.first_name,
                                        middle_name=row.middle_name,
                                        last_name=row.last_name,
                                        gender=row.gender,
                                        date_of_birth=row.date_of_birth,
                                        aadhaar_number=row.aadhaar_number,
                                        pan_number=row.pan_number,
                                        occupation=row.occupation,
                                        qualification=row.qualification,
                                        organization=row.organization,
                                        annual_income=float(row.annual_income) if row.annual_income is not None else None,
                                        mobile=row.mobile,
                                        alternate_mobile=row.alternate_mobile,
                                        email=row.email,
                                        emergency_contact_name=row.emergency_contact_name,
                                        emergency_contact_mobile=row.emergency_contact_mobile,
                                        photo_url=row.photo_url,
                                        address={"line": row.address} if row.address else {},
                                        communication_preferences={},
                                        settings={},
                                        ai_metrics={}
                                    )
                                    new_g = await g_service.create_guardian(tenant_id=tenant_id, obj_in=g_in, created_by=job.created_by)
                                    created_id = new_g.id

                                # Row execution success
                                row.validation_status = "executed"
                                row.created_guardian_id = created_id
                                self.db.add(row)

                                audit_row = ImportJobRow(
                                    import_job_id=job_id,
                                    row_number=row.row_number,
                                    status="success",
                                    source_identifier=row.source_identifier,
                                    entity_id=created_id,
                                    row_metadata={}
                                )
                                self.db.add(audit_row)
                                total_successful += 1

                        except Exception as row_ex:
                            # Row execution failure (rolls back nested savepoint only)
                            total_failed += 1
                            err_str = str(row_ex)
                            if "SOFT_DELETED_GUARDIAN_CONFLICT" in err_str:
                                row_error_code = "SOFT_DELETED_GUARDIAN_CONFLICT"
                                row_error_message = err_str.split(":", 1)[-1].strip()
                            elif "already exists" in err_str or "409" in err_str:
                                row_error_code = "GUARDIAN_ALREADY_EXISTS"
                                row_error_message = err_str
                            else:
                                row_error_code = "EXECUTION_FAILURE"
                                row_error_message = err_str

                            row.validation_status = "failed_execution"
                            row.validation_error_code = row_error_code
                            row.validation_error_message = row_error_message
                            self.db.add(row)

                            audit_row = ImportJobRow(
                                import_job_id=job_id,
                                row_number=row.row_number,
                                status="failed",
                                error_code=row_error_code,
                                error_message=row_error_message,
                                source_identifier=row.source_identifier,
                                row_metadata={}
                            )
                            self.db.add(audit_row)

                    # Commit chunk changes
                    self.db.commit = original_commit
                    await self.db.commit()
                    self.db.commit = mock_commit

                # Update job final counters and status
                job.processed_rows = total_successful + total_failed
                job.successful_rows = total_successful
                job.failed_rows = total_failed
                job.skipped_rows = total_skipped
                job.completed_at = datetime.now(timezone.utc)
                if total_failed > 0:
                    job.status = ImportJobStatus.COMPLETED_WITH_ERRORS
                else:
                    job.status = ImportJobStatus.COMPLETED
                self.db.add(job)
                self.db.commit = original_commit
                await self.db.commit()
                await self.db.refresh(job)
                return job

            except Exception as outer_ex:
                # Fatal execution exception
                self.db.commit = original_commit
                await self.db.rollback()
                job.status = ImportJobStatus.FAILED
                job.error_summary = f"Fatal execution error: {outer_ex}"
                job.completed_at = datetime.now(timezone.utc)
                self.db.add(job)
                await self.db.commit()
                await self.db.refresh(job)
                raise outer_ex

        finally:
            self.db.commit = original_commit

    async def validate_guardian_mapping_job(
        self,
        tenant_id: uuid.UUID,
        job_id: uuid.UUID,
        file_content: bytes,
        job: Optional[ImportJob] = None,
        sheet_name: Optional[str] = None
    ) -> ImportJob:
        import csv
        import io
        from sqlalchemy import or_
        from app.models.student_guardian_import import StudentGuardianImportRow
        from app.models.student import Student
        from app.models.guardian import Guardian, StudentGuardian, StudentGuardianRelationship
        from app.models.guardian_import import GuardianImportRow

        if not job:
            job = await self.get_job_by_id(tenant_id, job_id)
            if not job:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Import job not found."
                )

        job.status = ImportJobStatus.VALIDATING
        self.db.add(job)
        await self.db.commit()

        try:
            # 1. Save source file to GCS
            ext = os.path.splitext(job.source_filename)[1].lower() if job.source_filename else ".csv"
            gcs_path = f"imports/{job.import_type.value}/{job_id}{ext}"
            await self.storage_service.upload(file_content, gcs_path, "application/octet-stream")

            # Update job metadata with GCS path
            job_metadata = dict(job.job_metadata or {})
            job_metadata["source_file_path"] = gcs_path

            # Clean existing records for this job to support re-validation
            await self.db.execute(
                text("DELETE FROM student_guardian_import_rows WHERE import_job_id = :job_id").bindparams(job_id=job_id)
            )
            await self.db.execute(
                text("DELETE FROM import_job_rows WHERE import_job_id = :job_id").bindparams(job_id=job_id)
            )
            await self.db.commit()

            # 2. Parse Spreadsheet/CSV
            from app.utils.spreadsheet_reader import read_spreadsheet, normalize_header
            sheets, selected_sheet, rows = read_spreadsheet(file_content, job.source_filename, sheet_name=sheet_name)

            job_metadata["sheets"] = sheets
            job_metadata["selected_sheet"] = selected_sheet
            job.job_metadata = job_metadata
            self.db.add(job)
            await self.db.commit()

            if not rows:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Spreadsheet file is empty."
                )

            headers = [normalize_header(h) for h in rows[0]]
            
            # Mandatory header check
            req_headers = ["student_admission_number", "guardian_id", "relationship"]
            missing = [rh for rh in req_headers if rh not in headers]
            if missing:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Missing required CSV column headers: {', '.join(missing)}"
                )

            total_rows_count = 0
            failed_rows_count = 0

            # Tracking sets for duplicate detection inside CSV
            seen_mappings = set()  # (student_admission_number, guardian_id)
            seen_primaries = set()  # student_admission_number

            for index, row_data in enumerate(rows[1:], start=1):
                if not row_data or all(not val.strip() for val in row_data):
                    continue

                total_rows_count += 1

                # Padding shorter rows
                if len(row_data) < len(headers):
                    row_data = row_data + [""] * (len(headers) - len(row_data))

                # Extract cells
                student_admission_number = row_data[headers.index("student_admission_number")].strip()
                guardian_id = row_data[headers.index("guardian_id")].strip()
                relationship_str = row_data[headers.index("relationship")].strip()

                is_primary_str = "false"
                if "is_primary" in headers:
                    is_primary_str = row_data[headers.index("is_primary")].strip().lower()

                can_pickup_str = "true"
                if "can_pickup_student" in headers:
                    can_pickup_str = row_data[headers.index("can_pickup_student")].strip().lower()

                receives_notifications_str = "true"
                if "receives_notifications" in headers:
                    receives_notifications_str = row_data[headers.index("receives_notifications")].strip().lower()

                # Parse booleans safely
                is_primary = is_primary_str in ("true", "1", "yes")
                can_pickup = can_pickup_str not in ("false", "0", "no")
                receives_notifications = receives_notifications_str not in ("false", "0", "no")

                val_status = "valid"
                val_error_code = None
                val_error_message = None

                resolved_student_id = None
                resolved_guardian_id = None

                # 1. Validation: required fields blank checks
                if not student_admission_number or not guardian_id or not relationship_str:
                    val_status = "invalid"
                    val_error_code = "MISSING_REQUIRED_FIELD"
                    val_error_message = "Mandatory columns student_admission_number, guardian_id, and relationship cannot be empty."

                # 2. Validation: relationship enum validation
                if val_status == "valid":
                    try:
                        StudentGuardianRelationship(relationship_str.upper())
                    except ValueError:
                        val_status = "invalid"
                        val_error_code = "INVALID_RELATIONSHIP_TYPE"
                        val_error_message = f"Invalid relationship type '{relationship_str}'."

                # 3. Resolve Student
                if val_status == "valid":
                    stmt_stud = select(Student).where(
                        and_(
                            Student.admission_number == student_admission_number,
                            Student.school_id == job.school_id,
                            Student.tenant_id == tenant_id,
                            Student.deleted_at.is_(None)
                        )
                    )
                    res_stud = await self.db.execute(stmt_stud)
                    student_obj = res_stud.scalar_one_or_none()
                    if not student_obj:
                        val_status = "invalid"
                        val_error_code = "STUDENT_NOT_FOUND"
                        val_error_message = f"Student with admission number '{student_admission_number}' not found under target school."
                    else:
                        resolved_student_id = student_obj.id

                # 4. Resolve Guardian
                if val_status == "valid":
                    # Try UUID match first
                    g_uuid = None
                    try:
                        g_uuid = uuid.UUID(guardian_id)
                    except ValueError:
                        pass

                    if g_uuid:
                        stmt_g = select(Guardian).where(
                            and_(
                                Guardian.id == g_uuid,
                                Guardian.school_id == job.school_id,
                                Guardian.tenant_id == tenant_id,
                                Guardian.deleted_at.is_(None)
                            )
                        )
                        res_g = await self.db.execute(stmt_g)
                        g_obj = res_g.scalar_one_or_none()
                        if g_obj:
                            resolved_guardian_id = g_obj.id
                    
                    if not resolved_guardian_id:
                        # Try staged source_identifier match (from previous runs)
                        stmt_staged = select(GuardianImportRow).where(
                            and_(
                                GuardianImportRow.source_identifier == guardian_id,
                                GuardianImportRow.school_id == job.school_id,
                                GuardianImportRow.tenant_id == tenant_id
                            )
                        )
                        res_staged = await self.db.execute(stmt_staged)
                        staged_g_rows = res_staged.scalars().all()
                        for s_row in staged_g_rows:
                            if s_row.created_guardian_id:
                                resolved_guardian_id = s_row.created_guardian_id
                                break
                            elif s_row.resolved_guardian_id:
                                resolved_guardian_id = s_row.resolved_guardian_id
                                break

                    if not resolved_guardian_id:
                        # Try production match by mobile or email
                        stmt_g = select(Guardian).where(
                            and_(
                                Guardian.tenant_id == tenant_id,
                                Guardian.school_id == job.school_id,
                                Guardian.deleted_at.is_(None),
                                or_(
                                    Guardian.mobile == guardian_id,
                                    Guardian.email == guardian_id
                                )
                            )
                        )
                        res_g = await self.db.execute(stmt_g)
                        g_obj = res_g.scalar_one_or_none()
                        if g_obj:
                            resolved_guardian_id = g_obj.id

                    if not resolved_guardian_id:
                        val_status = "invalid"
                        val_error_code = "GUARDIAN_NOT_FOUND"
                        val_error_message = f"Guardian with identifier '{guardian_id}' not found."

                # 5. CSV Duplicate Check
                if val_status == "valid":
                    map_key = (student_admission_number, guardian_id)
                    if map_key in seen_mappings:
                        val_status = "invalid"
                        val_error_code = "DUPLICATE_ROW"
                        val_error_message = "Duplicate student-guardian mapping in CSV."
                    else:
                        seen_mappings.add(map_key)

                # 6. Database Existing Mapping Check
                if val_status == "valid" and resolved_student_id and resolved_guardian_id:
                    stmt_map = select(StudentGuardian).where(
                        and_(
                            StudentGuardian.student_id == resolved_student_id,
                            StudentGuardian.guardian_id == resolved_guardian_id,
                            StudentGuardian.tenant_id == tenant_id,
                            StudentGuardian.school_id == job.school_id,
                            StudentGuardian.deleted_at.is_(None)
                        )
                    )
                    res_map = await self.db.execute(stmt_map)
                    if res_map.scalar_one_or_none():
                        val_status = "invalid"
                        val_error_code = "MAPPING_ALREADY_EXISTS"
                        val_error_message = "This student-guardian mapping already exists in database."

                # 7. Primary Guardian Check
                if val_status == "valid" and is_primary and resolved_student_id:
                    # Check CSV primary limit
                    if student_admission_number in seen_primaries:
                        val_status = "invalid"
                        val_error_code = "PRIMARY_GUARDIAN_LIMIT_EXCEEDED"
                        val_error_message = "Multiple primary guardians assigned to this student in CSV."
                    else:
                        seen_primaries.add(student_admission_number)

                    # Check DB primary limit
                    if val_status == "valid":
                        stmt_prim = select(StudentGuardian).where(
                            and_(
                                StudentGuardian.student_id == resolved_student_id,
                                StudentGuardian.is_primary == True,
                                StudentGuardian.tenant_id == tenant_id,
                                StudentGuardian.school_id == job.school_id,
                                StudentGuardian.deleted_at.is_(None)
                            )
                        )
                        res_prim = await self.db.execute(stmt_prim)
                        if res_prim.scalar_one_or_none():
                            val_status = "invalid"
                            val_error_code = "PRIMARY_GUARDIAN_LIMIT_EXCEEDED"
                            val_error_message = "A primary guardian is already assigned to this student in database."

                if val_status == "invalid":
                    failed_rows_count += 1

                # Save staging row
                staging_row = StudentGuardianImportRow(
                    tenant_id=tenant_id,
                    school_id=job.school_id,
                    import_job_id=job_id,
                    row_number=index,
                    student_admission_number=student_admission_number,
                    guardian_id=guardian_id,
                    relationship=relationship_str,
                    is_primary=is_primary,
                    can_pickup_student=can_pickup,
                    receives_notifications=receives_notifications,
                    resolved_student_id=resolved_student_id,
                    resolved_guardian_id=resolved_guardian_id,
                    validation_status=val_status,
                    validation_error_code=val_error_code,
                    validation_error_message=val_error_message
                )
                self.db.add(staging_row)

                # Save audit row
                audit_row = ImportJobRow(
                    import_job_id=job_id,
                    row_number=index,
                    status="failed" if val_status == "invalid" else "success",
                    error_code=val_error_code,
                    error_message=val_error_message,
                    source_identifier=f"{student_admission_number}_{guardian_id}" if student_admission_number and guardian_id else f"ROW_{index}",
                    row_metadata={}
                )
                self.db.add(audit_row)

            # Update job statistics
            job.total_rows = total_rows_count
            job.processed_rows = total_rows_count
            job.successful_rows = total_rows_count - failed_rows_count
            job.failed_rows = failed_rows_count
            job.skipped_rows = 0
            job.status = ImportJobStatus.VALIDATED
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)

            return job

        except Exception as e:
            await self.db.rollback()
            job.status = ImportJobStatus.DRAFT
            job.error_summary = str(e)
            self.db.add(job)
            await self.db.commit()
            await self.db.refresh(job)
            raise

    async def execute_guardian_mapping_job(
        self,
        tenant_id: uuid.UUID,
        job_id: uuid.UUID,
        job: Optional[ImportJob] = None
    ) -> ImportJob:
        if not job:
            job = await self.get_job_by_id(tenant_id, job_id)
            if not job:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Import job not found."
                )

        if job.status != ImportJobStatus.VALIDATED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot start execution. Import job must be in VALIDATED state, current state is '{job.status}'."
            )

        # Transition status to RUNNING
        job.status = ImportJobStatus.RUNNING
        job.started_at = datetime.now(timezone.utc)
        self.db.add(job)
        await self.db.commit()

        # Initialize repositories and services
        from sqlalchemy import or_
        from app.repositories.guardian import GuardianRepository, StudentGuardianRepository
        from app.repositories.student import StudentRepository
        from app.repositories.school import SchoolRepository
        from app.services.guardian import GuardianService
        from app.schemas.guardian import StudentGuardianCreate
        from app.models.student_guardian_import import StudentGuardianImportRow
        from app.models.student import Student
        from app.models.guardian import Guardian, StudentGuardian, StudentGuardianRelationship

        g_repo = GuardianRepository(self.db)
        sg_repo = StudentGuardianRepository(self.db)
        stud_repo = StudentRepository(self.db)
        school_repo = SchoolRepository(self.db)
        
        g_service = GuardianService(
            guardian_repo=g_repo,
            student_guardian_repo=sg_repo,
            student_repo=stud_repo,
            school_repo=school_repo
        )

        # Mock commit to prevent nested transaction closure in GuardianService
        original_commit = self.db.commit
        async def mock_commit():
            await self.db.flush()
        self.db.commit = mock_commit

        try:
            try:
                chunk_size = 100
                total_successful = 0
                total_failed = 0

                # Remove existing audit row results if any (so we can rewrite them cleanly during execution)
                await self.db.execute(
                    text("DELETE FROM import_job_rows WHERE import_job_id = :job_id").bindparams(job_id=job_id)
                )
                await self.db.commit()

                # Get all rows that are validation-invalid to count them as skipped
                stmt_invalid = select(StudentGuardianImportRow).where(
                    and_(
                        StudentGuardianImportRow.import_job_id == job_id,
                        StudentGuardianImportRow.validation_status == "invalid",
                        StudentGuardianImportRow.tenant_id == tenant_id
                    )
                )
                res_invalid = await self.db.execute(stmt_invalid)
                invalid_rows = list(res_invalid.scalars().all())
                total_skipped = len(invalid_rows)

                # Write audit rows for skipped items
                for inv_row in invalid_rows:
                    audit_row = ImportJobRow(
                        import_job_id=job_id,
                        row_number=inv_row.row_number,
                        status="skipped",
                        error_code=inv_row.validation_error_code,
                        error_message=inv_row.validation_error_message,
                        source_identifier=f"{inv_row.student_admission_number}_{inv_row.guardian_id}" if inv_row.student_admission_number and inv_row.guardian_id else f"ROW_{inv_row.row_number}",
                        row_metadata={}
                    )
                    self.db.add(audit_row)
                await self.db.commit()

                while True:
                    # Fetch next chunk of valid rows that are not yet executed or failed execution
                    stmt = select(StudentGuardianImportRow).where(
                        and_(
                            StudentGuardianImportRow.import_job_id == job_id,
                            StudentGuardianImportRow.validation_status == "valid",
                            StudentGuardianImportRow.tenant_id == tenant_id
                        )
                    ).order_by(StudentGuardianImportRow.row_number.asc()).limit(chunk_size)

                    res = await self.db.execute(stmt)
                    chunk_rows = list(res.scalars().all())

                    if not chunk_rows:
                        break

                    for row in chunk_rows:
                        created_id = None
                        row_error_code = None
                        row_error_message = None

                        try:
                            # Row-level nested transaction (savepoint)
                            async with self.db.begin_nested():
                                # 1. Verify Student exists, is active, and is in tenant boundary
                                stmt_stud = select(Student).where(
                                    and_(
                                        Student.admission_number == row.student_admission_number,
                                        Student.tenant_id == tenant_id,
                                        Student.school_id == job.school_id,
                                        Student.deleted_at.is_(None)
                                    )
                                )
                                res_stud = await self.db.execute(stmt_stud)
                                student_obj = res_stud.scalar_one_or_none()
                                if not student_obj:
                                    raise Exception("STUDENT_NOT_FOUND: Student not found or is inactive under school/tenant context.")

                                # 2. Verify Guardian exists, is active, and is in tenant boundary
                                resolved_guardian_id = None
                                g_uuid = None
                                try:
                                    g_uuid = uuid.UUID(row.guardian_id)
                                except ValueError:
                                    pass

                                if g_uuid:
                                    stmt_g = select(Guardian).where(
                                        and_(
                                            Guardian.id == g_uuid,
                                            Guardian.tenant_id == tenant_id,
                                            Guardian.school_id == job.school_id,
                                            Guardian.deleted_at.is_(None)
                                        )
                                    )
                                    res_g = await self.db.execute(stmt_g)
                                    g_obj = res_g.scalar_one_or_none()
                                    if g_obj:
                                        resolved_guardian_id = g_obj.id
                                
                                if not resolved_guardian_id:
                                    # Search by mobile or email
                                    stmt_g = select(Guardian).where(
                                        and_(
                                            Guardian.tenant_id == tenant_id,
                                            Guardian.school_id == job.school_id,
                                            Guardian.deleted_at.is_(None),
                                            or_(
                                                Guardian.mobile == row.guardian_id,
                                                Guardian.email == row.guardian_id
                                            )
                                        )
                                    )
                                    res_g = await self.db.execute(stmt_g)
                                    g_obj = res_g.scalar_one_or_none()
                                    if g_obj:
                                        resolved_guardian_id = g_obj.id

                                if not resolved_guardian_id:
                                    # Staged match
                                    from app.models.guardian_import import GuardianImportRow
                                    stmt_staged = select(GuardianImportRow).where(
                                        and_(
                                            GuardianImportRow.source_identifier == row.guardian_id,
                                            GuardianImportRow.school_id == job.school_id,
                                            GuardianImportRow.tenant_id == tenant_id
                                        )
                                    )
                                    res_staged = await self.db.execute(stmt_staged)
                                    staged_g_rows = res_staged.scalars().all()
                                    for s_row in staged_g_rows:
                                        if s_row.created_guardian_id:
                                            resolved_guardian_id = s_row.created_guardian_id
                                            break
                                        elif s_row.resolved_guardian_id:
                                            resolved_guardian_id = s_row.resolved_guardian_id
                                            break

                                if not resolved_guardian_id:
                                    raise Exception("GUARDIAN_NOT_FOUND: Guardian not found or is inactive under school/tenant context.")

                                # 3. Check duplicate assignment against active database
                                stmt_map = select(StudentGuardian).where(
                                    and_(
                                        StudentGuardian.student_id == student_obj.id,
                                        StudentGuardian.guardian_id == resolved_guardian_id,
                                        StudentGuardian.tenant_id == tenant_id,
                                        StudentGuardian.school_id == job.school_id,
                                        StudentGuardian.deleted_at.is_(None)
                                    )
                                )
                                res_map = await self.db.execute(stmt_map)
                                existing_mapping = res_map.scalar_one_or_none()
                                if existing_mapping:
                                    raise Exception("MAPPING_ALREADY_EXISTS: This student-guardian mapping already exists in database.")

                                # 4. Check primary guardian limit
                                if row.is_primary:
                                    stmt_prim = select(StudentGuardian).where(
                                        and_(
                                            StudentGuardian.student_id == student_obj.id,
                                            StudentGuardian.is_primary == True,
                                            StudentGuardian.tenant_id == tenant_id,
                                            StudentGuardian.school_id == job.school_id,
                                            StudentGuardian.deleted_at.is_(None)
                                        )
                                    )
                                    res_prim = await self.db.execute(stmt_prim)
                                    if res_prim.scalar_one_or_none():
                                        raise Exception("PRIMARY_GUARDIAN_LIMIT_EXCEEDED: A primary guardian is already assigned to this student.")

                                # 5. Create new StudentGuardian mapping via service
                                sg_create = StudentGuardianCreate(
                                    school_id=job.school_id,
                                    student_id=student_obj.id,
                                    guardian_id=resolved_guardian_id,
                                    relationship=StudentGuardianRelationship(row.relationship.upper()),
                                    is_primary=bool(row.is_primary),
                                    can_pickup_student=bool(row.can_pickup_student),
                                    receives_notifications=bool(row.receives_notifications)
                                )

                                mapping_obj = await g_service.assign_student_guardian(
                                    tenant_id=tenant_id,
                                    obj_in=sg_create
                                )
                                created_id = mapping_obj.id

                                # Row execution success
                                row.validation_status = "executed"
                                row.resolved_student_id = student_obj.id
                                row.resolved_guardian_id = resolved_guardian_id
                                row.created_mapping_id = created_id
                                self.db.add(row)

                                audit_row = ImportJobRow(
                                    import_job_id=job_id,
                                    row_number=row.row_number,
                                    status="success",
                                    source_identifier=f"{row.student_admission_number}_{row.guardian_id}",
                                    entity_id=created_id,
                                    row_metadata={}
                                )
                                self.db.add(audit_row)
                                total_successful += 1

                        except Exception as row_ex:
                            # Row execution failure (rolls back nested savepoint only)
                            total_failed += 1
                            err_str = str(row_ex)
                            if "STUDENT_NOT_FOUND" in err_str:
                                row_error_code = "STUDENT_NOT_FOUND"
                                row_error_message = err_str.split(":", 1)[-1].strip()
                            elif "GUARDIAN_NOT_FOUND" in err_str:
                                row_error_code = "GUARDIAN_NOT_FOUND"
                                row_error_message = err_str.split(":", 1)[-1].strip()
                            elif "MAPPING_ALREADY_EXISTS" in err_str or "already mapped" in err_str or "409" in err_str:
                                row_error_code = "MAPPING_ALREADY_EXISTS"
                                row_error_message = err_str.split(":", 1)[-1].strip()
                            elif "PRIMARY_GUARDIAN_LIMIT_EXCEEDED" in err_str or "primary guardian has already been assigned" in err_str:
                                row_error_code = "PRIMARY_GUARDIAN_LIMIT_EXCEEDED"
                                row_error_message = err_str.split(":", 1)[-1].strip()
                            else:
                                row_error_code = "EXECUTION_FAILURE"
                                row_error_message = err_str

                            row.validation_status = "failed_execution"
                            row.validation_error_code = row_error_code
                            row.validation_error_message = row_error_message
                            self.db.add(row)

                            audit_row = ImportJobRow(
                                import_job_id=job_id,
                                row_number=row.row_number,
                                status="failed",
                                error_code=row_error_code,
                                error_message=row_error_message,
                                source_identifier=f"{row.student_admission_number}_{row.guardian_id}",
                                row_metadata={}
                            )
                            self.db.add(audit_row)

                    # Commit chunk changes
                    self.db.commit = original_commit
                    await self.db.commit()
                    self.db.commit = mock_commit

                # Update job final counters and status
                job.processed_rows = total_successful + total_failed
                job.successful_rows = total_successful
                job.failed_rows = total_failed
                job.skipped_rows = total_skipped
                job.completed_at = datetime.now(timezone.utc)
                if total_failed > 0:
                    job.status = ImportJobStatus.COMPLETED_WITH_ERRORS
                else:
                    job.status = ImportJobStatus.COMPLETED
                self.db.add(job)
                self.db.commit = original_commit
                await self.db.commit()
                await self.db.refresh(job)
                return job

            except Exception as outer_ex:
                # Fatal execution exception
                self.db.commit = original_commit
                await self.db.rollback()
                job.status = ImportJobStatus.FAILED
                job.error_summary = f"Fatal execution error: {outer_ex}"
                job.completed_at = datetime.now(timezone.utc)
                self.db.add(job)
                await self.db.commit()
                await self.db.refresh(job)
                raise outer_ex

        finally:
            self.db.commit = original_commit




