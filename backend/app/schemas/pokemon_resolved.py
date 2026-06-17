from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, BeforeValidator


def _coerce_to_list(v: object) -> object:
    """Smogon sometimes sends a bare string where a list is expected (e.g.
    teratypes: "Fire" instead of ["Fire"]).  Wrap it so Pydantic validation
    passes without raising."""
    if isinstance(v, str):
        return [v]
    return v


_StrOrList = Annotated[list[str] | None, BeforeValidator(_coerce_to_list)]


class EventMove(BaseModel):
    """A move the Pokémon can learn only via an in-game event/distribution.
    PokéAPI has no record of these; they are sourced from Showdown's learnsets."""

    name: str
    display_name: str
    generations: list[int]


class SmogonSet(BaseModel):
    """One competitive set from Smogon (pkmn.github.io/smogon).

    Arrays in moves/ability/item/nature/evs represent slash options
    (e.g. ["Calm Mind", ["Moonblast", "Flamethrower"]] means the set
    can run Moonblast OR Flamethrower in that slot).
    """

    moves: list[str | list[str]]
    ability: str | list[str] | None = None
    item: str | list[str] | None = None
    nature: str | list[str] | None = None
    evs: dict[str, int] | list[dict[str, int]] | None = None
    ivs: dict[str, int] | None = None
    teratypes: _StrOrList = None
    level: int | list[int] | None = None
    description: str | None = None


class SmogonFormatData(BaseModel):
    format_id: str
    sets: dict[str, SmogonSet]


class SpriteUrls(BaseModel):
    official_artwork: str | None = None
    official_artwork_shiny: str | None = None
    home: str | None = None
    home_shiny: str | None = None
    home_female: str | None = None
    battle_front: str | None = None
    battle_front_shiny: str | None = None


class PokemonResolvedResponse(BaseModel):
    """Aggregated Pokémon data from PokéAPI + Showdown event learnsets + Smogon.

    `gen` reflects the generation the data was resolved for.
    `types` and `base_stats` are gen-accurate (e.g. Clefairy is Normal in gen ≤ 5).
    `event_moves` supplements PokéAPI's move list with event-only distributions.
    `smogon_analyses` is null while the background load is in progress or when
    no Smogon data exists for this Pokémon.
    """

    pokemon_id: int
    gen: int
    name: str
    types: list[str]
    base_stats: dict[str, int]
    abilities: dict[str, str]
    event_moves: list[EventMove]
    smogon_analyses: list[SmogonFormatData] | None
    forms: list[str]
    sprite_urls: SpriteUrls
    resolved_at: datetime
