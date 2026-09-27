import uuid
from datetime import date, datetime, timezone, timedelta
from typing import Optional, List, Dict, Any, Tuple
from sqlalchemy import select, func, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.school import School
from app.models.school_administration import (
    SchoolComplianceRequirement, SchoolComplianceRecord, ComplianceAuditLog,
    SchoolDocument, ComplianceStatus, UdiseVerificationStatus
)
from app.models.user import User


DEFAULT_REQUIREMENTS = [
    {
        "code": "RTE_NORMS",
        "title": "Right to Education (RTE) Norms",
        "category": "RTE",
        "applicable_authority": "Department of School Education / District Educational Officer (DEO)",
        "statutory_reference": "Right of Children to Free and Compulsory Education Act, 2009 (Section 18 & 19)",
        "requirement_description": (
            "Mandatory compliance under the RTE Act 2009 requiring all recognized schools to maintain prescribed "
            "pupil-teacher ratios, implement 25% admission quota for economically weaker sections (EWS) and disadvantaged "
            "groups, maintain all-weather school building, drinking water, separated toilets, and barrier-free access."
        ),
        "what_school_must_maintain": (
            "Maintain 25% free quota admission register with student verification, student-teacher ratio of 30:1 (primary) "
            "and 35:1 (upper primary), functional School Management Committee (SMC), barrier-free entry, and timely "
            "triennial DEO recognition renewal certificates."
        ),
        "required_documents": [
            "RTE Recognition Certificate / Form II",
            "EWS & Disadvantaged Group Admission Register",
            "Pupil-Teacher Ratio (PTR) Audit Statement",
            "School Management Committee (SMC) Constitution Order"
        ],
        "field_schema": {
            "fields": [
                {"name": "ews_seats_allocated", "label": "EWS Seats Allocated", "type": "number", "required": True},
                {"name": "ews_seats_admitted", "label": "EWS Seats Admitted", "type": "number", "required": True},
                {"name": "pupil_teacher_ratio", "label": "Current PTR (e.g. 28:1)", "type": "text", "required": True},
                {"name": "smc_constituted", "label": "SMC Formed & Active", "type": "boolean", "required": True},
                {"name": "all_weather_building", "label": "All-Weather Building Verified", "type": "boolean", "required": True}
            ]
        },
        "default_validity_months": 36,
        "renewal_reminder_days": 90,
        "mandatory": True,
        "sort_order": 1
    },
    {
        "code": "FIRE_SAFETY",
        "title": "Fire Safety & Evacuation Certification",
        "category": "FIRE_SAFETY",
        "applicable_authority": "State Disaster Response & Fire Services Department / Municipal Fire Officer",
        "statutory_reference": "National Building Code (NBC) 2016 Part 4 & State Fire Prevention Measures Act",
        "requirement_description": (
            "Statutory requirement for all educational buildings to possess an active Fire No Objection Certificate (NOC), "
            "fully operational firefighting infrastructure (extinguishers, hose reels, alarms), clear unobstructed staircases, "
            "and bi-annually scheduled evacuation drills."
        ),
        "what_school_must_maintain": (
            "Annual Fire NOC renewal, biannual fire evacuation drills with logbook documentation, ABC and CO2 fire extinguishers "
            "serviced annually with inspection tags, illuminated exit signs, and unobstructed emergency assembly areas."
        ),
        "required_documents": [
            "Fire Safety Certificate / No Objection Certificate (NOC)",
            "Building Floor-wise Evacuation Plan",
            "Fire Evacuation Drill Logbook & Photographs",
            "Firefighting Equipment Maintenance & Inspection Log"
        ],
        "field_schema": {
            "fields": [
                {"name": "extinguisher_count", "label": "Operational Fire Extinguishers", "type": "number", "required": True},
                {"name": "last_fire_drill_date", "label": "Last Fire Drill Date", "type": "date", "required": True},
                {"name": "evacuation_plan_displayed", "label": "Evacuation Maps Displayed on Floors", "type": "boolean", "required": True},
                {"name": "fire_alarm_functional", "label": "Emergency Fire Alarm Operational", "type": "boolean", "required": True},
                {"name": "emergency_exits_count", "label": "Total Emergency Exits", "type": "number", "required": True}
            ]
        },
        "default_validity_months": 12,
        "renewal_reminder_days": 60,
        "mandatory": True,
        "sort_order": 2
    },
    {
        "code": "WATER_SANITATION",
        "title": "Safe Drinking Water & Sanitary Conditions",
        "category": "WATER_SANITATION",
        "applicable_authority": "Public Health Engineering Department (PHED) / Municipal Health Authority / District Lab",
        "statutory_reference": "IS 10500: 2012 Drinking Water Specification & CBSE Affiliation Bye-Laws Clause 4.7.9",
        "requirement_description": (
            "Mandatory compliance verifying that the school campus provides safe, potable drinking water certified by a "
            "government-accredited laboratory, along with clean, hygienic, gender-separated sanitary facilities with running water."
        ),
        "what_school_must_maintain": (
            "Bi-annual chemical and bacteriological water testing reports, regular overhead water tank disinfection logs, "
            "adequate numbers of separate, clean, locking toilets for boys and girls, running tap water, and handwashing stations with soap."
        ),
        "required_documents": [
            "Water Potability Lab Test Report (Bacteriological & Chemical)",
            "Sanitary Condition & Hygiene Certificate",
            "RO / Water Purifier Maintenance Contract & Disinfection Log"
        ],
        "field_schema": {
            "fields": [
                {"name": "testing_lab_name", "label": "Accredited Testing Laboratory Name", "type": "text", "required": True},
                {"name": "water_potable", "label": "Water Potability Test Passed (IS 10500)", "type": "boolean", "required": True},
                {"name": "purifier_type", "label": "Purification System (e.g. Commercial RO / UV)", "type": "text", "required": True},
                {"name": "boys_toilets_count", "label": "Functional Boys Toilets / Urinals", "type": "number", "required": True},
                {"name": "girls_toilets_count", "label": "Functional Girls Toilets / Urinals", "type": "number", "required": True},
                {"name": "running_water_available", "label": "Continuous Running Water in Toilets", "type": "boolean", "required": True}
            ]
        },
        "default_validity_months": 12,
        "renewal_reminder_days": 45,
        "mandatory": True,
        "sort_order": 3
    },
    {
        "code": "BUILDING_SAFETY",
        "title": "Building Structural Safety & Fitness",
        "category": "BUILDING_SAFETY",
        "applicable_authority": "Executive Engineer, Roads & Buildings (R&B) / PWD / Registered Structural Engineer",
        "statutory_reference": "National Building Code 2016 & State Educational Institutions (Safety & Standards) Regulations",
        "requirement_description": (
            "Mandatory engineering certificate affirming that the school building structure, load-bearing columns, beams, "
            "roofs, and boundary walls are structurally sound, earthquake resistant according to regional seismic zones, and safe for occupancy."
        ),
        "what_school_must_maintain": (
            "Triennial structural stability and soundness certificate issued by an authorized Executive Engineer or licensed structural engineer, "
            "routine crack/plaster/dampness maintenance, and structural fitness approval for any newly constructed blocks or floors."
        ),
        "required_documents": [
            "Building Structural Soundness & Fitness Certificate",
            "Certifying Engineer License / Registration Certificate",
            "Soil Test & Foundation Stability Report"
        ],
        "field_schema": {
            "fields": [
                {"name": "certifying_engineer_name", "label": "Certifying Engineer / Agency Name", "type": "text", "required": True},
                {"name": "engineer_license_number", "label": "Engineer Registration / License No", "type": "text", "required": True},
                {"name": "building_blocks_covered", "label": "Blocks Covered (e.g. Block A, B & Science Wing)", "type": "text", "required": True},
                {"name": "structural_stability_passed", "label": "Structural Fitness Audit Passed", "type": "boolean", "required": True},
                {"name": "seismic_zone", "label": "Seismic Zone Classification", "type": "text", "required": False}
            ]
        },
        "default_validity_months": 36,
        "renewal_reminder_days": 90,
        "mandatory": True,
        "sort_order": 4
    },
    {
        "code": "DISABILITY_ACCESS",
        "title": "Barrier-Free Disability Access",
        "category": "DISABILITY_ACCESS",
        "applicable_authority": "Department of Empowerment of Persons with Disabilities / State Commissioner for PwD",
        "statutory_reference": "Rights of Persons with Disabilities (RPwD) Act, 2016 & Harmonised Guidelines 2021",
        "requirement_description": (
            "Statutory mandate ensuring barrier-free physical access across the school campus for Children with Special Needs (CwSN), "
            "including continuous ramps with handrails, accessible toilets, tactile warning paving, and wide doorways."
        ),
        "what_school_must_maintain": (
            "Gentle entry ramps with 1:12 maximum gradient and dual-height handrails at all building entrances, at least one "
            "dedicated wheelchair-accessible toilet with grab bars on the ground floor, clear signage, and assistive aids."
        ),
        "required_documents": [
            "CwSN Accessibility Audit & Compliance Certificate",
            "Site Photographs of Ramps, Handrails, and Accessible Toilets",
            "Assistive Learning Aids & Equipment Register"
        ],
        "field_schema": {
            "fields": [
                {"name": "has_wheelchair_ramp", "label": "Wheelchair Ramps at Main Entrances", "type": "boolean", "required": True},
                {"name": "ramp_slope_ratio", "label": "Ramp Slope Gradient (e.g. 1:12)", "type": "text", "required": True},
                {"name": "has_accessible_toilet", "label": "CwSN Accessible Toilet with Grab Bars", "type": "boolean", "required": True},
                {"name": "has_handrails", "label": "Continuous Dual-Height Handrails", "type": "boolean", "required": True},
                {"name": "accessible_ground_floor", "label": "Ground Floor Classrooms Barrier-Free", "type": "boolean", "required": True}
            ]
        },
        "default_validity_months": 36,
        "renewal_reminder_days": 60,
        "mandatory": True,
        "sort_order": 5
    }
]


class ComplianceService:
    """
    Evidence-based statutory compliance management service.
    Zero fake compliance: evaluates real document evidence, dates, and sign-offs.
    """

    @classmethod
    async def ensure_catalogue_and_school_records(
        cls,
        db: AsyncSession,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> List[SchoolComplianceRecord]:
        """
        Ensures all standard statutory requirements exist in the catalogue and
        that the school has corresponding compliance records initialized.
        """
        # 1. Seed standard requirements if missing
        req_result = await db.execute(select(SchoolComplianceRequirement))
        existing_reqs = {r.code: r for r in req_result.scalars().all()}

        for req_data in DEFAULT_REQUIREMENTS:
            code = req_data["code"]
            if code not in existing_reqs:
                new_req = SchoolComplianceRequirement(
                    id=uuid.uuid4(),
                    code=code,
                    title=req_data["title"],
                    category=req_data["category"],
                    applicable_authority=req_data["applicable_authority"],
                    statutory_reference=req_data["statutory_reference"],
                    requirement_description=req_data["requirement_description"],
                    what_school_must_maintain=req_data["what_school_must_maintain"],
                    required_documents=req_data["required_documents"],
                    field_schema=req_data["field_schema"],
                    default_validity_months=req_data["default_validity_months"],
                    renewal_reminder_days=req_data["renewal_reminder_days"],
                    mandatory=req_data["mandatory"],
                    sort_order=req_data["sort_order"],
                    is_active=True
                )
                db.add(new_req)
                await db.flush()
                existing_reqs[code] = new_req

        # 2. Fetch existing school records
        rec_result = await db.execute(
            select(SchoolComplianceRecord)
            .options(
                selectinload(SchoolComplianceRecord.requirement),
                selectinload(SchoolComplianceRecord.primary_document),
                selectinload(SchoolComplianceRecord.verifier)
            )
            .where(SchoolComplianceRecord.school_id == school_id)
        )
        existing_records = {r.requirement_id: r for r in rec_result.scalars().all()}

        # 3. Initialize missing records for this school
        today = date.today()
        changed = False
        for code, req in existing_reqs.items():
            if req.id not in existing_records:
                initial_missing = list(req.required_documents) if req.required_documents else ["Mandatory statutory certificate required"]
                new_record = SchoolComplianceRecord(
                    id=uuid.uuid4(),
                    tenant_id=tenant_id,
                    school_id=school_id,
                    requirement_id=req.id,
                    status=ComplianceStatus.MISSING_EVIDENCE.value,
                    certificate_number=None,
                    issuing_authority=None,
                    issue_date=None,
                    expiry_date=None,
                    last_inspection_date=None,
                    next_renewal_date=None,
                    primary_document_id=None,
                    supporting_document_ids=[],
                    photo_evidence_urls=[],
                    specific_data={},
                    missing_items=initial_missing,
                    verification_status="UNVERIFIED",
                    verified_at=None,
                    verified_by=None,
                    verification_notes=None,
                    remarks=None
                )
                db.add(new_record)
                changed = True
                existing_records[req.id] = new_record

        if changed:
            await db.commit()

        # 4. Fetch all records fresh and evaluate status dynamically
        final_records_res = await db.execute(
            select(SchoolComplianceRecord)
            .options(
                selectinload(SchoolComplianceRecord.requirement),
                selectinload(SchoolComplianceRecord.primary_document),
                selectinload(SchoolComplianceRecord.verifier)
            )
            .where(SchoolComplianceRecord.school_id == school_id)
            .order_by(SchoolComplianceRecord.created_at.asc())
        )
        records = list(final_records_res.scalars().all())

        # Sort according to requirement sort_order
        records.sort(key=lambda r: r.requirement.sort_order if r.requirement else 99)

        # Dynamic status refresh based on dates & documents
        updated_any = False
        for rec in records:
            new_status, missing_items = cls.compute_dynamic_status(rec)
            if rec.status != new_status or rec.missing_items != missing_items:
                rec.status = new_status
                rec.missing_items = missing_items
                updated_any = True

        if updated_any:
            await db.commit()

        return records

    @classmethod
    def compute_dynamic_status(cls, record: SchoolComplianceRecord) -> Tuple[str, List[str]]:
        """
        Dynamically calculates the exact evidence-based compliance status.
        Never fakes COMPLIANT.
        """
        req = record.requirement
        required_docs = list(req.required_documents) if req and req.required_documents else []
        missing = []

        # Check document presence
        has_primary_doc = record.primary_document_id is not None
        has_cert_num = bool(record.certificate_number and record.certificate_number.strip())

        if not has_primary_doc:
            missing.append(f"Official certificate file not attached from Documents Vault ({required_docs[0] if required_docs else 'Mandatory Certificate'})")
        if not has_cert_num:
            missing.append("Certificate / Registration / NOC number is required")

        today = date.today()

        # Check expiry
        if record.expiry_date:
            days_left = (record.expiry_date - today).days
            if days_left < 0:
                return ComplianceStatus.EXPIRED.value, missing + [f"Certificate expired on {record.expiry_date.isoformat()}"]
            elif days_left <= (req.renewal_reminder_days if req else 60):
                if missing:
                    return ComplianceStatus.MISSING_EVIDENCE.value, missing
                return ComplianceStatus.EXPIRING_SOON.value, [f"Certificate expires in {days_left} days (on {record.expiry_date.isoformat()})"]

        if missing:
            return ComplianceStatus.MISSING_EVIDENCE.value, missing

        # If evidence is complete, check verification status
        if record.verification_status == "VERIFIED":
            return ComplianceStatus.VERIFIED.value, []
        elif record.verification_status == "REJECTED":
            return ComplianceStatus.NON_COMPLIANT.value, [record.verification_notes or "Verification was rejected by regulatory authority"]
        else:
            return ComplianceStatus.PENDING_VERIFICATION.value, ["Evidence submitted; awaiting administrative verification"]

    @classmethod
    async def get_dashboard_summary(
        cls,
        db: AsyncSession,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        status_filter: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Calculates metric counts and returns all records with their full details.
        """
        records = await cls.ensure_catalogue_and_school_records(db, school_id, tenant_id)

        # Count metrics
        total = len(records)
        verified = sum(1 for r in records if r.status == ComplianceStatus.VERIFIED.value)
        pending = sum(1 for r in records if r.status == ComplianceStatus.PENDING_VERIFICATION.value)
        missing_ev = sum(1 for r in records if r.status == ComplianceStatus.MISSING_EVIDENCE.value)
        expiring = sum(1 for r in records if r.status == ComplianceStatus.EXPIRING_SOON.value)
        expired = sum(1 for r in records if r.status == ComplianceStatus.EXPIRED.value)
        non_compliant = sum(1 for r in records if r.status == ComplianceStatus.NON_COMPLIANT.value)
        not_applicable = sum(1 for r in records if r.status == ComplianceStatus.NOT_APPLICABLE.value)

        compliance_pct = round((verified / total * 100.0) if total > 0 else 0.0, 1)

        # Apply status filter if provided
        filtered_records = records
        if status_filter and status_filter.upper() != "ALL":
            target = status_filter.upper()
            filtered_records = [r for r in records if r.status == target]

        # Resolve supporting documents for each record
        items = []
        for r in filtered_records:
            items.append(await cls.format_record_response(db, r))

        return {
            "school_id": school_id,
            "total_requirements": total,
            "verified_count": verified,
            "pending_verification_count": pending,
            "missing_evidence_count": missing_ev,
            "expiring_soon_count": expiring,
            "expired_count": expired,
            "non_compliant_count": non_compliant,
            "not_applicable_count": not_applicable,
            "compliance_percentage": compliance_pct,
            "items": items
        }

    @classmethod
    async def get_record_detail(
        cls,
        db: AsyncSession,
        school_id: uuid.UUID,
        record_id: uuid.UUID
    ) -> Optional[Dict[str, Any]]:
        result = await db.execute(
            select(SchoolComplianceRecord)
            .options(
                selectinload(SchoolComplianceRecord.requirement),
                selectinload(SchoolComplianceRecord.primary_document),
                selectinload(SchoolComplianceRecord.verifier)
            )
            .where(
                SchoolComplianceRecord.id == record_id,
                SchoolComplianceRecord.school_id == school_id
            )
        )
        record = result.scalars().first()
        if not record:
            return None

        # Re-evaluate dynamic status
        new_status, missing_items = cls.compute_dynamic_status(record)
        if record.status != new_status or record.missing_items != missing_items:
            record.status = new_status
            record.missing_items = missing_items
            await db.commit()

        return await cls.format_record_response(db, record)

    @classmethod
    async def update_record(
        cls,
        db: AsyncSession,
        school_id: uuid.UUID,
        record_id: uuid.UUID,
        tenant_id: uuid.UUID,
        actor: Optional[User],
        update_data: Dict[str, Any]
    ) -> Optional[Dict[str, Any]]:
        result = await db.execute(
            select(SchoolComplianceRecord)
            .options(
                selectinload(SchoolComplianceRecord.requirement),
                selectinload(SchoolComplianceRecord.primary_document),
                selectinload(SchoolComplianceRecord.verifier)
            )
            .where(
                SchoolComplianceRecord.id == record_id,
                SchoolComplianceRecord.school_id == school_id
            )
        )
        record = result.scalars().first()
        if not record:
            return None

        changes = {}
        fields_to_update = [
            "certificate_number", "issuing_authority", "issue_date", "expiry_date",
            "last_inspection_date", "next_renewal_date", "primary_document_id",
            "supporting_document_ids", "photo_evidence_urls", "specific_data", "remarks"
        ]

        for field in fields_to_update:
            if field in update_data and update_data[field] is not None:
                old_val = getattr(record, field)
                new_val = update_data[field]
                if old_val != new_val:
                    changes[field] = {
                        "before": str(old_val) if old_val is not None else None,
                        "after": str(new_val) if new_val is not None else None
                    }
                    setattr(record, field, new_val)

        # If changes were made to evidence/dates, reset verification to UNVERIFIED for safety
        if changes:
            if record.verification_status == "VERIFIED":
                record.verification_status = "UNVERIFIED"
                record.verified_at = None
                record.verified_by = None
                changes["verification_status"] = {"before": "VERIFIED", "after": "UNVERIFIED (Requires Re-verification)"}

        record.updated_at = datetime.now(timezone.utc)
        if actor:
            record.updated_by = actor.id

        # Dynamically compute new status
        new_status, missing_items = cls.compute_dynamic_status(record)
        record.status = new_status
        record.missing_items = missing_items

        # Record audit log
        audit_log = ComplianceAuditLog(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            school_id=school_id,
            record_id=record.id,
            action="UPDATED",
            actor_id=actor.id if actor else None,
            actor_name=f"{actor.first_name} {actor.last_name}".strip() if actor else "System Administrator",
            actor_role=actor.role.name if actor and actor.role else "ADMIN",
            changes=changes,
            notes=f"Compliance updated. Current status: {new_status}"
        )
        db.add(audit_log)
        await db.commit()

        # Reload with relations
        return await cls.get_record_detail(db, school_id, record_id)

    @classmethod
    async def verify_record(
        cls,
        db: AsyncSession,
        school_id: uuid.UUID,
        record_id: uuid.UUID,
        tenant_id: uuid.UUID,
        actor: Optional[User],
        verification_status: str,
        notes: Optional[str]
    ) -> Optional[Dict[str, Any]]:
        result = await db.execute(
            select(SchoolComplianceRecord)
            .options(
                selectinload(SchoolComplianceRecord.requirement),
                selectinload(SchoolComplianceRecord.primary_document),
                selectinload(SchoolComplianceRecord.verifier)
            )
            .where(
                SchoolComplianceRecord.id == record_id,
                SchoolComplianceRecord.school_id == school_id
            )
        )
        record = result.scalars().first()
        if not record:
            return None

        status_str = "VERIFIED" if verification_status.upper() == "VERIFIED" else "REJECTED"
        old_v_status = record.verification_status

        record.verification_status = status_str
        record.verified_at = datetime.now(timezone.utc)
        record.verified_by = actor.id if actor else None
        record.verification_notes = notes
        record.updated_at = datetime.now(timezone.utc)

        new_status, missing_items = cls.compute_dynamic_status(record)
        record.status = new_status
        record.missing_items = missing_items

        # Audit log
        audit_log = ComplianceAuditLog(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            school_id=school_id,
            record_id=record.id,
            action="VERIFIED" if status_str == "VERIFIED" else "REJECTED",
            actor_id=actor.id if actor else None,
            actor_name=f"{actor.first_name} {actor.last_name}".strip() if actor else "Inspector / Auditor",
            actor_role=actor.role.name if actor and actor.role else "ADMIN",
            changes={
                "verification_status": {"before": old_v_status, "after": status_str},
                "status": {"after": new_status}
            },
            notes=notes or f"Compliance item marked as {status_str}"
        )
        db.add(audit_log)
        await db.commit()

        return await cls.get_record_detail(db, school_id, record_id)

    @classmethod
    async def get_audit_logs(
        cls,
        db: AsyncSession,
        school_id: uuid.UUID,
        record_id: uuid.UUID
    ) -> List[Dict[str, Any]]:
        result = await db.execute(
            select(ComplianceAuditLog)
            .where(
                ComplianceAuditLog.record_id == record_id,
                ComplianceAuditLog.school_id == school_id
            )
            .order_by(ComplianceAuditLog.created_at.desc())
        )
        logs = result.scalars().all()
        return [
            {
                "id": l.id,
                "record_id": l.record_id,
                "action": l.action,
                "actor_id": l.actor_id,
                "actor_name": l.actor_name,
                "actor_role": l.actor_role,
                "changes": l.changes,
                "notes": l.notes,
                "created_at": l.created_at
            }
            for l in logs
        ]

    @classmethod
    async def format_record_response(
        cls,
        db: AsyncSession,
        r: SchoolComplianceRecord
    ) -> Dict[str, Any]:
        # Days until expiry & flags
        today = date.today()
        days_until_expiry = None
        is_expired = False
        is_expiring_soon = False

        if r.expiry_date:
            days_until_expiry = (r.expiry_date - today).days
            is_expired = days_until_expiry < 0
            reminder_days = r.requirement.renewal_reminder_days if r.requirement else 60
            is_expiring_soon = 0 <= days_until_expiry <= reminder_days

        primary_doc_dict = None
        doc = r.primary_document
        if not doc and r.primary_document_id:
            doc = await db.get(SchoolDocument, r.primary_document_id)
        if doc:
            primary_doc_dict = {
                "id": doc.id,
                "title": doc.title,
                "file_name": doc.file_name,
                "file_path": doc.file_path,
                "content_type": doc.content_type,
                "file_size_bytes": doc.file_size_bytes,
                "issue_date": doc.issue_date,
                "expiry_date": doc.expiry_date,
                "issuing_authority": doc.issuing_authority,
                "document_number": doc.document_number
            }

        # Fetch supporting documents
        supporting_docs = []
        if r.supporting_document_ids and isinstance(r.supporting_document_ids, list):
            doc_uuids = []
            for did in r.supporting_document_ids:
                try:
                    doc_uuids.append(uuid.UUID(str(did)))
                except (ValueError, TypeError):
                    pass
            if doc_uuids:
                docs_res = await db.execute(
                    select(SchoolDocument).where(SchoolDocument.id.in_(doc_uuids))
                )
                for sd in docs_res.scalars().all():
                    supporting_docs.append({
                        "id": sd.id,
                        "title": sd.title,
                        "file_name": sd.file_name,
                        "file_path": sd.file_path,
                        "content_type": sd.content_type,
                        "file_size_bytes": sd.file_size_bytes,
                        "issue_date": sd.issue_date,
                        "expiry_date": sd.expiry_date,
                        "issuing_authority": sd.issuing_authority,
                        "document_number": sd.document_number
                    })

        verified_by_name = None
        if r.verifier:
            verified_by_name = f"{r.verifier.first_name} {r.verifier.last_name}".strip()

        return {
            "id": r.id,
            "tenant_id": r.tenant_id,
            "school_id": r.school_id,
            "requirement_id": r.requirement_id,
            "requirement": {
                "id": r.requirement.id,
                "code": r.requirement.code,
                "title": r.requirement.title,
                "category": r.requirement.category,
                "applicable_authority": r.requirement.applicable_authority,
                "statutory_reference": r.requirement.statutory_reference,
                "requirement_description": r.requirement.requirement_description,
                "what_school_must_maintain": r.requirement.what_school_must_maintain,
                "required_documents": r.requirement.required_documents or [],
                "field_schema": r.requirement.field_schema or {},
                "default_validity_months": r.requirement.default_validity_months,
                "renewal_reminder_days": r.requirement.renewal_reminder_days,
                "mandatory": r.requirement.mandatory,
                "sort_order": r.requirement.sort_order,
                "is_active": r.requirement.is_active
            } if r.requirement else None,
            "status": r.status,
            "certificate_number": r.certificate_number,
            "issuing_authority": r.issuing_authority,
            "issue_date": r.issue_date,
            "expiry_date": r.expiry_date,
            "last_inspection_date": r.last_inspection_date,
            "next_renewal_date": r.next_renewal_date,
            "primary_document_id": r.primary_document_id,
            "primary_document": primary_doc_dict,
            "supporting_document_ids": [str(x) for x in (r.supporting_document_ids or [])],
            "supporting_documents": supporting_docs,
            "photo_evidence_urls": r.photo_evidence_urls or [],
            "specific_data": r.specific_data or {},
            "missing_items": r.missing_items or [],
            "verification_status": r.verification_status,
            "verified_at": r.verified_at,
            "verified_by": r.verified_by,
            "verified_by_name": verified_by_name,
            "verification_notes": r.verification_notes,
            "remarks": r.remarks,
            "created_at": r.created_at,
            "updated_at": r.updated_at,
            "days_until_expiry": days_until_expiry,
            "is_expired": is_expired,
            "is_expiring_soon": is_expiring_soon
        }
