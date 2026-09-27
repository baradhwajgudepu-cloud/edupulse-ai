import uuid
from datetime import date
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import get_current_user
from app.models.user import User
from app.services.syllabus_prediction_engine import SyllabusPredictionEngine
from app.services.cross_teacher_recovery_service import CrossTeacherRecoveryService
from app.repositories.syllabus_recovery import SyllabusRecoveryRepository
from app.schemas.syllabus_recovery import (
    SyllabusRecoveryPlanCreate, SyllabusRecoveryPlanRead, RecoveryPlanItemRead,
    RecoveryPlanItemUpdate, RecoveryValidationRequest, RecoveryValidationResponse,
    RecoveryApprovalRequest, StudentSyllabusProgressResponse, TeacherAbsenceImpactResponse,
    AcademicHeatmapResponse, CandidateEvaluation, CrossTeacherRecoveryRecommendation,
    CrossTeacherApprovalRequest, CrossTeacherEditRequest, RecoveryAnalyticsSummary
)
from app.schemas.response import APIResponse

router = APIRouter()

def get_prediction_engine(db: AsyncSession = Depends(get_db)) -> SyllabusPredictionEngine:
    return SyllabusPredictionEngine(db=db)

def get_recovery_repo(db: AsyncSession = Depends(get_db)) -> SyllabusRecoveryRepository:
    return SyllabusRecoveryRepository(db=db)

def get_cross_teacher_service(db: AsyncSession = Depends(get_db)) -> CrossTeacherRecoveryService:
    return CrossTeacherRecoveryService(db=db)


@router.get(
    "/absence-impact",
    response_model=APIResponse[TeacherAbsenceImpactResponse],
    summary="Analyze teacher absence ripple effect on syllabus and timetable schedule"
)
async def get_teacher_absence_impact(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    teacher_id: uuid.UUID = Query(...),
    absence_date: date = Query(...),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine),
    current_user: User = Depends(get_current_user)
) -> APIResponse[TeacherAbsenceImpactResponse]:
    impact = await engine.analyze_teacher_absence_impact(
        school_id=school_id,
        academic_year_id=academic_year_id,
        teacher_id=teacher_id,
        absence_date=absence_date
    )
    return APIResponse[TeacherAbsenceImpactResponse](
        success=True,
        message="Teacher absence impact analyzed successfully.",
        data=impact
    )


@router.post(
    "/plans/generate",
    response_model=APIResponse[SyllabusRecoveryPlanRead],
    status_code=status.HTTP_201_CREATED,
    summary="Generate 4-phase AI Syllabus Recovery Plan (Catch-up, Core, Practice, Buffer)"
)
async def generate_recovery_plan(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    class_id: uuid.UUID = Query(...),
    section_id: uuid.UUID = Query(...),
    subject_id: uuid.UUID = Query(...),
    reason: str = Query(..., min_length=3),
    target_completion_date: Optional[date] = Query(None),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine),
    current_user: User = Depends(get_current_user)
) -> APIResponse[SyllabusRecoveryPlanRead]:
    plan = await engine.generate_syllabus_recovery_plan(
        school_id=school_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        section_id=section_id,
        subject_id=subject_id,
        reason=reason,
        target_completion_date=target_completion_date,
        created_by=current_user.id
    )
    await engine.db.commit()
    return APIResponse[SyllabusRecoveryPlanRead](
        success=True,
        message="AI Syllabus Recovery Plan generated successfully.",
        data=plan
    )


@router.get(
    "/plans",
    response_model=APIResponse[List[SyllabusRecoveryPlanRead]],
    summary="List syllabus recovery plans"
)
async def list_recovery_plans(
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    class_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    subject_id: Optional[uuid.UUID] = Query(None),
    teacher_id: Optional[uuid.UUID] = Query(None),
    plan_status: Optional[str] = Query(None, alias="status"),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine),
    repo: SyllabusRecoveryRepository = Depends(get_recovery_repo),
    current_user: User = Depends(get_current_user)
) -> APIResponse[List[SyllabusRecoveryPlanRead]]:
    plans = await repo.get_plans(
        school_id=school_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        section_id=section_id,
        subject_id=subject_id,
        teacher_id=teacher_id,
        status=plan_status
    )
    read_plans = [await engine._plan_to_read_schema(p) for p in plans]
    return APIResponse[List[SyllabusRecoveryPlanRead]](
        success=True,
        message="Retrieved syllabus recovery plans.",
        data=read_plans
    )


@router.get(
    "/plans/{plan_id}",
    response_model=APIResponse[SyllabusRecoveryPlanRead],
    summary="Get single recovery plan by ID with items"
)
async def get_recovery_plan(
    plan_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine),
    repo: SyllabusRecoveryRepository = Depends(get_recovery_repo),
    current_user: User = Depends(get_current_user)
) -> APIResponse[SyllabusRecoveryPlanRead]:
    plan = await repo.get_plan_by_id(plan_id, school_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Recovery plan not found.")
    read_plan = await engine._plan_to_read_schema(plan)
    return APIResponse[SyllabusRecoveryPlanRead](
        success=True,
        message="Retrieved syllabus recovery plan.",
        data=read_plan
    )


@router.put(
    "/plans/{plan_id}/items/{item_id}",
    response_model=APIResponse[RecoveryPlanItemRead],
    summary="Update candidate recovery slot and automatically re-validate conflicts"
)
async def update_recovery_item(
    plan_id: uuid.UUID,
    item_id: uuid.UUID,
    obj_in: RecoveryPlanItemUpdate,
    school_id: uuid.UUID = Query(...),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine),
    current_user: User = Depends(get_current_user)
) -> APIResponse[RecoveryPlanItemRead]:
    try:
        updated_item = await engine.update_recovery_plan_item(
            school_id=school_id,
            plan_id=plan_id,
            item_id=item_id,
            update_data=obj_in,
            user_id=current_user.id
        )
        await engine.db.commit()
        return APIResponse[RecoveryPlanItemRead](
            success=True,
            message="Recovery slot updated and re-validated.",
            data=updated_item
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/plans/{plan_id}/regenerate",
    response_model=APIResponse[SyllabusRecoveryPlanRead],
    summary="Regenerate remaining unapproved recovery periods preserving approved/modified ones"
)
async def regenerate_plan(
    plan_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine),
    current_user: User = Depends(get_current_user)
) -> APIResponse[SyllabusRecoveryPlanRead]:
    try:
        plan = await engine.regenerate_recovery_plan(
            school_id=school_id,
            plan_id=plan_id,
            user_id=current_user.id
        )
        await engine.db.commit()
        return APIResponse[SyllabusRecoveryPlanRead](
            success=True,
            message="Remaining plan regenerated successfully.",
            data=plan
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/plans/{plan_id}/approve",
    response_model=APIResponse[SyllabusRecoveryPlanRead],
    summary="Approve recovery plan, commit timetable changes, and dispatch teacher notification"
)
async def approve_plan(
    plan_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine),
    current_user: User = Depends(get_current_user)
) -> APIResponse[SyllabusRecoveryPlanRead]:
    try:
        plan = await engine.approve_recovery_plan(
            school_id=school_id,
            plan_id=plan_id,
            user_id=current_user.id
        )
        await engine.db.commit()
        return APIResponse[SyllabusRecoveryPlanRead](
            success=True,
            message="Syllabus recovery plan approved and timetable updated.",
            data=plan
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/plans/{plan_id}/reject",
    response_model=APIResponse[SyllabusRecoveryPlanRead],
    summary="Reject recovery plan with optional remarks"
)
async def reject_plan(
    plan_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    req: RecoveryApprovalRequest = RecoveryApprovalRequest(action="REJECT"),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine),
    current_user: User = Depends(get_current_user)
) -> APIResponse[SyllabusRecoveryPlanRead]:
    try:
        plan = await engine.reject_recovery_plan(
            school_id=school_id,
            plan_id=plan_id,
            user_id=current_user.id,
            remarks=req.remarks
        )
        await engine.db.commit()
        return APIResponse[SyllabusRecoveryPlanRead](
            success=True,
            message="Recovery plan rejected.",
            data=plan
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/validate",
    response_model=APIResponse[RecoveryValidationResponse],
    summary="Validate proposed recovery slots against teacher, room, holiday, and exam conflicts"
)
async def validate_candidate_slots(
    req: RecoveryValidationRequest,
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine),
    current_user: User = Depends(get_current_user)
) -> APIResponse[RecoveryValidationResponse]:
    res = await engine.validate_recovery_plan(
        school_id=req.school_id,
        academic_year_id=req.academic_year_id,
        items=req.items
    )
    return APIResponse[RecoveryValidationResponse](
        success=True,
        message=f"Validated {len(req.items)} candidate slots ({res.total_conflicts} conflict(s) detected).",
        data=res
    )


@router.get(
    "/student-progress",
    response_model=APIResponse[StudentSyllabusProgressResponse],
    summary="Get sanitized student/parent syllabus progress view (strictly excludes internal remarks)"
)
async def get_student_syllabus_progress(
    student_id: uuid.UUID = Query(...),
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine),
    current_user: User = Depends(get_current_user)
) -> APIResponse[StudentSyllabusProgressResponse]:
    try:
        progress = await engine.get_student_syllabus_progress(
            school_id=school_id,
            academic_year_id=academic_year_id,
            student_id=student_id
        )
        return APIResponse[StudentSyllabusProgressResponse](
            success=True,
            message="Retrieved student syllabus progress.",
            data=progress
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get(
    "/academic-heatmap",
    response_model=APIResponse[AcademicHeatmapResponse],
    summary="Get school-wide Academic Health Heatmap (Classes × Subjects)"
)
async def get_academic_heatmap(
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine),
    current_user: User = Depends(get_current_user)
) -> APIResponse[AcademicHeatmapResponse]:
    if not academic_year_id:
        from app.models.academic_year import AcademicYear, AcademicYearStatus
        from sqlalchemy import select
        ay_stmt = select(AcademicYear).where(
            AcademicYear.school_id == school_id,
            AcademicYear.status == AcademicYearStatus.ACTIVE,
            AcademicYear.deleted_at.is_(None)
        ).order_by(AcademicYear.start_date.desc())
        ay_res = await engine.db.execute(ay_stmt)
        ay = ay_res.scalars().first()
        if ay:
            academic_year_id = ay.id
        else:
            ay_stmt2 = select(AcademicYear).where(
                AcademicYear.school_id == school_id,
                AcademicYear.deleted_at.is_(None)
            ).order_by(AcademicYear.created_at.desc())
            ay_res2 = await engine.db.execute(ay_stmt2)
            ay2 = ay_res2.scalars().first()
            if ay2:
                academic_year_id = ay2.id
            else:
                raise HTTPException(status_code=400, detail="No academic year found for school.")

    heatmap = await engine.get_academic_heatmap(
        school_id=school_id,
        academic_year_id=academic_year_id
    )
    return APIResponse[AcademicHeatmapResponse](
        success=True,
        message="Retrieved academic heatmap.",
        data=heatmap
    )


# =============================================================================
# CROSS-TEACHER SYLLABUS RECOVERY INTELLIGENCE ENDPOINTS
# =============================================================================

@router.get(
    "/cross-teacher/candidates",
    response_model=APIResponse[List[CandidateEvaluation]],
    summary="Evaluate eligible peer teacher recovery candidates against 15 academic and timetable constraints"
)
async def get_recovery_candidates(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    class_id: uuid.UUID = Query(...),
    section_id: uuid.UUID = Query(...),
    subject_id: uuid.UUID = Query(...),
    exclude_teacher_id: Optional[uuid.UUID] = Query(None),
    service: CrossTeacherRecoveryService = Depends(get_cross_teacher_service),
    current_user: User = Depends(get_current_user)
) -> APIResponse[List[CandidateEvaluation]]:
    candidates = await service.find_eligible_candidates_for_recovery(
        school_id=school_id,
        academic_year_id=academic_year_id,
        target_class_id=class_id,
        target_section_id=section_id,
        target_subject_id=subject_id,
        exclude_teacher_id=exclude_teacher_id
    )
    return APIResponse[List[CandidateEvaluation]](
        success=True,
        message=f"Evaluated {len(candidates)} peer teacher candidate(s).",
        data=candidates
    )


@router.post(
    "/cross-teacher/recommendations/generate",
    response_model=APIResponse[CrossTeacherRecoveryRecommendation],
    status_code=status.HTTP_201_CREATED,
    summary="Generate AI cross-teacher syllabus recovery recommendation with factual candidate comparison"
)
async def generate_cross_teacher_recommendation(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    class_id: uuid.UUID = Query(...),
    section_id: uuid.UUID = Query(...),
    subject_id: uuid.UUID = Query(...),
    reason: Optional[str] = Query(None),
    service: CrossTeacherRecoveryService = Depends(get_cross_teacher_service),
    current_user: User = Depends(get_current_user)
) -> APIResponse[CrossTeacherRecoveryRecommendation]:
    rec = await service.generate_recovery_recommendation(
        school_id=school_id,
        academic_year_id=academic_year_id,
        class_id=class_id,
        section_id=section_id,
        subject_id=subject_id,
        reason=reason,
        user_id=current_user.id
    )
    await service.db.commit()
    return APIResponse[CrossTeacherRecoveryRecommendation](
        success=True,
        message="AI Cross-Teacher recovery recommendation generated. Review and approve before publishing.",
        data=rec
    )


@router.post(
    "/cross-teacher/plans/{plan_id}/approve",
    response_model=APIResponse[SyllabusRecoveryPlanRead],
    summary="Principal approves cross-teacher recovery plan, commits timetable slot with badge, and recalculates"
)
async def approve_cross_teacher_plan(
    plan_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    req: CrossTeacherApprovalRequest = CrossTeacherApprovalRequest(action="APPROVE"),
    service: CrossTeacherRecoveryService = Depends(get_cross_teacher_service),
    current_user: User = Depends(get_current_user)
) -> APIResponse[SyllabusRecoveryPlanRead]:
    try:
        plan = await service.approve_recovery_plan(
            school_id=school_id,
            plan_id=plan_id,
            selected_teacher_id=req.selected_teacher_id,
            user_id=current_user.id
        )
        await service.db.commit()
        return APIResponse[SyllabusRecoveryPlanRead](
            success=True,
            message="Cross-teacher recovery plan approved. Timetable updated with RECOVERY CLASS badge.",
            data=plan
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/cross-teacher/plans/{plan_id}/reject",
    response_model=APIResponse[SyllabusRecoveryPlanRead],
    summary="Principal rejects cross-teacher recovery plan with optional remarks"
)
async def reject_cross_teacher_plan(
    plan_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    req: CrossTeacherApprovalRequest = CrossTeacherApprovalRequest(action="REJECT"),
    service: CrossTeacherRecoveryService = Depends(get_cross_teacher_service),
    current_user: User = Depends(get_current_user)
) -> APIResponse[SyllabusRecoveryPlanRead]:
    try:
        plan = await service.reject_recovery_plan(
            school_id=school_id,
            plan_id=plan_id,
            remarks=req.remarks,
            user_id=current_user.id
        )
        await service.db.commit()
        return APIResponse[SyllabusRecoveryPlanRead](
            success=True,
            message="Cross-teacher recovery plan rejected.",
            data=plan
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.put(
    "/cross-teacher/plans/{plan_id}/edit",
    response_model=APIResponse[SyllabusRecoveryPlanRead],
    summary="Principal edits recovery candidate teacher, frequency, duration, or slots"
)
async def edit_cross_teacher_plan(
    plan_id: uuid.UUID,
    edit_req: CrossTeacherEditRequest,
    school_id: uuid.UUID = Query(...),
    service: CrossTeacherRecoveryService = Depends(get_cross_teacher_service),
    current_user: User = Depends(get_current_user)
) -> APIResponse[SyllabusRecoveryPlanRead]:
    try:
        plan = await service.edit_recovery_plan(
            school_id=school_id,
            plan_id=plan_id,
            edit_req=edit_req,
            user_id=current_user.id
        )
        await service.db.commit()
        return APIResponse[SyllabusRecoveryPlanRead](
            success=True,
            message="Cross-teacher recovery plan edited successfully.",
            data=plan
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post(
    "/cross-teacher/plans/{plan_id}/cancel",
    response_model=APIResponse[SyllabusRecoveryPlanRead],
    summary="Cancel approved recovery plan, safely roll back timetable slots, and recalculate prediction"
)
async def cancel_cross_teacher_plan(
    plan_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    reason: Optional[str] = Query(None),
    service: CrossTeacherRecoveryService = Depends(get_cross_teacher_service),
    current_user: User = Depends(get_current_user)
) -> APIResponse[SyllabusRecoveryPlanRead]:
    try:
        plan = await service.cancel_recovery_plan(
            school_id=school_id,
            plan_id=plan_id,
            reason=reason,
            user_id=current_user.id
        )
        await service.db.commit()
        return APIResponse[SyllabusRecoveryPlanRead](
            success=True,
            message="Recovery plan cancelled and timetable slots safely reverted.",
            data=plan
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get(
    "/analytics",
    response_model=APIResponse[RecoveryAnalyticsSummary],
    summary="School-wide recovery analytics distinguishing normal, recovery, cross-teacher, and absence teaching"
)
async def get_recovery_analytics(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    service: CrossTeacherRecoveryService = Depends(get_cross_teacher_service),
    current_user: User = Depends(get_current_user)
) -> APIResponse[RecoveryAnalyticsSummary]:
    analytics = await service.get_recovery_analytics(
        school_id=school_id,
        academic_year_id=academic_year_id
    )
    return APIResponse[RecoveryAnalyticsSummary](
        success=True,
        message="Retrieved academic recovery analytics.",
        data=analytics
    )

