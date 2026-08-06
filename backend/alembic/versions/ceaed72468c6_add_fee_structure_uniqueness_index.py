"""add_fee_structure_uniqueness_index

Revision ID: ceaed72468c6
Revises: e1bd5008ada5
Create Date: 2026-08-05 14:02:05.091170

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ceaed72468c6'
down_revision: Union[str, None] = 'e1bd5008ada5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Apply missing scholarships keys
    op.create_index(op.f('ix_scholarships_school_id'), 'scholarships', ['school_id'], unique=False)
    op.create_foreign_key(None, 'scholarships', 'schools', ['school_id'], ['id'], ondelete='CASCADE')

    bind = op.get_bind()

    # 2. Data Cleanup & Deduplication
    res = bind.execute(sa.text(
        "SELECT id, tenant_id, school_id, academic_year_id, class_id, fee_type_id, created_at "
        "FROM fee_structures WHERE deleted_at IS NULL"
    )).all()

    groups = {}
    for row in res:
        # Handle nullable class_id gracefully in grouping key
        cls_id = str(row.class_id) if row.class_id else "all"
        key = (str(row.tenant_id), str(row.school_id), str(row.academic_year_id), cls_id, str(row.fee_type_id))
        groups.setdefault(key, []).append(row)

    ref_res = bind.execute(sa.text(
        "SELECT DISTINCT fee_structure_id FROM student_fee_assignments"
    )).all()
    referenced_ids = {str(r.fee_structure_id) for r in ref_res}

    to_delete_ids = []
    from datetime import datetime
    for key, group in groups.items():
        if len(group) <= 1:
            continue
        
        # Sort by created_at ascending (oldest first), fallback to ID comparison
        group_sorted = sorted(group, key=lambda r: (r.created_at or datetime.min, str(r.id)))
        referenced_in_group = [r for r in group_sorted if str(r.id) in referenced_ids]

        if not referenced_in_group:
            # None are referenced: keep oldest, delete others
            for r in group_sorted[1:]:
                to_delete_ids.append(r.id)
        else:
            # Keep all referenced ones, delete unreferenced duplicates
            for r in group_sorted:
                if str(r.id) not in referenced_ids:
                    to_delete_ids.append(r.id)

    # Hard-delete duplicates to allow creating the unique index
    for delete_id in to_delete_ids:
        bind.execute(sa.text("DELETE FROM fee_structures WHERE id = :id"), {"id": delete_id})

    # 3. Create unique functional index on active structures
    bind.execute(sa.text(
        "CREATE UNIQUE INDEX uq_fee_structure_active "
        "ON fee_structures (tenant_id, school_id, academic_year_id, class_id, fee_type_id) "
        "WHERE deleted_at IS NULL"
    ))


def downgrade() -> None:
    bind = op.get_bind()
    bind.execute(sa.text("DROP INDEX IF EXISTS uq_fee_structure_active"))

    # Drop constraint & index for scholarships keys
    # Handle constraint drop safely: in PostgreSQL, naming is generated or we drop by type
    if bind.dialect.name == 'postgresql':
        bind.execute(sa.text("ALTER TABLE scholarships DROP CONSTRAINT IF EXISTS scholarships_school_id_fkey"))
    else:
        op.drop_constraint(None, 'scholarships', type_='foreignkey')
    op.drop_index(op.f('ix_scholarships_school_id'), table_name='scholarships')
