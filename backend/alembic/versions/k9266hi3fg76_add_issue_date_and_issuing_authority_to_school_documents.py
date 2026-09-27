"""add_issue_date_and_issuing_authority_to_school_documents

Revision ID: k9266hi3fg76
Revises: i8155gh2ef65, j8155gh2ef65
Create Date: 2026-09-27 07:38:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'k9266hi3fg76'
down_revision: Union[str, Sequence[str], None] = ('i8155gh2ef65', 'j8155gh2ef65')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    
    # 1. Safely add issue_date to school_documents
    res_issue_date = conn.execute(
        sa.text("SELECT column_name FROM information_schema.columns WHERE table_name = 'school_documents' AND column_name = 'issue_date'")
    ).fetchone()
    if not res_issue_date:
        op.add_column('school_documents', sa.Column('issue_date', sa.Date(), nullable=True))
        
    # 2. Safely add issuing_authority to school_documents
    res_authority = conn.execute(
        sa.text("SELECT column_name FROM information_schema.columns WHERE table_name = 'school_documents' AND column_name = 'issuing_authority'")
    ).fetchone()
    if not res_authority:
        op.add_column('school_documents', sa.Column('issuing_authority', sa.String(255), nullable=True))


def downgrade() -> None:
    op.drop_column('school_documents', 'issuing_authority')
    op.drop_column('school_documents', 'issue_date')