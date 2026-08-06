"""add_scholarship_school_isolation_uniqueness

Revision ID: e1bd5008ada5
Revises: 2ea8c0ebd123
Create Date: 2026-08-04 23:59:20.171892

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e1bd5008ada5'
down_revision: Union[str, None] = '2ea8c0ebd123'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add school_id column as nullable initially
    op.add_column('scholarships', sa.Column('school_id', sa.Uuid(), nullable=True))

    bind = op.get_bind()

    # 2. Backfill school_id for existing records
    # Try to resolve through student fee assignments
    bind.execute(sa.text(
        "UPDATE scholarships SET school_id = ("
        "  SELECT s.school_id FROM student_fee_assignments a "
        "  JOIN students s ON a.student_id = s.id "
        "  WHERE a.scholarship_id = scholarships.id "
        "  LIMIT 1"
        ") WHERE school_id IS NULL"
    ))
    # If still null, default to the first school under the same tenant
    bind.execute(sa.text(
        "UPDATE scholarships SET school_id = ("
        "  SELECT id FROM schools WHERE tenant_id = scholarships.tenant_id "
        "  LIMIT 1"
        ") WHERE school_id IS NULL"
    ))

    # 3. Perform duplicate cleanup (preserving oldest or referenced)
    # Fetch all active scholarships
    res = bind.execute(sa.text(
        "SELECT id, tenant_id, school_id, name, created_at FROM scholarships WHERE deleted_at IS NULL"
    )).all()

    # Group by key: (tenant_id, school_id, lower(name))
    groups = {}
    for row in res:
        # Gracefully handle potentially null school_id during backfill phase
        sch_id = str(row.school_id) if row.school_id else "unknown"
        key = (str(row.tenant_id), sch_id, row.name.lower().strip())
        groups.setdefault(key, []).append(row)

    # Get scholarship IDs currently referenced in student fee assignments
    ref_res = bind.execute(sa.text(
        "SELECT DISTINCT scholarship_id FROM student_fee_assignments WHERE scholarship_id IS NOT NULL"
    )).all()
    referenced_ids = {str(r.scholarship_id) for r in ref_res}

    to_delete_ids = []
    from datetime import datetime
    for key, group in groups.items():
        if len(group) <= 1:
            continue
        
        # Sort by created_at ascending (oldest first), fallback to ID comparison
        group_sorted = sorted(group, key=lambda r: (r.created_at or datetime.min, str(r.id)))
        
        # Find duplicates that are in use
        referenced_in_group = [r for r in group_sorted if str(r.id) in referenced_ids]
        
        if not referenced_in_group:
            # None are referenced: keep the oldest record, delete other duplicates
            keep = group_sorted[0]
            for r in group_sorted[1:]:
                to_delete_ids.append(r.id)
        else:
            # Some are referenced: we must keep all referenced records
            # Delete any duplicate that is NOT in use
            for r in group_sorted:
                if str(r.id) not in referenced_ids:
                    to_delete_ids.append(r.id)

    # Execute hard-deletion of duplicates
    for delete_id in to_delete_ids:
        bind.execute(sa.text("DELETE FROM scholarships WHERE id = :id"), {"id": delete_id})

    # 4. Enforce NOT NULL on school_id
    op.alter_column('scholarships', 'school_id', existing_type=sa.Uuid(), nullable=False)

    # 5. Create unique functional index
    bind.execute(sa.text(
        "CREATE UNIQUE INDEX uq_scholarships_tenant_school_name_lower "
        "ON scholarships (tenant_id, school_id, lower(name)) "
        "WHERE deleted_at IS NULL"
    ))


def downgrade() -> None:
    bind = op.get_bind()
    bind.execute(sa.text("DROP INDEX IF EXISTS uq_scholarships_tenant_school_name_lower"))
    op.drop_column('scholarships', 'school_id')
