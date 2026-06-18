from datetime import datetime

from sqlalchemy import DateTime, Integer, SmallInteger, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class PokemonResolved(Base):
    __tablename__ = "pokemon_resolved"

    pokemon_id: Mapped[int] = mapped_column(Integer, primary_key=True)
    gen: Mapped[int] = mapped_column(SmallInteger, primary_key=True, default=9)
    data: Mapped[dict] = mapped_column(JSONB(astext_type=Text()))
    resolved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ttl_days: Mapped[int] = mapped_column(Integer, default=7)
