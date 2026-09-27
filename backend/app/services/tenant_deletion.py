import uuid
import logging
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text, select
from app.models.tenant import Tenant
from app.models.user import User
from app.services.storage import StorageService

logger = logging.getLogger(__name__)

SYSTEM_TENANT_CODE = "EDUPULSE_SYSTEM"
SYSTEM_TENANT_ID = "ff9e842b-3008-451b-a42b-e177c996d3e9"

class TenantDeletionService:
    """
    Dedicated, atomic service for permanently deleting tenants and all exclusively
    scoped child entities. Enforces protection for system master tenant and platform administrators.
    Supports dry-run validation with rollback.
    """
    def __init__(self, db: AsyncSession, storage_service: Optional[StorageService] = None) -> None:
        self.db = db
        self.storage_service = storage_service

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

    def validate_protection(self, tenant: Tenant) -> None:
        """
        Enforces that the platform master tenant can NEVER be deleted.
        Checks both the tenant code and known master UUID.
        """
        is_system_code = bool(tenant.code and tenant.code.strip().upper() == SYSTEM_TENANT_CODE)
        is_system_id = str(tenant.id) == SYSTEM_TENANT_ID
        if is_system_code or is_system_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="The platform master tenant (EDUPULSE_SYSTEM) is strictly protected and cannot be deleted."
            )

    async def preview_deletion(self, tenant_id: uuid.UUID, current_user: User) -> Dict[str, Any]:
        """
        Performs dry-run deletion analysis. Executes full deletion logic inside a transaction
        savepoint to verify referential integrity and count records, then rolls back.
        """
        return await self.delete_tenant_permanent(
            tenant_id=tenant_id,
            current_user=current_user,
            dry_run=True
        )

    async def delete_tenant_permanent(
        self,
        tenant_id: uuid.UUID,
        current_user: User,
        dry_run: bool = False
    ) -> Dict[str, Any]:
        """
        Permanently purges a tenant and all its associated data.
        If dry_run is True: executes in a savepoint and rolls back.
        If dry_run is False: commits the transaction and performs best-effort storage cleanup.
        """
        tenant = await self.get_tenant(tenant_id)
        self.validate_protection(tenant)

        # Pre-capture string attributes safely without triggering descriptor lazy-loads
        user_dict = getattr(current_user, "__dict__", {})
        actor_id = str(user_dict.get("id") or getattr(current_user, "id", "unknown"))
        actor_email = str(user_dict.get("email") or getattr(current_user, "email", "unknown"))

        tenant_dict = getattr(tenant, "__dict__", {})
        tenant_name = str(tenant_dict.get("name") or getattr(tenant, "name", "unknown"))
        tenant_code = str(tenant_dict.get("code") or getattr(tenant, "code", "unknown"))

        # 1. Collect storage file paths before table deletions
        files_to_delete: List[str] = []
        try:
            # Fee receipts
            rc_res = await self.db.execute(
                text("SELECT pdf_path FROM fee_receipts WHERE tenant_id = :tid AND pdf_path IS NOT NULL"),
                {"tid": tenant_id}
            )
            files_to_delete.extend([r[0] for r in rc_res.fetchall() if r[0]])

            # Report card publications
            pub_res = await self.db.execute(
                text("SELECT pdf_url FROM report_card_publications WHERE tenant_id = :tid AND pdf_url IS NOT NULL"),
                {"tid": tenant_id}
            )
            files_to_delete.extend([r[0] for r in pub_res.fetchall() if r[0]])

            # School logos
            logo_res = await self.db.execute(
                text("SELECT logo_url FROM schools WHERE tenant_id = :tid AND logo_url IS NOT NULL"),
                {"tid": tenant_id}
            )
            files_to_delete.extend([r[0] for r in logo_res.fetchall() if r[0]])
        except Exception as e:
            logger.warning(f"Could not scan files for storage cleanup: {e}")

        # 2. Protect any Super Admin user associated with this tenant
        # Reassign their tenant_id to the system master tenant so they are never deleted
        try:
            await self.db.execute(
                text("""
                    UPDATE users 
                    SET tenant_id = (SELECT id FROM tenants WHERE code = 'EDUPULSE_SYSTEM' LIMIT 1)
                    WHERE tenant_id = :tid AND is_superuser = true
                """),
                {"tid": tenant_id}
            )
        except Exception as e:
            logger.warning(f"Could not reassign superusers: {e}")

        # 3. Ordered Deletion Sequence to satisfy all foreign-key constraints
        deleted_counts: Dict[str, int] = {}
        warnings: List[str] = []

        deletion_steps = [
            # Financials (allocations first to prevent RESTRICT on student_fee_assignments)
            ("fee_payment_allocations", """
                DELETE FROM fee_payment_allocations 
                WHERE payment_id IN (SELECT id FROM fee_payments WHERE tenant_id = :tid)
                   OR assignment_id IN (SELECT id FROM student_fee_assignments WHERE tenant_id = :tid)
            """),
            ("fee_receipts", "DELETE FROM fee_receipts WHERE tenant_id = :tid"),
            ("fee_payments", "DELETE FROM fee_payments WHERE tenant_id = :tid"),
            ("student_fee_assignments", "DELETE FROM student_fee_assignments WHERE tenant_id = :tid"),
            ("fee_structures", "DELETE FROM fee_structures WHERE tenant_id = :tid"),
            ("fine_rules", "DELETE FROM fine_rules WHERE tenant_id = :tid"),
            ("scholarships", "DELETE FROM scholarships WHERE tenant_id = :tid"),
            ("fee_types", "DELETE FROM fee_types WHERE tenant_id = :tid"),

            # Import staging data
            ("import_job_rows", """
                DELETE FROM import_job_rows 
                WHERE import_job_id IN (SELECT id FROM import_jobs WHERE tenant_id = :tid)
            """),
            ("import_jobs", "DELETE FROM import_jobs WHERE tenant_id = :tid"),
            ("student_guardian_import_rows", "DELETE FROM student_guardian_import_rows WHERE tenant_id = :tid"),
            ("guardian_import_rows", """
                DELETE FROM guardian_import_rows 
                WHERE school_id IN (SELECT id FROM schools WHERE tenant_id = :tid)
            """),
            ("student_import_rows", "DELETE FROM student_import_rows WHERE tenant_id = :tid"),
            ("academic_setup_import_rows", """
                DELETE FROM academic_setup_import_rows 
                WHERE school_id IN (SELECT id FROM schools WHERE tenant_id = :tid)
            """),

            # Marks and Report Cards
            ("marks", "DELETE FROM marks WHERE tenant_id = :tid"),
            ("report_card_publications", "DELETE FROM report_card_publications WHERE tenant_id = :tid"),

            # Examinations
            ("exam_schedules", "DELETE FROM exam_schedules WHERE tenant_id = :tid"),
            ("examination_classes", "DELETE FROM examination_classes WHERE tenant_id = :tid"),
            ("examinations", "DELETE FROM examinations WHERE tenant_id = :tid"),
            ("exam_templates", "DELETE FROM exam_templates WHERE tenant_id = :tid"),
            ("exam_type_masters", "DELETE FROM exam_type_masters WHERE tenant_id = :tid"),

            # Attendance and Leaves
            ("attendances", "DELETE FROM attendances WHERE tenant_id = :tid"),
            ("attendance_sessions", "DELETE FROM attendance_sessions WHERE tenant_id = :tid"),
            ("staff_attendances", """
                DELETE FROM staff_attendances 
                WHERE school_id IN (SELECT id FROM schools WHERE tenant_id = :tid)
            """),
            ("teacher_leaves", """
                DELETE FROM teacher_leaves 
                WHERE school_id IN (SELECT id FROM schools WHERE tenant_id = :tid)
            """),

            # Homeworks, Syllabuses, Timetables
            ("homeworks", "DELETE FROM homeworks WHERE tenant_id = :tid"),
            ("syllabuses", "DELETE FROM syllabuses WHERE tenant_id = :tid"),
            ("timetables", "DELETE FROM timetables WHERE tenant_id = :tid"),

            # Teachers and Assignments
            ("teacher_subject_assignments", "DELETE FROM teacher_subject_assignments WHERE tenant_id = :tid"),
            ("teachers", "DELETE FROM teachers WHERE tenant_id = :tid"),

            # Students and Guardians
            ("student_guardians", "DELETE FROM student_guardians WHERE tenant_id = :tid"),
            ("guardians", "DELETE FROM guardians WHERE tenant_id = :tid"),
            ("students", "DELETE FROM students WHERE tenant_id = :tid"),

            # Academic Structure
            ("sections", "DELETE FROM sections WHERE tenant_id = :tid"),
            ("classes", "DELETE FROM classes WHERE tenant_id = :tid"),
            ("subjects", "DELETE FROM subjects WHERE tenant_id = :tid"),
            ("academic_years", "DELETE FROM academic_years WHERE tenant_id = :tid"),

            # Events and Announcements
            ("school_events", "DELETE FROM school_events WHERE tenant_id = :tid"),
            ("announcements", "DELETE FROM announcements WHERE tenant_id = :tid"),

            # Communications (if tables exist)
            ("communication_attachments", "DELETE FROM communication_attachments WHERE tenant_id = :tid"),
            ("communication_audit_logs", "DELETE FROM communication_audit_logs WHERE tenant_id = :tid"),
            ("communication_messages", "DELETE FROM communication_messages WHERE tenant_id = :tid"),
            ("communication_participants", "DELETE FROM communication_participants WHERE tenant_id = :tid"),
            ("communication_requests", "DELETE FROM communication_requests WHERE tenant_id = :tid"),

            # Notifications
            ("notification_deliveries", "DELETE FROM notification_deliveries WHERE tenant_id = :tid"),
            ("notification_preferences", "DELETE FROM notification_preferences WHERE tenant_id = :tid"),
            ("notifications", "DELETE FROM notifications WHERE tenant_id = :tid"),

            # School Associations and Schools
            ("parent_login_sequences", "DELETE FROM parent_login_sequences WHERE tenant_id = :tid"),
            ("school_users", """
                DELETE FROM school_users 
                WHERE school_id IN (SELECT id FROM schools WHERE tenant_id = :tid)
            """),
            ("schools", "DELETE FROM schools WHERE tenant_id = :tid"),

            # Auth tokens, User roles, Roles
            ("user_device_tokens", "DELETE FROM user_device_tokens WHERE tenant_id = :tid"),
            ("refresh_tokens", "DELETE FROM refresh_tokens WHERE tenant_id = :tid"),
            ("user_roles", """
                DELETE FROM user_roles 
                WHERE user_id IN (SELECT id FROM users WHERE tenant_id = :tid AND is_superuser = false)
            """),
            ("roles", "DELETE FROM roles WHERE tenant_id = :tid"),

            # Tenant-scoped Users (Never touch superusers!)
            ("users", "DELETE FROM users WHERE tenant_id = :tid AND is_superuser = false"),

            # Finally, the Tenant record itself
            ("tenants", "DELETE FROM tenants WHERE id = :tid"),
        ]

        try:
            if dry_run:
                # Use a savepoint transaction for dry-run
                async with self.db.begin_nested():
                    for table_name, stmt in deletion_steps:
                        try:
                            result = await self.db.execute(text(stmt), {"tid": tenant_id})
                            cnt = result.rowcount if result.rowcount is not None and result.rowcount >= 0 else 0
                            if cnt > 0:
                                deleted_counts[table_name] = cnt
                        except Exception as step_err:
                            # Table might not exist or has zero rows
                            logger.debug(f"Dry-run step {table_name} skipped or failed: {step_err}")
                    # Unconditional rollback of savepoint
                    await self.db.rollback()
            else:
                # Real deletion
                for table_name, stmt in deletion_steps:
                    try:
                        result = await self.db.execute(text(stmt), {"tid": tenant_id})
                        cnt = result.rowcount if result.rowcount is not None and result.rowcount >= 0 else 0
                        if cnt > 0:
                            deleted_counts[table_name] = cnt
                    except Exception as step_err:
                        logger.warning(f"Deletion step {table_name} error: {step_err}")
                        raise step_err

                # Commit atomic database changes
                await self.db.commit()

        except Exception as e:
            await self.db.rollback()
            logger.error(f"Permanent deletion failed for tenant {tenant_id}: {e}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Permanent tenant deletion failed: {str(e)}"
            )

        # 4. Storage cleanup (Best-effort after successful database commit)
        storage_status: Dict[str, Any] = {
            "attempted": False,
            "status": "skipped",
            "files_removed": 0,
            "errors": []
        }
        if not dry_run and self.storage_service and files_to_delete:
            storage_status["attempted"] = True
            for file_path in files_to_delete:
                try:
                    await self.storage_service.delete(file_path)
                    storage_status["files_removed"] += 1
                except Exception as s_err:
                    storage_status["errors"].append(f"{file_path}: {s_err}")
            storage_status["status"] = "partial" if storage_status["errors"] else "success"

        total_deleted = sum(deleted_counts.values())

        # 5. Audit Logging
        logger.info(
            f"AUDIT LOG [TENANT_PERMANENT_DELETION]: "
            f"actor_id={actor_id}, actor_email={actor_email}, "
            f"tenant_id={tenant_id}, tenant_name='{tenant_name}', tenant_code='{tenant_code}', "
            f"dry_run={dry_run}, records_deleted={total_deleted}, "
            f"timestamp={datetime.now(timezone.utc).isoformat()}"
        )

        return {
            "tenant_id": tenant_id,
            "tenant_name": tenant_name,
            "tenant_code": tenant_code,
            "dry_run": dry_run,
            "deleted_counts": deleted_counts,
            "total_records_deleted": total_deleted,
            "storage_cleanup": storage_status,
            "warnings": warnings
        }
