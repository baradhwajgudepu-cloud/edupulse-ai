from datetime import date
import uuid
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import get_current_user
from app.models.user import User
from app.models.timetable_recommendation import TimetableRecommendation
from app.repositories.timetable import TimetableRepository
from app.repositories.timetable_recommendation import TimetableRecommendationRepository
from app.services.timetable_ai_engine import TimetableAIEngine
from app.services.syllabus_prediction_engine import SyllabusPredictionEngine
from app.schemas.academic_calendar import HolidayImpactResponse, AIRecoveryPreviewResponse
from app.schemas.academic_planning import (
    AcademicPlanningSummary, SyllabusPredictionItem,
    TimetableAIRecommendationRequest, TimetableAIRecommendationResponse,
    TimetableGridValidationRequest, TimetableGridValidationResponse,
    AdaptiveRecommendationItem, TimetableAIApproveRequest
)
from app.schemas.response import APIResponse

router = APIRouter()

def get_timetable_ai_engine(db: AsyncSession = Depends(get_db)) -> TimetableAIEngine:
    return TimetableAIEngine(
        db=db,
        timetable_repo=TimetableRepository(db),
        recommendation_repo=TimetableRecommendationRepository(db)
    )

def get_prediction_engine(db: AsyncSession = Depends(get_db)) -> SyllabusPredictionEngine:
    return SyllabusPredictionEngine(db=db)

@router.get(
    "/summary",
    response_model=APIResponse[AcademicPlanningSummary],
    summary="Get school-wide academic planning overview with completion and at-risk metrics"
)
async def get_academic_planning_summary(
    school_id: uuid.UUID = Query(...),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine)
) -> APIResponse[AcademicPlanningSummary]:
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

    summary = await engine.get_school_planning_summary(
        school_id=school_id,
        academic_year_id=academic_year_id,
        tenant_id=tenant_id
    )
    return APIResponse[AcademicPlanningSummary](
        success=True,
        message="Retrieved academic planning summary.",
        data=summary
    )

@router.get(
    "/predictions",
    response_model=APIResponse[List[SyllabusPredictionItem]],
    summary="Get syllabus completion predictions for a class or subject"
)
async def get_syllabus_predictions(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    class_id: uuid.UUID = Query(...),
    subject_id: Optional[uuid.UUID] = Query(None),
    section_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine)
) -> APIResponse[List[SyllabusPredictionItem]]:
    from sqlalchemy import select
    from app.models.subject import Subject

    subject_ids = []
    if subject_id:
        subject_ids = [subject_id]
    else:
        db = engine.db
        stmt = select(Subject.id).where(
            Subject.school_id == school_id,
            Subject.academic_year_id == academic_year_id,
            Subject.deleted_at.is_(None)
        )
        res = await db.execute(stmt)
        subject_ids = list(res.scalars().all())

    results = []
    for s_id in subject_ids:
        pred = await engine.predict_subject_completion(
            school_id=school_id,
            academic_year_id=academic_year_id,
            class_id=class_id,
            subject_id=s_id,
            section_id=section_id
        )
        results.append(pred)

    return APIResponse[List[SyllabusPredictionItem]](
        success=True,
        message="Calculated syllabus completion predictions.",
        data=results
    )

@router.post(
    "/timetable-recommendations",
    response_model=APIResponse[TimetableAIRecommendationResponse],
    status_code=status.HTTP_200_OK,
    summary="Generate AI syllabus-aware timetable recommendation for class/section"
)
@router.post(
    "/timetable-ai/recommend",
    response_model=APIResponse[TimetableAIRecommendationResponse],
    status_code=status.HTTP_200_OK,
    summary="Generate AI syllabus-aware timetable recommendation (alias)"
)
async def generate_timetable_recommendation(
    req: TimetableAIRecommendationRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: TimetableAIEngine = Depends(get_timetable_ai_engine)
) -> APIResponse[TimetableAIRecommendationResponse]:
    res = await engine.generate_recommendation(
        tenant_id=tenant_id,
        req=req,
        current_user=current_user
    )
    return APIResponse[TimetableAIRecommendationResponse](
        success=True,
        message="AI Timetable recommendation generated successfully. Review and approve before publishing.",
        data=res
    )

@router.get(
    "/timetable-recommendations",
    response_model=APIResponse[List[dict]],
    summary="List timetable recommendations for a school or section"
)
async def list_timetable_recommendations(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    section_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: TimetableAIEngine = Depends(get_timetable_ai_engine)
) -> APIResponse[List[dict]]:
    if section_id:
        rec = await engine.recommendation_repo.get_latest_for_section(
            school_id=school_id,
            section_id=section_id,
            tenant_id=tenant_id
        )
        data = [
            {
                "id": str(rec.id),
                "section_id": str(rec.section_id),
                "class_id": str(rec.class_id),
                "status": rec.status,
                "created_at": rec.created_at.isoformat() if rec.created_at else None,
                "suggested_slots": rec.suggested_slots.get("slots", []),
                "rationale": rec.rationale,
                "risk_factors": rec.risk_factors
            }
        ] if rec else []
    else:
        recs = await engine.recommendation_repo.get_all_for_school(
            school_id=school_id,
            academic_year_id=academic_year_id,
            tenant_id=tenant_id
        )
        data = [
            {
                "id": str(r.id),
                "section_id": str(r.section_id),
                "class_id": str(r.class_id),
                "status": r.status,
                "created_at": r.created_at.isoformat() if r.created_at else None,
                "rationale": r.rationale,
                "risk_factors": r.risk_factors
            }
            for r in recs
        ]

    return APIResponse[List[dict]](
        success=True,
        message="Retrieved timetable recommendations.",
        data=data
    )

@router.post(
    "/timetable-recommendations/{recommendation_id}/approve",
    response_model=APIResponse[int],
    status_code=status.HTTP_200_OK,
    summary="Approve and publish an AI timetable recommendation into active schedules"
)
async def approve_and_publish_recommendation(
    recommendation_id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: TimetableAIEngine = Depends(get_timetable_ai_engine)
) -> APIResponse[int]:
    count = await engine.approve_and_publish_recommendation(
        tenant_id=tenant_id,
        school_id=school_id,
        recommendation_id=recommendation_id,
        current_user=current_user
    )
    return APIResponse[int](
        success=True,
        message=f"Timetable recommendation approved! {count} active slots published.",
        data=count
    )

@router.post(
    "/timetable-ai/approve",
    response_model=APIResponse[int],
    status_code=status.HTTP_200_OK,
    summary="Approve and publish an AI timetable recommendation via JSON payload"
)
async def approve_timetable_ai_json(
    req: TimetableAIApproveRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: TimetableAIEngine = Depends(get_timetable_ai_engine)
) -> APIResponse[int]:
    rec = await engine.recommendation_repo.get_by_id(
        recommendation_id=req.recommendation_id,
        tenant_id=tenant_id
    )
    if not rec:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recommendation not found.")
    count = await engine.approve_and_publish_recommendation(
        tenant_id=tenant_id,
        school_id=rec.school_id,
        recommendation_id=req.recommendation_id,
        current_user=current_user
    )
    return APIResponse[int](
        success=True,
        message=f"Timetable recommendation approved! {count} active slots published.",
        data=count
    )

@router.post(
    "/validate-timetable-grid",
    response_model=APIResponse[TimetableGridValidationResponse],
    status_code=status.HTTP_200_OK,
    summary="Validate timetable grid for teacher clashes, double booking, and period deficit"
)
@router.post(
    "/timetable-grid/validate",
    response_model=APIResponse[TimetableGridValidationResponse],
    status_code=status.HTTP_200_OK,
    summary="Validate timetable grid (alias)"
)
async def validate_timetable_grid(
    req: TimetableGridValidationRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: TimetableAIEngine = Depends(get_timetable_ai_engine)
) -> APIResponse[TimetableGridValidationResponse]:
    res = await engine.validate_grid(
        tenant_id=tenant_id,
        req=req
    )
    return APIResponse[TimetableGridValidationResponse](
        success=not res.has_conflict,
        message="Validation completed.",
        data=res
    )

@router.get(
    "/adaptive-recommendations",
    response_model=APIResponse[List[AdaptiveRecommendationItem]],
    summary="Get continuous pace-recovery recommendations for at-risk subjects"
)
async def get_adaptive_recommendations(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: SyllabusPredictionEngine = Depends(get_prediction_engine)
) -> APIResponse[List[AdaptiveRecommendationItem]]:
    summary = await engine.get_school_planning_summary(
        school_id=school_id,
        academic_year_id=academic_year_id,
        tenant_id=tenant_id
    )
    return APIResponse[List[AdaptiveRecommendationItem]](
        success=True,
        message="Retrieved adaptive pace-recovery recommendations.",
        data=summary.adaptive_recommendations
    )


@router.get(
    "/holiday-impact",
    response_model=APIResponse[HolidayImpactResponse],
    summary="Analyze timetable impact and exam conflicts for a holiday date"
)
async def get_holiday_impact(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    holiday_date: date = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: TimetableAIEngine = Depends(get_timetable_ai_engine)
) -> APIResponse[HolidayImpactResponse]:
    res = await engine.analyze_holiday_impact(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        holiday_date=holiday_date
    )
    return APIResponse[HolidayImpactResponse](
        success=True,
        message=res.get("message", "Calculated holiday impact."),
        data=HolidayImpactResponse(**res)
    )

@router.post(
    "/holiday-recovery/generate",
    response_model=APIResponse[AIRecoveryPreviewResponse],
    status_code=status.HTTP_200_OK,
    summary="Generate AI minimum-disruption timetable recovery recommendation for a holiday"
)
async def generate_holiday_recovery(
    school_id: uuid.UUID = Query(...),
    academic_year_id: uuid.UUID = Query(...),
    holiday_date: date = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: TimetableAIEngine = Depends(get_timetable_ai_engine)
) -> APIResponse[AIRecoveryPreviewResponse]:
    res = await engine.generate_holiday_recovery(
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=academic_year_id,
        holiday_date=holiday_date,
        current_user=current_user
    )
    return APIResponse[AIRecoveryPreviewResponse](
        success=True,
        message="AI holiday recovery recommendation generated. Review and approve before applying.",
        data=AIRecoveryPreviewResponse(**res)
    )

@router.post(
    "/holiday-recovery/{id}/apply",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Principal approves and applies timetable recovery changes"
)
async def apply_holiday_recovery(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: TimetableAIEngine = Depends(get_timetable_ai_engine)
) -> APIResponse[Dict[str, Any]]:
    res = await engine.approve_and_apply_holiday_recovery(
        tenant_id=tenant_id,
        school_id=school_id,
        recommendation_id=id,
        current_user=current_user
    )
    return APIResponse[Dict[str, Any]](
        success=True,
        message=res.get("message", "Applied recovery adjustments."),
        data=res
    )

@router.post(
    "/holiday-recovery/{id}/reject",
    response_model=APIResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Principal rejects timetable recovery recommendation"
)
async def reject_holiday_recovery(
    id: uuid.UUID,
    school_id: uuid.UUID = Query(...),
    remarks: Optional[str] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: TimetableAIEngine = Depends(get_timetable_ai_engine)
) -> APIResponse[Dict[str, Any]]:
    res = await engine.reject_holiday_recovery(
        tenant_id=tenant_id,
        school_id=school_id,
        recommendation_id=id,
        current_user=current_user,
        remarks=remarks
    )
    return APIResponse[Dict[str, Any]](
        success=True,
        message=res.get("message", "Rejected recovery recommendation."),
        data=res
    )
