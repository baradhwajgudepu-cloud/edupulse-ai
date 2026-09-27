"""add_curriculum_masters_and_syllabus_audit

Revision ID: c1720de8fa3a
Revises: a4622cd9da5b
Create Date: 2026-09-23 15:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = 'c1720de8fa3a'
down_revision: Union[str, None] = 'a4622cd9da5b'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create curriculum_masters table
    op.create_table(
        'curriculum_masters',
        sa.Column('id', sa.UUID(), nullable=False, server_default=sa.text('gen_random_uuid()')),
        sa.Column('board', postgresql.ENUM('CBSE', 'ICSE', 'SSC', 'STATE', 'IB', 'IGCSE', 'CAMBRIDGE', 'OTHER', name='schoolboard', create_type=False), nullable=False),
        sa.Column('state', sa.String(length=100), nullable=True),
        sa.Column('academic_year_code', sa.String(length=30), nullable=False),
        sa.Column('class_level', sa.Integer(), nullable=False),
        sa.Column('class_name', sa.String(length=100), nullable=False),
        sa.Column('subject_code', sa.String(length=50), nullable=False),
        sa.Column('subject_name', sa.String(length=150), nullable=False),
        sa.Column('source', sa.String(length=255), nullable=False),
        sa.Column('source_version', sa.String(length=50), nullable=False),
        sa.Column('retrieved_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('verification_status', sa.String(length=30), server_default='VERIFIED', nullable=False),
        sa.Column('is_active', sa.Boolean(), server_default='true', nullable=False),
        sa.Column('metadata_json', sa.JSON(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('board', 'state', 'academic_year_code', 'class_level', 'subject_code', name='uq_curriculum_master_board_state_ay_class_sub')
    )
    op.create_index('ix_curriculum_masters_lookup', 'curriculum_masters', ['board', 'academic_year_code', 'class_level'], unique=False)
    op.create_index(op.f('ix_curriculum_masters_board'), 'curriculum_masters', ['board'], unique=False)
    op.create_index(op.f('ix_curriculum_masters_state'), 'curriculum_masters', ['state'], unique=False)
    op.create_index(op.f('ix_curriculum_masters_academic_year_code'), 'curriculum_masters', ['academic_year_code'], unique=False)
    op.create_index(op.f('ix_curriculum_masters_class_level'), 'curriculum_masters', ['class_level'], unique=False)
    op.create_index(op.f('ix_curriculum_masters_subject_code'), 'curriculum_masters', ['subject_code'], unique=False)

    # 2. Create curriculum_master_items table
    op.create_table(
        'curriculum_master_items',
        sa.Column('id', sa.UUID(), nullable=False, server_default=sa.text('gen_random_uuid()')),
        sa.Column('curriculum_master_id', sa.UUID(), nullable=False),
        sa.Column('item_code', sa.String(length=80), nullable=False),
        sa.Column('unit_name', sa.String(length=150), nullable=False),
        sa.Column('chapter_name', sa.String(length=150), nullable=False),
        sa.Column('topic_name', sa.String(length=150), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('sequence_order', sa.Integer(), server_default='1', nullable=False),
        sa.Column('learning_outcomes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(['curriculum_master_id'], ['curriculum_masters.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('curriculum_master_id', 'item_code', name='uq_curriculum_master_item_code')
    )
    op.create_index('ix_curriculum_master_items_seq', 'curriculum_master_items', ['curriculum_master_id', 'sequence_order'], unique=False)
    op.create_index(op.f('ix_curriculum_master_items_curriculum_master_id'), 'curriculum_master_items', ['curriculum_master_id'], unique=False)

    # 3. Add audit trail columns to syllabuses
    op.add_column('syllabuses', sa.Column('curriculum_master_id', sa.UUID(), nullable=True))
    op.add_column('syllabuses', sa.Column('source', sa.String(length=255), nullable=True))
    op.add_column('syllabuses', sa.Column('source_version', sa.String(length=50), nullable=True))
    op.add_column('syllabuses', sa.Column('retrieved_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('syllabuses', sa.Column('verification_status', sa.String(length=30), server_default='VERIFIED', nullable=False))
    op.add_column('syllabuses', sa.Column('derived_from', sa.String(length=255), nullable=True))
    op.add_column('syllabuses', sa.Column('is_custom', sa.Boolean(), server_default='false', nullable=False))

    op.create_foreign_key(
        'fk_syllabuses_curriculum_master_id',
        'syllabuses', 'curriculum_masters',
        ['curriculum_master_id'], ['id'],
        ondelete='SET NULL'
    )
    op.create_index(op.f('ix_syllabuses_curriculum_master_id'), 'syllabuses', ['curriculum_master_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_syllabuses_curriculum_master_id'), table_name='syllabuses')
    op.drop_constraint('fk_syllabuses_curriculum_master_id', 'syllabuses', type_='foreignkey')
    op.drop_column('syllabuses', 'is_custom')
    op.drop_column('syllabuses', 'derived_from')
    op.drop_column('syllabuses', 'verification_status')
    op.drop_column('syllabuses', 'retrieved_at')
    op.drop_column('syllabuses', 'source_version')
    op.drop_column('syllabuses', 'source')
    op.drop_column('syllabuses', 'curriculum_master_id')

    op.drop_index(op.f('ix_curriculum_master_items_curriculum_master_id'), table_name='curriculum_master_items')
    op.drop_index('ix_curriculum_master_items_seq', table_name='curriculum_master_items')
    op.drop_table('curriculum_master_items')

    op.drop_index(op.f('ix_curriculum_masters_subject_code'), table_name='curriculum_masters')
    op.drop_index(op.f('ix_curriculum_masters_class_level'), table_name='curriculum_masters')
    op.drop_index(op.f('ix_curriculum_masters_academic_year_code'), table_name='curriculum_masters')
    op.drop_index(op.f('ix_curriculum_masters_state'), table_name='curriculum_masters')
    op.drop_index(op.f('ix_curriculum_masters_board'), table_name='curriculum_masters')
    op.drop_index('ix_curriculum_masters_lookup', table_name='curriculum_masters')
    op.drop_table('curriculum_masters')
