import os
import sys
import argparse
import asyncio
from pathlib import Path

# Add backend directory to sys.path
BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import text
from app.core.settings import settings

SYSTEM_TENANT_CODE = "EDUPULSE_SYSTEM"

async def run_reset(dry_run: bool = True, confirm_reset: bool = False) -> int:
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    print("==================================================================")
    print("      EDUPULSE AI - PRODUCTION DATA RESET & AUDIT UTILITY       ")
    print("==================================================================")
    print(f"Mode: {'DRY RUN (Read-Only Audit)' if dry_run else 'LIVE DESTRUCTION (Reset Production Demo Data)'}")
    print(f"Database Target: {settings.POSTGRES_SERVER}/{settings.POSTGRES_DB}\n")

    async with async_session() as session:
        # 1. Identify System Tenant and Super Admin accounts to preserve
        sys_res = await session.execute(
            text("SELECT id, name, code FROM tenants WHERE code = :code"),
            {"code": SYSTEM_TENANT_CODE}
        )
        system_tenant = sys_res.fetchone()
        system_tenant_id = system_tenant[0] if system_tenant else None

        sa_res = await session.execute(
            text("SELECT id, email, is_superuser, tenant_id FROM users WHERE is_superuser = true")
        )
        super_admins = sa_res.fetchall()

        print("--- 1. PRESERVED SYSTEM ENTITIES (WILL NOT BE TOUCHED) ---")
        if system_tenant:
            print(f"System Tenant: [ID: {system_tenant[0]}] Name: '{system_tenant[1]}' (Code: {system_tenant[2]})")
        else:
            print("System Tenant: None found with code EDUPULSE_SYSTEM")
        for sa in super_admins:
            print(f"Super Admin Account: [ID: {sa[0]}] Email: '{sa[1]}' (Superuser: {sa[2]}, TenantID: {sa[3]})")
        print()

        # 2. Identify Tenants and Schools targeted for deletion
        t_res = await session.execute(
            text("SELECT id, name, code, is_active FROM tenants WHERE code != :code ORDER BY created_at"),
            {"code": SYSTEM_TENANT_CODE}
        )
        tenants_to_delete = t_res.fetchall()

        if not tenants_to_delete:
            print("No test/demo tenants found to delete. The database is already clean!")
            return 0

        tenant_ids = [t[0] for t in tenants_to_delete]

        s_res = await session.execute(
            text("SELECT id, tenant_id, name, code, is_active FROM schools WHERE tenant_id = ANY(:tids) ORDER BY created_at"),
            {"tids": tenant_ids}
        )
        schools_to_delete = s_res.fetchall()
        school_ids = [s[0] for s in schools_to_delete]

        print("--- 2. TARGET TENANTS FOR CLEANUP ---")
        for t in tenants_to_delete:
            print(f" - Tenant ID: {t[0]} | Code: {t[2]} | Name: '{t[1]}'")
        print(f"Total Tenants: {len(tenants_to_delete)}\n")

        print("--- 3. TARGET SCHOOLS FOR CLEANUP ---")
        for s in schools_to_delete:
            print(f" - School ID: {s[0]} | Tenant ID: {s[1]} | Code: {s[3]} | Name: '{s[2]}'")
        print(f"Total Schools: {len(schools_to_delete)}\n")

        # 3. Audit all dependent tables and count records
        print("--- 4. RECORD COUNTS ACROSS DEPENDENT BUSINESS TABLES ---")
        tables_res = await session.execute(text("""
            SELECT DISTINCT table_name 
            FROM information_schema.columns 
            WHERE column_name IN ('tenant_id', 'school_id') 
              AND table_schema = 'public'
            ORDER BY table_name
        """))
        candidate_tables = [r[0] for r in tables_res.fetchall()]

        total_records_affected = 0
        table_breakdown = {}

        for tbl in candidate_tables:
            if tbl in ('tenants', 'schools'):
                continue
            
            # Check if table has tenant_id or school_id
            col_res = await session.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = :tbl AND table_schema = 'public' AND column_name IN ('tenant_id', 'school_id')
            """), {"tbl": tbl})
            cols = [c[0] for c in col_res.fetchall()]

            conditions = []
            params = {}
            if 'tenant_id' in cols:
                conditions.append("tenant_id = ANY(:tids)")
                params["tids"] = tenant_ids
            if 'school_id' in cols and school_ids:
                conditions.append("school_id = ANY(:sids)")
                params["sids"] = school_ids

            if conditions:
                where_clause = " OR ".join(conditions)
                # Ensure we never touch super_admin records in users table
                if tbl == 'users':
                    where_clause = f"({where_clause}) AND is_superuser = false"
                
                try:
                    cnt_res = await session.execute(text(f"SELECT count(*) FROM {tbl} WHERE {where_clause}"), params)
                    cnt = cnt_res.scalar() or 0
                    if cnt > 0:
                        table_breakdown[tbl] = cnt
                        total_records_affected += cnt
                        print(f"  * {tbl:<30}: {cnt} records")
                except Exception as e:
                    pass

        print(f"\nTotal Dependent Business Records to be Deleted: {total_records_affected}")
        print("------------------------------------------------------------------\n")

        if dry_run or not confirm_reset:
            print("[DRY-RUN COMPLETE] No records were modified or deleted.")
            print("To execute this reset, pass both --confirm-production-reset and make sure --dry-run is omitted.")
            return 0

        # LIVE DELETION
        print("Executing production data reset...")
        async with session.begin():
            # Safety check: verify super admin is not in tenant_ids
            for sa in super_admins:
                if sa[3] in tenant_ids:
                    print(f"[FATAL] Super admin {sa[1]} belongs to tenant {sa[3]} which is in deletion list! Aborting.", file=sys.stderr)
                    return 1

            # Delete users scoped to these tenants except superusers
            await session.execute(
                text("DELETE FROM users WHERE tenant_id = ANY(:tids) AND is_superuser = false"),
                {"tids": tenant_ids}
            )

            # Delete tenants (Cascades to all foreign key tables: schools, marks, classes, etc.)
            del_res = await session.execute(
                text("DELETE FROM tenants WHERE id = ANY(:tids)"),
                {"tids": tenant_ids}
            )
            print(f"[SUCCESS] Deleted {del_res.rowcount} tenants and all cascaded child records.")

        # Verification after deletion
        print("\n--- POST-RESET INTEGRITY VERIFICATION ---")
        rem_tenants = await session.execute(text("SELECT id, name, code FROM tenants"))
        tenants_remaining = rem_tenants.fetchall()
        print(f"Remaining Tenants ({len(tenants_remaining)}):")
        for t in tenants_remaining:
            print(f"  + [Tenant] ID: {t[0]} | Code: {t[2]} | Name: {t[1]}")

        rem_schools = await session.execute(text("SELECT id, name, code FROM schools"))
        schools_list = rem_schools.fetchall()
        print(f"Remaining Schools ({len(schools_list)}):")
        for s in schools_list:
            print(f"  + [School] ID: {s[0]} | Code: {s[2]} | Name: {s[1]}")

        rem_sa = await session.execute(text("SELECT id, email, is_superuser FROM users WHERE is_superuser = true"))
        sa_list = rem_sa.fetchall()
        print(f"Preserved Super Admin Accounts ({len(sa_list)}):")
        for sa in sa_list:
            print(f"  + [SuperAdmin] ID: {sa[0]} | Email: {sa[1]}")

        if len(sa_list) > 0 and len(schools_list) == 0:
            print("\n[VERIFICATION PASSED] Database successfully reset to clean production state.")
            return 0
        else:
            print("\n[VERIFICATION NOTE] Check above outputs for status.")
            return 0

def main():
    parser = argparse.ArgumentParser(description="Safely reset production demo/test data in EduPulse AI.")
    parser.add_argument("--dry-run", action="store_true", default=False, help="Perform read-only audit without modifying database.")
    parser.add_argument("--confirm-production-reset", action="store_true", default=False, help="Confirm live deletion of test/demo tenants.")
    args = parser.parse_args()

    # Default to dry-run unless --confirm-production-reset is explicitly passed without --dry-run
    dry_run = args.dry_run or not args.confirm_production_reset

    ret = asyncio.run(run_reset(dry_run=dry_run, confirm_reset=args.confirm_production_reset))
    sys.exit(ret)

if __name__ == "__main__":
    main()
