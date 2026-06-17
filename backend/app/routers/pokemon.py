from fastapi import APIRouter, HTTPException, Query

from app.core.deps import DB
from app.schemas.pokemon_resolved import (
    FormsResponse,
    PokemonResolvedResponse,
    VarietiesResponse,
)
from app.services.pokemon_resolver import pokemon_resolver_service

router = APIRouter(prefix="/pokemon", tags=["pokemon"])

# IMPORTANT: literal-segment routes must be declared before the parameterised
# /{name_or_id}/resolved route so FastAPI doesn't swallow "varieties" or "forms"
# as the name_or_id param value.


@router.get("/varieties/{name_or_id}", response_model=VarietiesResponse)
async def get_pokemon_varieties(
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
    return await pokemon_resolver_service.resolve_varieties(name_or_id, gen, db)


@router.get("/forms/{name_or_id}", response_model=FormsResponse)
async def get_pokemon_forms(
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
    return await pokemon_resolver_service.resolve_forms(name_or_id, gen, db)


@router.get("/{name_or_id}/resolved", response_model=PokemonResolvedResponse)
async def get_resolved_pokemon(
    name_or_id: str,
    db: DB,
    gen: int = 9,
    includes: list[str] = Query(default=[]),
) -> PokemonResolvedResponse:
    """
    Aggregate PokéAPI + Showdown + Smogon data for a single Pokémon.
    Results are cached in PostgreSQL for 7 days.

    - **name_or_id**: PokéAPI pokemon name ("charizard", "charizard-mega-x") or
      numeric ID (6, 10034). Form variants have their own names and IDs.
    - **gen**: Generation to resolve for (1–9, default 9).
      Types and base stats reflect gen-accurate values from Showdown's
      historical data (e.g. Clefairy is Normal-type in gen ≤ 5).
    - **includes**: Comma-separated list of fields to expand.
      - `varieties` — embed types, base_stats, abilities, sprite_urls per variety
      - `forms` — embed sprite_urls per cosmetic form
      Default (omitted): slim entries with name + id only; no extra API calls.

    `smogon_analyses` is null while the background format preload is in
    progress (typically < 15 s after cold start) or when the Pokémon has
    no data in any loaded competitive format.
    """
    if not 1 <= gen <= 9:
        raise HTTPException(status_code=400, detail="gen must be between 1 and 9")
    pokemon_id = await pokemon_resolver_service._resolve_name_or_id(name_or_id)
    normalised = []
    for item in includes:
        normalised.extend(i.strip() for i in item.split(",") if i.strip())
    return await pokemon_resolver_service.resolve(pokemon_id, gen, normalised, db)
