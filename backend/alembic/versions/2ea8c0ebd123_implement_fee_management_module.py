"""implement_fee_management_module

Revision ID: 2ea8c0ebd123
Revises: 0db5caad1556
Create Date: 2026-08-03 00:09:20.000000

"""
from typing import Sequence, Union
import uuid
from datetime import datetime, timezone

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '2ea8c0ebd123'
down_revision: Union[str, None] = '0db5caad1556'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create Enums using raw SQL wrapped in try-except for duplicate safety
    bind = op.get_bind()
    
    try:
        bind.execute(sa.text("CREATE TYPE concessiontype AS ENUM ('FIXED', 'PERCENTAGE')"))
    except Exception:
        pass

    try:
        bind.execute(sa.text("CREATE TYPE paymentmethod AS ENUM ('CASH', 'BANK_TRANSFER', 'CARD', 'CHEQUE', 'ONLINE')"))
    except Exception:
        pass

    try:
        bind.execute(sa.text("CREATE TYPE paymentstatus AS ENUM ('COMPLETED', 'CANCELLED')"))
    except Exception:
        pass

    try:
        bind.execute(sa.text("CREATE TYPE feeassignmentstatus AS ENUM ('UNPAID', 'PARTIALLY_PAID', 'PAID')"))
    except Exception:
        pass

    try:
        bind.execute(sa.text("CREATE TYPE finetype AS ENUM ('FIXED', 'PERCENTAGE', 'DAILY_FIXED')"))
    except Exception:
        pass

    # 2. Create Tables using create_type=False for PostgreSQL Enums
    op.create_table('fee_types',
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('code', sa.String(length=50), nullable=False),
        sa.Column('description', sa.String(length=500), nullable=True),
        sa.Column('is_system', sa.Boolean(), server_default='false', nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('tenant_id', 'code', name='uq_fee_types_tenant_code')
    )
    op.create_index(op.f('ix_fee_types_id'), 'fee_types', ['id'], unique=False)
    op.create_index(op.f('ix_fee_types_tenant_id'), 'fee_types', ['tenant_id'], unique=False)

    op.create_table('scholarships',
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('concession_type', postgresql.ENUM(name='concessiontype', create_type=False), nullable=False),
        sa.Column('value', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('description', sa.String(length=500), nullable=True),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_scholarships_id'), 'scholarships', ['id'], unique=False)
    op.create_index(op.f('ix_scholarships_tenant_id'), 'scholarships', ['tenant_id'], unique=False)

    op.create_table('fee_structures',
        sa.Column('fee_type_id', sa.Uuid(), nullable=False),
        sa.Column('academic_year_id', sa.Uuid(), nullable=False),
        sa.Column('class_id', sa.Uuid(), nullable=True),
        sa.Column('amount', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('due_date', sa.Date(), nullable=False),
        sa.Column('description', sa.String(length=500), nullable=True),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('school_id', sa.Uuid(), nullable=False),
        sa.Column('version', sa.Integer(), nullable=False),
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['academic_year_id'], ['academic_years.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['class_id'], ['classes.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['fee_type_id'], ['fee_types.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_fee_structures_id'), 'fee_structures', ['id'], unique=False)
    op.create_index(op.f('ix_fee_structures_school_id'), 'fee_structures', ['school_id'], unique=False)
    op.create_index(op.f('ix_fee_structures_tenant_id'), 'fee_structures', ['tenant_id'], unique=False)

    op.create_table('fine_rules',
        sa.Column('fee_structure_id', sa.Uuid(), nullable=False),
        sa.Column('grace_period_days', sa.Integer(), server_default='0', nullable=False),
        sa.Column('fine_type', postgresql.ENUM(name='finetype', create_type=False), nullable=False),
        sa.Column('fine_value', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['fee_structure_id'], ['fee_structures.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('fee_structure_id', name='uq_fine_rules_fee_structure')
    )
    op.create_index(op.f('ix_fine_rules_id'), 'fine_rules', ['id'], unique=False)
    op.create_index(op.f('ix_fine_rules_tenant_id'), 'fine_rules', ['tenant_id'], unique=False)

    op.create_table('student_fee_assignments',
        sa.Column('student_id', sa.Uuid(), nullable=False),
        sa.Column('fee_structure_id', sa.Uuid(), nullable=False),
        sa.Column('academic_year_id', sa.Uuid(), nullable=False),
        sa.Column('assigned_amount', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('scholarship_id', sa.Uuid(), nullable=True),
        sa.Column('discount_amount', sa.Numeric(precision=10, scale=2), server_default='0.00', nullable=False),
        sa.Column('fine_amount', sa.Numeric(precision=10, scale=2), server_default='0.00', nullable=False),
        sa.Column('paid_amount', sa.Numeric(precision=10, scale=2), server_default='0.00', nullable=False),
        sa.Column('status', postgresql.ENUM(name='feeassignmentstatus', create_type=False), server_default='UNPAID', nullable=False),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('version', sa.Integer(), nullable=False),
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['academic_year_id'], ['academic_years.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['fee_structure_id'], ['fee_structures.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['scholarship_id'], ['scholarships.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['student_id'], ['students.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('student_id', 'fee_structure_id', name='uq_student_fee_assignments_student_structure')
    )
    op.create_index(op.f('ix_student_fee_assignments_id'), 'student_fee_assignments', ['id'], unique=False)
    op.create_index(op.f('ix_student_fee_assignments_tenant_id'), 'student_fee_assignments', ['tenant_id'], unique=False)

    op.create_table('fee_payments',
        sa.Column('student_id', sa.Uuid(), nullable=False),
        sa.Column('academic_year_id', sa.Uuid(), nullable=False),
        sa.Column('amount_paid', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('payment_date', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('payment_method', postgresql.ENUM(name='paymentmethod', create_type=False), nullable=False),
        sa.Column('status', postgresql.ENUM(name='paymentstatus', create_type=False), server_default='COMPLETED', nullable=False),
        sa.Column('transaction_reference', sa.String(length=150), nullable=True),
        sa.Column('remarks', sa.String(length=500), nullable=True),
        sa.Column('cancel_reason', sa.String(length=250), nullable=True),
        sa.Column('cancelled_by', sa.Uuid(), nullable=True),
        sa.Column('cancelled_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('version', sa.Integer(), nullable=False),
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['academic_year_id'], ['academic_years.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['cancelled_by'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['student_id'], ['students.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_fee_payments_id'), 'fee_payments', ['id'], unique=False)
    op.create_index(op.f('ix_fee_payments_tenant_id'), 'fee_payments', ['tenant_id'], unique=False)

    op.create_table('fee_payment_allocations',
        sa.Column('payment_id', sa.Uuid(), nullable=False),
        sa.Column('assignment_id', sa.Uuid(), nullable=False),
        sa.Column('amount_allocated', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.ForeignKeyConstraint(['assignment_id'], ['student_fee_assignments.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['payment_id'], ['fee_payments.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('payment_id', 'assignment_id')
    )

    op.create_table('fee_receipts',
        sa.Column('payment_id', sa.Uuid(), nullable=False),
        sa.Column('receipt_number', sa.String(length=50), nullable=False),
        sa.Column('pdf_path', sa.String(length=255), nullable=True),
        sa.Column('tenant_id', sa.Uuid(), nullable=False),
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Uuid(), nullable=True),
        sa.Column('updated_by', sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(['payment_id'], ['fee_payments.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['tenant_id'], ['tenants.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('payment_id', name='uq_fee_receipts_payment'),
        sa.UniqueConstraint('receipt_number', name='uq_fee_receipts_number')
    )
    op.create_index(op.f('ix_fee_receipts_id'), 'fee_receipts', ['id'], unique=False)
    op.create_index(op.f('ix_fee_receipts_tenant_id'), 'fee_receipts', ['tenant_id'], unique=False)

    # 3. Seed Permissions
    now = datetime.now(timezone.utc)
    permissions_data = [
        {"id": uuid.uuid4(), "name": "Create Fee", "code": "fee.create", "description": "Create fee structures & mappings", "created_at": now, "updated_at": now},
        {"id": uuid.uuid4(), "name": "Read Fee", "code": "fee.read", "description": "View fee ledgers & assignments", "created_at": now, "updated_at": now},
        {"id": uuid.uuid4(), "name": "Update Fee", "code": "fee.update", "description": "Modify fee entries", "created_at": now, "updated_at": now},
        {"id": uuid.uuid4(), "name": "Delete Fee", "code": "fee.delete", "description": "Soft delete fee items", "created_at": now, "updated_at": now},
        {"id": uuid.uuid4(), "name": "Collect Fee Payment", "code": "fee.pay", "description": "Collect payment and generate receipts", "created_at": now, "updated_at": now},
        {"id": uuid.uuid4(), "name": "Cancel Fee Payment", "code": "fee.cancel", "description": "Reverse payment allocations", "created_at": now, "updated_at": now},
        {"id": uuid.uuid4(), "name": "Fee Reports Access", "code": "fee.report", "description": "Access dashboard predictive analytics", "created_at": now, "updated_at": now},
    ]
    
    op.bulk_insert(
        sa.table(
            'permissions',
            sa.column('id', sa.Uuid),
            sa.column('name', sa.String),
            sa.column('code', sa.String),
            sa.column('description', sa.String),
            sa.column('created_at', sa.DateTime(timezone=True)),
            sa.column('updated_at', sa.DateTime(timezone=True))
        ),
        permissions_data
    )

    # 4. Map Permissions to System Roles (SUPER_ADMIN, ADMIN, PRINCIPAL, STAFF, PARENT, TEACHER)
    roles = bind.execute(sa.text("SELECT id, code FROM roles WHERE deleted_at IS NULL")).all()
    perms = bind.execute(sa.text("SELECT id, code FROM permissions WHERE code LIKE 'fee.%'")).all()
    
    perm_map = {p.code: p.id for p in perms}
    
    for r in roles:
        role_code = str(r.code).upper()
        if role_code in ['SUPER_ADMIN', 'ADMIN', 'PRINCIPAL', 'STAFF']:
            # Map ALL fee permissions
            for p_code, p_id in perm_map.items():
                bind.execute(sa.text(
                    "INSERT INTO role_permissions (role_id, permission_id) VALUES (:r_id, :p_id)"
                ), {"r_id": r.id, "p_id": p_id})
        elif role_code in ['PARENT', 'TEACHER']:
            # Map ONLY fee.read permission
            if 'fee.read' in perm_map:
                bind.execute(sa.text(
                    "INSERT INTO role_permissions (role_id, permission_id) VALUES (:r_id, :p_id)"
                ), {"r_id": r.id, "p_id": perm_map['fee.read']})


def downgrade() -> None:
    # Delete Role Permissions Mappings
    bind = op.get_bind()
    bind.execute(sa.text("DELETE FROM role_permissions WHERE permission_id IN (SELECT id FROM permissions WHERE code LIKE 'fee.%')"))
    bind.execute(sa.text("DELETE FROM permissions WHERE code LIKE 'fee.%'"))

    # Drop Tables
    op.drop_table('fee_receipts')
    op.drop_table('fee_payment_allocations')
    op.drop_table('fee_payments')
    op.drop_table('student_fee_assignments')
    op.drop_table('fine_rules')
    op.drop_table('fee_structures')
    op.drop_table('scholarships')
    op.drop_table('fee_types')

    # Drop Enums
    op.execute("DROP TYPE IF EXISTS concessiontype;")
    op.execute("DROP TYPE IF EXISTS paymentmethod;")
    op.execute("DROP TYPE IF EXISTS paymentstatus;")
    op.execute("DROP TYPE IF EXISTS feeassignmentstatus;")
    op.execute("DROP TYPE IF EXISTS finetype;")
