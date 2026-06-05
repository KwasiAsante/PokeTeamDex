"""add format_label to teams

Revision ID: 0006
Revises: 0005
Create Date: 2026-06-05

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0006"
down_revision: Union[str, None] = "0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("teams", sa.Column("format_label", sa.String(100), nullable=True))


def downgrade() -> None:
    op.drop_column("teams", "format_label")
