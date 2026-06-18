"""add pokemon_resolved cache table

Revision ID: 0009
Revises: 0008
Create Date: 2026-06-17

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0009"
down_revision: Union[str, None] = "0008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "pokemon_resolved",
        sa.Column("pokemon_id", sa.Integer(), nullable=False),
        sa.Column("gen", sa.SmallInteger(), nullable=False, server_default="9"),
        sa.Column("data", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column(
            "resolved_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column("ttl_days", sa.Integer(), nullable=False, server_default="7"),
        sa.PrimaryKeyConstraint("pokemon_id", "gen"),
    )


def downgrade() -> None:
    op.drop_table("pokemon_resolved")
