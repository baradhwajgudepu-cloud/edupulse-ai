import uuid
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.api.dependencies.common import get_tenant_id, verify_school_access
from app.api.dependencies.auth import require_permission
from app.models.school import School
from app.models.school_administration import (
    SchoolProfile, SchoolRecognition, SchoolCustomField, SchoolDocument,
    UdiseVerificationStatus, RecognitionStatus
)
from app.models.payroll import PayrollPolicy, TeacherPayroll, PayrollStatus
from app.models.teacher import Teacher, TeacherStatus
from app.models.user import User
from app.schemas.response import APIResponse
from app.schemas.school_administration import (
    SchoolProfileUpdate, SchoolProfileResponse, UdiseVerifyRequest,
    SchoolRecognitionCreate, SchoolRecognitionUpdate, SchoolRecognitionResponse,
    SchoolCustomFieldCreate, SchoolCustomFieldResponse, ComplianceDashboardResponse,
    ComplianceRequirementResponse, ComplianceDocumentSummary, ComplianceAuditLogResponse,
    ComplianceRecordResponse, ComplianceRecordUpdate, ComplianceVerificationRequest,
    ComplianceDashboardSummary
)
from app.services.compliance_service import ComplianceService

router = APIRouter()


async def _get_or_create_profile(db: AsyncSession, tenant_id: uuid.UUID, school: School) -> SchoolProfile:
    stmt = select(SchoolProfile).options(selectinload(SchoolProfile.verified_by_user)).where(
        SchoolProfile.tenant_id == tenant_id,
        SchoolProfile.school_id == school.id,
        SchoolProfile.deleted_at.is_(None)
    )
    profile = (await db.execute(stmt)).scalars().first()
    if not profile:
        profile = SchoolProfile(
            tenant_id=tenant_id,
            school_id=school.id,
            medium_of_instruction="English",
            gender_type="Co-Education",
            minority_status="Non-Minority",
            area_type="Urban",
            total_capacity=1000,
            udise_status="CONFIGURED" if school.udise_code else "NOT_CONFIGURED",
            udise_verification_status=UdiseVerificationStatus.UNVERIFIED
        )
        db.add(profile)
        await db.flush()
        await db.refresh(profile)
    return profile


def _build_profile_response(school: School, profile: SchoolProfile) -> SchoolProfileResponse:
    verified_name = None
    try:
        if profile.udise_verified_by and getattr(profile, "verified_by_user", None):
            u = profile.verified_by_user
            verified_name = f"{u.first_name} {u.last_name or ''}".strip()
    except Exception:
        verified_name = None

    return SchoolProfileResponse(
        id=profile.id,
        tenant_id=profile.tenant_id,
        school_id=school.id,
        school_name=school.name,
        school_code=school.code,
        board=school.board.value if hasattr(school.board, "value") else str(school.board),
        school_type=school.school_type.value if hasattr(school.school_type, "value") else str(school.school_type),
        email=school.email,
        phone=school.phone,
        website=school.website,
        principal_name=school.principal_name,
        address=school.address,
        city=school.city,
        state=school.state,
        postal_code=school.postal_code,
        logo_url=school.logo_url,

        school_category=profile.school_category,
        management_type=profile.management_type,
        school_level=profile.school_level,
        established_year=profile.established_year,
        medium_of_instruction=profile.medium_of_instruction,
        gender_type=profile.gender_type,
        minority_status=profile.minority_status,
        area_type=profile.area_type,
        school_photo_url=profile.school_photo_url,
        school_motto=profile.school_motto,

        correspondent_name=profile.correspondent_name,
        headmaster_name=profile.headmaster_name,
        management_contact=profile.management_contact,
        emergency_contact=profile.emergency_contact,
        school_working_hours=profile.school_working_hours,
        office_working_hours=profile.office_working_hours,
        morning_assembly_time=profile.morning_assembly_time,
        lunch_time=profile.lunch_time,

        total_capacity=profile.total_capacity,
        current_capacity=profile.current_capacity,
        total_sections_count=profile.total_sections_count,
        has_transport=profile.has_transport,
        has_hostel=profile.has_hostel,
        has_library=profile.has_library,
        has_laboratory=profile.has_laboratory,
        has_sports_facilities=profile.has_sports_facilities,
        has_smart_classrooms=profile.has_smart_classrooms,
        has_computer_lab=profile.has_computer_lab,
        has_medical_room=profile.has_medical_room,
        has_cctv=profile.has_cctv,
        has_fire_safety=profile.has_fire_safety,
        has_water_sanitation=profile.has_water_sanitation,
        has_electricity_backup=profile.has_electricity_backup,
        has_accessibility_ramps=profile.has_accessibility_ramps,

        udise_code=school.udise_code,
        udise_status=profile.udise_status,
        udise_verification_status=profile.udise_verification_status,
        udise_verified_at=profile.udise_verified_at,
        udise_verified_by_name=verified_name,
        udise_notes=profile.udise_notes,
        custom_values=profile.custom_values or {},
        created_at=profile.created_at,
        updated_at=profile.updated_at
    )


@router.get(
    "/schools/{school_id}/profile",
    response_model=APIResponse[SchoolProfileResponse],
    status_code=status.HTTP_200_OK,
    summary="Get comprehensive school profile"
)
async def get_school_profile(
    school_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.profile.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SchoolProfileResponse]:
    await verify_school_access(current_user, school_id, db)
    school = await db.get(School, school_id)
    if not school or school.tenant_id != tenant_id or school.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="School not found")

    profile = await _get_or_create_profile(db, tenant_id, school)
    await db.commit()

    return APIResponse[SchoolProfileResponse](
        success=True,
        message="School profile retrieved successfully",
        data=_build_profile_response(school, profile)
    )


@router.put(
    "/schools/{school_id}/profile",
    response_model=APIResponse[SchoolProfileResponse],
    status_code=status.HTTP_200_OK,
    summary="Update school profile"
)
async def update_school_profile(
    school_id: uuid.UUID,
    req: SchoolProfileUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.profile.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SchoolProfileResponse]:
    await verify_school_access(current_user, school_id, db)
    school = await db.get(School, school_id)
    if not school or school.tenant_id != tenant_id or school.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="School not found")

    profile = await _get_or_create_profile(db, tenant_id, school)

    # Update profile fields
    for field, val in req.model_dump(exclude_unset=True).items():
        setattr(profile, field, val)

    await db.commit()
    await db.refresh(profile)

    return APIResponse[SchoolProfileResponse](
        success=True,
        message="School profile updated successfully",
        data=_build_profile_response(school, profile)
    )


@router.post(
    "/schools/{school_id}/udise/verify",
    response_model=APIResponse[SchoolProfileResponse],
    status_code=status.HTTP_200_OK,
    summary="Verify school UDISE+ identifier"
)
async def verify_udise(
    school_id: uuid.UUID,
    req: UdiseVerifyRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.compliance.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SchoolProfileResponse]:
    await verify_school_access(current_user, school_id, db)
    school = await db.get(School, school_id)
    if not school or school.tenant_id != tenant_id or school.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="School not found")

    profile = await _get_or_create_profile(db, tenant_id, school)

    if req.is_verified:
        profile.udise_verification_status = UdiseVerificationStatus.VERIFIED
        profile.udise_status = "VERIFIED"
        profile.udise_verified_at = datetime.now(timezone.utc)
        profile.udise_verified_by = current_user.id
    else:
        profile.udise_verification_status = UdiseVerificationStatus.REJECTED
        profile.udise_status = "REJECTED"
        profile.udise_verified_at = datetime.now(timezone.utc)
        profile.udise_verified_by = current_user.id

    if req.notes:
        profile.udise_notes = req.notes

    profile.verified_by_user = current_user
    await db.commit()
    await db.refresh(profile)

    return APIResponse[SchoolProfileResponse](
        success=True,
        message="UDISE+ verification status updated successfully",
        data=_build_profile_response(school, profile)
    )


@router.get(
    "/schools/{school_id}/compliance",
    response_model=APIResponse[ComplianceDashboardResponse],
    status_code=status.HTTP_200_OK,
    summary="Get School Compliance Dashboard overview"
)
async def get_compliance_dashboard(
    school_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.compliance.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ComplianceDashboardResponse]:
    await verify_school_access(current_user, school_id, db)
    school = await db.get(School, school_id)
    if not school or school.tenant_id != tenant_id or school.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="School not found")

    profile = await _get_or_create_profile(db, tenant_id, school)
    await db.commit()

    # Recognitions count
    rec_stmt = select(SchoolRecognition).where(
        SchoolRecognition.tenant_id == tenant_id,
        SchoolRecognition.school_id == school_id,
        SchoolRecognition.deleted_at.is_(None)
    )
    recognitions = list((await db.execute(rec_stmt)).scalars().all())
    active_recs = [r for r in recognitions if r.status == RecognitionStatus.ACTIVE or getattr(r.status, "value", str(r.status)) == "ACTIVE"]
    central_recs = [r for r in recognitions if r.authority_level == RecognitionAuthorityLevel.CENTRAL or getattr(r.authority_level, "value", str(r.authority_level)) == "CENTRAL"]
    state_recs = [r for r in recognitions if r.authority_level == RecognitionAuthorityLevel.STATE or getattr(r.authority_level, "value", str(r.authority_level)) == "STATE"]

    # Documents count
    doc_stmt = select(SchoolDocument).where(
        SchoolDocument.tenant_id == tenant_id,
        SchoolDocument.school_id == school_id,
        SchoolDocument.is_archived == False,
        SchoolDocument.deleted_at.is_(None)
    )
    documents = list((await db.execute(doc_stmt)).scalars().all())
    conf_docs = [d for d in documents if d.confidentiality_level != "STANDARD"]
    today = datetime.now(timezone.utc).date()
    expiring = [d for d in documents if d.expiry_date and 0 <= (d.expiry_date - today).days <= 60]
    expired = [d for d in documents if d.expiry_date and (d.expiry_date - today).days < 0]

    # Payroll Readiness
    pol_stmt = select(PayrollPolicy).where(
        PayrollPolicy.tenant_id == tenant_id,
        PayrollPolicy.school_id == school_id,
        PayrollPolicy.is_active == True,
        PayrollPolicy.deleted_at.is_(None)
    )
    policy = (await db.execute(pol_stmt)).scalars().first()

    teachers_stmt = select(Teacher).where(
        Teacher.tenant_id == tenant_id,
        Teacher.school_id == school_id,
        Teacher.status == TeacherStatus.ACTIVE,
        Teacher.deleted_at.is_(None)
    )
    teachers = list((await db.execute(teachers_stmt)).scalars().all())

    # Current month payroll status
    curr_month = today.month
    curr_year = today.year
    pay_stmt = select(TeacherPayroll).where(
        TeacherPayroll.tenant_id == tenant_id,
        TeacherPayroll.school_id == school_id,
        TeacherPayroll.month == curr_month,
        TeacherPayroll.year == curr_year,
        TeacherPayroll.deleted_at.is_(None)
    )
    payrolls = list((await db.execute(pay_stmt)).scalars().all())
    approved_count = len([p for p in payrolls if p.status == PayrollStatus.APPROVED])
    draft_count = len([p for p in payrolls if p.status in (PayrollStatus.DRAFT, PayrollStatus.REVIEWED)])

    data = ComplianceDashboardResponse(
        school_id=school.id,
        school_name=school.name,
        udise_code=school.udise_code,
        udise_configured=bool(school.udise_code and school.udise_code.strip()),
        udise_verification_status=profile.udise_verification_status,
        udise_verified_at=profile.udise_verified_at,
        total_recognitions=len(recognitions),
        active_recognitions=len(active_recs),
        central_recognitions_count=len(central_recs),
        state_recognitions_count=len(state_recs),
        total_documents=len(documents),
        confidential_documents_count=len(conf_docs),
        expiring_documents_count=len(expiring),
        expired_documents_count=len(expired),
        payroll_policy_configured=policy is not None,
        payroll_ready=policy is not None and len(teachers) > 0,
        teachers_count=len(teachers),
        pending_payroll_count=draft_count,
        approved_payroll_count=approved_count
    )

    return APIResponse[ComplianceDashboardResponse](
        success=True,
        message="Compliance dashboard data retrieved successfully",
        data=data
    )


# -------------------------------------------------------------
# Statutory Compliance & Evidence Engine Endpoints
# -------------------------------------------------------------

@router.get(
    "/schools/{school_id}/compliance/items",
    response_model=APIResponse[ComplianceDashboardSummary],
    status_code=status.HTTP_200_OK,
    summary="Get School Compliance Items with dynamic evidence status and dashboard metrics"
)
async def get_compliance_items(
    school_id: uuid.UUID,
    status_filter: Optional[str] = Query(None, alias="status", description="Optional status filter"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.compliance.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ComplianceDashboardSummary]:
    await verify_school_access(current_user, school_id, db)
    school = await db.get(School, school_id)
    if not school or school.tenant_id != tenant_id or school.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="School not found")

    summary_data = await ComplianceService.get_dashboard_summary(
        db=db,
        school_id=school_id,
        tenant_id=tenant_id,
        status_filter=status_filter
    )
    return APIResponse[ComplianceDashboardSummary](
        success=True,
        message="Compliance items and metrics retrieved successfully",
        data=summary_data
    )


@router.get(
    "/schools/{school_id}/compliance/items/{record_id}",
    response_model=APIResponse[ComplianceRecordResponse],
    status_code=status.HTTP_200_OK,
    summary="Get Compliance Record details by ID"
)
async def get_compliance_record(
    school_id: uuid.UUID,
    record_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.compliance.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ComplianceRecordResponse]:
    await verify_school_access(current_user, school_id, db)
    record = await ComplianceService.get_record_detail(db, school_id, record_id)
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compliance record not found")

    return APIResponse[ComplianceRecordResponse](
        success=True,
        message="Compliance record details retrieved successfully",
        data=record
    )


@router.put(
    "/schools/{school_id}/compliance/items/{record_id}",
    response_model=APIResponse[ComplianceRecordResponse],
    status_code=status.HTTP_200_OK,
    summary="Update Compliance Record evidence, details, and dynamic fields"
)
async def update_compliance_record(
    school_id: uuid.UUID,
    record_id: uuid.UUID,
    payload: ComplianceRecordUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.compliance.write", "school.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ComplianceRecordResponse]:
    await verify_school_access(current_user, school_id, db)
    update_dict = payload.model_dump(exclude_unset=True)
    updated_record = await ComplianceService.update_record(
        db=db,
        school_id=school_id,
        record_id=record_id,
        tenant_id=tenant_id,
        actor=current_user,
        update_data=update_dict
    )
    if not updated_record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compliance record not found")

    return APIResponse[ComplianceRecordResponse](
        success=True,
        message="Compliance record updated successfully",
        data=updated_record
    )


@router.post(
    "/schools/{school_id}/compliance/items/{record_id}/verify",
    response_model=APIResponse[ComplianceRecordResponse],
    status_code=status.HTTP_200_OK,
    summary="Verify or reject a Compliance Record"
)
async def verify_compliance_record(
    school_id: uuid.UUID,
    record_id: uuid.UUID,
    payload: ComplianceVerificationRequest,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.compliance.verify", "school.verify", "school.write")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[ComplianceRecordResponse]:
    await verify_school_access(current_user, school_id, db)
    verified_record = await ComplianceService.verify_record(
        db=db,
        school_id=school_id,
        record_id=record_id,
        tenant_id=tenant_id,
        actor=current_user,
        verification_status=payload.status,
        notes=payload.notes
    )
    if not verified_record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Compliance record not found")

    return APIResponse[ComplianceRecordResponse](
        success=True,
        message=f"Compliance record {payload.status.lower()} successfully",
        data=verified_record
    )


@router.get(
    "/schools/{school_id}/compliance/items/{record_id}/audit-logs",
    response_model=APIResponse[List[ComplianceAuditLogResponse]],
    status_code=status.HTTP_200_OK,
    summary="Get immutable audit logs for a Compliance Record"
)
async def get_compliance_audit_logs(
    school_id: uuid.UUID,
    record_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.compliance.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[ComplianceAuditLogResponse]]:
    await verify_school_access(current_user, school_id, db)
    logs = await ComplianceService.get_audit_logs(db, school_id, record_id)
    return APIResponse[List[ComplianceAuditLogResponse]](
        success=True,
        message="Compliance audit logs retrieved successfully",
        data=logs
    )


# -------------------------------------------------------------
# Recognition Endpoints
# -------------------------------------------------------------

@router.get(
    "/schools/{school_id}/recognitions",
    response_model=APIResponse[List[SchoolRecognitionResponse]],
    status_code=status.HTTP_200_OK,
    summary="List school recognition records"
)
async def list_school_recognitions(
    school_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.recognition.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[SchoolRecognitionResponse]]:
    await verify_school_access(current_user, school_id, db)
    stmt = select(SchoolRecognition).where(
        SchoolRecognition.tenant_id == tenant_id,
        SchoolRecognition.school_id == school_id,
        SchoolRecognition.deleted_at.is_(None)
    ).order_by(SchoolRecognition.created_at.desc())
    records = list((await db.execute(stmt)).scalars().all())

    # Map document titles
    doc_ids = [r.document_id for r in records if r.document_id]
    doc_map = {}
    if doc_ids:
        docs = list((await db.execute(select(SchoolDocument).where(SchoolDocument.id.in_(doc_ids)))).scalars().all())
        doc_map = {d.id: d.title for d in docs}

    items = []
    for r in records:
        resp = SchoolRecognitionResponse.model_validate(r)
        if r.document_id:
            resp.document_title = doc_map.get(r.document_id)
        items.append(resp)

    return APIResponse[List[SchoolRecognitionResponse]](
        success=True,
        message="Recognition records retrieved successfully",
        data=items
    )


@router.post(
    "/schools/{school_id}/recognitions",
    response_model=APIResponse[SchoolRecognitionResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Add school recognition record"
)
async def create_school_recognition(
    school_id: uuid.UUID,
    req: SchoolRecognitionCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.recognition.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SchoolRecognitionResponse]:
    await verify_school_access(current_user, school_id, db)
    rec = SchoolRecognition(
        tenant_id=tenant_id,
        school_id=school_id,
        authority_level=req.authority_level,
        authority_name=req.authority_name,
        recognition_type=req.recognition_type,
        recognition_number=req.recognition_number,
        certificate_number=req.certificate_number,
        proceedings_order_number=req.proceedings_order_number,
        issue_date=req.issue_date,
        valid_from=req.valid_from,
        valid_until=req.valid_until,
        status=req.status,
        document_id=req.document_id,
        remarks=req.remarks
    )
    db.add(rec)
    await db.commit()
    await db.refresh(rec)

    return APIResponse[SchoolRecognitionResponse](
        success=True,
        message="School recognition record created successfully",
        data=SchoolRecognitionResponse.model_validate(rec)
    )


@router.put(
    "/recognitions/{id}",
    response_model=APIResponse[SchoolRecognitionResponse],
    status_code=status.HTTP_200_OK,
    summary="Update school recognition record"
)
async def update_school_recognition(
    id: uuid.UUID,
    req: SchoolRecognitionUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.recognition.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SchoolRecognitionResponse]:
    rec = await db.get(SchoolRecognition, id)
    if not rec or rec.tenant_id != tenant_id or rec.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recognition record not found")
    await verify_school_access(current_user, rec.school_id, db)

    for field, val in req.model_dump(exclude_unset=True).items():
        setattr(rec, field, val)

    await db.commit()
    await db.refresh(rec)

    return APIResponse[SchoolRecognitionResponse](
        success=True,
        message="Recognition record updated successfully",
        data=SchoolRecognitionResponse.model_validate(rec)
    )


@router.delete(
    "/recognitions/{id}",
    response_model=APIResponse[dict],
    status_code=status.HTTP_200_OK,
    summary="Delete school recognition record"
)
async def delete_school_recognition(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.recognition.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[dict]:
    rec = await db.get(SchoolRecognition, id)
    if not rec or rec.tenant_id != tenant_id or rec.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recognition record not found")
    await verify_school_access(current_user, rec.school_id, db)

    rec.deleted_at = datetime.now(timezone.utc)
    await db.commit()

    return APIResponse[dict](
        success=True,
        message="Recognition record deleted successfully",
        data={"deleted_id": str(id)}
    )


# -------------------------------------------------------------
# Custom Fields Endpoints
# -------------------------------------------------------------

@router.get(
    "/schools/{school_id}/custom-fields",
    response_model=APIResponse[List[SchoolCustomFieldResponse]],
    status_code=status.HTTP_200_OK,
    summary="List custom fields for school"
)
async def list_custom_fields(
    school_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.profile.read", "school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[SchoolCustomFieldResponse]]:
    await verify_school_access(current_user, school_id, db)
    stmt = select(SchoolCustomField).where(
        SchoolCustomField.tenant_id == tenant_id,
        SchoolCustomField.school_id == school_id,
        SchoolCustomField.deleted_at.is_(None)
    ).order_by(SchoolCustomField.created_at.asc())
    fields = list((await db.execute(stmt)).scalars().all())

    return APIResponse[List[SchoolCustomFieldResponse]](
        success=True,
        message="Custom fields retrieved successfully",
        data=[SchoolCustomFieldResponse.model_validate(f) for f in fields]
    )


@router.post(
    "/schools/{school_id}/custom-fields",
    response_model=APIResponse[SchoolCustomFieldResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create custom field definition"
)
async def create_custom_field(
    school_id: uuid.UUID,
    req: SchoolCustomFieldCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.profile.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[SchoolCustomFieldResponse]:
    await verify_school_access(current_user, school_id, db)

    # Check key uniqueness
    existing = (await db.execute(select(SchoolCustomField).where(
        SchoolCustomField.school_id == school_id,
        SchoolCustomField.field_key == req.field_key,
        SchoolCustomField.deleted_at.is_(None)
    ))).scalars().first()
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Field key already exists for this school")

    cf = SchoolCustomField(
        tenant_id=tenant_id,
        school_id=school_id,
        field_name=req.field_name,
        field_key=req.field_key,
        field_type=req.field_type,
        field_options=req.field_options or [],
        is_required=req.is_required,
        visible_to_principal=req.visible_to_principal,
        visible_to_teachers=req.visible_to_teachers,
        visible_to_parents=req.visible_to_parents
    )
    db.add(cf)
    await db.commit()
    await db.refresh(cf)

    return APIResponse[SchoolCustomFieldResponse](
        success=True,
        message="Custom field created successfully",
        data=SchoolCustomFieldResponse.model_validate(cf)
    )


@router.delete(
    "/custom-fields/{id}",
    response_model=APIResponse[dict],
    status_code=status.HTTP_200_OK,
    summary="Delete custom field definition"
)
async def delete_custom_field(
    id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.profile.write", "school.update")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[dict]:
    cf = await db.get(SchoolCustomField, id)
    if not cf or cf.tenant_id != tenant_id or cf.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Custom field not found")
    await verify_school_access(current_user, cf.school_id, db)

    cf.deleted_at = datetime.now(timezone.utc)
    await db.commit()

    return APIResponse[dict](
        success=True,
        message="Custom field deleted successfully",
        data={"deleted_id": str(id)}
    )
