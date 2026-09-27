"""release_2_0_additive_models

Revision ID: f2461c0741e3
Revises: e1351c0630e2
Create Date: 2026-09-20 07:20:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'f2461c0741e3'
down_revision: Union[str, None] = 'e1351c0630e2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add stafftype enum and staff_type column to teachers
    with op.get_context().autocommit_block():
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'stafftype') THEN
                    CREATE TYPE stafftype AS ENUM ('TEACHING', 'NON_TEACHING');
                END IF;
            END
            $$;
        """)

    conn = op.get_bind()
    # Add column staff_type to teachers if not exists
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'teachers' AND column_name = 'staff_type'
            ) THEN
                ALTER TABLE teachers ADD COLUMN staff_type stafftype NOT NULL DEFAULT 'TEACHING';
            END IF;
        END
        $$;
    """)

    # 2. Create rooms table
    op.create_table(
        'rooms',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.UUID(), nullable=True),
        sa.Column('updated_by', sa.UUID(), nullable=True),
        sa.Column('tenant_id', sa.UUID(), nullable=False),
        sa.Column('school_id', sa.UUID(), nullable=False),
        sa.Column('room_number', sa.String(length=50), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('room_type', sa.String(length=50), server_default='CLASSROOM', nullable=False),
        sa.Column('capacity', sa.Integer(), server_default='40', nullable=False),
        sa.Column('floor', sa.String(length=20), nullable=True),
        sa.Column('building', sa.String(length=100), nullable=True),
        sa.Column('is_active', sa.Boolean(), server_default='true', nullable=False),
        sa.Column('settings', sa.JSON(), server_default='{}', nullable=False),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('tenant_id', 'school_id', 'room_number', name='uq_rooms_tenant_school_room_number')
    )
    op.create_index(op.f('ix_rooms_id'), 'rooms', ['id'], unique=False)
    op.create_index(op.f('ix_rooms_tenant_id'), 'rooms', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_rooms_school_id'), 'rooms', ['school_id'], unique=False)

    # 3. Create Enums for staff_salaries
    with op.get_context().autocommit_block():
        op.execute("""
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'salarystatus') THEN
                    CREATE TYPE salarystatus AS ENUM ('GENERATED', 'PENDING', 'PAID');
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'salarypaymentmethod') THEN
                    CREATE TYPE salarypaymentmethod AS ENUM ('BANK_TRANSFER', 'CASH', 'CHEQUE', 'ONLINE');
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'expensecategory') THEN
                    CREATE TYPE expensecategory AS ENUM ('STAFF', 'INFRASTRUCTURE', 'ACADEMIC', 'OPERATIONS', 'OTHER');
                END IF;
            END
            $$;
        """)

    # 4. Create staff_salaries table
    op.create_table(
        'staff_salaries',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.UUID(), nullable=True),
        sa.Column('updated_by', sa.UUID(), nullable=True),
        sa.Column('tenant_id', sa.UUID(), nullable=False),
        sa.Column('school_id', sa.UUID(), nullable=False),
        sa.Column('staff_id', sa.UUID(), nullable=False),
        sa.Column('month', sa.Integer(), nullable=False),
        sa.Column('year', sa.Integer(), nullable=False),
        sa.Column('base_salary', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('allowances', sa.Numeric(precision=12, scale=2), server_default='0.00', nullable=False),
        sa.Column('deductions', sa.Numeric(precision=12, scale=2), server_default='0.00', nullable=False),
        sa.Column('net_salary', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('status', postgresql.ENUM('GENERATED', 'PENDING', 'PAID', name='salarystatus', create_type=False), server_default='PENDING', nullable=False),
        sa.Column('payment_date', sa.Date(), nullable=True),
        sa.Column('payment_method', postgresql.ENUM('BANK_TRANSFER', 'CASH', 'CHEQUE', 'ONLINE', name='salarypaymentmethod', create_type=False), nullable=True),
        sa.Column('reference_number', sa.String(length=150), nullable=True),
        sa.Column('remarks', sa.String(length=500), nullable=True),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['staff_id'], ['teachers.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('tenant_id', 'school_id', 'staff_id', 'month', 'year', name='uq_staff_salaries_tenant_school_staff_month_year')
    )
    op.create_index(op.f('ix_staff_salaries_id'), 'staff_salaries', ['id'], unique=False)
    op.create_index(op.f('ix_staff_salaries_tenant_id'), 'staff_salaries', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_staff_salaries_school_id'), 'staff_salaries', ['school_id'], unique=False)
    op.create_index(op.f('ix_staff_salaries_staff_id'), 'staff_salaries', ['staff_id'], unique=False)

    # 5. Create expenses table
    op.create_table(
        'expenses',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.UUID(), nullable=True),
        sa.Column('updated_by', sa.UUID(), nullable=True),
        sa.Column('tenant_id', sa.UUID(), nullable=False),
        sa.Column('school_id', sa.UUID(), nullable=False),
        sa.Column('category', postgresql.ENUM('STAFF', 'INFRASTRUCTURE', 'ACADEMIC', 'OPERATIONS', 'OTHER', name='expensecategory', create_type=False), nullable=False),
        sa.Column('subcategory', sa.String(length=100), nullable=True),
        sa.Column('amount', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('expense_date', sa.Date(), nullable=False),
        sa.Column('description', sa.String(length=500), nullable=False),
        sa.Column('paid_to', sa.String(length=150), nullable=False),
        sa.Column('payment_method', sa.String(length=50), server_default='BANK_TRANSFER', nullable=False),
        sa.Column('reference_number', sa.String(length=150), nullable=True),
        sa.Column('receipt_url', sa.String(length=500), nullable=True),
        sa.Column('salary_payment_id', sa.UUID(), nullable=True),
        sa.Column('status', sa.String(length=20), server_default='APPROVED', nullable=False),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['salary_payment_id'], ['staff_salaries.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('salary_payment_id', name='uq_expenses_salary_payment_id')
    )
    op.create_index(op.f('ix_expenses_id'), 'expenses', ['id'], unique=False)
    op.create_index(op.f('ix_expenses_tenant_id'), 'expenses', ['tenant_id'], unique=False)
    op.create_index(op.f('ix_expenses_school_id'), 'expenses', ['school_id'], unique=False)
    op.create_index(op.f('ix_expenses_category'), 'expenses', ['category'], unique=False)
    op.create_index(op.f('ix_expenses_expense_date'), 'expenses', ['expense_date'], unique=False)


def downgrade() -> None:
    op.drop_table('expenses')
    op.drop_table('staff_salaries')
    op.drop_table('rooms')
    op.execute("ALTER TABLE teachers DROP COLUMN IF EXISTS staff_type")
