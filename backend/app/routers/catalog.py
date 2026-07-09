from typing import Annotated, Literal

from fastapi import APIRouter, Path, Query

from app.schemas.catalog import (
    AbilitiesListResponse,
    AbilityEntry,
    ItemEntry,
    ItemsListResponse,
    MoveEntry,
    MovesListResponse,
)
from app.services.catalog_service import catalog_service

router = APIRouter(tags=["catalog"])

_Page = Annotated[int, Query(ge=1, description="1-indexed page number.")]
_PageSize = Annotated[int, Query(ge=1, le=1000, description="Results per page (max 1000).")]
_Gen = Annotated[int | None, Query(ge=1, le=9, description="Filter to a generation (1–9).")]


@router.get("/moves", response_model=MovesListResponse, summary="List moves")
async def list_moves(
    page: _Page = 1,
    page_size: _PageSize = 50,
    gen: _Gen = None,
    damage_class: Literal["physical", "special", "status", "varies"] | None = None,
    contest_type: str | None = Query(default=None, description="e.g. 'cool', 'tough' (PokéAPI contest-type name)."),
    is_z_move: bool | None = None,
    is_max_move: bool | None = None,
) -> MovesListResponse:
    """
    Paginated move catalog. Enumerated from PokéAPI (~900 moves), enriched with
    Pokémon Showdown battle data. PS-only entries (Z-moves, Max moves) with no
    PokéAPI page are appended. Returns `503` briefly after a cold start while the
    background preload is running. `contest_type` and `target` may be null for
    PS-only entries.
    """
    return catalog_service.list_moves(
        page, page_size, gen=gen, damage_class=damage_class, contest_type=contest_type,
        is_z_move=is_z_move, is_max_move=is_max_move,
    )


@router.get("/moves/{id_or_name}", response_model=MoveEntry, summary="Get a move")
async def get_move(
    id_or_name: Annotated[str, Path(description="Move name (e.g. 'thunderbolt') or PokéAPI numeric id.")],
) -> MoveEntry:
    """
    Single move, consolidated from PokéAPI + Pokémon Showdown.

    Always available immediately — falls back to a live PokéAPI fetch when the
    move isn't in the (possibly still-loading) in-memory catalog yet.
    """
    return await catalog_service.get_move(id_or_name)


@router.get("/items", response_model=ItemsListResponse, summary="List items")
async def list_items(
    page: _Page = 1,
    page_size: _PageSize = 50,
    gen: _Gen = None,
    category: str | None = Query(default=None, description="PokéAPI item-category name (e.g. 'mega-stones')."),
    is_mega_stone: bool | None = None,
    is_z_crystal: bool | None = None,
    is_berry: bool | None = None,
    is_plate: bool | None = None,
    is_memory: bool | None = None,
) -> ItemsListResponse:
    """
    Paginated item catalog. Enumerated from PokéAPI (~2100 items including key
    items, mail, medicine, etc.), enriched with Pokémon Showdown data where
    available. Returns `503` briefly after a cold start while the background
    preload is running.
    """
    return catalog_service.list_items(
        page, page_size, gen=gen, category=category,
        is_mega_stone=is_mega_stone, is_z_crystal=is_z_crystal,
        is_berry=is_berry, is_plate=is_plate, is_memory=is_memory,
    )


@router.get("/items/{id_or_name}", response_model=ItemEntry, summary="Get an item")
async def get_item(
    id_or_name: Annotated[str, Path(description="Item name (e.g. 'leftovers') or PokéAPI numeric id.")],
) -> ItemEntry:
    """
    Single item, consolidated from PokéAPI + Pokémon Showdown.

    Always available immediately — falls back to a live PokéAPI fetch when the
    item isn't in the (possibly still-loading) in-memory catalog yet.
    """
    return await catalog_service.get_item(id_or_name)


@router.get("/abilities", response_model=AbilitiesListResponse, summary="List abilities")
async def list_abilities(
    page: _Page = 1,
    page_size: _PageSize = 50,
    gen: _Gen = None,
    pokemon: str | None = Query(
        default=None,
        description=(
            "Pokémon name or Pokédex species number — when given, ignores gen/pagination "
            "and returns that Pokémon's full ability list (slot 1, 2, or 3=hidden per entry) "
            "instead of the paginated catalog."
        ),
    ),
) -> AbilitiesListResponse:
    """
    Paginated ability catalog. Enumerated from PokéAPI (~300 abilities), enriched
    with Pokémon Showdown data. With `pokemon`: returns that species' 2–3 abilities
    directly (no pagination, `gen` ignored) with `slot`/`is_hidden` per entry.
    Without `pokemon`: paginated full catalog. Returns `503` briefly after a cold
    start while the background preload is running.
    """
    return catalog_service.list_abilities(page, page_size, gen=gen, pokemon=pokemon)


@router.get("/abilities/{id_or_name}", response_model=AbilityEntry, summary="Get an ability")
async def get_ability(
    id_or_name: Annotated[str, Path(description="Ability name (e.g. 'intimidate') or PokéAPI numeric id.")],
) -> AbilityEntry:
    """
    Single ability, consolidated from PokéAPI + Pokémon Showdown.

    Always available immediately — falls back to a live PokéAPI fetch when the
    ability isn't in the (possibly still-loading) in-memory catalog yet.
    """
    return await catalog_service.get_ability(id_or_name)
