"""add_principal_rbac_permissions

Revision ID: 322808ea39d1
Revises: ceaed72468c6
Create Date: 2026-08-09 15:33:11.535145

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '322808ea39d1'
down_revision: Union[str, None] = 'ceaed72468c6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Retrieve connection binding
    bind = op.get_bind()
    
    # 2. Define the missing target permissions
    target_permissions = [
        'student.read', 'teacher.read', 'attendance.read',
        'exam.read', 'marks.read', 'homework.read',
        'report_card.read', 'report_card.download', 'report_card.publish'
    ]
    
    # 3. Retrieve permission IDs
    permissions_res = bind.execute(
        sa.text("SELECT id, code FROM permissions WHERE code = ANY(:codes)"),
        {"codes": target_permissions}
    )
    permissions = {row[1]: row[0] for row in permissions_res.fetchall()}
    
    # Verify all permissions exist
    missing = [p for p in target_permissions if p not in permissions]
    if missing:
        raise ValueError(f"Required permissions missing from database: {missing}")

    # 4. Retrieve roles with code 'PRINCIPAL'
    roles_res = bind.execute(
        sa.text("SELECT id, tenant_id FROM roles WHERE code = 'PRINCIPAL'")
    )
    roles = roles_res.fetchall()
    
    # 5. Insert role_permissions mappings idempotently
    for role in roles:
        role_id = role[0]
        for perm_code, perm_id in permissions.items():
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
    target_permissions = [
        'student.read', 'teacher.read', 'attendance.read',
        'exam.read', 'marks.read', 'homework.read',
        'report_card.read', 'report_card.download', 'report_card.publish'
    ]
    
    # Delete associations for any roles with code 'PRINCIPAL'
    bind.execute(
        sa.text("""
            DELETE FROM role_permissions 
            WHERE role_id IN (SELECT id FROM roles WHERE code = 'PRINCIPAL')
              AND permission_id IN (SELECT id FROM permissions WHERE code = ANY(:codes))
        """),
        {"codes": target_permissions}
    )
