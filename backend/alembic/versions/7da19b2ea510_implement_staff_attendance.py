"""implement staff attendance

Revision ID: 7da19b2ea510
Revises: 6c07269ae8b8
Create Date: 2026-08-18 16:35:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import uuid

# revision identifiers, used by Alembic.
revision: str = '7da19b2ea510'
down_revision: Union[str, None] = '6c07269ae8b8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Alter schools table: add latitude, longitude, geofence_radius_meters
    op.add_column('schools', sa.Column('latitude', sa.Float(), nullable=True))
    op.add_column('schools', sa.Column('longitude', sa.Float(), nullable=True))
    op.add_column('schools', sa.Column('geofence_radius_meters', sa.Integer(), server_default='100', nullable=False))

    # 2. Create staff_attendances table
    op.create_table(
        'staff_attendances',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('teacher_id', sa.Uuid(), nullable=False),
        sa.Column('school_id', sa.Uuid(), nullable=False),
        sa.Column('attendance_date', sa.Date(), nullable=False),
        sa.Column('check_in_time', sa.DateTime(timezone=True), nullable=False),
        sa.Column('check_in_latitude', sa.Float(), nullable=False),
        sa.Column('check_in_longitude', sa.Float(), nullable=False),
        sa.Column('check_in_distance_meters', sa.Float(), nullable=False),
        sa.Column('check_out_time', sa.DateTime(timezone=True), nullable=True),
        sa.Column('check_out_latitude', sa.Float(), nullable=True),
        sa.Column('check_out_longitude', sa.Float(), nullable=True),
        sa.Column('check_out_distance_meters', sa.Float(), nullable=True),
        sa.Column('is_mocked_location', sa.Boolean(), server_default='false', nullable=False),
        sa.Column('remarks', sa.String(length=500), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['teacher_id'], ['teachers.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('teacher_id', 'attendance_date', name='uq_staff_attendance_teacher_date')
    )
    
    # 3. Create indexes
    op.create_index(op.f('ix_staff_attendances_id'), 'staff_attendances', ['id'], unique=False)
    op.create_index(op.f('ix_staff_attendances_tenant_id'), 'staff_attendances', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_staff_attendances_teacher_id'), 'staff_attendances', ['teacher_id'], unique=False)
    op.create_index(op.f('ix_staff_attendances_school_id'), 'staff_attendances', ['school_id'], unique=False)
    op.create_index(op.f('ix_staff_attendances_attendance_date'), 'staff_attendances', ['attendance_date'], unique=False)

    # 4. Seed new permissions
    bind = op.get_bind()
    
    target_permissions = [
        {"id": uuid.uuid4(), "name": "Read Staff Attendance", "code": "staff_attendance.read", "description": "Allows reading staff attendance logs"},
        {"id": uuid.uuid4(), "name": "Create Staff Check-In", "code": "staff_attendance.create", "description": "Allows checking in"},
        {"id": uuid.uuid4(), "name": "Update Staff Check-Out", "code": "staff_attendance.update", "description": "Allows checking out"},
        {"id": uuid.uuid4(), "name": "Admin Staff Attendance", "code": "staff_attendance.admin", "description": "Allows administrative staff attendance operations"},
    ]
    
    for perm in target_permissions:
        # Check if already exists (idempotency)
        exist_res = bind.execute(
            sa.text("SELECT 1 FROM permissions WHERE code = :code"),
            {"code": perm["code"]}
        )
        if not exist_res.fetchone():
            bind.execute(
                sa.text("INSERT INTO permissions (id, name, code, description) VALUES (:id, :name, :code, :description)"),
                {"id": perm["id"], "name": perm["name"], "code": perm["code"], "description": perm["description"]}
            )

    # 5. Fetch all permission IDs from DB to map them correctly
    perm_codes = ["staff_attendance.read", "staff_attendance.create", "staff_attendance.update", "staff_attendance.admin"]
    permissions_res = bind.execute(
        sa.text("SELECT id, code FROM permissions WHERE code = ANY(:codes)"),
        {"codes": perm_codes}
    )
    permissions = {row[1]: row[0] for row in permissions_res.fetchall()}

    # 6. Seed role_permissions idempotently
    role_mappings = {
        "TEACHER": ["staff_attendance.read", "staff_attendance.create", "staff_attendance.update"],
        "PRINCIPAL": ["staff_attendance.read", "staff_attendance.admin"],
        "ADMIN": ["staff_attendance.read", "staff_attendance.admin"],
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
    perm_codes = ["staff_attendance.read", "staff_attendance.create", "staff_attendance.update", "staff_attendance.admin"]
    bind.execute(
        sa.text("DELETE FROM role_permissions WHERE permission_id IN (SELECT id FROM permissions WHERE code = ANY(:codes))"),
        {"codes": perm_codes}
    )
    
    # 2. Delete permissions
    bind.execute(
        sa.text("DELETE FROM permissions WHERE code = ANY(:codes)"),
        {"codes": perm_codes}
    )
    
    # 3. Drop staff_attendances table & indexes
    op.drop_index(op.f('ix_staff_attendances_attendance_date'), table_name='staff_attendances')
    op.drop_index(op.f('ix_staff_attendances_school_id'), table_name='staff_attendances')
    op.drop_index(op.f('ix_staff_attendances_teacher_id'), table_name='staff_attendances')
    op.drop_index(op.f('ix_staff_attendances_tenant_id'), table_name='staff_attendances')
    op.drop_index(op.f('ix_staff_attendances_id'), table_name='staff_attendances')
    op.drop_table('staff_attendances')
    
    # 4. Drop schools columns
    op.drop_column('schools', 'geofence_radius_meters')
    op.drop_column('schools', 'longitude')
    op.drop_column('schools', 'latitude')
