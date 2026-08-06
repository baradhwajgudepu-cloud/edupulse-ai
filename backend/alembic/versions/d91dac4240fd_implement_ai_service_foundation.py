"""implement ai service foundation

Revision ID: d91dac4240fd
Revises: 1f1c5c19e22d
Create Date: 2026-08-02 15:09:22.592878

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd91dac4240fd'
down_revision: Union[str, None] = '1f1c5c19e22d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Seed default AI assistant permission
    import uuid
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc)
    permissions_data = [
        {"id": uuid.uuid4(), "name": "Use AI Assistant", "code": "ai.use", "description": "Allows executing queries using the AI Service foundation", "created_at": now, "updated_at": now},
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


def downgrade() -> None:
    op.execute("DELETE FROM permissions WHERE code = 'ai.use';")
