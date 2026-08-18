"""create teacher leaves

Revision ID: 3da58b9f1d0b
Revises: 7da19b2ea510
Create Date: 2026-08-18 17:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import uuid

# revision identifiers, used by Alembic.
revision: str = '3da58b9f1d0b'
down_revision: Union[str, None] = '7da19b2ea510'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create teacher_leaves table
    op.create_table(
        'teacher_leaves',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('school_id', sa.Uuid(), nullable=False),
        sa.Column('teacher_id', sa.Uuid(), nullable=False),
        sa.Column('leave_type', sa.Enum('CASUAL', 'SICK', 'EARNED', 'EMERGENCY', 'OTHER', name='teacherleavetype'), nullable=False),
        sa.Column('start_date', sa.Date(), nullable=False),
        sa.Column('end_date', sa.Date(), nullable=False),
        sa.Column('reason', sa.String(length=500), nullable=False),
        sa.Column('remarks', sa.String(length=500), nullable=True),
        sa.Column('status', sa.Enum('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', name='teacherleavestatus'), nullable=False, server_default='PENDING'),
        sa.Column('requested_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('reviewed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('reviewed_by', sa.Uuid(), nullable=True),
        sa.Column('reviewer_remarks', sa.String(length=500), nullable=True),
        sa.Column('cancelled_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('cancellation_reason', sa.String(length=500), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['teacher_id'], ['teachers.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['reviewed_by'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )

    # 2. Create indexes
    op.create_index(op.f('ix_teacher_leaves_id'), 'teacher_leaves', ['id'], unique=False)
    op.create_index(op.f('ix_teacher_leaves_tenant_id'), 'teacher_leaves', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_teacher_leaves_school_id'), 'teacher_leaves', ['school_id'], unique=False)
    op.create_index(op.f('ix_teacher_leaves_teacher_id'), 'teacher_leaves', ['teacher_id'], unique=False)
    op.create_index(op.f('ix_teacher_leaves_start_date'), 'teacher_leaves', ['start_date'], unique=False)
    op.create_index(op.f('ix_teacher_leaves_end_date'), 'teacher_leaves', ['end_date'], unique=False)
    op.create_index(op.f('ix_teacher_leaves_status'), 'teacher_leaves', ['status'], unique=False)

    # 3. Seed new permissions
    bind = op.get_bind()
    
    target_permissions = [
        {"id": uuid.uuid4(), "name": "Read Teacher Leaves", "code": "teacher_leave.read", "description": "Allows viewing teacher leaves"},
        {"id": uuid.uuid4(), "name": "Create Teacher Leave", "code": "teacher_leave.create", "description": "Allows submitting teacher leave"},
        {"id": uuid.uuid4(), "name": "Cancel Teacher Leave", "code": "teacher_leave.cancel", "description": "Allows cancelling pending teacher leave"},
        {"id": uuid.uuid4(), "name": "Review Teacher Leave", "code": "teacher_leave.review", "description": "Allows reviewing teacher leaves"},
        {"id": uuid.uuid4(), "name": "Admin Teacher Leave", "code": "teacher_leave.admin", "description": "Allows administrative teacher leave operations"},
    ]

    for perm in target_permissions:
        exist_res = bind.execute(
            sa.text("SELECT 1 FROM permissions WHERE code = :code"),
            {"code": perm["code"]}
        )
        if not exist_res.fetchone():
            bind.execute(
                sa.text("INSERT INTO permissions (id, name, code, description) VALUES (:id, :name, :code, :description)"),
                {"id": perm["id"], "name": perm["name"], "code": perm["code"], "description": perm["description"]}
            )

    # 4. Fetch all permission IDs from DB to map them correctly
    perm_codes = ["teacher_leave.read", "teacher_leave.create", "teacher_leave.cancel", "teacher_leave.review", "teacher_leave.admin"]
    permissions_res = bind.execute(
        sa.text("SELECT id, code FROM permissions WHERE code = ANY(:codes)"),
        {"codes": perm_codes}
    )
    permissions = {row[1]: row[0] for row in permissions_res.fetchall()}

    # 5. Seed role_permissions idempotently
    role_mappings = {
        "TEACHER": ["teacher_leave.read", "teacher_leave.create", "teacher_leave.cancel"],
        "PRINCIPAL": ["teacher_leave.read", "teacher_leave.review", "teacher_leave.admin"],
        "ADMIN": ["teacher_leave.read", "teacher_leave.review", "teacher_leave.admin"],
    }

    for role_code, codes in role_mappings.items():
        roles_res = bind.execute(
            sa.text("SELECT id FROM roles WHERE code = :role_code AND deleted_at IS NULL"),
            {"role_code": role_code}
        )
        roles = roles_res.fetchall()
        for role in roles:
            role_id = role[0]
            for code in codes:
                perm_id = permissions[code]
                exist_rp = bind.execute(
                    sa.text("SELECT 1 FROM role_permissions WHERE role_id = :role_id AND permission_id = :perm_id"),
                    {"role_id": role_id, "perm_id": perm_id}
                )
                if not exist_rp.fetchone():
                    bind.execute(
                        sa.text("INSERT INTO role_permissions (role_id, permission_id) VALUES (:role_id, :perm_id)"),
                        {"role_id": role_id, "perm_id": perm_id}
                    )


def downgrade() -> None:
    bind = op.get_bind()
    
    # 1. Delete role permissions
    perm_codes = ["teacher_leave.read", "teacher_leave.create", "teacher_leave.cancel", "teacher_leave.review", "teacher_leave.admin"]
    bind.execute(
        sa.text("DELETE FROM role_permissions WHERE permission_id IN (SELECT id FROM permissions WHERE code = ANY(:codes))"),
        {"codes": perm_codes}
    )
    
    # 2. Delete permissions
    bind.execute(
        sa.text("DELETE FROM permissions WHERE code = ANY(:codes)"),
        {"codes": perm_codes}
    )

    # 3. Drop indexes and table
    op.drop_index(op.f('ix_teacher_leaves_status'), table_name='teacher_leaves')
    op.drop_index(op.f('ix_teacher_leaves_end_date'), table_name='teacher_leaves')
    op.drop_index(op.f('ix_teacher_leaves_start_date'), table_name='teacher_leaves')
    op.drop_index(op.f('ix_teacher_leaves_teacher_id'), table_name='teacher_leaves')
    op.drop_index(op.f('ix_teacher_leaves_school_id'), table_name='teacher_leaves')
    op.drop_index(op.f('ix_teacher_leaves_tenant_id'), table_name='teacher_leaves')
    op.drop_index(op.f('ix_teacher_leaves_id'), table_name='teacher_leaves')
    op.drop_table('teacher_leaves')

    # 4. Drop Enum types in Postgres (if Postgres)
    # SQLAlchemy drop Enum is database-specific, but using schema-driven Enum with create_type=True
    # can be dropped by dropping the type name explicitly.
    try:
        bind.execute(sa.text("DROP TYPE teacherleavetype"))
        bind.execute(sa.text("DROP TYPE teacherleavestatus"))
    except Exception:
        pass
