"""make folder_id nullable, add user_id to teams

Revision ID: 0002
Revises: 0001
Create Date: 2026-05-29

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add user_id to teams
    op.add_column(
        "teams",
        sa.Column("user_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_teams_user_id", "teams", "users", ["user_id"], ["id"], ondelete="CASCADE"
    )
    op.create_index("ix_teams_user_id", "teams", ["user_id"])

    # Make folder_id nullable and change ondelete to SET NULL
    op.alter_column("teams", "folder_id", existing_type=sa.Integer(), nullable=True)
    op.drop_constraint("teams_folder_id_fkey", "teams", type_="foreignkey")
    op.create_foreign_key(
        "fk_teams_folder_id", "teams", "team_folders", ["folder_id"], ["id"], ondelete="SET NULL"
    )


def downgrade() -> None:
    op.drop_constraint("fk_teams_folder_id", "teams", type_="foreignkey")
    op.create_foreign_key(
        "teams_folder_id_fkey", "teams", "team_folders", ["folder_id"], ["id"], ondelete="CASCADE"
    )
    op.alter_column("teams", "folder_id", existing_type=sa.Integer(), nullable=False)
    op.drop_index("ix_teams_user_id", "teams")
    op.drop_constraint("fk_teams_user_id", "teams", type_="foreignkey")
    op.drop_column("teams", "user_id")
