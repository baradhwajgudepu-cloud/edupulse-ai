"""link_notification_permissions_to_roles

Revision ID: 0db5caad1556
Revises: 1c42b0ebbc33
Create Date: 2026-08-02 23:57:08.000000

"""
from typing import Sequence, Union
import uuid

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0db5caad1556'
down_revision: Union[str, None] = '1c42b0ebbc33'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Get database connection
    bind = op.get_bind()
    
    # 1. Fetch the notification permissions
    perm_read_id = bind.execute(sa.text("SELECT id FROM permissions WHERE code = 'notification.read'")).scalar()
    perm_mark_read_id = bind.execute(sa.text("SELECT id FROM permissions WHERE code = 'notification.mark_read'")).scalar()
    
    if not perm_read_id or not perm_mark_read_id:
        return  # Safeguard if permissions were not seeded yet
        
    # 2. Fetch the roles (PARENT, TEACHER, PRINCIPAL, STAFF, ADMIN)
    role_codes = ['PARENT', 'TEACHER', 'PRINCIPAL', 'STAFF', 'ADMIN']
    roles = bind.execute(sa.text("SELECT id, code FROM roles WHERE deleted_at IS NULL")).all()
    
    # 3. Insert mappings into role_permissions
    for role in roles:
        role_code = str(role.code).upper()
        if role_code in role_codes:
            for perm_id in [perm_read_id, perm_mark_read_id]:
                # Check if mapping already exists
                exists = bind.execute(sa.text(
                    "SELECT 1 FROM role_permissions WHERE role_id = :role_id AND permission_id = :perm_id"
                ), {"role_id": role.id, "perm_id": perm_id}).scalar()
                
                if not exists:
                    bind.execute(sa.text(
                        "INSERT INTO role_permissions (role_id, permission_id) VALUES (:role_id, :perm_id)"
                    ), {"role_id": role.id, "perm_id": perm_id})


def downgrade() -> None:
    bind = op.get_bind()
    perm_read_id = bind.execute(sa.text("SELECT id FROM permissions WHERE code = 'notification.read'")).scalar()
    perm_mark_read_id = bind.execute(sa.text("SELECT id FROM permissions WHERE code = 'notification.mark_read'")).scalar()
    
    if perm_read_id and perm_mark_read_id:
        bind.execute(sa.text(
            "DELETE FROM role_permissions WHERE permission_id IN (:p1, :p2)"
        ), {"p1": perm_read_id, "p2": perm_mark_read_id})
