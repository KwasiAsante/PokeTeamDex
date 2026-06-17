from fastapi import APIRouter, HTTPException, Query

from app.core.deps import DB
from app.schemas.pokemon_resolved import PokemonResolvedResponse
from app.services.pokemon_resolver import pokemon_resolver_service

router = APIRouter(prefix="/pokemon", tags=["pokemon"])


@router.get("/{pokemon_id}/resolved", response_model=PokemonResolvedResponse)
async def get_resolved_pokemon(
    pokemon_id: int,
    db: DB,
    gen: int = 9,
    includes: list[str] = Query(default=[]),
) -> PokemonResolvedResponse:
    """
    Aggregate PokéAPI + Showdown + Smogon data for a single Pokémon.
    Results are cached in PostgreSQL for 7 days.

    - **pokemon_id**: PokéAPI pokemon ID (not species ID).
      Form variants have their own IDs (e.g. Rotom-Wash = 10009).
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
    if pokemon_id < 1:
        raise HTTPException(status_code=400, detail="pokemon_id must be a positive integer")
    if not 1 <= gen <= 9:
        raise HTTPException(status_code=400, detail="gen must be between 1 and 9")
    # Normalise includes (accept both "varieties,forms" and separate params)
    normalised = []
    for item in includes:
        normalised.extend(i.strip() for i in item.split(",") if i.strip())
    return await pokemon_resolver_service.resolve(pokemon_id, gen, normalised, db)
