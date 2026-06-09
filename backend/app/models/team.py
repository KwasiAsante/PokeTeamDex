from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, SmallInteger, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class PokemonInstance(Base):
    __tablename__ = "pokemon_instances"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    pokemon_id: Mapped[int] = mapped_column(Integer)
    parent_instance_id: Mapped[int | None] = mapped_column(
        ForeignKey("pokemon_instances.id", ondelete="SET NULL"), nullable=True, index=True
    )
    nickname_aliases: Mapped[str | None] = mapped_column(Text, nullable=True)
    inherited_ribbons: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    slots: Mapped[list["TeamSlot"]] = relationship("TeamSlot", back_populates="instance")


class TeamFolder(Base):
    __tablename__ = "team_folders"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(100))
    sort_order: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")

    user: Mapped["User"] = relationship("User", back_populates="folders")  # noqa: F821
    teams: Mapped[list["Team"]] = relationship(
        "Team", back_populates="folder", cascade="all, delete-orphan"
    )


class Team(Base):
    __tablename__ = "teams"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    folder_id: Mapped[int | None] = mapped_column(
        ForeignKey("team_folders.id", ondelete="SET NULL"), index=True, nullable=True
    )
    name: Mapped[str] = mapped_column(String(100))
    format_label: Mapped[str | None] = mapped_column(String(100), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    is_box: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")

    folder: Mapped[TeamFolder | None] = relationship("TeamFolder", back_populates="teams")
    slots: Mapped[list["TeamSlot"]] = relationship(
        "TeamSlot", back_populates="team", cascade="all, delete-orphan"
    )


class TeamSlot(Base):
    __tablename__ = "team_slots"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    team_id: Mapped[int] = mapped_column(
        ForeignKey("teams.id", ondelete="CASCADE"), index=True
    )
    slot: Mapped[int] = mapped_column(SmallInteger)  # 1–6
    pokemon_id: Mapped[int] = mapped_column(Integer)
    nickname: Mapped[str | None] = mapped_column(String(50), nullable=True)
    instance_id: Mapped[int | None] = mapped_column(
        ForeignKey("pokemon_instances.id", ondelete="SET NULL"), nullable=True, index=True
    )

    # Form / variant
    form_name: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # Basics
    level: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    gender: Mapped[str | None] = mapped_column(String(10), nullable=True)
    is_shiny: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    friendship: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)

    # Build
    ability_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    nature_name: Mapped[str | None] = mapped_column(String(50), nullable=True)
    held_item_name: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # Moves
    move1: Mapped[str | None] = mapped_column(String(100), nullable=True)
    move2: Mapped[str | None] = mapped_column(String(100), nullable=True)
    move3: Mapped[str | None] = mapped_column(String(100), nullable=True)
    move4: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # EVs
    ev_hp:  Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    ev_atk: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    ev_def: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    ev_spa: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    ev_spd: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    ev_spe: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)

    # IVs
    iv_hp:  Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    iv_atk: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    iv_def: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    iv_spa: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    iv_spd: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    iv_spe: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)

    # Ribbons (JSON array of ribbon IDs)
    ribbons: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Mega / Gigantamax / Alpha
    is_mega_evolved:    Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    has_gigantamax:     Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    gigantamax_enabled: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    is_alpha:           Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")

    # Tera Type (Gen 9 / No Format)
    tera_type: Mapped[str | None] = mapped_column(String(20), nullable=True)

    # Contest conditions
    contest_cool:      Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    contest_beautiful: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    contest_cute:      Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    contest_clever:    Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    contest_tough:     Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    contest_sheen:     Mapped[int | None] = mapped_column(SmallInteger, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")

    team: Mapped[Team] = relationship("Team", back_populates="slots")
    instance: Mapped["PokemonInstance | None"] = relationship("PokemonInstance", back_populates="slots")
