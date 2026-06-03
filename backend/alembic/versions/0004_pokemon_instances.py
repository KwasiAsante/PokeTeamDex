"""add pokemon_instances table and instance_id on team_slots

Revision ID: 0004
Revises: 0003
Create Date: 2026-06-03

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "pokemon_instances",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("pokemon_id", sa.Integer(), nullable=False),
        sa.Column("parent_instance_id", sa.Integer(), sa.ForeignKey("pokemon_instances.id", ondelete="SET NULL"), nullable=True, index=True),
        sa.Column("nickname_aliases", sa.Text(), nullable=True),
        sa.Column("inherited_ribbons", sa.Text(), nullable=True),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), onupdate=sa.func.now()),
    )
    op.add_column(
        "team_slots",
        sa.Column(
            "instance_id",
            sa.Integer(),
            sa.ForeignKey("pokemon_instances.id", ondelete="SET NULL"),
            nullable=True,
            index=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("team_slots", "instance_id")
    op.drop_table("pokemon_instances")
