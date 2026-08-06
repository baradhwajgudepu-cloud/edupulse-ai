"""add_identity_provisioning_columns

Revision ID: 1c42b0ebbc33
Revises: 36ec2ed78a9e
Create Date: 2026-08-02 17:27:48.756932

"""
from typing import Sequence, Union
import uuid
from datetime import datetime, timezone

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from app.core.security import hash_password

# revision identifiers, used by Alembic.
revision: str = '1c42b0ebbc33'
down_revision: Union[str, None] = '36ec2ed78a9e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add columns to tables
    op.add_column('users', sa.Column('must_change_password', sa.Boolean(), server_default='false', nullable=False))
    
    op.add_column('guardians', sa.Column('user_id', sa.Uuid(), nullable=True))
    op.create_index(op.f('ix_guardians_user_id'), 'guardians', ['user_id'], unique=True)
    op.create_foreign_key(None, 'guardians', 'users', ['user_id'], ['id'], ondelete='SET NULL')
    
    op.add_column('teachers', sa.Column('user_id', sa.Uuid(), nullable=True))
    op.create_index(op.f('ix_teachers_user_id'), 'teachers', ['user_id'], unique=True)
    op.create_foreign_key(None, 'teachers', 'users', ['user_id'], ['id'], ondelete='SET NULL')

    # 2. Seed missing permissions
    now = datetime.now(timezone.utc)
    permissions_data = [
        {"id": uuid.uuid4(), "name": "Create Identity", "code": "identity.create", "description": "Allows creating user identities", "created_at": now, "updated_at": now},
        {"id": uuid.uuid4(), "name": "Read Identity", "code": "identity.read", "description": "Allows viewing user identities", "created_at": now, "updated_at": now},
        {"id": uuid.uuid4(), "name": "Update Identity", "code": "identity.update", "description": "Allows updating user identities", "created_at": now, "updated_at": now},
        {"id": uuid.uuid4(), "name": "Delete Identity", "code": "identity.delete", "description": "Allows deleting user identities", "created_at": now, "updated_at": now},
        {"id": uuid.uuid4(), "name": "Provision Identity", "code": "identity.provision", "description": "Allows provisioning user identities", "created_at": now, "updated_at": now},
        {"id": uuid.uuid4(), "name": "Reset Password Identity", "code": "identity.reset_password", "description": "Allows resetting passwords", "created_at": now, "updated_at": now},
    ]

    bind = op.get_bind()

    # Seed permissions
    for p in permissions_data:
        # Check if code already exists to remain idempotent
        exist_p = bind.execute(sa.text("SELECT id FROM permissions WHERE code = :code"), {"code": p["code"]}).fetchone()
        if not exist_p:
            bind.execute(
                sa.text(
                    "INSERT INTO permissions (id, name, code, description, created_at, updated_at) "
                    "VALUES (:id, :name, :code, :description, :created_at, :updated_at)"
                ),
                p
            )

    # 3. Retrieve all tenants to seed roles per tenant
    tenants = bind.execute(sa.text("SELECT id FROM tenants")).fetchall()
    hashed_pwd = hash_password("EduPulse@123")

    for tenant in tenants:
        t_id = tenant[0]
        
        # Seed missing roles for this tenant (TEACHER, PARENT, PRINCIPAL, STAFF)
        roles_to_seed = [
            {"code": "TEACHER", "name": "Teacher"},
            {"code": "PARENT", "name": "Parent"},
            {"code": "PRINCIPAL", "name": "Principal"},
            {"code": "STAFF", "name": "Staff"}
        ]
        
        seeded_role_ids = {}
        for r in roles_to_seed:
            # Check case-insensitively
            exist_r = bind.execute(
                sa.text("SELECT id FROM roles WHERE tenant_id = :t_id AND (UPPER(code) = :code OR UPPER(name) = :ucode)"),
                {"t_id": t_id, "code": r["code"], "ucode": r["code"]}
            ).fetchone()
            
            if exist_r:
                seeded_role_ids[r["code"]] = exist_r[0]
            else:
                r_id = uuid.uuid4()
                bind.execute(
                    sa.text(
                        "INSERT INTO roles (id, tenant_id, name, code, description, is_system, version, created_at, updated_at) "
                        "VALUES (:id, :tenant_id, :name, :code, :description, :is_system, :version, :created_at, :updated_at)"
                    ),
                    {
                        "id": r_id,
                        "tenant_id": t_id,
                        "name": r["name"],
                        "code": r["code"],
                        "description": f"System role for {r['name']}",
                        "is_system": True,
                        "version": 1,
                        "created_at": now,
                        "updated_at": now
                    }
                )
                seeded_role_ids[r["code"]] = r_id

        # 4. Perform idempotent backfill for existing teachers
        teachers = bind.execute(
            sa.text("SELECT id, official_email, first_name, last_name, school_id FROM teachers WHERE tenant_id = :t_id AND user_id IS NULL"),
            {"t_id": t_id}
        ).fetchall()

        for teacher in teachers:
            teacher_id, email, first_name, last_name, school_id = teacher
            # Check if user already exists
            exist_u = bind.execute(
                sa.text("SELECT id FROM users WHERE tenant_id = :t_id AND email = :email"),
                {"t_id": t_id, "email": email}
            ).fetchone()

            if exist_u:
                u_id = exist_u[0]
            else:
                u_id = uuid.uuid4()
                bind.execute(
                    sa.text(
                        "INSERT INTO users (id, tenant_id, email, hashed_password, first_name, last_name, status, is_superuser, must_change_password, version, created_at, updated_at) "
                        "VALUES (:id, :tenant_id, :email, :hashed_password, :first_name, :last_name, :status, :is_superuser, :must_change_password, :version, :created_at, :updated_at)"
                    ),
                    {
                        "id": u_id,
                        "tenant_id": t_id,
                        "email": email,
                        "hashed_password": hashed_pwd,
                        "first_name": first_name,
                        "last_name": last_name,
                        "status": "ACTIVE",
                        "is_superuser": False,
                        "must_change_password": True,
                        "version": 1,
                        "created_at": now,
                        "updated_at": now
                    }
                )
                # Link user to the school in school_users if exists
                if school_id:
                    # Check if already exists in school_users
                    exist_su = bind.execute(
                        sa.text("SELECT user_id FROM school_users WHERE user_id = :u_id AND school_id = :s_id"),
                        {"u_id": u_id, "s_id": school_id}
                    ).fetchone()
                    if not exist_su:
                        bind.execute(
                            sa.text("INSERT INTO school_users (user_id, school_id) VALUES (:u_id, :s_id)"),
                            {"u_id": u_id, "s_id": school_id}
                        )

            # Assign TEACHER role if not already assigned
            role_id = seeded_role_ids.get("TEACHER")
            if role_id:
                exist_ur = bind.execute(
                    sa.text("SELECT user_id FROM user_roles WHERE user_id = :u_id AND role_id = :r_id"),
                    {"u_id": u_id, "r_id": role_id}
                ).fetchone()
                if not exist_ur:
                    bind.execute(
                        sa.text("INSERT INTO user_roles (user_id, role_id) VALUES (:u_id, :r_id)"),
                        {"u_id": u_id, "r_id": role_id}
                    )

            # Update teacher record
            bind.execute(
                sa.text("UPDATE teachers SET user_id = :u_id WHERE id = :teacher_id"),
                {"u_id": u_id, "teacher_id": teacher_id}
            )

        # 5. Perform idempotent backfill for existing guardians
        guardians = bind.execute(
            sa.text("SELECT id, email, first_name, last_name, mobile, school_id FROM guardians WHERE tenant_id = :t_id AND user_id IS NULL"),
            {"t_id": t_id}
        ).fetchall()

        for guardian in guardians:
            guardian_id, email, first_name, last_name, mobile, school_id = guardian
            # Resolve email
            if not email:
                if mobile:
                    email = f"guardian.{mobile}@edupulse.local"
                else:
                    email = f"guardian.{uuid.uuid4().hex[:8]}@edupulse.local"

            # Check if user already exists
            exist_u = bind.execute(
                sa.text("SELECT id FROM users WHERE tenant_id = :t_id AND email = :email"),
                {"t_id": t_id, "email": email}
            ).fetchone()

            if exist_u:
                u_id = exist_u[0]
            else:
                u_id = uuid.uuid4()
                bind.execute(
                    sa.text(
                        "INSERT INTO users (id, tenant_id, email, hashed_password, first_name, last_name, status, is_superuser, must_change_password, version, created_at, updated_at) "
                        "VALUES (:id, :tenant_id, :email, :hashed_password, :first_name, :last_name, :status, :is_superuser, :must_change_password, :version, :created_at, :updated_at)"
                    ),
                    {
                        "id": u_id,
                        "tenant_id": t_id,
                        "email": email,
                        "hashed_password": hashed_pwd,
                        "first_name": first_name,
                        "last_name": last_name,
                        "status": "ACTIVE",
                        "is_superuser": False,
                        "must_change_password": True,
                        "version": 1,
                        "created_at": now,
                        "updated_at": now
                    }
                )
                # Link user to school_users if school_id exists
                if school_id:
                    exist_su = bind.execute(
                        sa.text("SELECT user_id FROM school_users WHERE user_id = :u_id AND school_id = :s_id"),
                        {"u_id": u_id, "s_id": school_id}
                    ).fetchone()
                    if not exist_su:
                        bind.execute(
                            sa.text("INSERT INTO school_users (user_id, school_id) VALUES (:u_id, :s_id)"),
                            {"u_id": u_id, "s_id": school_id}
                        )

            # Assign PARENT role if not already assigned
            role_id = seeded_role_ids.get("PARENT")
            if role_id:
                exist_ur = bind.execute(
                    sa.text("SELECT user_id FROM user_roles WHERE user_id = :u_id AND role_id = :r_id"),
                    {"u_id": u_id, "r_id": role_id}
                ).fetchone()
                if not exist_ur:
                    bind.execute(
                        sa.text("INSERT INTO user_roles (user_id, role_id) VALUES (:u_id, :r_id)"),
                        {"u_id": u_id, "r_id": role_id}
                    )

            # Update guardian record
            bind.execute(
                sa.text("UPDATE guardians SET user_id = :u_id WHERE id = :guardian_id"),
                {"u_id": u_id, "guardian_id": guardian_id}
            )


def downgrade() -> None:
    # 1. Clean seeded permissions
    op.execute("DELETE FROM permissions WHERE code IN ('identity.create', 'identity.read', 'identity.update', 'identity.delete', 'identity.provision', 'identity.reset_password');")
    
    # 2. Downgrade columns
    op.drop_column('users', 'must_change_password')
    op.drop_constraint(None, 'teachers', type_='foreignkey')
    op.drop_index(op.f('ix_teachers_user_id'), table_name='teachers')
    op.drop_column('teachers', 'user_id')
    op.drop_constraint(None, 'guardians', type_='foreignkey')
    op.drop_index(op.f('ix_guardians_user_id'), table_name='guardians')
    op.drop_column('guardians', 'user_id')
