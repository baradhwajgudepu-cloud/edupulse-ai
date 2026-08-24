"""implement_school_planner_module

Revision ID: 3b29aeac0383
Revises: 3da58b9f1d0c
Create Date: 2026-08-20 14:43:53.361839

"""
from typing import Sequence, Union
import uuid

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '3b29aeac0383'
down_revision: Union[str, None] = '3da58b9f1d0c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create school_events table
    op.create_table('school_events',
        sa.Column('event_name', sa.String(length=200), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('event_date', sa.Date(), nullable=False),
        sa.Column('start_time', sa.Time(), nullable=False),
        sa.Column('end_time', sa.Time(), nullable=False),
        sa.Column('venue', sa.String(length=200), nullable=True),
        sa.Column('target_audience', sa.Enum('ALL', 'STUDENTS', 'PARENTS', 'TEACHERS', name='eventaudience'), nullable=False),
        sa.Column('status', sa.Enum('DRAFT', 'PUBLISHED', 'CANCELLED', 'COMPLETED', name='eventstatus'), nullable=False),
        sa.Column('is_holiday', sa.Boolean(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('version', sa.Integer(), nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('school_id', sa.Uuid(), nullable=False),
        sa.Column('academic_year_id', sa.Uuid(), nullable=False),
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['academic_year_id'], ['academic_years.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_school_events_academic_year_id'), 'school_events', ['academic_year_id'], unique=False)
    op.create_index('ix_school_events_event_date', 'school_events', ['event_date'], unique=False)
    op.create_index(op.f('ix_school_events_id'), 'school_events', ['id'], unique=False)
    op.create_index(op.f('ix_school_events_school_id'), 'school_events', ['school_id'], unique=False)
    op.create_index('ix_school_events_status', 'school_events', ['status'], unique=False)
    op.create_index('ix_school_events_target_audience', 'school_events', ['target_audience'], unique=False)
    op.create_index(op.f('ix_school_events_tenant_id'), 'school_events', ['tenant_id'], unique=False)

    # 2. Create announcements table
    op.create_table('announcements',
        sa.Column('title', sa.String(length=200), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('audience_type', sa.Enum('ROLE', 'CLASS', 'SECTION', name='announcementaudiencetype'), nullable=False),
        sa.Column('target_role', postgresql.ENUM('PARENT', 'TEACHER', 'PRINCIPAL', 'ADMIN', 'STAFF', name='notificationtargetrole', create_type=False), nullable=True),
        sa.Column('target_class_id', sa.Uuid(), nullable=True),
        sa.Column('target_section_id', sa.Uuid(), nullable=True),
        sa.Column('publish_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('priority', postgresql.ENUM('LOW', 'NORMAL', 'HIGH', 'URGENT', name='notificationpriority', create_type=False), nullable=False),
        sa.Column('attachment_url', sa.String(length=500), nullable=True),
        sa.Column('status', sa.Enum('DRAFT', 'PUBLISHED', 'CANCELLED', name='announcementstatus'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('version', sa.Integer(), nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('school_id', sa.Uuid(), nullable=False),
        sa.Column('academic_year_id', sa.Uuid(), nullable=False),
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['academic_year_id'], ['academic_years.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['target_class_id'], ['classes.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['target_section_id'], ['sections.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_announcements_academic_year_id'), 'announcements', ['academic_year_id'], unique=False)
    op.create_index(op.f('ix_announcements_id'), 'announcements', ['id'], unique=False)
    op.create_index('ix_announcements_publish_at', 'announcements', ['publish_at'], unique=False)
    op.create_index(op.f('ix_announcements_school_id'), 'announcements', ['school_id'], unique=False)
    op.create_index('ix_announcements_status', 'announcements', ['status'], unique=False)
    op.create_index(op.f('ix_announcements_target_class_id'), 'announcements', ['target_class_id'], unique=False)
    op.create_index(op.f('ix_announcements_target_section_id'), 'announcements', ['target_section_id'], unique=False)
    op.create_index(op.f('ix_announcements_tenant_id'), 'announcements', ['tenant_id'], unique=False)

    # 3. Seed new permissions
    bind = op.get_bind()
    
    target_permissions = [
        {"id": uuid.uuid4(), "name": "Create Events", "code": "event.create", "description": "Allows creating school events"},
        {"id": uuid.uuid4(), "name": "Read Events", "code": "event.read", "description": "Allows viewing school events"},
        {"id": uuid.uuid4(), "name": "Update Events", "code": "event.update", "description": "Allows updating school events"},
        {"id": uuid.uuid4(), "name": "Delete Events", "code": "event.delete", "description": "Allows deleting school events"},
        {"id": uuid.uuid4(), "name": "Publish Events", "code": "event.publish", "description": "Allows publishing school events"},
        
        {"id": uuid.uuid4(), "name": "Create Announcements", "code": "announcement.create", "description": "Allows creating announcements"},
        {"id": uuid.uuid4(), "name": "Read Announcements", "code": "announcement.read", "description": "Allows viewing announcements"},
        {"id": uuid.uuid4(), "name": "Update Announcements", "code": "announcement.update", "description": "Allows updating announcements"},
        {"id": uuid.uuid4(), "name": "Delete Announcements", "code": "announcement.delete", "description": "Allows deleting announcements"},
        {"id": uuid.uuid4(), "name": "Publish Announcements", "code": "announcement.publish", "description": "Allows publishing announcements"},
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

    # 4. Fetch permissions map
    perm_codes = [p["code"] for p in target_permissions]
    permissions_res = bind.execute(
        sa.text("SELECT id, code FROM permissions WHERE code = ANY(:codes)"),
        {"codes": perm_codes}
    )
    permissions = {row[1]: row[0] for row in permissions_res.fetchall()}

    # 5. Seed role_permissions idempotently
    role_mappings = {
        "PRINCIPAL": perm_codes,
        "ADMIN": perm_codes,
        "TEACHER": ["event.read", "announcement.read"],
        "PARENT": ["event.read", "announcement.read"],
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
                if code in permissions:
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
    perm_codes = [
        "event.create", "event.read", "event.update", "event.delete", "event.publish",
        "announcement.create", "announcement.read", "announcement.update", "announcement.delete", "announcement.publish"
    ]
    bind.execute(
        sa.text("DELETE FROM role_permissions WHERE permission_id IN (SELECT id FROM permissions WHERE code = ANY(:codes))"),
        {"codes": perm_codes}
    )
    
    # 2. Delete permissions
    bind.execute(
        sa.text("DELETE FROM permissions WHERE code = ANY(:codes)"),
        {"codes": perm_codes}
    )

    # 3. Drop tables and indexes
    op.drop_index(op.f('ix_announcements_tenant_id'), table_name='announcements')
    op.drop_index(op.f('ix_announcements_target_section_id'), table_name='announcements')
    op.drop_index(op.f('ix_announcements_target_class_id'), table_name='announcements')
    op.drop_index('ix_announcements_status', table_name='announcements')
    op.drop_index(op.f('ix_announcements_school_id'), table_name='announcements')
    op.drop_index('ix_announcements_publish_at', table_name='announcements')
    op.drop_index(op.f('ix_announcements_id'), table_name='announcements')
    op.drop_index(op.f('ix_announcements_academic_year_id'), table_name='announcements')
    op.drop_table('announcements')

    op.drop_index(op.f('ix_school_events_tenant_id'), table_name='school_events')
    op.drop_index('ix_school_events_target_audience', table_name='school_events')
    op.drop_index('ix_school_events_status', table_name='school_events')
    op.drop_index(op.f('ix_school_events_school_id'), table_name='school_events')
    op.drop_index(op.f('ix_school_events_id'), table_name='school_events')
    op.drop_index('ix_school_events_event_date', table_name='school_events')
    op.drop_index(op.f('ix_school_events_academic_year_id'), table_name='school_events')
    op.drop_table('school_events')

    # Drop custom PostgreSQL Enums
    try:
        bind.execute(sa.text("DROP TYPE eventaudience"))
        bind.execute(sa.text("DROP TYPE eventstatus"))
        bind.execute(sa.text("DROP TYPE announcementaudiencetype"))
        bind.execute(sa.text("DROP TYPE announcementstatus"))
    except Exception:
        pass
