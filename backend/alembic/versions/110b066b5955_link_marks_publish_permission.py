"""link_marks_publish_permission

Revision ID: 110b066b5955
Revises: 793f22643c13
Create Date: 2026-08-24 12:57:48.414170

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '110b066b5955'
down_revision: Union[str, None] = '793f22643c13'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Retrieve connection binding
    bind = op.get_bind()
    
    # 2. Retrieve permission ID from database for 'marks.publish'
    permission_res = bind.execute(
        sa.text("SELECT id FROM permissions WHERE code = 'marks.publish'")
    )
    row = permission_res.fetchone()
    if not row:
        raise ValueError("Required permission 'marks.publish' is missing from the database.")
    perm_id = row[0]
    
    # 3. Retrieve all active roles with code 'TEACHER' or 'PRINCIPAL'
    roles_res = bind.execute(
        sa.text("SELECT id FROM roles WHERE code IN ('TEACHER', 'PRINCIPAL') AND deleted_at IS NULL")
    )
    roles = roles_res.fetchall()
    
    # 4. Insert role_permissions mappings idempotently
    for role in roles:
        role_id = role[0]
        # Check if association already exists
        exist_res = bind.execute(
            sa.text("SELECT 1 FROM role_permissions WHERE role_id = :role_id AND permission_id = :perm_id"),
            {"role_id": role_id, "perm_id": perm_id}
        )
        if not exist_res.fetchone():
            bind.execute(
                sa.text("INSERT INTO role_permissions (role_id, permission_id) VALUES (:role_id, :perm_id)"),
                {"role_id": role_id, "perm_id": perm_id}
            )


def downgrade() -> None:
    bind = op.get_bind()
    
    permission_res = bind.execute(
        sa.text("SELECT id FROM permissions WHERE code = 'marks.publish'")
    )
    row = permission_res.fetchone()
    if row:
        perm_id = row[0]
        # Delete associations for any roles with code 'TEACHER' or 'PRINCIPAL'
        bind.execute(
            sa.text("""
                DELETE FROM role_permissions 
                WHERE role_id IN (SELECT id FROM roles WHERE code IN ('TEACHER', 'PRINCIPAL'))
                  AND permission_id = :perm_id
            """),
            {"perm_id": perm_id}
        )
