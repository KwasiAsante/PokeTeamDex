"""expand team_slots with full slot config fields

Revision ID: 0005
Revises: 0004
Create Date: 2026-06-03

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("team_slots", sa.Column("form_name", sa.String(100), nullable=True))
    op.add_column("team_slots", sa.Column("level", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("gender", sa.String(10), nullable=True))
    op.add_column("team_slots", sa.Column("is_shiny", sa.Boolean(), nullable=False, server_default="false"))
    op.add_column("team_slots", sa.Column("friendship", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("ability_name", sa.String(100), nullable=True))
    op.add_column("team_slots", sa.Column("nature_name", sa.String(50), nullable=True))
    op.add_column("team_slots", sa.Column("held_item_name", sa.String(100), nullable=True))
    op.add_column("team_slots", sa.Column("move1", sa.String(100), nullable=True))
    op.add_column("team_slots", sa.Column("move2", sa.String(100), nullable=True))
    op.add_column("team_slots", sa.Column("move3", sa.String(100), nullable=True))
    op.add_column("team_slots", sa.Column("move4", sa.String(100), nullable=True))
    op.add_column("team_slots", sa.Column("ev_hp",  sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("ev_atk", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("ev_def", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("ev_spa", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("ev_spd", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("ev_spe", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("iv_hp",  sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("iv_atk", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("iv_def", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("iv_spa", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("iv_spd", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("iv_spe", sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("ribbons", sa.Text(), nullable=True))
    op.add_column("team_slots", sa.Column("is_mega_evolved",    sa.Boolean(), nullable=False, server_default="false"))
    op.add_column("team_slots", sa.Column("has_gigantamax",     sa.Boolean(), nullable=False, server_default="false"))
    op.add_column("team_slots", sa.Column("gigantamax_enabled", sa.Boolean(), nullable=False, server_default="false"))
    op.add_column("team_slots", sa.Column("is_alpha",           sa.Boolean(), nullable=False, server_default="false"))
    op.add_column("team_slots", sa.Column("contest_cool",       sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("contest_beautiful",  sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("contest_cute",       sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("contest_clever",     sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("contest_tough",      sa.SmallInteger(), nullable=True))
    op.add_column("team_slots", sa.Column("contest_sheen",      sa.SmallInteger(), nullable=True))


def downgrade() -> None:
    for col in [
        "form_name", "level", "gender", "is_shiny", "friendship",
        "ability_name", "nature_name", "held_item_name",
        "move1", "move2", "move3", "move4",
        "ev_hp", "ev_atk", "ev_def", "ev_spa", "ev_spd", "ev_spe",
        "iv_hp", "iv_atk", "iv_def", "iv_spa", "iv_spd", "iv_spe",
        "ribbons",
        "is_mega_evolved", "has_gigantamax", "gigantamax_enabled", "is_alpha",
        "contest_cool", "contest_beautiful", "contest_cute",
        "contest_clever", "contest_tough", "contest_sheen",
    ]:
        op.drop_column("team_slots", col)
