import uuid
from typing import List, Optional, Dict
from fastapi import APIRouter, Depends, Query, Body, status, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import get_current_user
from app.models.user import User
from app.repositories.curriculum import CurriculumRepository
from app.repositories.syllabus import SyllabusRepository
from app.services.curriculum_engine import CurriculumEngine
from app.models.syllabus import Syllabus
from app.schemas.syllabus import SyllabusResponse
from app.schemas.curriculum import (
    CurriculumMasterRead,
    CurriculumPopulateRequest,
    CurriculumPopulateResponse,
    CurriculumStatusRead,
    CurriculumPopulateResultRead,
    CurriculumDerivePreviousRequest,
    SyllabusImportRequest,
    CurriculumResolveResponse,
    CurriculumResolveSubject,
    CustomChapterRequest,
    AIDraftSyllabusRequest,
    AIDraftSyllabusResponse,
    AIDraftSyllabusApproveRequest
)
from app.schemas.response import APIResponse


router = APIRouter()

def get_curriculum_engine(db: AsyncSession = Depends(get_db)) -> CurriculumEngine:
    return CurriculumEngine(
        db=db,
        curriculum_repo=CurriculumRepository(db),
        syllabus_repo=SyllabusRepository(db)
    )

@router.get(
    "/status",
    response_model=APIResponse[CurriculumStatusRead],
    summary="Get board-based curriculum status and metrics for a school"
)
async def get_curriculum_status(
    school_id: uuid.UUID = Query(..., description="Target School ID"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Optional target Academic Year ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: CurriculumEngine = Depends(get_curriculum_engine)
) -> APIResponse[CurriculumStatusRead]:
    status_data = await engine.get_school_curriculum_status(
        school_id=school_id,
        academic_year_id=academic_year_id,
        tenant_id=tenant_id
    )
    return APIResponse[CurriculumStatusRead](
        success=True,
        message="Retrieved curriculum setup status.",
        data=status_data
    )

@router.post(
    "/auto-populate",
    response_model=APIResponse[CurriculumPopulateResultRead],
    status_code=status.HTTP_200_OK,
    summary="Auto-populate official board curriculum for all configured classes/subjects in active academic year"
)
async def auto_populate_curriculum(
    school_id: uuid.UUID = Query(..., description="Target School ID"),
    override_existing: bool = Query(False, description="Whether to replace existing syllabus copies"),
    academic_year_id: Optional[uuid.UUID] = Query(None, description="Optional target Academic Year ID"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: CurriculumEngine = Depends(get_curriculum_engine)
) -> APIResponse[CurriculumPopulateResultRead]:
    result = await engine.auto_populate_school(
        tenant_id=tenant_id,
        school_id=school_id,
        current_user=current_user,
        override_existing=override_existing,
        academic_year_id=academic_year_id
    )
    return APIResponse[CurriculumPopulateResultRead](
        success=result.success,
        message=result.message,
        data=result
    )

@router.post(
    "/populate-from-board",
    response_model=APIResponse[CurriculumPopulateResultRead],
    status_code=status.HTTP_200_OK,
    summary="Populate school syllabus from verified board curriculum template"
)
async def populate_from_board(
    req: Optional[CurriculumPopulateRequest] = Body(None),
    school_id: Optional[uuid.UUID] = Query(None),
    override_existing: bool = Query(False),
    academic_year_id: Optional[uuid.UUID] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: CurriculumEngine = Depends(get_curriculum_engine)
) -> APIResponse[CurriculumPopulateResultRead]:
    target_school_id = req.school_id if req else school_id
    if not target_school_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="school_id is required.")

    target_ay_id = req.academic_year_id if req and req.academic_year_id else academic_year_id
    target_override = req.override_existing if req else override_existing

    result = await engine.auto_populate_school(
        tenant_id=tenant_id,
        school_id=target_school_id,
        current_user=current_user,
        override_existing=target_override,
        academic_year_id=target_ay_id,
        class_ids=req.class_ids if req else None,
        subject_ids=req.subject_ids if req else None,
        board=req.board if req else None,
        state=req.state if req else None
    )
    return APIResponse[CurriculumPopulateResultRead](
        success=result.success,
        message=result.message,
        data=result
    )

@router.post(
    "/populate-school-syllabus",
    response_model=APIResponse[CurriculumPopulateResponse],
    status_code=status.HTTP_200_OK,
    summary="Populate school syllabus from verified board curriculum template (legacy endpoint)"
)
async def populate_school_syllabus(
    req: CurriculumPopulateRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: CurriculumEngine = Depends(get_curriculum_engine)
) -> APIResponse[CurriculumPopulateResponse]:
    result = await engine.populate_school_syllabus(
        tenant_id=tenant_id,
        req=req,
        current_user=current_user
    )
    return APIResponse[CurriculumPopulateResponse](
        success=result.success,
        message=result.message,
        data=result
    )

@router.post(
    "/derive-previous",
    response_model=APIResponse[CurriculumPopulateResultRead],
    status_code=status.HTTP_200_OK,
    summary="Derive school syllabus from a previous academic year"
)
async def derive_previous_year_curriculum(
    school_id: uuid.UUID = Query(..., description="Target School ID"),
    req: CurriculumDerivePreviousRequest = Body(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: CurriculumEngine = Depends(get_curriculum_engine)
) -> APIResponse[CurriculumPopulateResultRead]:
    result = await engine.derive_from_previous_year(
        tenant_id=tenant_id,
        school_id=school_id,
        req=req,
        current_user=current_user
    )
    return APIResponse[CurriculumPopulateResultRead](
        success=result.success,
        message=result.message,
        data=result
    )

@router.get(
    "/templates",
    response_model=APIResponse[List[CurriculumMasterRead]],
    summary="List verified board curriculum master templates"
)
async def list_curriculum_templates(
    board: Optional[str] = Query(None, description="e.g. CBSE, ICSE, STATE"),
    class_level: Optional[int] = Query(None, description="e.g. 8, 9, 10"),
    state: Optional[str] = Query(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: CurriculumEngine = Depends(get_curriculum_engine)
) -> APIResponse[List[CurriculumMasterRead]]:
    templates = await engine.get_verified_templates(
        board=board,
        class_level=class_level,
        state=state
    )
    return APIResponse[List[CurriculumMasterRead]](
        success=True,
        message="Retrieved verified curriculum templates.",
        data=[CurriculumMasterRead.model_validate(t) for t in templates]
    )

@router.post(
    "/import",
    response_model=APIResponse[int],
    status_code=status.HTTP_201_CREATED,
    summary="Import custom syllabus items"
)
async def import_custom_syllabus(
    req: SyllabusImportRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: CurriculumEngine = Depends(get_curriculum_engine)
) -> APIResponse[int]:
    count = await engine.import_custom_syllabus(
        tenant_id=tenant_id,
        req=req,
        current_user=current_user
    )
    return APIResponse[int](
        success=True,
        message=f"Successfully imported {count} syllabus topics.",
        data=count
    )

@router.get(
    "/resolve",
    response_model=APIResponse[CurriculumResolveResponse],
    summary="Resolve verified board curriculum for a given board, academic year, and class level"
)
async def resolve_curriculum(
    board: str = Query(..., description="e.g. CBSE, ICSE, STATE"),
    academic_year: str = Query("2026-2027", description="e.g. 2026-2027"),
    class_level: int = Query(8, description="Class level, e.g. 8, 9, 10"),
    state: Optional[str] = Query(None, description="State name for state board curricula"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: CurriculumEngine = Depends(get_curriculum_engine)
) -> APIResponse[CurriculumResolveResponse]:
    b_upper = board.strip().upper()
    if b_upper in ["OTHER", "UNKNOWN"] or academic_year != "2026-2027":
        return APIResponse[CurriculumResolveResponse](
            success=True,
            message="Curriculum template unavailable.",
            data=CurriculumResolveResponse(
                verified_available=False,
                board=board,
                state=state,
                academic_year=academic_year,
                message=f"Verified curriculum data unavailable for board {board} ({academic_year})."
            )
        )

    if b_upper in ["STATE", "SSC"] and (not state or not state.strip()):
        return APIResponse[CurriculumResolveResponse](
            success=True,
            message="State parameter required for state board.",
            data=CurriculumResolveResponse(
                verified_available=False,
                board=board,
                state=state,
                academic_year=academic_year,
                message="Verified curriculum data unavailable: State must be specified for State Board."
            )
        )

    templates = await engine.get_verified_templates(
        board=board,
        class_level=class_level,
        state=state,
        academic_year_code=academic_year
    )

    if not templates:
        return APIResponse[CurriculumResolveResponse](
            success=True,
            message="Curriculum template unavailable.",
            data=CurriculumResolveResponse(
                verified_available=False,
                board=board,
                state=state,
                academic_year=academic_year,
                message=f"Verified curriculum data unavailable for {board} Class {class_level}."
            )
        )

    subjects_dict: Dict[str, List[str]] = {}
    for t in templates:
        if t.subject_name not in subjects_dict:
            subjects_dict[t.subject_name] = []
        for it in t.items:
            if it.unit_name and it.unit_name not in subjects_dict[t.subject_name]:
                subjects_dict[t.subject_name].append(it.unit_name)

    subjects = [
        CurriculumResolveSubject(subject_name=name, units=units)
        for name, units in subjects_dict.items()
    ]

    return APIResponse[CurriculumResolveResponse](
        success=True,
        message=f"Resolved verified {board} curriculum.",
        data=CurriculumResolveResponse(
            verified_available=True,
            board=board,
            state=state,
            academic_year=academic_year,
            source=templates[0].source,
            verification_status=templates[0].verification_status,
            subjects=subjects,
            message="Verified curriculum resolved."
        )
    )

@router.post(
    "/populate",
    response_model=APIResponse[CurriculumPopulateResultRead],
    status_code=status.HTTP_201_CREATED,
    summary="Populate school syllabus from verified board curriculum template"
)
async def populate_curriculum(
    school_id: Optional[uuid.UUID] = Query(None, description="Target School ID"),
    req: Optional[CurriculumPopulateRequest] = Body(None),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: CurriculumEngine = Depends(get_curriculum_engine)
) -> APIResponse[CurriculumPopulateResultRead]:
    target_school_id = school_id or (req.school_id if req else None)
    if not target_school_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="school_id is required.")

    ay_id = req.academic_year_id if req else None
    override = req.override_existing if req else False
    result = await engine.auto_populate_school(
        tenant_id=tenant_id,
        school_id=target_school_id,
        current_user=current_user,
        override_existing=override,
        academic_year_id=ay_id
    )
    return APIResponse[CurriculumPopulateResultRead](
        success=result.success,
        message=result.message,
        data=result
    )

@router.post(
    "/custom-chapter",
    response_model=APIResponse[SyllabusResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add a custom chapter / topic to school syllabus"
)
async def create_custom_chapter(
    school_id: uuid.UUID = Query(..., description="Target School ID"),
    req: CustomChapterRequest = Body(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SyllabusResponse]:
    code = f"CUSTOM_{uuid.uuid4().hex[:8]}"
    new_syll = Syllabus(
        syllabus_code=code,
        unit_name=req.unit_name,
        chapter_name=req.chapter_name,
        topic_name=req.topic_name,
        description=req.description,
        sequence_order=req.sequence_order,
        estimated_periods=req.estimated_periods,
        coverage_status="PENDING",
        lifecycle_status="PLANNED",
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=req.academic_year_id,
        class_id=req.class_id,
        subject_id=req.subject_id,
        is_custom=True,
        verification_status="CUSTOM",
        created_by=current_user.id
    )
    db.add(new_syll)
    await db.commit()
    await db.refresh(new_syll)
    return APIResponse[SyllabusResponse](
        success=True,
        message="Custom chapter created.",
        data=SyllabusResponse.model_validate(new_syll)
    )


@router.post(
    "/ai-draft-syllabus",
    response_model=APIResponse[AIDraftSyllabusResponse],
    status_code=status.HTTP_200_OK,
    summary="Generate AI draft syllabus for a school-specific or custom subject"
)
async def generate_ai_draft_syllabus(
    req: AIDraftSyllabusRequest = Body(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: CurriculumEngine = Depends(get_curriculum_engine)
) -> APIResponse[AIDraftSyllabusResponse]:
    result = await engine.generate_ai_draft_syllabus(
        tenant_id=tenant_id,
        req=req,
        current_user=current_user
    )
    return APIResponse[AIDraftSyllabusResponse](
        success=True,
        message="AI draft syllabus generated successfully.",
        data=result
    )


@router.post(
    "/ai-draft-syllabus/approve",
    response_model=APIResponse[Dict],
    status_code=status.HTTP_200_OK,
    summary="Approve and persist AI-drafted syllabus into school editable syllabus"
)
async def approve_ai_draft_syllabus(
    req: AIDraftSyllabusApproveRequest = Body(...),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(get_current_user),
    engine: CurriculumEngine = Depends(get_curriculum_engine)
) -> APIResponse[Dict]:
    result = await engine.approve_ai_draft_syllabus(
        tenant_id=tenant_id,
        req=req,
        current_user=current_user
    )
    return APIResponse[Dict](
        success=True,
        message=result.get("message", "Syllabus topics approved."),
        data=result
    )

