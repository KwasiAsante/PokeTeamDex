from fastapi import APIRouter, HTTPException, Query, Request

from app.core.deps import DB
from app.schemas.pokemon_resolved import (
    FlavorTextResponse,
    FormsResponse,
    MovesResponse,
    PokemonResolvedResponse,
    SmogonResponse,
    VarietiesResponse,
)
from app.services.pokemon_resolver import pokemon_resolver_service

router = APIRouter(prefix="/pokemon", tags=["pokemon"])

# IMPORTANT: literal-segment routes must be declared before the parameterised
# /{name_or_id}/resolved route so FastAPI doesn't swallow "varieties", "forms",
# or "smogon" as the name_or_id param value.


def _base_url(request: Request) -> str:
    """Return the scheme+host base URL with no trailing slash.
    e.g. http://localhost:8000 or https://poketeamdex.duckdns.org
    """
    return str(request.base_url).rstrip("/")


@router.get("/varieties/{name_or_id}", response_model=VarietiesResponse)
async def get_pokemon_varieties(
    request: Request,
    name_or_id: str,
    db: DB,
    gen: int = 9,
) -> VarietiesResponse:
    """
    Return all non-default varieties for a Pokémon species with full data.

    Varieties are distinct Pokémon with their own stats, types, and abilities
    (Mega evolutions, regional forms, Gigantamax, battle-state forms).

    - **name_or_id**: Base Pokémon name ("charizard") or numeric ID (6).
    - **gen**: Generation to resolve for (1–9, default 9).

    Always returns fully expanded variety data (types, base_stats, abilities,
    sprite_urls). Results are cached alongside the full resolved data.
    """
    if not 1 <= gen <= 9:
        raise HTTPException(status_code=400, detail="gen must be between 1 and 9")
    return await pokemon_resolver_service.resolve_varieties(name_or_id, gen, db, _base_url(request))


@router.get("/forms/{name_or_id}", response_model=FormsResponse)
async def get_pokemon_forms(
    request: Request,
    name_or_id: str,
    db: DB,
    gen: int = 9,
) -> FormsResponse:
    """
    Return all cosmetic form-entries for a Pokémon with full sprite data.

    Forms are visual-only variants that share types, stats, and abilities with
    the base (Unown letters, Shellos East/West, Burmy cloaks, Alcremie decorations).

    - **name_or_id**: Base Pokémon name ("unown") or numeric ID (201).
    - **gen**: Generation to resolve for (1–9, default 9).

    Always returns fully expanded form data (sprite_urls for each form).
    Results are cached alongside the full resolved data.
    """
    if not 1 <= gen <= 9:
        raise HTTPException(status_code=400, detail="gen must be between 1 and 9")
    return await pokemon_resolver_service.resolve_forms(name_or_id, gen, db, _base_url(request))


@router.get("/smogon/{name_or_id}", response_model=SmogonResponse)
async def get_pokemon_smogon(
    request: Request,
    name_or_id: str,
    db: DB,
    gen: int | None = None,
) -> SmogonResponse:
    """
    Return Smogon competitive analyses for a Pokémon.

    - **name_or_id**: Pokémon name ("venusaur") or numeric ID (3).
    - **gen**: When omitted, returns all formats across every generation.
      When specified (1–9), returns only formats for that generation
      (e.g. gen=5 returns gen5ou, gen5uu, gen5ubers, etc.).

    `smogon_analyses` is null while the background format preload is in
    progress (~15 s after cold start).
    """
    if gen is not None and not 1 <= gen <= 9:
        raise HTTPException(status_code=400, detail="gen must be between 1 and 9")
    return await pokemon_resolver_service.resolve_smogon(name_or_id, gen, db, _base_url(request))


@router.get("/moves/{name_or_id}", response_model=MovesResponse)
async def get_pokemon_moves(
    request: Request,
    name_or_id: str,
    db: DB,
) -> MovesResponse:
    """
    Return the full moves list for a Pokémon (all version groups).
    Served from PostgreSQL cache when available; triggers a full resolve on miss.
    """
    return await pokemon_resolver_service.resolve_moves(
        name_or_id, db, _base_url(request)
    )


@router.get("/flavor-text/{name_or_id}", response_model=FlavorTextResponse)
async def get_pokemon_flavor_text(
    request: Request,
    name_or_id: str,
    db: DB,
    lang: str | None = None,
) -> FlavorTextResponse:
    """
    Return Pokédex flavor text entries for a Pokémon.
    - **lang**: Optional language code (e.g. "en"). Omit for all languages.
    Served from PostgreSQL cache when available.
    """
    return await pokemon_resolver_service.resolve_flavor_text(
        name_or_id, lang, db, _base_url(request)
    )


@router.get("/{name_or_id}/resolved", response_model=PokemonResolvedResponse)
async def get_resolved_pokemon(
    request: Request,
    name_or_id: str,
    db: DB,
    gen: int | None = None,
    includes: list[str] = Query(default=[]),
) -> PokemonResolvedResponse:
    """
    Aggregate PokéAPI + Showdown + Smogon data for a single Pokémon.
    Results are cached in PostgreSQL for 7 days.

    - **name_or_id**: PokéAPI pokemon name ("charizard", "charizard-mega-x") or
      numeric ID (6, 10034). Form variants have their own names and IDs.
    - **gen**: Generation to resolve for (1–9). When omitted, types and base stats
      use gen 9 accuracy and game_front uses the plain PokéAPI front sprite
      (sprites/pokemon/{id}.png) rather than a versioned game directory.
    - **includes**: Comma-separated list of fields to expand.
      - `varieties` — embed types, base_stats, abilities, sprite_urls per variety
      - `forms` — embed sprite_urls per cosmetic form
      - `smogon` — embed full competitive sets (moves, EVs, items, etc.)
      Default (omitted): slim entries; no extra API calls.

    Navigation URLs (`smogon_url`, `varieties_url`, `forms_url`) are absolute
    so the client can follow them directly without constructing paths.
    """
    if gen is not None and not 1 <= gen <= 9:
        raise HTTPException(status_code=400, detail="gen must be between 1 and 9")
    pokemon_id = await pokemon_resolver_service._resolve_name_or_id(name_or_id)
    normalised = []
    for item in includes:
        normalised.extend(i.strip() for i in item.split(",") if i.strip())
    return await pokemon_resolver_service.resolve(pokemon_id, gen, normalised, db, _base_url(request))
