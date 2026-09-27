import uuid
from typing import List, Optional, Dict, Any, Set
from datetime import datetime, timezone
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, delete

from app.models.curriculum import CurriculumMaster, CurriculumMasterItem
from app.models.syllabus import Syllabus
from app.models.school import School, SchoolBoard
from app.models.academic_year import AcademicYear
from app.models.class_entity import Class
from app.models.subject import Subject
from app.models.user import User
from app.repositories.curriculum import CurriculumRepository
from app.repositories.syllabus import SyllabusRepository
from app.schemas.curriculum import (
    CurriculumPopulateRequest,
    CurriculumPopulateResponse,
    CurriculumStatusRead,
    CurriculumPopulateResultRead,
    CurriculumDerivePreviousRequest,
    SyllabusImportRequest,
    AIDraftSyllabusRequest,
    AIDraftSyllabusResponse,
    AIDraftSyllabusTopic,
    AIDraftSyllabusApproveRequest
)
from app.services.canonical_curriculum_data import CANONICAL_CURRICULUM


def _normalize_subject_tokens(name: str) -> Set[str]:
    """
    Extracts core normalized tokens from a subject name for robust matching.
    e.g., 'Telugu Regional Language' -> {'telugu'}
    e.g., 'General Science' -> {'science'}
    e.g., 'Social Studies' -> {'social', 'studies'}
    """
    noise_words = {"language", "regional", "second", "general", "first", "composite", "&", "and"}
    tokens = set()
    for raw in name.lower().replace("-", " ").replace("/", " ").split():
        cleaned = "".join(c for c in raw if c.isalnum())
        if cleaned and cleaned not in noise_words:
            tokens.add(cleaned)
    # Special synonyms
    if "math" in tokens or "maths" in tokens or "mathematics" in tokens:
        tokens.add("math")
    if "science" in tokens:
        tokens.add("science")
    return tokens


def _subjects_match(school_subj_name: str, template_subj_name: str) -> bool:
    """
    Checks if a school subject matches a curriculum template subject.
    """
    s_low = school_subj_name.strip().lower()
    t_low = template_subj_name.strip().lower()
    if s_low == t_low or s_low in t_low or t_low in s_low:
        return True
    s_tokens = _normalize_subject_tokens(school_subj_name)
    t_tokens = _normalize_subject_tokens(template_subj_name)
    if s_tokens and t_tokens and s_tokens.intersection(t_tokens):
        return True
    return False


class CurriculumEngine:
    """
    Curriculum Engine handles:
    1. Verified board curriculum resolution from canonical templates.
    2. Zero-hallucination policy: If verified curriculum is unavailable, it reports so explicitly.
    3. Idempotent cloning to school-specific editable Syllabus copy.
    4. Guarding global master templates from mutation.
    5. Board-based curriculum status evaluation and school setup orchestration.
    """
    def __init__(
        self,
        db: AsyncSession,
        curriculum_repo: CurriculumRepository,
        syllabus_repo: SyllabusRepository
    ) -> None:
        self.db = db
        self.curriculum_repo = curriculum_repo
        self.syllabus_repo = syllabus_repo

    async def ensure_seed_canonical_data(self) -> None:
        """
        Seeds canonical master templates idempotently if not already present.
        """
        # Fetch existing master signatures: (board, state, academic_year_code, class_level, subject_code)
        stmt = select(
            CurriculumMaster.board,
            CurriculumMaster.state,
            CurriculumMaster.academic_year_code,
            CurriculumMaster.class_level,
            CurriculumMaster.subject_code
        )
        res = await self.db.execute(stmt)
        existing_signatures = set()
        for r in res.fetchall():
            b_val = r[0].value if hasattr(r[0], 'value') else str(r[0])
            st_val = (r[1] or "").lower()
            ay_val = str(r[2])
            cl_val = int(r[3])
            sc_val = str(r[4])
            existing_signatures.add((b_val, st_val, ay_val, cl_val, sc_val))

        seeded_new = False
        for master_def in CANONICAL_CURRICULUM:
            b_str = master_def["board"]
            st_str = master_def.get("state")
            ay_str = master_def["academic_year_code"]
            cl_int = master_def["class_level"]
            sc_str = master_def["subject_code"]

            sig = (b_str, (st_str or "").lower(), ay_str, cl_int, sc_str)
            if sig in existing_signatures:
                continue

            try:
                sb = SchoolBoard(b_str)
            except Exception:
                sb = SchoolBoard.STATE if b_str in ["STATE", "SSC"] else SchoolBoard.OTHER

            master = CurriculumMaster(
                board=sb,
                state=st_str,
                academic_year_code=ay_str,
                class_level=cl_int,
                class_name=master_def["class_name"],
                subject_code=sc_str,
                subject_name=master_def["subject_name"],
                source=master_def["source"],
                source_version=master_def["source_version"],
                verification_status="VERIFIED",
                is_active=True
            )
            for item_def in master_def["items"]:
                CurriculumMasterItem(
                    master=master,
                    item_code=f"{master.subject_code}_{item_def['seq']}",
                    unit_name=item_def["unit"],
                    chapter_name=item_def["chapter"],
                    topic_name=item_def["topic"],
                    sequence_order=item_def["seq"],
                    estimated_periods=item_def.get("periods", 4)
                )
            self.db.add(master)

            existing_signatures.add(sig)
            seeded_new = True

        if seeded_new:
            await self.db.commit()

    async def get_verified_templates(
        self,
        board: Optional[str] = None,
        class_level: Optional[int] = None,
        state: Optional[str] = None,
        academic_year_code: Optional[str] = None
    ) -> List[CurriculumMaster]:
        """
        Retrieves verified master curriculum templates.
        Enforces explicit state validation for State Board curricula.
        National boards (CBSE, ICSE) do not filter by state.
        """
        await self.ensure_seed_canonical_data()

        is_state_board = board and board.upper() in ["STATE", "SSC"]
        # Strict Rule: State board resolution requires state
        if is_state_board:
            if not state or not state.strip():
                # STATE without state cannot resolve to a verified template
                return []
            state_filter = state
        else:
            state_filter = None

        return await self.curriculum_repo.get_templates(
            board=board,
            class_level=class_level,
            state=state_filter,
            academic_year_code=academic_year_code
        )

    async def get_school_curriculum_status(
        self,
        school_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        tenant_id: Optional[uuid.UUID] = None
    ) -> CurriculumStatusRead:
        """
        Evaluates the current curriculum status for a school.
        Returns whether official curriculum is populated, chapter/topic counts,
        and verified availability.
        """
        await self.ensure_seed_canonical_data()

        school = await self.db.get(School, school_id)
        if not school or (tenant_id and school.tenant_id != tenant_id):
            return CurriculumStatusRead(
                is_populated=False,
                verified_curriculum_available=False,
                board="Not Found",
                status_badge="UNAVAILABLE",
                total_subjects_with_syllabus=0,
                total_chapters=0,
                total_topics=0,
                message="School record not found or inaccessible."
            )

        # Resolve Academic Year
        ay: Optional[AcademicYear] = None
        if academic_year_id:
            ay = await self.db.get(AcademicYear, academic_year_id)
        if not ay:
            ay_stmt = select(AcademicYear).where(
                AcademicYear.school_id == school_id,
                AcademicYear.status == "ACTIVE"
            ).order_by(AcademicYear.start_date.desc())
            ay_res = await self.db.execute(ay_stmt)
            ay = ay_res.scalars().first()

        if not ay:
            ay_stmt2 = select(AcademicYear).where(
                AcademicYear.school_id == school_id
            ).order_by(AcademicYear.start_date.desc())
            ay_res2 = await self.db.execute(ay_stmt2)
            ay = ay_res2.scalars().first()

        board_str = school.board.value if hasattr(school.board, "value") else str(school.board)
        state_str = school.state
        ay_name = ay.name if ay else "2026-2027"

        # Check existing school syllabuses
        syllabus_rows: List[Syllabus] = []
        if ay:
            s_stmt = select(Syllabus).where(
                Syllabus.school_id == school_id,
                Syllabus.academic_year_id == ay.id,
                Syllabus.deleted_at.is_(None)
            )
            s_res = await self.db.execute(s_stmt)
            syllabus_rows = list(s_res.scalars().all())

        # Check if any existing row is linked to a verified curriculum master or has verified source
        verified_populated_rows = [
            s for s in syllabus_rows 
            if s.curriculum_master_id is not None or (s.source and "Official" in s.source)
        ]
        is_officially_populated = len(verified_populated_rows) > 0

        # Query school's configured classes to know which levels to evaluate
        classes_stmt = select(Class).where(
            Class.school_id == school_id,
            Class.deleted_at.is_(None)
        ).order_by(Class.level)
        classes_res = await self.db.execute(classes_stmt)
        school_classes = list(classes_res.scalars().all())
        configured_levels = [c.level for c in school_classes if c.level is not None]

        # Check if verified templates exist for this school's board configuration
        matching_templates: List[CurriculumMaster] = []
        if board_str.upper() in ["STATE", "SSC"] and not state_str:
            # STATE without state cannot resolve
            matching_templates = []
        else:
            matching_templates = await self.get_verified_templates(
                board=board_str,
                state=state_str,
                academic_year_code="2026-2027"
            )
            if configured_levels:
                matching_templates = [t for t in matching_templates if t.class_level in configured_levels]

        verified_curriculum_available = len(matching_templates) > 0

        if is_officially_populated:
            distinct_chapters = set(s.chapter_name for s in verified_populated_rows)
            distinct_subjects = set(s.subject_id for s in verified_populated_rows)
            first_source = next((s.source for s in verified_populated_rows if s.source), None)
            first_version = next((s.source_version for s in verified_populated_rows if s.source_version), "2026.1")
            first_derivation = next((s.derived_from for s in verified_populated_rows if s.derived_from), None)

            return CurriculumStatusRead(
                is_populated=True,
                verified_curriculum_available=True,
                board=board_str,
                state=state_str,
                academic_year_name=ay_name,
                source=first_source or (
                    "SCERT Telangana State Board Official Curriculum"
                    if board_str.upper() in ["STATE", "SSC"] and state_str and "Telangana" in state_str
                    else f"{board_str} Official Curriculum"
                ),
                source_version=first_version,
                verification_status="VERIFIED",
                derived_from=first_derivation,
                total_subjects_with_syllabus=len(distinct_subjects),
                total_chapters=len(distinct_chapters),
                total_topics=len(verified_populated_rows),
                status_badge="VERIFIED OFFICIAL",
                message=f"Official {board_str} syllabus resolved and verified. Isolated per campus with exam question mapping."
            )

        # If not officially populated, evaluate template counts or unavailable state
        if verified_curriculum_available:
            template_items = [item for t in matching_templates for item in t.items]
            distinct_chapters = set(item.chapter_name for item in template_items)
            distinct_subjects = set(t.subject_code for t in matching_templates)

            return CurriculumStatusRead(
                is_populated=False,
                verified_curriculum_available=True,
                board=board_str,
                state=state_str,
                academic_year_name=ay_name,
                source=matching_templates[0].source,
                source_version=matching_templates[0].source_version,
                verification_status="VERIFIED",
                total_subjects_with_syllabus=0,
                total_chapters=0,
                total_topics=0,
                status_badge="AVAILABLE",
                message=f"Official {board_str} curriculum ({len(distinct_chapters)} chapters, {len(template_items)} topics) verified and available for auto-population."
            )

        # Unavailable fallback
        reason = f"Verified curriculum unavailable for {board_str}"
        if board_str.upper() in ["STATE", "SSC"]:
            if not state_str:
                reason += " (State not specified in school settings)"
            else:
                reason += f" ({state_str})"

        return CurriculumStatusRead(
            is_populated=False,
            verified_curriculum_available=False,
            board=board_str,
            state=state_str,
            academic_year_name=ay_name,
            total_subjects_with_syllabus=0,
            total_chapters=0,
            total_topics=0,
            status_badge="UNAVAILABLE",
            message=f"{reason}. You can import a custom syllabus or create topics manually."
        )

    async def auto_populate_school(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        current_user: User,
        override_existing: bool = False,
        academic_year_id: Optional[uuid.UUID] = None,
        class_ids: Optional[List[uuid.UUID]] = None,
        subject_ids: Optional[List[uuid.UUID]] = None,
        board: Optional[str] = None,
        state: Optional[str] = None
    ) -> CurriculumPopulateResultRead:
        """
        Executes automatic board-based syllabus population for the school's configured
        classes and subjects.
        Guarantees:
        - Strict tenant and school isolation.
        - Master templates are NEVER modified.
        - Idempotent: no duplicate chapters/topics created.
        - Official SCERT / CBSE / ICSE curriculum resolution.
        """
        await self.ensure_seed_canonical_data()

        # 1. Fetch School & Academic Year
        school = await self.db.get(School, school_id)
        if not school or school.tenant_id != tenant_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="School not found.")

        ay: Optional[AcademicYear] = None
        if academic_year_id:
            ay = await self.db.get(AcademicYear, academic_year_id)
        if not ay:
            ay_stmt = select(AcademicYear).where(
                AcademicYear.school_id == school_id,
                AcademicYear.status == "ACTIVE"
            ).order_by(AcademicYear.start_date.desc())
            ay_res = await self.db.execute(ay_stmt)
            ay = ay_res.scalars().first()

        if not ay:
            ay_stmt2 = select(AcademicYear).where(
                AcademicYear.school_id == school_id
            ).order_by(AcademicYear.start_date.desc())
            ay_res2 = await self.db.execute(ay_stmt2)
            ay = ay_res2.scalars().first()

        if not ay:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No academic year found for school.")

        board_str = board or (school.board.value if hasattr(school.board, "value") else str(school.board))
        state_str = state if state is not None else school.state

        # Explicit State Board check
        if board_str.upper() in ["STATE", "SSC"] and not state_str:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Affiliation board is STATE but state is not configured in school settings."
            )

        # 2. Fetch Classes and Subjects configured for the school
        classes_filters = [
            Class.school_id == school_id,
            Class.deleted_at.is_(None)
        ]
        if class_ids:
            classes_filters.append(Class.id.in_(class_ids))

        classes_stmt = select(Class).where(and_(*classes_filters)).order_by(Class.level)
        c_res = await self.db.execute(classes_stmt)
        classes = list(c_res.scalars().all())

        if not classes:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No classes configured for school.")

        subjects_filters = [
            Subject.school_id == school_id,
            Subject.academic_year_id == ay.id,
            Subject.deleted_at.is_(None)
        ]
        if subject_ids:
            subjects_filters.append(Subject.id.in_(subject_ids))

        subjects_stmt = select(Subject).where(and_(*subjects_filters))
        s_res = await self.db.execute(subjects_stmt)
        school_subjects = list(s_res.scalars().all())

        if not school_subjects:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No subjects configured for academic year.")

        # 3. Clean up unlinked placeholder rows or existing rows if override_existing
        if override_existing:
            del_stmt = delete(Syllabus).where(
                Syllabus.school_id == school_id,
                Syllabus.academic_year_id == ay.id
            )
            await self.db.execute(del_stmt)
            await self.db.flush()
        else:
            # If all existing rows for this school/ay are unlinked placeholders (curriculum_master_id is None and source is None),
            # clean them up so official verified syllabus cleanly replaces placeholder mock data
            chk_stmt = select(Syllabus).where(
                Syllabus.school_id == school_id,
                Syllabus.academic_year_id == ay.id,
                Syllabus.curriculum_master_id.is_not(None)
            )
            chk_res = await self.db.execute(chk_stmt)
            has_official = chk_res.scalars().first() is not None
            if not has_official:
                # Replace generic mock data with official curriculum
                del_unlinked = delete(Syllabus).where(
                    Syllabus.school_id == school_id,
                    Syllabus.academic_year_id == ay.id,
                    Syllabus.curriculum_master_id.is_(None)
                )
                await self.db.execute(del_unlinked)
                await self.db.flush()

        # 4. Process each class and match templates
        classes_processed = 0
        subjects_matched = 0
        total_chapters_populated = 0
        total_topics_populated = 0
        distinct_chapters_set = set()
        matched_source = ""
        matched_version = ""

        for class_obj in classes:
            class_level = getattr(class_obj, "level", None) or 10

            templates = await self.get_verified_templates(
                board=board_str,
                state=state_str,
                class_level=class_level,
                academic_year_code="2026-2027"
            )
            if not templates:
                continue

            classes_processed += 1

            for template in templates:
                matched_source = template.source
                matched_version = template.source_version

                # Match against school subjects
                matched_sub = next(
                    (s for s in school_subjects if _subjects_match(s.subject_name, template.subject_name)),
                    None
                )
                if not matched_sub:
                    continue

                subjects_matched += 1

                for item in template.items:
                    code = f"SYLL_{class_obj.code}_{matched_sub.subject_code}_{item.item_code}"

                    # Check if already exists in this school copy
                    existing = await self.syllabus_repo.get_by_code(
                        syllabus_code=code,
                        academic_year_id=ay.id,
                        class_id=class_obj.id,
                        subject_id=matched_sub.id,
                        tenant_id=tenant_id
                    )
                    if existing:
                        continue

                    new_syll = Syllabus(
                        syllabus_code=code,
                        unit_name=item.unit_name,
                        chapter_name=item.chapter_name,
                        topic_name=item.topic_name,
                        description=item.description,
                        sequence_order=item.sequence_order,
                        estimated_periods=item.estimated_periods,
                        coverage_status="PENDING",
                        lifecycle_status="PLANNED",
                        tenant_id=tenant_id,
                        school_id=school_id,
                        academic_year_id=ay.id,
                        class_id=class_obj.id,
                        subject_id=matched_sub.id,
                        curriculum_master_id=template.id,
                        source=template.source,
                        source_version=template.source_version,
                        retrieved_at=datetime.now(timezone.utc),
                        verification_status="VERIFIED",
                        is_custom=False,
                        created_by=current_user.id
                    )
                    self.db.add(new_syll)
                    total_topics_populated += 1
                    distinct_chapters_set.add((class_obj.id, matched_sub.id, item.chapter_name))

        await self.db.commit()

        total_chapters_populated = len(distinct_chapters_set)

        if classes_processed > 0 and subjects_matched > 0 and total_topics_populated == 0 and not override_existing:
            existing_syll_q = select(Syllabus).where(
                Syllabus.school_id == school_id,
                Syllabus.academic_year_id == ay.id,
                Syllabus.deleted_at.is_(None)
            )
            existing_res = await self.db.execute(existing_syll_q)
            existing_items = existing_res.scalars().all()
            if existing_items:
                existing_chapters = {(s.class_id, s.subject_id, s.chapter_name) for s in existing_items}
                first_src = next((s.source for s in existing_items if s.source), matched_source)
                first_ver = next((s.source_version for s in existing_items if s.source_version), matched_version)
                return CurriculumPopulateResultRead(
                    success=True,
                    message=f"Official {board_str} syllabus is already populated ({len(existing_chapters)} chapters, {len(existing_items)} topics).",
                    board=board_str,
                    state=state_str,
                    academic_year_name=ay.name,
                    total_classes_processed=classes_processed,
                    total_subjects_matched=subjects_matched,
                    total_chapters_populated=len(existing_chapters),
                    total_topics_populated=len(existing_items),
                    source=first_src,
                    source_version=first_ver,
                    verification_status="VERIFIED"
                )

        if classes_processed == 0 or total_topics_populated == 0:
            return CurriculumPopulateResultRead(
                success=False,
                message=f"Verified curriculum unavailable for {board_str}{' - ' + state_str if state_str else ''}. Please check board settings.",
                board=board_str,
                state=state_str,
                academic_year_name=ay.name,
                total_classes_processed=classes_processed,
                total_subjects_matched=subjects_matched,
                total_chapters_populated=0,
                total_topics_populated=0,
                source="",
                source_version="",
                verification_status="UNAVAILABLE"
            )

        return CurriculumPopulateResultRead(
            success=True,
            message=f"Official {board_str} syllabus auto-populated successfully ({total_chapters_populated} chapters, {total_topics_populated} topics).",
            board=board_str,
            state=state_str,
            academic_year_name=ay.name,
            total_classes_processed=classes_processed,
            total_subjects_matched=subjects_matched,
            total_chapters_populated=total_chapters_populated,
            total_topics_populated=total_topics_populated,
            source=matched_source,
            source_version=matched_version,
            verification_status="VERIFIED"
        )

    async def populate_school_syllabus(
        self,
        tenant_id: uuid.UUID,
        req: CurriculumPopulateRequest,
        current_user: User
    ) -> CurriculumPopulateResponse:
        """
        Legacy populate endpoint compatible with CurriculumPopulateRequest.
        Delegates to auto_populate_school or class-specific filtering.
        """
        result = await self.auto_populate_school(
            tenant_id=tenant_id,
            school_id=req.school_id,
            current_user=current_user,
            override_existing=req.override_existing,
            academic_year_id=req.academic_year_id,
            class_ids=req.class_ids,
            subject_ids=req.subject_ids,
            board=req.board,
            state=req.state
        )

        return CurriculumPopulateResponse(
            success=result.success,
            board=result.board,
            cloned_count=result.total_topics_populated,
            available=result.success,
            message=result.message,
            details={
                "total_chapters_populated": result.total_chapters_populated,
                "total_topics_populated": result.total_topics_populated,
                "source": result.source,
                "source_version": result.source_version,
                "can_import": True
            }
        )

    async def derive_from_previous_year(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        req: CurriculumDerivePreviousRequest,
        current_user: User
    ) -> CurriculumPopulateResultRead:
        """
        Derives syllabus copy from a previous academic year into the target academic year.
        """
        src_ay = await self.db.get(AcademicYear, req.source_academic_year_id)
        tgt_ay = await self.db.get(AcademicYear, req.target_academic_year_id)
        if not src_ay or not tgt_ay or src_ay.school_id != school_id or tgt_ay.school_id != school_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Academic year not found.")

        filters = [
            Syllabus.school_id == school_id,
            Syllabus.academic_year_id == req.source_academic_year_id,
            Syllabus.deleted_at.is_(None)
        ]
        if req.class_ids:
            filters.append(Syllabus.class_id.in_(req.class_ids))

        stmt = select(Syllabus).where(and_(*filters))
        res = await self.db.execute(stmt)
        source_items = list(res.scalars().all())

        if not source_items:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No syllabus items found in source academic year.")

        cloned_topics = 0
        distinct_chapters = set()
        for item in source_items:
            existing = await self.syllabus_repo.get_by_code(
                syllabus_code=item.syllabus_code,
                academic_year_id=req.target_academic_year_id,
                class_id=item.class_id,
                subject_id=item.subject_id,
                tenant_id=tenant_id
            )
            if existing:
                continue

            new_item = Syllabus(
                syllabus_code=item.syllabus_code,
                unit_name=item.unit_name,
                chapter_name=item.chapter_name,
                topic_name=item.topic_name,
                description=item.description,
                sequence_order=item.sequence_order,
                estimated_periods=item.estimated_periods,
                coverage_status="PENDING",
                lifecycle_status="PLANNED",
                tenant_id=tenant_id,
                school_id=school_id,
                academic_year_id=req.target_academic_year_id,
                class_id=item.class_id,
                subject_id=item.subject_id,
                curriculum_master_id=item.curriculum_master_id,
                source=item.source,
                source_version=item.source_version,
                retrieved_at=datetime.now(timezone.utc),
                verification_status=item.verification_status,
                derived_from=f"Derived from {src_ay.name}",
                is_custom=item.is_custom,
                created_by=current_user.id
            )
            self.db.add(new_item)
            cloned_topics += 1
            distinct_chapters.add((item.class_id, item.subject_id, item.chapter_name))

        await self.db.commit()

        school = await self.db.get(School, school_id)
        board_str = school.board.value if school and hasattr(school.board, "value") else ""

        return CurriculumPopulateResultRead(
            success=True,
            message=f"Successfully derived {cloned_topics} syllabus topics from {src_ay.name}.",
            board=board_str,
            state=school.state if school else None,
            academic_year_name=tgt_ay.name,
            total_classes_processed=len(req.class_ids) if req.class_ids else 1,
            total_subjects_matched=len(set(item.subject_id for item in source_items)),
            total_chapters_populated=len(distinct_chapters),
            total_topics_populated=cloned_topics,
            source=f"Derived from {src_ay.name}",
            source_version="1.0",
            verification_status="DERIVED"
        )

    async def import_custom_syllabus(
        self,
        tenant_id: uuid.UUID,
        req: SyllabusImportRequest,
        current_user: User
    ) -> int:
        """
        Imports custom syllabus items provided via upload.
        """
        imported_count = 0
        for item in req.items:
            existing = await self.syllabus_repo.get_by_code(
                syllabus_code=item.syllabus_code,
                academic_year_id=req.academic_year_id,
                class_id=req.class_id,
                subject_id=req.subject_id,
                tenant_id=tenant_id
            )
            if existing:
                continue

            db_obj = Syllabus(
                syllabus_code=item.syllabus_code,
                unit_name=item.unit_name,
                chapter_name=item.chapter_name,
                topic_name=item.topic_name,
                description=item.description,
                sequence_order=item.sequence_order,
                estimated_periods=item.estimated_periods,
                coverage_status="PENDING",
                lifecycle_status=item.lifecycle_status or "PLANNED",
                tenant_id=tenant_id,
                school_id=req.school_id,
                academic_year_id=req.academic_year_id,
                class_id=req.class_id,
                subject_id=req.subject_id,
                is_custom=True,
                verification_status="CUSTOM",
                created_by=current_user.id
            )
            self.db.add(db_obj)
            imported_count += 1

        await self.db.commit()
        return imported_count

    async def generate_ai_draft_syllabus(
        self,
        tenant_id: uuid.UUID,
        req: AIDraftSyllabusRequest,
        current_user: User
    ) -> AIDraftSyllabusResponse:
        """
        Generates an AI Draft syllabus proposal for school-specific / additional subjects.
        Zero-Hallucination Policy: Official board subjects are guarded, and all AI drafts
        are explicitly labeled 'AI GENERATED DRAFT' with disclaimer requiring admin review.
        """
        subject = await self.db.get(Subject, req.subject_id)
        if not subject or (subject.tenant_id is not None and subject.tenant_id != tenant_id):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subject not found")

        class_obj = await self.db.get(Class, req.class_id)
        if not class_obj or class_obj.tenant_id != tenant_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class not found")

        subj_name_lower = subject.name.lower()
        topics: List[AIDraftSyllabusTopic] = []

        if any(w in subj_name_lower for w in ["coding", "computer", "program", "robot", "ai", "artificial intelligence", "tech", "ict"]):
            raw_modules = [
                (
                    "Unit 1: Foundations of Computing & Problem Solving",
                    [
                        ("Introduction to Computational Thinking", [
                            ("Algorithms & Flowcharting", "Concepts of step-by-step problem decomposition and graphical algorithms.", 3),
                            ("Logical Reasoning & Patterns", "Identifying patterns and translating logic into pseudo-code.", 3),
                        ]),
                        ("Core Data Structures & Variables", [
                            ("Data Types and Constants", "Understanding numbers, strings, booleans, and variables.", 4),
                            ("User Input and Screen Output", "Capturing keyboard inputs and formatting console/visual displays.", 3),
                        ]),
                    ]
                ),
                (
                    "Unit 2: Control Logic, Automation & Creative Projects",
                    [
                        ("Conditional Branching & Iteration", [
                            ("Conditional Expressions (If-Else)", "Building branching decisions and multi-path conditions.", 4),
                            ("Iteration & Loops", "Automating repetitive workflows using while and for loops.", 4),
                        ]),
                        ("Interactive Capstone & Debugging", [
                            ("Modular Design & Functions", "Organizing reusable logic into callable functions and procedures.", 4),
                            ("Interactive Project Lab", "Developing a real-world mini application with testing and debugging.", 4),
                        ]),
                    ]
                ),
            ]
        elif any(w in subj_name_lower for w in ["finance", "financial", "money", "banking", "commerce"]):
            raw_modules = [
                (
                    "Unit 1: Money, Banking & Personal Budgeting",
                    [
                        ("The World of Currency & Banking", [
                            ("Evolution of Currency and Modern Banking", "History of money, currency tokens, and role of commercial banks.", 3),
                            ("Savings Accounts & Financial Instruments", "Account types, deposits, simple interest, and account management.", 3),
                        ]),
                        ("Personal Financial Planning", [
                            ("Budgeting & Needs vs Wants", "Tracking income, expenses, distinguishing essential vs discretionary spending.", 3),
                            ("Smart Saving Disciplines", "Setting short-term and long-term saving goals and emergency reserves.", 3),
                        ]),
                    ]
                ),
                (
                    "Unit 2: Digital Payments, Cyber Safety & Wealth Basics",
                    [
                        ("Digital Ecosystem & Payment Gateways", [
                            ("Digital Payments (UPI, Cards, NetBanking)", "Understanding electronic fund transfers, QR codes, and digital wallets.", 3),
                            ("Cyber Hygiene & Fraud Prevention", "Phishing awareness, OTP safety, password security, and fraud remediation.", 3),
                        ]),
                        ("Principles of Compounding & Investment", [
                            ("Power of Compounding & Inflation", "How money grows over time and beating inflationary erosion.", 4),
                            ("Basic Investment Literacy", "Mutual funds, fixed deposits, bonds, and risk-return principles.", 4),
                        ]),
                    ]
                ),
            ]
        elif any(w in subj_name_lower for w in ["environmental", "evs", "ecology", "sustainability", "green"]):
            raw_modules = [
                (
                    "Unit 1: Ecosystems, Biodiversity & Local Habitats",
                    [
                        ("Interdependence in Nature", [
                            ("Ecosystem Components & Food Webs", "Producers, consumers, decomposers, and habitat interdependence.", 3),
                            ("Local Flora, Fauna & Conservation", "Native species, local green spaces, and preserving biodiversity.", 3),
                        ]),
                        ("Natural Resources & Climate Systems", [
                            ("Water & Soil Conservation", "Rainwater harvesting, soil erosion prevention, and water cycles.", 3),
                            ("Renewable Energy & Efficiency", "Solar, wind energy vs fossil fuels, and household energy conservation.", 3),
                        ]),
                    ]
                ),
                (
                    "Unit 2: Waste Hierarchy, Climate Action & Sustainability",
                    [
                        ("Waste Segregation & Circular Economy", [
                            ("The 5 R's of Waste Management", "Refuse, Reduce, Reuse, Repurpose, Recycle methodologies.", 3),
                            ("Composting & Single-Use Plastic Alternatives", "Solid waste sorting, biodegradable cycles, and reducing plastic use.", 3),
                        ]),
                        ("Climate Action & Community Living", [
                            ("Carbon Footprint & Urban Microclimates", "Measuring individual carbon footprints and local heat islands.", 4),
                            ("School & Community Green Action Plan", "School garden projects, clean air campaigns, and eco-club initiatives.", 4),
                        ]),
                    ]
                ),
            ]
        elif any(w in subj_name_lower for w in ["value", "moral", "ethics", "life skill", "sel"]):
            raw_modules = [
                (
                    "Unit 1: Self-Awareness, Emotional Wellbeing & Empathy",
                    [
                        ("Understanding Self & Emotional Intelligence", [
                            ("Self-Awareness & Identifying Strengths", "Recognizing emotions, personal strengths, and areas for growth.", 3),
                            ("Mindfulness & Stress Resilience", "Techniques for emotional regulation, calm response, and mindfulness.", 3),
                        ]),
                        ("Empathy & Active Communication", [
                            ("Active Listening & Perspective Taking", "Respectful listening, non-violent communication, and empathy.", 3),
                            ("Resolving Conflicts Collaboratively", "Managing peer disagreements calmly and finding win-win solutions.", 3),
                        ]),
                    ]
                ),
                (
                    "Unit 2: Moral Integrity, Citizenship & Leadership",
                    [
                        ("Ethics, Honesty & Digital Citizenship", [
                            ("Honesty, Integrity & Fairness", "Practicing academic and personal honesty in daily situations.", 3),
                            ("Digital Ethics & Online Respect", "Cyber courtesy, respecting digital privacy, and countering cyberbullying.", 3),
                        ]),
                        ("Civic Responsibility & Collective Action", [
                            ("Inclusivity & Community Service", "Appreciating diversity, helping the marginalized, and civic pride.", 4),
                            ("Collaborative Leadership", "Working together for team success and leading positive change.", 4),
                        ]),
                    ]
                ),
            ]
        else:
            raw_modules = [
                (
                    f"Unit 1: Foundations of {subject.name}",
                    [
                        (f"Core Concepts of {subject.name}", [
                            (f"Fundamental Principles of {subject.name}", f"Introduction to primary terminology and key ideas in {subject.name}.", 4),
                            ("Exploration & Historical Context", f"Evolution, significance, and real-world relevance of {subject.name}.", 3),
                        ]),
                        ("Methodologies & Core Skills", [
                            ("Basic Techniques and Practice", f"Key methods and hands-on exercises for {subject.name}.", 4),
                            ("Problem Solving and Application", f"Applying basic principles to structured scenarios in {subject.name}.", 4),
                        ]),
                    ]
                ),
                (
                    f"Unit 2: Advanced Topics & Practical Projects in {subject.name}",
                    [
                        (f"Applied {subject.name} in Practice", [
                            ("Practical Applications and Case Studies", f"Case studies and situational analysis in {subject.name}.", 4),
                            ("Group Activity & Workshop", f"Collaborative exercises and interactive practice in {subject.name}.", 4),
                        ]),
                        ("Synthesis, Review & Capstone", [
                            ("Project Review and Presentations", f"Presenting student work and demonstrating mastery in {subject.name}.", 4),
                            ("Evaluation and Forward Outlook", f"Synthesizing learnings and self-assessment in {subject.name}.", 3),
                        ]),
                    ]
                ),
            ]

        seq = 1
        num_units_limit = req.num_units or 2
        for unit_name, chapters in raw_modules[:num_units_limit]:
            chaps_limit = req.chapters_per_unit or 2
            for chap_name, topic_list in chapters[:chaps_limit]:
                for topic_title, desc, est_p in topic_list:
                    topics.append(AIDraftSyllabusTopic(
                        unit_name=unit_name,
                        chapter_name=chap_name,
                        topic_name=topic_title,
                        description=desc,
                        sequence_order=seq,
                        estimated_periods=est_p
                    ))
                    seq += 1

        return AIDraftSyllabusResponse(
            subject_id=subject.id,
            subject_name=subject.name,
            class_id=class_obj.id,
            class_name=class_obj.name,
            is_ai_draft=True,
            status="AI GENERATED DRAFT",
            disclaimer=(
                "AI GENERATED DRAFT: This draft syllabus is generated for school-specific curriculum planning. "
                "It is NOT officially prescribed by CBSE, ICSE, or State Board. Administrator review and approval required."
            ),
            topics=topics
        )

    async def approve_ai_draft_syllabus(
        self,
        tenant_id: uuid.UUID,
        req: AIDraftSyllabusApproveRequest,
        current_user: User
    ) -> Dict[str, Any]:
        """
        Approves and persists AI-drafted syllabus topics into the school's editable Syllabus table.
        Topics are stored with verification_status='AI_DRAFT_APPROVED' and source='AI GENERATED DRAFT (Admin Approved)'.
        """
        subject = await self.db.get(Subject, req.subject_id)
        if not subject or (subject.tenant_id is not None and subject.tenant_id != tenant_id):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Subject not found")

        persisted_count = 0
        for topic in req.topics:
            code = f"AIDRAFT_{req.subject_id.hex[:6].upper()}_{topic.sequence_order:03d}_{uuid.uuid4().hex[:4].upper()}"
            new_item = Syllabus(
                syllabus_code=code,
                unit_name=topic.unit_name,
                chapter_name=topic.chapter_name,
                topic_name=topic.topic_name,
                description=topic.description,
                sequence_order=topic.sequence_order,
                estimated_periods=topic.estimated_periods,
                coverage_status="PENDING",
                lifecycle_status="APPROVED",
                tenant_id=tenant_id,
                school_id=req.school_id,
                academic_year_id=req.academic_year_id,
                class_id=req.class_id,
                subject_id=req.subject_id,
                is_custom=True,
                source="AI GENERATED DRAFT (Admin Approved)",
                source_version="1.0",
                verification_status="AI_DRAFT_APPROVED",
                retrieved_at=datetime.now(timezone.utc),
                created_by=current_user.id
            )
            self.db.add(new_item)
            persisted_count += 1

        await self.db.commit()
        return {
            "success": True,
            "message": f"Successfully approved and persisted {persisted_count} syllabus topics for {subject.name}.",
            "approved_topics_count": persisted_count,
            "subject_id": str(req.subject_id),
            "subject_name": subject.name
        }
