"""add_section_id_to_syllabuses

Revision ID: j8155gh2ef65
Revises: h7044fg1de54
Create Date: 2026-09-26 22:38:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'j8155gh2ef65'
down_revision: Union[str, None] = 'h7044fg1de54'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Safely add section_id if not present
    conn = op.get_bind()
    res = conn.execute(sa.text("SELECT column_name FROM information_schema.columns WHERE table_name = 'syllabuses' AND column_name = 'section_id'")).fetchone()
    if not res:
        op.add_column('syllabuses', sa.Column('section_id', sa.Uuid(), sa.ForeignKey('sections.id', ondelete='CASCADE'), nullable=True))
        op.create_index('ix_syllabuses_section_id', 'syllabuses', ['section_id'])


def downgrade() -> None:
    op.drop_index('ix_syllabuses_section_id', table_name='syllabuses')
    op.drop_column('syllabuses', 'section_id')
