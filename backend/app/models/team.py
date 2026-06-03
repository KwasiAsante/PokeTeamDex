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
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")

    team: Mapped[Team] = relationship("Team", back_populates="slots")
    instance: Mapped["PokemonInstance | None"] = relationship("PokemonInstance", back_populates="slots")
