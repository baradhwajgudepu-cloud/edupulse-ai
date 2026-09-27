import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.settings import settings

async def inspect():
    engine = create_async_engine(settings.DATABASE_URL)
    async with engine.connect() as conn:
        # 1. Direct tenant_id tables
        t_tables = await conn.execute(text("""
            SELECT table_name, is_nullable
            FROM information_schema.columns 
            WHERE column_name = 'tenant_id' AND table_schema = 'public'
            ORDER BY table_name
        """))
        print("=== TABLES WITH DIRECT tenant_id ===")
        for r in t_tables.fetchall():
            print(f"  {r[0]} (nullable: {r[1]})")

        # 2. Tables with school_id
        s_tables = await conn.execute(text("""
            SELECT table_name, is_nullable
            FROM information_schema.columns 
            WHERE column_name = 'school_id' AND table_schema = 'public'
            ORDER BY table_name
        """))
        print("\n=== TABLES WITH school_id ===")
        for r in s_tables.fetchall():
            print(f"  {r[0]} (nullable: {r[1]})")

        # 3. Foreign key constraints referencing tenants
        fk_tenants = await conn.execute(text("""
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
            WHERE tc.constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'tenants'
            ORDER BY tc.table_name;
        """))
        print("\n=== FOREIGN KEYS REFERENCING tenants ===")
        for r in fk_tenants.fetchall():
            print(f"  {r[0]}.{r[1]} -> {r[2]}.{r[3]} [ON DELETE {r[4]}]")

        # 4. Foreign key constraints referencing schools
        fk_schools = await conn.execute(text("""
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
            WHERE tc.constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'schools'
            ORDER BY tc.table_name;
        """))
        print("\n=== FOREIGN KEYS REFERENCING schools ===")
        for r in fk_schools.fetchall():
            print(f"  {r[0]}.{r[1]} -> {r[2]}.{r[3]} [ON DELETE {r[4]}]")

        # 5. Check all foreign keys with NO ACTION or RESTRICT or SET NULL
        fk_restrict = await conn.execute(text("""
            SELECT
                tc.table_name, kcu.column_name,
                ccu.table_name AS foreign_table_name,
                rc.delete_rule
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
              ON tc.constraint_name = kcu.constraint_name
            JOIN information_schema.referential_constraints AS rc
              ON tc.constraint_name = rc.constraint_name
            JOIN information_schema.constraint_column_usage AS ccu
              ON rc.unique_constraint_name = ccu.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY' 
              AND rc.delete_rule != 'CASCADE'
              AND tc.table_schema = 'public'
            ORDER BY tc.table_name;
        """))
        print("\n=== FOREIGN KEYS WITH NON-CASCADE DELETE RULE ===")
        for r in fk_restrict.fetchall():
            print(f"  {r[0]}.{r[1]} -> {r[2]} [ON DELETE {r[3]}]")

if __name__ == '__main__':
    asyncio.run(inspect())
