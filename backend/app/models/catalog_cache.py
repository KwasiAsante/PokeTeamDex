from datetime import datetime

from sqlalchemy import DateTime, Integer, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CatalogCache(Base):
    __tablename__ = "catalog_cache"

    kind: Mapped[str] = mapped_column(Text, primary_key=True)           # 'move' | 'item' | 'ability'
    name: Mapped[str] = mapped_column(Text, primary_key=True)           # PokéAPI slug
    pokeapi_id: Mapped[int | None] = mapped_column(Integer, nullable=True)  # for *_by_id maps
    data: Mapped[dict] = mapped_column(JSONB(astext_type=Text()))
    fetched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ttl_days: Mapped[int] = mapped_column(Integer, default=7)
