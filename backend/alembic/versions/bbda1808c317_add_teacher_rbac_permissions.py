"""add_teacher_rbac_permissions

Revision ID: bbda1808c317
Revises: 5b8bff5f3ef6
Create Date: 2026-08-14 21:45:00.281238

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'bbda1808c317'
down_revision: Union[str, None] = '5b8bff5f3ef6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


target_permissions = [
    'academic_year.read',
    'class.read',
    'section.read',
    'subject.read',
    'teacher.read',
    'teacher_subject_assignment.read',
    'timetable.read',
    'student.read',
    'attendance.read',
    'attendance.create',
    'attendance.update',
    'homework.read',
    'homework.create',
    'homework.update',
    'homework.delete',
    'exam.read',
    'marks.read',
    'marks.create',
    'marks.update',
    'report_card.read',
    'report_card.generate',
]


def upgrade() -> None:
    # 1. Retrieve connection binding
    bind = op.get_bind()
    
    # 2. Retrieve permission IDs from database
    permissions_res = bind.execute(
        sa.text("SELECT id, code FROM permissions WHERE code = ANY(:codes)"),
        {"codes": target_permissions}
    )
    permissions = {row[1]: row[0] for row in permissions_res.fetchall()}
    
    # Verify all required permissions exist
    missing = [p for p in target_permissions if p not in permissions]
    if missing:
        raise ValueError(f"Required permissions missing from database: {missing}")

    # 3. Retrieve all roles with code 'TEACHER'
    roles_res = bind.execute(
        sa.text("SELECT id, tenant_id FROM roles WHERE code = 'TEACHER' AND deleted_at IS NULL")
    )
    roles = roles_res.fetchall()
    
    # 4. Insert role_permissions mappings idempotently
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
    
    # Delete associations for any roles with code 'TEACHER' matching the target permission codes
    bind.execute(
        sa.text("""
            DELETE FROM role_permissions 
            WHERE role_id IN (SELECT id FROM roles WHERE code = 'TEACHER')
              AND permission_id IN (SELECT id FROM permissions WHERE code = ANY(:codes))
        """),
        {"codes": target_permissions}
    )
