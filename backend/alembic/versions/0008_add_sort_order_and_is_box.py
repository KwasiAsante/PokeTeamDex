"""add sort_order to team_folders and teams, is_box to teams

Revision ID: 0008
Revises: 0007
Create Date: 2026-06-09

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0008"
down_revision: Union[str, None] = "0007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("team_folders", sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("teams", sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"))
    op.add_column("teams", sa.Column("is_box", sa.Boolean(), nullable=False, server_default="false"))


def downgrade() -> None:
    op.drop_column("team_folders", "sort_order")
    op.drop_column("teams", "sort_order")
    op.drop_column("teams", "is_box")
