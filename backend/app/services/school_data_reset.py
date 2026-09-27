import uuid
import logging
import hashlib
import json
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List, Optional, Tuple
import jwt
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker
from sqlalchemy import text, select
from app.core.settings import settings
from app.models.school import School
from app.models.tenant import Tenant
from app.models.user import User
from app.models.role import Role, user_roles
from app.models.school_reset_audit import SchoolResetAudit
from app.schemas.school import SchoolDataResetRequest, SchoolDataResetResponse, SchoolDataSummaryResponse

logger = logging.getLogger(__name__)

ALLOWED_RESET_ROLES = {"SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN"}
ACTIVE_LOCK_WINDOW_MINUTES = 10
CONFIRMATION_TOKEN_EXPIRY_MINUTES = 15


class SchoolDataResetService:
    """
    Dedicated, transactional service for safely resetting a school's operational,
    academic, and onboarding child data while strictly preserving the school identity,
    tenant entity, all user accounts, administrator access, and authentication configuration.
    """

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    def _format_id(self, val: Any) -> Any:
        if val is None:
            return None
        dialect_name = ""
        bind = getattr(self.db, "bind", None)
        if not bind and hasattr(self.db, "get_bind"):
            try:
                bind = self.db.get_bind()
            except Exception:
                bind = None
        if bind and hasattr(bind, "dialect"):
            dialect_name = bind.dialect.name

        if dialect_name == "sqlite":
            if isinstance(val, uuid.UUID):
                return val.hex
            if isinstance(val, str) and len(val) == 36 and "-" in val:
                try:
                    return uuid.UUID(val).hex
                except Exception:
                    return val
        return val

    async def get_school(self, school_id: uuid.UUID) -> School:
        res = await self.db.execute(
            select(School).where(School.id == school_id)
        )
        school = res.scalar_one_or_none()
        if not school:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"School with ID '{school_id}' not found."
            )
        return school

    async def get_tenant(self, tenant_id: uuid.UUID) -> Tenant:
        res = await self.db.execute(
            select(Tenant).where(Tenant.id == tenant_id)
        )
        tenant = res.scalar_one_or_none()
        if not tenant:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Tenant with ID '{tenant_id}' not found."
            )
        return tenant

    async def verify_authorization(self, current_user: Any, school: School, tenant_id: uuid.UUID) -> Tuple[str, str]:
        """
        Enforces strict RBAC and multi-tenancy boundaries:
        - Only SUPER_ADMIN, SYSTEM_ADMIN, and TENANT_ADMIN allowed.
        - School must belong to requested tenant.
        - Non-superusers must belong to requested tenant.
        Returns actor_id and primary_role.
        """
        is_superuser = bool(getattr(current_user, "is_superuser", False))
        user_roles_set = set()

        user_dict = getattr(current_user, "__dict__", {})
        if "roles" in user_dict and user_dict["roles"]:
            for r in user_dict["roles"]:
                code = getattr(r, "code", str(r))
                user_roles_set.add(str(code).upper())
        elif hasattr(current_user, "id"):
            stmt = select(Role.code).join(user_roles, user_roles.c.role_id == Role.id).where(user_roles.c.user_id == current_user.id)
            res = await self.db.execute(stmt)
            for code in res.scalars().all():
                user_roles_set.add(str(code).upper())

        if not is_superuser and not (user_roles_set & ALLOWED_RESET_ROLES):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Only Super Administrators, System Administrators, and Tenant Administrators can reset school data."
            )

        # Multi-tenancy isolation
        if str(school.tenant_id) != str(tenant_id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="School does not belong to the active tenant."
            )

        user_tenant_id = getattr(current_user, "tenant_id", None)
        if not is_superuser and user_tenant_id and str(user_tenant_id) != str(tenant_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied. Cross-tenant reset operations are strictly prohibited."
            )

        actor_id = str(getattr(current_user, "id", "unknown"))
        primary_role = "SUPER_ADMIN" if is_superuser else (list(user_roles_set & ALLOWED_RESET_ROLES)[0] if (user_roles_set & ALLOWED_RESET_ROLES) else "UNKNOWN")
        return actor_id, primary_role

    def generate_confirmation_token(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        actor_id: str,
        total_records: int,
        counts_hash: str,
        expires_minutes: int = CONFIRMATION_TOKEN_EXPIRY_MINUTES
    ) -> Tuple[str, datetime]:
        """
        Generates a cryptographically signed JWT confirmation token tied to the
        actor, school, tenant, and summary counts hash.
        """
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=expires_minutes)
        payload = {
            "sub": str(actor_id),
            "school_id": str(school_id),
            "tenant_id": str(tenant_id),
            "total_records": total_records,
            "counts_hash": counts_hash,
            "type": "school_reset_confirmation",
            "exp": expires_at,
            "iat": datetime.now(timezone.utc),
        }
        token = jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
        return token, expires_at

    def verify_confirmation_token(
        self,
        token: str,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        actor_id: str
    ) -> Dict[str, Any]:
        """
        Verifies the validity, expiry, and context binding of the confirmation token.
        Raises HTTP 422 if invalid, expired, or bound to a different context.
        """
        if not token or not token.strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Missing confirmation token. Please review the school data summary first."
            )
        try:
            payload = jwt.decode(token.strip(), settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Reset confirmation token has expired. Please refresh the data summary before confirming."
            )
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Invalid reset confirmation token. It does not match the system verification signature."
            )

        if payload.get("type") != "school_reset_confirmation":
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Invalid token type supplied for school reset confirmation."
            )

        if payload.get("school_id") != str(school_id):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Confirmation token was issued for a different school."
            )

        if payload.get("tenant_id") != str(tenant_id):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Confirmation token was issued for a different tenant."
            )

        if payload.get("sub") != str(actor_id):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Confirmation token was issued to a different administrator."
            )

        return payload

    async def _record_durable_audit(
        self,
        audit_id: str,
        status: str,
        school_id: uuid.UUID,
        school_name: str,
        tenant_id: uuid.UUID,
        actor_id: Optional[uuid.UUID],
        actor_role: str,
        actor_email: str,
        reason: str,
        deletion_counts: Optional[Dict[str, Any]] = None,
        total_records_deleted: int = 0,
        error_message: Optional[str] = None,
        summary_snapshot: Optional[Dict[str, Any]] = None,
    ) -> None:
        """
        Writes or updates a durable SchoolResetAudit record in a genuinely separate database session.
        This guarantees audit records for STARTED, FAILED, and ROLLED_BACK survive transaction rollback.
        """
        async_session_factory = async_sessionmaker(
            bind=self.db.bind,
            class_=AsyncSession,
            expire_on_commit=False,
            autocommit=False,
            autoflush=False
        )
        async with async_session_factory() as audit_db:
            try:
                stmt = select(SchoolResetAudit).where(SchoolResetAudit.audit_id == audit_id)
                res = await audit_db.execute(stmt)
                record = res.scalar_one_or_none()
                now = datetime.now(timezone.utc)

                if not record:
                    record = SchoolResetAudit(
                        id=uuid.uuid4(),
                        audit_id=audit_id,
                        actor_id=actor_id,
                        actor_role=actor_role,
                        actor_email=actor_email,
                        tenant_id=tenant_id,
                        school_id=school_id,
                        school_name=school_name,
                        reason=reason,
                        status=status,
                        deletion_counts=deletion_counts,
                        total_records_deleted=total_records_deleted,
                        error_message=error_message,
                        summary_snapshot=summary_snapshot,
                        created_at=now,
                        updated_at=now,
                    )
                    audit_db.add(record)
                else:
                    record.status = status
                    record.updated_at = now
                    if deletion_counts is not None:
                        record.deletion_counts = deletion_counts
                    record.total_records_deleted = total_records_deleted
                    if error_message is not None:
                        record.error_message = error_message
                    if summary_snapshot is not None:
                        record.summary_snapshot = summary_snapshot

                await audit_db.commit()
            except Exception as audit_err:
                logger.error(f"Failed to record durable audit log (audit_id={audit_id}): {audit_err}", exc_info=True)

    async def _check_concurrency(self, school_id: uuid.UUID) -> None:
        """
        Checks if another reset operation is currently running for the target school.
        """
        cutoff = datetime.now(timezone.utc) - timedelta(minutes=ACTIVE_LOCK_WINDOW_MINUTES)
        stmt = (
            select(SchoolResetAudit)
            .where(
                SchoolResetAudit.school_id == school_id,
                SchoolResetAudit.status == "STARTED",
                SchoolResetAudit.updated_at >= cutoff
            )
        )
        res = await self.db.execute(stmt)
        active_audit = res.scalar_one_or_none()
        if active_audit:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A school data reset is already in progress for this school. Please wait for it to complete."
            )

    async def get_school_data_summary(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        current_user: Any
    ) -> SchoolDataSummaryResponse:
        """
        Returns live record counts for all school-scoped child tables and preserved entities.
        Includes query health checks, blocking dependencies, and signed confirmation token.
        """
        school = await self.get_school(school_id)
        tenant = await self.get_tenant(tenant_id)
        actor_id, _ = await self.verify_authorization(current_user, school, tenant_id)

        summary_queries = [
            ("students", "SELECT COUNT(*) FROM students WHERE school_id = :sid"),
            ("guardians", "SELECT COUNT(*) FROM guardians WHERE school_id = :sid"),
            ("teachers", "SELECT COUNT(*) FROM teachers WHERE school_id = :sid"),
            ("teacher_assignments", "SELECT COUNT(*) FROM teacher_subject_assignments WHERE school_id = :sid"),
            ("classes", "SELECT COUNT(*) FROM classes WHERE school_id = :sid"),
            ("sections", "SELECT COUNT(*) FROM sections WHERE school_id = :sid"),
            ("subjects", "SELECT COUNT(*) FROM subjects WHERE school_id = :sid"),
            ("academic_years", "SELECT COUNT(*) FROM academic_years WHERE school_id = :sid"),
            ("timetables", "SELECT COUNT(*) FROM timetables WHERE school_id = :sid"),
            ("attendance_records", "SELECT COUNT(*) FROM attendances WHERE school_id = :sid"),
            ("attendance_sessions", "SELECT COUNT(*) FROM attendance_sessions WHERE school_id = :sid"),
            ("staff_attendances", "SELECT COUNT(*) FROM staff_attendances WHERE school_id = :sid"),
            ("teacher_leaves", "SELECT COUNT(*) FROM teacher_leaves WHERE school_id = :sid"),
            ("examinations", "SELECT COUNT(*) FROM examinations WHERE school_id = :sid"),
            ("exam_schedules", "SELECT COUNT(*) FROM exam_schedules WHERE school_id = :sid"),
            ("marks", "SELECT COUNT(*) FROM marks WHERE school_id = :sid"),
            ("report_cards", "SELECT COUNT(*) FROM report_card_publications WHERE school_id = :sid"),
            ("fee_structures", "SELECT COUNT(*) FROM fee_structures WHERE school_id = :sid"),
            ("fee_assignments", "SELECT COUNT(*) FROM student_fee_assignments WHERE student_id IN (SELECT id FROM students WHERE school_id = :sid)"),
            ("fee_payments", "SELECT COUNT(*) FROM fee_payments WHERE student_id IN (SELECT id FROM students WHERE school_id = :sid)"),
            ("homeworks", "SELECT COUNT(*) FROM homeworks WHERE school_id = :sid"),
            ("syllabuses", "SELECT COUNT(*) FROM syllabuses WHERE school_id = :sid"),
            ("import_jobs", "SELECT COUNT(*) FROM import_jobs WHERE school_id = :sid"),
            ("announcements", "SELECT COUNT(*) FROM announcements WHERE school_id = :sid"),
            ("school_events", "SELECT COUNT(*) FROM school_events WHERE school_id = :sid"),
            ("communication_requests", "SELECT COUNT(*) FROM communication_requests WHERE school_id = :sid"),
            ("notifications", "SELECT COUNT(*) FROM notifications WHERE school_id = :sid"),
            ("parent_login_sequences", "SELECT COUNT(*) FROM parent_login_sequences WHERE school_id = :sid"),
        ]

        records_to_delete: Dict[str, int] = {}
        query_errors: List[str] = []
        blocking_dependencies: List[str] = []
        warnings: List[str] = []
        eligible = True

        formatted_sid = self._format_id(school_id)
        formatted_tid = self._format_id(tenant_id)

        for key, query in summary_queries:
            try:
                res = await self.db.execute(text(query), {"sid": formatted_sid, "tid": formatted_tid})
                val = res.scalar() or 0
                records_to_delete[key] = val
            except Exception as q_err:
                logger.error(f"Summary query check failed for category '{key}': {q_err}", exc_info=True)
                records_to_delete[key] = 0
                query_errors.append(f"Failed to query operational records for category '{key}'.")
                blocking_dependencies.append(f"Unresolved database dependency: {key}")
                eligible = False

        total_records = sum(records_to_delete.values())

        # Preserved records overview
        preserved_counts: Dict[str, Any] = {
            "tenant": tenant.name,
            "school_identity": f"{school.name} ({school.code})",
            "user_accounts": "100% preserved (no users deleted)",
            "admin_access": "Preserved",
            "auth_configuration": "Preserved",
            "other_schools": "Preserved",
            "master_catalogs": "Preserved",
        }

        confirmation_token = None
        token_expires_at = None

        if eligible:
            counts_hash = hashlib.sha256(
                json.dumps(records_to_delete, sort_keys=True).encode()
            ).hexdigest()[:16]
            confirmation_token, token_expires_at = self.generate_confirmation_token(
                school_id=school.id,
                tenant_id=tenant.id,
                actor_id=actor_id,
                total_records=total_records,
                counts_hash=counts_hash
            )
        else:
            warnings.append("Data summary contains unresolved query dependencies. Reset is disabled until all checks pass.")

        return SchoolDataSummaryResponse(
            school_id=school.id,
            school_name=school.name,
            tenant_id=tenant.id,
            tenant_name=tenant.name,
            records_to_delete=records_to_delete,
            total_records_to_delete=total_records,
            records_to_preserve=preserved_counts,
            eligible=eligible,
            blocking_dependencies=blocking_dependencies,
            query_errors=query_errors,
            warnings=warnings,
            confirmation_token=confirmation_token,
            token_expires_at=token_expires_at
        )

    async def reset_school_data(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        payload: SchoolDataResetRequest,
        current_user: Any
    ) -> SchoolDataResetResponse:
        """
        Safely purges operational and onboarding child data belonging exclusively to the selected school.
        Executes strictly in a single atomic transaction with full rollback on any failure.
        Maintains durable audit logs that survive transaction rollbacks.
        """
        audit_id = str(uuid.uuid4())
        school = await self.get_school(school_id)
        tenant = await self.get_tenant(tenant_id)
        actor_id, actor_role = await self.verify_authorization(current_user, school, tenant_id)
        actor_email = str(getattr(current_user, "email", "unknown"))
        actor_uuid = uuid.UUID(actor_id) if actor_id and actor_id != "unknown" else None
        school_name = str(school.name)

        # 1. Input Validations
        if payload.school_name != school_name:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=f"Confirmation school name '{payload.school_name}' does not match the actual school name '{school_name}'."
            )

        if not payload.confirm_destruction:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Confirmation checkbox must be checked to proceed with school data reset."
            )

        if not payload.reason or len(payload.reason.strip()) < 3:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="A valid justification reason (at least 3 characters) is required for resetting school data."
            )

        # 2. Verify Confirmation Token
        self.verify_confirmation_token(
            token=payload.confirmation_token,
            school_id=school_id,
            tenant_id=tenant_id,
            actor_id=actor_id
        )

        # 3. Concurrency Protection
        await self._check_concurrency(school_id)

        # 4. Record Durable Audit: STARTED (Survives any subsequent rollback)
        await self._record_durable_audit(
            audit_id=audit_id,
            status="STARTED",
            school_id=school_id,
            school_name=school_name,
            tenant_id=tenant_id,
            actor_id=actor_uuid,
            actor_role=actor_role,
            actor_email=actor_email,
            reason=payload.reason.strip(),
            summary_snapshot={"confirmation_token_received": True}
        )

        logger.info(
            f"AUDIT LOG [SCHOOL_DATA_RESET_STARTED]: "
            f"audit_id={audit_id}, actor_id={actor_id}, actor_role={actor_role}, actor_email={actor_email}, "
            f"tenant_id={tenant_id}, school_id={school_id}, school_name='{school_name}', "
            f"reason='{payload.reason.strip()}'"
        )

        deleted_counts: Dict[str, int] = {}

        # 5. Ordered Deletion Sequence to satisfy all foreign-key constraints
        # Strictly school-scoped child tables only across all 47 operational tables
        deletion_steps = [
            # Financials (allocations and payments first)
            ("fee_payment_allocations", """
                DELETE FROM fee_payment_allocations 
                WHERE payment_id IN (
                    SELECT id FROM fee_payments 
                    WHERE student_id IN (SELECT id FROM students WHERE school_id = :sid)
                )
                OR assignment_id IN (
                    SELECT id FROM student_fee_assignments 
                    WHERE student_id IN (SELECT id FROM students WHERE school_id = :sid)
                )
            """),
            ("fee_receipts", """
                DELETE FROM fee_receipts 
                WHERE payment_id IN (
                    SELECT id FROM fee_payments 
                    WHERE student_id IN (SELECT id FROM students WHERE school_id = :sid)
                )
            """),
            ("fee_payments", """
                DELETE FROM fee_payments 
                WHERE student_id IN (SELECT id FROM students WHERE school_id = :sid)
                   OR academic_year_id IN (SELECT id FROM academic_years WHERE school_id = :sid)
            """),
            ("student_fee_assignments", """
                DELETE FROM student_fee_assignments 
                WHERE student_id IN (SELECT id FROM students WHERE school_id = :sid)
                   OR academic_year_id IN (SELECT id FROM academic_years WHERE school_id = :sid)
                   OR fee_structure_id IN (SELECT id FROM fee_structures WHERE school_id = :sid)
            """),
            ("fine_rules", """
                DELETE FROM fine_rules 
                WHERE fee_structure_id IN (SELECT id FROM fee_structures WHERE school_id = :sid)
            """),
            ("fee_structures", "DELETE FROM fee_structures WHERE school_id = :sid"),
            ("scholarships", "DELETE FROM scholarships WHERE school_id = :sid"),

            # Import staging & execution history
            ("import_job_rows", """
                DELETE FROM import_job_rows 
                WHERE import_job_id IN (SELECT id FROM import_jobs WHERE school_id = :sid)
            """),
            ("student_guardian_import_rows", """
                DELETE FROM student_guardian_import_rows 
                WHERE school_id = :sid OR import_job_id IN (SELECT id FROM import_jobs WHERE school_id = :sid)
            """),
            ("guardian_import_rows", """
                DELETE FROM guardian_import_rows 
                WHERE school_id = :sid OR import_job_id IN (SELECT id FROM import_jobs WHERE school_id = :sid)
            """),
            ("student_import_rows", """
                DELETE FROM student_import_rows 
                WHERE school_id = :sid OR import_job_id IN (SELECT id FROM import_jobs WHERE school_id = :sid)
            """),
            ("academic_setup_import_rows", """
                DELETE FROM academic_setup_import_rows 
                WHERE school_id = :sid OR import_job_id IN (SELECT id FROM import_jobs WHERE school_id = :sid)
            """),
            ("import_jobs", "DELETE FROM import_jobs WHERE school_id = :sid"),

            # Marks and Report Cards
            ("marks", "DELETE FROM marks WHERE school_id = :sid"),
            ("report_card_publications", "DELETE FROM report_card_publications WHERE school_id = :sid"),

            # Examinations & Timetable
            ("exam_schedules", "DELETE FROM exam_schedules WHERE school_id = :sid"),
            ("examination_classes", """
                DELETE FROM examination_classes 
                WHERE examination_id IN (SELECT id FROM examinations WHERE school_id = :sid)
            """),
            ("examinations", "DELETE FROM examinations WHERE school_id = :sid"),
            ("exam_templates", "DELETE FROM exam_templates WHERE school_id = :sid"),
            ("exam_type_masters", "DELETE FROM exam_type_masters WHERE school_id = :sid"),

            # Attendance & Leaves
            ("attendance_audit_logs", "DELETE FROM attendance_audit_logs WHERE school_id = :sid"),
            ("attendances", "DELETE FROM attendances WHERE school_id = :sid"),
            ("attendance_sessions", "DELETE FROM attendance_sessions WHERE school_id = :sid"),
            ("staff_attendances", "DELETE FROM staff_attendances WHERE school_id = :sid"),
            ("teacher_leaves", "DELETE FROM teacher_leaves WHERE school_id = :sid"),

            # Homework, Syllabus, Timetables
            ("homeworks", "DELETE FROM homeworks WHERE school_id = :sid"),
            ("syllabuses", "DELETE FROM syllabuses WHERE school_id = :sid"),
            ("timetables", "DELETE FROM timetables WHERE school_id = :sid"),

            # Teachers & Assignments
            ("teacher_subject_assignments", "DELETE FROM teacher_subject_assignments WHERE school_id = :sid"),
            ("teachers", "DELETE FROM teachers WHERE school_id = :sid"),

            # Students & Guardians
            ("student_guardians", """
                DELETE FROM student_guardians 
                WHERE student_id IN (SELECT id FROM students WHERE school_id = :sid)
            """),
            ("guardians", "DELETE FROM guardians WHERE school_id = :sid"),
            ("students", "DELETE FROM students WHERE school_id = :sid"),

            # Events & Announcements
            ("school_events", "DELETE FROM school_events WHERE school_id = :sid"),
            ("announcements", "DELETE FROM announcements WHERE school_id = :sid"),

            # Communications
            ("communication_attachments", "DELETE FROM communication_attachments WHERE school_id = :sid"),
            ("communication_audit_logs", "DELETE FROM communication_audit_logs WHERE school_id = :sid"),
            ("communication_messages", "DELETE FROM communication_messages WHERE school_id = :sid"),
            ("communication_participants", "DELETE FROM communication_participants WHERE school_id = :sid"),
            ("communication_requests", "DELETE FROM communication_requests WHERE school_id = :sid"),

            # Notifications
            ("notification_deliveries", """
                DELETE FROM notification_deliveries 
                WHERE notification_id IN (SELECT id FROM notifications WHERE school_id = :sid)
            """),
            ("notifications", "DELETE FROM notifications WHERE school_id = :sid"),

            # Academic Structure
            ("sections", "DELETE FROM sections WHERE school_id = :sid"),
            ("classes", "DELETE FROM classes WHERE school_id = :sid"),
            ("subjects", "DELETE FROM subjects WHERE school_id = :sid"),
            ("academic_years", "DELETE FROM academic_years WHERE school_id = :sid"),

            # Sequences
            ("parent_login_sequences", "DELETE FROM parent_login_sequences WHERE school_id = :sid"),

            # School-User links (Unlink school association for non-admins, never delete users!)
            ("school_users", """
                DELETE FROM school_users 
                WHERE school_id = :sid 
                  AND user_id NOT IN (
                    SELECT id FROM users 
                    WHERE is_superuser IS TRUE 
                       OR (tenant_id = :tid AND id IN (
                         SELECT user_id FROM user_roles 
                         JOIN roles ON user_roles.role_id = roles.id 
                         WHERE roles.code IN ('SUPER_ADMIN', 'SYSTEM_ADMIN', 'TENANT_ADMIN')
                       ))
                  )
            """),
        ]

        formatted_sid = self._format_id(school_id)
        formatted_tid = self._format_id(tenant_id)

        try:
            # 6. Execute all deletions inside the atomic transaction
            for table_name, stmt in deletion_steps:
                try:
                    result = await self.db.execute(text(stmt), {"sid": formatted_sid, "tid": formatted_tid})
                    cnt = result.rowcount if result.rowcount is not None and result.rowcount >= 0 else 0
                    deleted_counts[table_name] = cnt
                except Exception as step_err:
                    logger.error(f"Error executing deletion step for table '{table_name}': {step_err}", exc_info=True)
                    raise step_err

            # 7. Reset School Onboarding State in school.settings
            current_settings = dict(school.settings or {})
            existing_audit_logs = list(current_settings.get("audit_logs", []))

            audit_entry = {
                "audit_id": audit_id,
                "actor_id": actor_id,
                "actor_role": actor_role,
                "actor_email": actor_email,
                "reason": payload.reason.strip(),
                "status": "COMPLETED",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "deleted_counts": deleted_counts,
                "total_records_deleted": sum(deleted_counts.values())
            }
            existing_audit_logs.append(audit_entry)

            current_settings["onboarding_completed"] = False
            current_settings["current_onboarding_step"] = "Step 1"
            current_settings["onboarding_step"] = 0
            current_settings["import_summaries"] = {}
            current_settings["last_reset"] = audit_entry
            current_settings["audit_logs"] = existing_audit_logs

            school.settings = current_settings
            self.db.add(school)

            # Commit the atomic transaction
            await self.db.commit()

        except Exception as e:
            # 8. Atomic Rollback on Any Failure
            await self.db.rollback()

            # Record durable audit: FAILED and ROLLED_BACK (committed in separate session)
            await self._record_durable_audit(
                audit_id=audit_id,
                status="ROLLED_BACK",
                school_id=school_id,
                school_name=school_name,
                tenant_id=tenant_id,
                actor_id=actor_uuid,
                actor_role=actor_role,
                actor_email=actor_email,
                reason=payload.reason.strip(),
                error_message="Transactional deletion failure. All previously deleted records restored after rollback.",
                summary_snapshot={"error": "Database operation failed during deletion step"}
            )

            logger.error(
                f"AUDIT LOG [SCHOOL_DATA_RESET_ROLLED_BACK]: "
                f"audit_id={audit_id}, actor_id={actor_id}, actor_role={actor_role}, "
                f"tenant_id={tenant_id}, school_id={school_id}, school_name='{school_name}', "
                f"error='{str(e)}'",
                exc_info=True
            )

            # Return sanitized error message hiding raw DB/SQL syntax
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"School data reset failed and was completely rolled back due to an internal server error. Reference Audit ID: {audit_id}."
            )

        total_deleted = sum(deleted_counts.values())
        timestamp_completed = datetime.now(timezone.utc)

        # 9. Record durable audit: COMPLETED
        await self._record_durable_audit(
            audit_id=audit_id,
            status="COMPLETED",
            school_id=school_id,
            school_name=school_name,
            tenant_id=tenant_id,
            actor_id=actor_uuid,
            actor_role=actor_role,
            actor_email=actor_email,
            reason=payload.reason.strip(),
            deletion_counts=deleted_counts,
            total_records_deleted=total_deleted,
            summary_snapshot={"completed_at": timestamp_completed.isoformat()}
        )

        logger.info(
            f"AUDIT LOG [SCHOOL_DATA_RESET_COMPLETED]: "
            f"audit_id={audit_id}, actor_id={actor_id}, actor_role={actor_role}, actor_email={actor_email}, "
            f"tenant_id={tenant_id}, school_id={school_id}, school_name='{school_name}', "
            f"records_deleted={total_deleted}"
        )

        return SchoolDataResetResponse(
            audit_id=audit_id,
            status="COMPLETED",
            school_id=school.id,
            school_name=school.name,
            tenant_id=tenant.id,
            deleted_counts=deleted_counts,
            total_records_deleted=total_deleted,
            timestamp=timestamp_completed,
            message="School operational and onboarding data reset successfully."
        )
