import uuid
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy import select, func, and_, text
from sqlalchemy.orm import Session

from app.models.import_job import ImportJob, ImportJobRow, ImportType, ImportJobStatus
from app.schemas.import_job import ImportJobCreate, ImportJobRowCreate

class ImportJobService:
    def __init__(self, db: Session) -> None:
        self.db = db

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

        job.status = ImportJobStatus.RUNNING
        job.started_at = datetime.now(timezone.utc)
        self.db.add(job)
        await self.db.commit()
        await self.db.refresh(job)
        return job

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
