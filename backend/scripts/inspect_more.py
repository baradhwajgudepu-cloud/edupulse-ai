import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.settings import settings

async def inspect_fee():
    engine = create_async_engine(settings.DATABASE_URL)
    async with engine.connect() as conn:
        cols = await conn.execute(text("""
            SELECT table_name, column_name, data_type
            FROM information_schema.columns
            WHERE table_name IN ('fee_payment_allocations', 'fee_receipts', 'fee_payments', 'student_fee_assignments', 'fee_structures', 'import_jobs', 'school_users', 'users')
            ORDER BY table_name, ordinal_position
        """))
        print("=== COLUMNS ===")
        current_table = None
        for c in cols.fetchall():
            if c[0] != current_table:
                current_table = c[0]
                print(f"\n[{current_table}]")
            print(f"  {c[1]} ({c[2]})")

        # Foreign keys of fee_payment_allocations
        fks = await conn.execute(text("""
            SELECT
                tc.table_name, kcu.column_name,
                ccu.table_name AS foreign_table_name,
                ccu.column_name AS foreign_column_name,
                rc.delete_rule
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
              ON tc.constraint_name = kcu.constraint_name
            JOIN information_schema.referential_constraints AS rc
              ON tc.constraint_name = rc.constraint_name
            JOIN information_schema.constraint_column_usage AS ccu
              ON rc.unique_constraint_name = ccu.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name = 'fee_payment_allocations'
        """))
        print("\n=== fee_payment_allocations FKs ===")
        for r in fks.fetchall():
            print(f"  {r[1]} -> {r[2]}.{r[3]} [ON DELETE {r[4]}]")

if __name__ == '__main__':
    asyncio.run(inspect_fee())
