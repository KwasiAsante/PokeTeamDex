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


class AbilityInfo(BaseModel):
    name: str
    is_hidden: bool
    slot: int


class MoveLearnDetail(BaseModel):
    version_group: str
    method: str   # "level-up", "machine", "egg", "tutor"
    level: int    # 0 for non-level-up methods


class MoveSummary(BaseModel):
    name: str
    learn_details: list[MoveLearnDetail]


class FlavorTextEntry(BaseModel):
    text: str
    language: str
    version: str


class MovesResponse(BaseModel):
    pokemon_id: int
    name: str
    moves: list[MoveSummary]


class FlavorTextResponse(BaseModel):
    pokemon_id: int
    name: str
    flavor_text_entries: list[FlavorTextEntry]


class EventMove(BaseModel):
    """A move absent from PokéAPI's learnset that Showdown's data supplies.

    Covers event distributions (S), but also egg moves (E) and tutor moves (T)
    that PokéAPI is missing for older generations.
    """

    name: str
    display_name: str
    generations: list[int]
    methods: list[str]  # e.g. ["event"], ["egg"], ["tutor"], ["level", "event"]


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
    """One competitive format's data from Smogon.

    Slim (default / no includes=smogon): format_id only — no sets.
    Full (?includes[]=smogon or /pokemon/smogon/{id}): sets populated.
    """

    format_id: str
    sets: dict[str, SmogonSet] | None = None  # None in slim response


class SpriteUrls(BaseModel):
    """Slim sprite set — returned in the base pokemon response always."""

    official_artwork: str | None = None
    home: str | None = None


class SpriteUrlsFull(BaseModel):
    """Full sprite set — returned for varieties/forms when included,
    and always for the base pokemon."""

    official_artwork: str | None = None
    official_artwork_shiny: str | None = None
    home: str | None = None
    home_shiny: str | None = None
    home_female: str | None = None
    home_female_shiny: str | None = None
    game_front: str | None = None
    game_front_shiny: str | None = None
    game_front_female: str | None = None
    game_front_female_shiny: str | None = None


class VarietyData(BaseModel):
    """A species variant with its own /pokemon resource (Mega, regional, Gmax, etc.).

    Slim (default): name, pokemon_id, is_default, resolved_url.
    Full (?includes[]=varieties): adds types, base_stats, abilities, sprite_urls.

    resolved_url is always present — it points to the variety's own resolved
    endpoint so the client can fetch full data without knowing the numeric ID.
    """

    name: str
    pokemon_id: int
    is_default: bool
    resolved_url: str | None = None  # /pokemon/{pokemon_id}/resolved (None in stale cached rows)
    types: list[str] | None = None
    base_stats: dict[str, int] | None = None
    abilities: dict[str, str] | None = None
    sprite_urls: SpriteUrlsFull | None = None


class FormData(BaseModel):
    """A cosmetic form-entry variant — no separate /pokemon resource.
    Same types/stats/abilities as the base; only sprites differ.

    Slim (default): name + front_sprite_url (constructed without an API call).
    Full (?includes[]=forms): adds the complete sprite_urls set.

    front_sprite_url is always present so the client can render a form chip
    without requesting the full forms endpoint.
    """

    name: str
    form_id: int | None = None
    is_default: bool = False
    front_sprite_url: str | None = None  # always set from sprites.front_default
    sprite_urls: SpriteUrlsFull | None = None


class SmogonResponse(BaseModel):
    """Full Smogon analyses for a single Pokémon, across all loaded formats.

    gen is null when no generation filter was applied (all formats returned).
    """

    pokemon_id: int
    gen: int | None  # null = all generations; int = filtered to that gen
    name: str
    smogon_analyses: list[SmogonFormatData] | None  # null while background load runs


class VarietiesResponse(BaseModel):
    """All non-default varieties of a base Pokémon species, always fully expanded."""

    pokemon_id: int
    gen: int
    name: str
    varieties: list[VarietyData]


class FormsResponse(BaseModel):
    """All cosmetic form-entries of a base Pokémon, always fully expanded with sprites."""

    pokemon_id: int
    gen: int
    name: str
    forms: list[FormData]


class PokemonResolvedResponse(BaseModel):
    """Aggregated Pokémon data from PokéAPI + Showdown + Smogon.

    `gen` reflects the generation the data was resolved for.
    `types` and `base_stats` are gen-accurate (e.g. Clefairy is Normal in gen ≤ 5).
    `supplement_moves` fills PokéAPI gaps: event distributions, plus egg/tutor moves
    missing for older gens.
    `smogon_analyses` is null while the background load is in progress or when
    no Smogon data exists for this Pokémon.
    `varieties` and `forms` are slim by default; use ?includes[]=varieties,forms
    for full embedded data.
    """

    pokemon_id: int
    gen: int
    name: str
    # pokemon detail
    types: list[str]
    base_stats: dict[str, int]
    abilities: list[AbilityInfo]          # changed from dict[str, str]
    height: int = 0
    weight: int = 0
    base_experience: int | None = None
    species_name: str | None = None
    form_names: list[str] = []            # derived from forms[].name for convenience
    moves: list[MoveSummary] = []         # slim: []; full via ?includes[]=moves
    moves_url: str | None = None
    supplement_moves: list[EventMove]
    smogon_analyses: list[SmogonFormatData] | None
    smogon_url: str | None = None
    varieties: list[VarietyData]
    varieties_url: str | None = None
    forms: list[FormData]
    forms_url: str | None = None
    sprite_urls: SpriteUrlsFull
    resolved_at: datetime
    # species detail
    genus: str | None = None
    generation_name: str = "generation-ix"
    gender_rate: int | None = None
    capture_rate: int | None = None
    base_happiness: int | None = None
    hatch_counter: int | None = None
    growth_rate: str | None = None
    egg_groups: list[str] = []
    flavor_text_entries: list[FlavorTextEntry] = []  # slim: []; full via ?includes[]=flavor
    flavor_text_url: str | None = None
    is_baby: bool = False
    is_legendary: bool = False
    is_mythical: bool = False
    evolution_chain_id: int | None = None
