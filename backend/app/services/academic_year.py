import uuid
from typing import List, Optional
from datetime import date
from fastapi import HTTPException, status
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.repositories.academic_year import AcademicYearRepository
from app.schemas.academic_year import AcademicYearCreate, AcademicYearUpdate

class AcademicYearService:
    """
    Service Layer containing business validations for Academic Years.
    Handles date overlaps, state machine constraints, transactional current switching, and delete protections.
    """
    def __init__(self, repo: AcademicYearRepository) -> None:
        self.repo = repo

    async def get_academic_year(
        self, ay_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> AcademicYear:
        """
        Retrieves a single academic year or raises a 404 error if not found.
        """
        ay = await self.repo.get_by_id(ay_id, school_id, tenant_id)
        if not ay:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Academic Year not found under the active school and tenant scopes."
            )
        return ay

    async def list_academic_years(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        skip: int = 0,
        limit: int = 100,
        status_filter: Optional[AcademicYearStatus] = None
    ) -> List[AcademicYear]:
        """
        Lists academic years matching pagination and status filters.
        """
        return await self.repo.get_multi(
            school_id=school_id,
            tenant_id=tenant_id,
            skip=skip,
            limit=limit,
            status=status_filter
        )

    async def get_current_academic_year(
        self, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> AcademicYear:
        """
        Fetches the current academic year, raising a 404 if none is configured.
        """
        ay = await self.repo.get_current_year(school_id, tenant_id)
        if not ay:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No current academic year has been configured for this school."
            )
        return ay

    async def create_academic_year(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        obj_in: AcademicYearCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> AcademicYear:
        """
        Registers a new academic year within a school scope, executing overlap and validation rules.
        """
        # 1. Validate composite uniqueness (name & code) within the school
        if await self.repo.get_by_name(obj_in.name, school_id, tenant_id):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Academic year name '{obj_in.name}' is already registered under this school."
            )
        if await self.repo.get_by_code(obj_in.code, school_id, tenant_id):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Academic year code '{obj_in.code}' is already registered under this school."
            )

        # 2. Validate date overlaps
        await self._check_date_overlaps(
            school_id=school_id,
            tenant_id=tenant_id,
            start_date=obj_in.start_date,
            end_date=obj_in.end_date
        )

        # 3. Handle transactional is_current toggle
        if obj_in.is_current:
            await self._disable_current_year(school_id, tenant_id)

        # 4. Handle status = ACTIVE limits
        if obj_in.status == AcademicYearStatus.ACTIVE:
            await self._complete_active_year(school_id, tenant_id)

        return await self.repo.create(tenant_id, school_id, obj_in, created_by=created_by)

    async def update_academic_year(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        ay_id: uuid.UUID,
        obj_in: AcademicYearUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> AcademicYear:
        """
        Modifies properties of an existing Academic Year.
        """
        ay = await self.get_academic_year(ay_id, school_id, tenant_id)

        # 1. Validate composite uniqueness if changing name/code
        if obj_in.name is not None and obj_in.name != ay.name:
            if await self.repo.get_by_name(obj_in.name, school_id, tenant_id):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Academic year name '{obj_in.name}' is already registered under this school."
                )
        if obj_in.code is not None and obj_in.code != ay.code:
            if await self.repo.get_by_code(obj_in.code, school_id, tenant_id):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Academic year code '{obj_in.code}' is already registered under this school."
                )

        # 2. Validate state machine transition logic
        if obj_in.status is not None and obj_in.status != ay.status:
            self._validate_state_transition(current_state=ay.status, target_state=obj_in.status)
            
            # If transitioning to ACTIVE, automatically complete previous active year
            if obj_in.status == AcademicYearStatus.ACTIVE:
                await self._complete_active_year(school_id, tenant_id, exclude_id=ay.id)
            
            # Block transition to ARCHIVED if currently marked as current
            if obj_in.status == AcademicYearStatus.ARCHIVED and ay.is_current:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Cannot archive the current academic year. Switch the current year first."
                )

        # 3. Validate date overlaps if changing dates
        new_start = obj_in.start_date if obj_in.start_date is not None else ay.start_date
        new_end = obj_in.end_date if obj_in.end_date is not None else ay.end_date
        if obj_in.start_date is not None or obj_in.end_date is not None:
            await self._check_date_overlaps(
                school_id=school_id,
                tenant_id=tenant_id,
                start_date=new_start,
                end_date=new_end,
                exclude_id=ay.id
            )

        # 4. Handle transactional is_current toggle
        if obj_in.is_current is True and not ay.is_current:
            # Block switching to current if the year is archived
            target_status = obj_in.status if obj_in.status is not None else ay.status
            if target_status == AcademicYearStatus.ARCHIVED:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Cannot set an archived academic year as current."
                )
            await self._disable_current_year(school_id, tenant_id, exclude_id=ay.id)

        return await self.repo.update(ay, obj_in, updated_by=updated_by)

    async def delete_academic_year(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        ay_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> AcademicYear:
        """
        Soft-deletes the selected year, blocking deletes on current years.
        """
        ay = await self.get_academic_year(ay_id, school_id, tenant_id)
        if ay.is_current:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Cannot delete the current academic year. Please transition the current year parameter first."
            )
        return await self.repo.soft_delete(ay, deleted_by=deleted_by)

    async def activate_academic_year(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, ay_id: uuid.UUID, updated_by: Optional[uuid.UUID] = None
    ) -> AcademicYear:
        """
        Transitions status of academic year to ACTIVE.
        """
        return await self.update_academic_year(
            tenant_id=tenant_id,
            school_id=school_id,
            ay_id=ay_id,
            obj_in=AcademicYearUpdate(status=AcademicYearStatus.ACTIVE),
            updated_by=updated_by
        )

    async def archive_academic_year(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, ay_id: uuid.UUID, updated_by: Optional[uuid.UUID] = None
    ) -> AcademicYear:
        """
        Transitions status of academic year to ARCHIVED.
        """
        return await self.update_academic_year(
            tenant_id=tenant_id,
            school_id=school_id,
            ay_id=ay_id,
            obj_in=AcademicYearUpdate(status=AcademicYearStatus.ARCHIVED),
            updated_by=updated_by
        )

    # --- Private Helper Methods ---

    async def _check_date_overlaps(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        start_date: date,
        end_date: date,
        exclude_id: Optional[uuid.UUID] = None
    ) -> None:
        """
        Checks that a date range does not overlap with any existing academic years in the school.
        """
        existing_years = await self.repo.get_all_active_ranges(school_id, tenant_id)
        for ey in existing_years:
            if exclude_id and ey.id == exclude_id:
                continue
            
            # Range overlap formula: new_start < existing_end and new_end > existing_start
            if start_date < ey.end_date and end_date > ey.start_date:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"The selected date range overlaps with academic year '{ey.name}' ({ey.start_date} to {ey.end_date})."
                )

    async def _disable_current_year(
        self, school_id: uuid.UUID, tenant_id: uuid.UUID, exclude_id: Optional[uuid.UUID] = None
    ) -> None:
        """
        Transactional Switch: Disables is_current for any existing current year under the school.
        """
        current_year = await self.repo.get_current_year(school_id, tenant_id)
        if current_year:
            if exclude_id and current_year.id == exclude_id:
                return
            await self.repo.update(current_year, AcademicYearUpdate(is_current=False))

    async def _complete_active_year(
        self, school_id: uuid.UUID, tenant_id: uuid.UUID, exclude_id: Optional[uuid.UUID] = None
    ) -> None:
        """
        Transactional status transition: Moves any currently ACTIVE year to COMPLETED.
        """
        active_year = await self.repo.get_active_year(school_id, tenant_id)
        if active_year:
            if exclude_id and active_year.id == exclude_id:
                return
            await self.repo.update(active_year, AcademicYearUpdate(status=AcademicYearStatus.COMPLETED))

    def _validate_state_transition(
        self, current_state: AcademicYearStatus, target_state: AcademicYearStatus
    ) -> None:
        """
        Enforces status flow logic: UPCOMING -> ACTIVE -> COMPLETED -> ARCHIVED.
        Also allows UPCOMING -> ARCHIVED.
        """
        valid_transitions = {
            AcademicYearStatus.UPCOMING: [AcademicYearStatus.ACTIVE, AcademicYearStatus.ARCHIVED],
            AcademicYearStatus.ACTIVE: [AcademicYearStatus.COMPLETED],
            AcademicYearStatus.COMPLETED: [AcademicYearStatus.ARCHIVED],
            AcademicYearStatus.ARCHIVED: []
        }
        
        allowed = valid_transitions.get(current_state, [])
        if target_state not in allowed:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Invalid state transition: Cannot transition from status '{current_state}' to '{target_state}'."
            )
