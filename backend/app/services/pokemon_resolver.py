"""
pokemon_resolver.py — Backend aggregation service for GET /pokemon/{id}/resolved.

Merges:
  - PokéAPI  (types, stats, abilities, forms, sprites)
  - Showdown event_learnsets  (event-only moves PokéAPI doesn't know about)
  - Showdown pokedex / gen-overrides  (gen-accurate types & stats)
  - Smogon pkmn.github.io  (competitive sets, fetched in background)
"""

import asyncio
import json
import logging
import os
from datetime import datetime, timezone

import httpx
from fastapi import HTTPException
from sqlalchemy import func, select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.pokemon_resolved import PokemonResolved
from app.schemas.pokemon_resolved import (
    EventMove,
    PokemonResolvedResponse,
    SmogonFormatData,
    SmogonSet,
    SpriteUrls,
)

logger = logging.getLogger(__name__)

_STATIC_DIR = os.path.join(os.path.dirname(__file__), "..", "static")

# Curated Smogon formats to pre-load at startup (background task).
# Covers all gens × major tiers; absent formats return smogon_analyses=null.
_SMOGON_FORMATS = [
    "gen1ou", "gen1ubers",
    "gen2ou", "gen2ubers", "gen2uu",
    "gen3ou", "gen3ubers", "gen3uu", "gen3nu",
    "gen4ou", "gen4ubers", "gen4uu", "gen4nu",
    "gen5ou", "gen5ubers", "gen5uu", "gen5ru", "gen5nu",
    "gen6ou", "gen6ubers", "gen6uu", "gen6ru", "gen6nu", "gen6pu",
    "gen7ou", "gen7ubers", "gen7uu", "gen7ru", "gen7nu", "gen7pu", "gen7lc",
    "gen8ou", "gen8ubers", "gen8uu", "gen8ru", "gen8nu", "gen8pu", "gen8lc",
    "gen9ou", "gen9ubers", "gen9uu", "gen9ru", "gen9nu", "gen9pu", "gen9lc",
    "gen9doublesou",
]

_SMOGON_BASE = "https://pkmn.github.io/smogon/data"
_POKEAPI_BASE = "https://pokeapi.co/api/v2"
_SHOWDOWN_SPRITES = "https://play.pokemonshowdown.com/sprites"

# National Dex number ranges → generation introduced.
_GEN_RANGES = [(151, 1), (251, 2), (386, 3), (493, 4), (649, 5),
               (721, 6), (809, 7), (905, 8), (10000, 9)]


def _num_to_gen(num: int) -> int:
    for limit, gen in _GEN_RANGES:
        if num <= limit:
            return gen
    return 9


def _ps_name(pokeapi_name: str) -> str:
    """Convert a PokéAPI pokemon name to a Showdown ID (lowercase, no hyphens)."""
    return pokeapi_name.replace("-", "").lower()


def _smogon_display_name(pokeapi_pokemon_name: str, english_species_name: str) -> str:
    """
    Derive the Smogon display name used as a key in pkmn.github.io data.

    For base species, use the English name from PokéAPI (e.g. "Venusaur").
    For form variants (pokemon.name differs from species slug), title-case each
    hyphen-separated segment (e.g. "giratina-origin" → "Giratina-Origin").
    """
    species_slug = english_species_name.lower().replace(" ", "-").replace(".", "").replace("'", "")
    if pokeapi_pokemon_name == species_slug or pokeapi_pokemon_name == species_slug.replace("-", ""):
        return english_species_name
    return "-".join(w.title() for w in pokeapi_pokemon_name.split("-"))


class PokemonResolverService:
    def __init__(self) -> None:
        self._event_learnsets: dict[str, dict] = {}
        self._moves_index: dict[str, dict] = {}
        self._ps_pokedex: dict[str, dict] = {}
        self._ps_pokedex_overrides: dict[str, dict[str, dict]] = {}
        self._smogon_sets: dict[str, dict] = {}
        self._smogon_analyses: dict[str, dict] = {}
        self._smogon_loaded = False
        # Two separate clients so the Smogon bulk preload (88 concurrent requests)
        # can never starve the per-request PokéAPI calls.
        self._pokeapi_http = httpx.AsyncClient(
            timeout=10.0, limits=httpx.Limits(max_connections=10)
        )
        self._smogon_http = httpx.AsyncClient(
            timeout=30.0, limits=httpx.Limits(max_connections=20)
        )

    # ------------------------------------------------------------------
    # Startup loading
    # ------------------------------------------------------------------

    def load_ps_data(self) -> None:
        """Load PS static files from disk into memory. Called synchronously at startup."""
        for fname, attr in [
            ("event_learnsets.json", "_event_learnsets"),
            ("moves.json", "_moves_index"),
            ("pokedex.json", "_ps_pokedex"),
        ]:
            path = os.path.join(_STATIC_DIR, fname)
            if os.path.exists(path):
                with open(path, encoding="utf-8") as f:
                    setattr(self, attr, json.load(f))
                logger.info("Loaded %s (%d entries)", fname, len(getattr(self, attr)))
            else:
                logger.warning("%s not found — run scripts/sync_ps_data.py", fname)

        overrides_path = os.path.join(_STATIC_DIR, "pokedex-gen-overrides.json")
        if os.path.exists(overrides_path):
            with open(overrides_path, encoding="utf-8") as f:
                self._ps_pokedex_overrides = json.load(f)
            total = sum(len(v) for v in self._ps_pokedex_overrides.values())
            logger.info("Loaded pokedex-gen-overrides.json (%d gen override entries)", total)
        else:
            logger.warning("pokedex-gen-overrides.json not found")

    async def load_smogon_data(self) -> None:
        """Fetch Smogon sets + analyses for all curated formats. Runs as background task."""
        logger.info("Starting Smogon data preload (%d formats)…", len(_SMOGON_FORMATS))

        async def _fetch(fmt: str) -> tuple[str, dict, dict]:
            sets_url = f"{_SMOGON_BASE}/sets/{fmt}.json"
            analyses_url = f"{_SMOGON_BASE}/analyses/{fmt}.json"
            try:
                sets_r, analyses_r = await asyncio.gather(
                    self._smogon_http.get(sets_url),
                    self._smogon_http.get(analyses_url),
                    return_exceptions=True,
                )
                sets = sets_r.json() if not isinstance(sets_r, Exception) and sets_r.status_code == 200 else {}
                analyses = analyses_r.json() if not isinstance(analyses_r, Exception) and analyses_r.status_code == 200 else {}
            except Exception as exc:
                logger.warning("Failed to fetch Smogon format %s: %s", fmt, exc)
                sets, analyses = {}, {}
            return fmt, sets, analyses

        results = await asyncio.gather(*[_fetch(fmt) for fmt in _SMOGON_FORMATS])
        loaded = 0
        for fmt, sets, analyses in results:
            if sets or analyses:
                self._smogon_sets[fmt] = sets
                self._smogon_analyses[fmt] = analyses
                loaded += 1
        self._smogon_loaded = True
        logger.info("Smogon preload complete: %d/%d formats loaded", loaded, len(_SMOGON_FORMATS))

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _apply_gen_overrides(
        self,
        ps_name: str,
        base_types: list[str],
        base_stats: dict[str, int],
        base_abilities: dict[str, str],
        gen: int,
    ) -> tuple[list[str], dict[str, int], dict[str, str]]:
        """Apply gen-accurate overrides from pokedex-gen-overrides.json.

        PS stores gen mods as *deltas from the current gen*, not from the
        previous gen.  A change introduced in Gen 6 (e.g. Clefairy gaining
        Fairy) appears in the gen5 override (marking the pre-change value) but
        NOT in gen4/gen3/gen2/gen1 — because they all share the same pre-change
        value.

        To resolve gen=4 correctly we must also look at gen5's overrides when
        gen4 has no override for a given field.  Algorithm: scan upward from the
        requested gen to find the first gen that explicitly overrides each field.
        Once a field is resolved we stop scanning for that field.
        """
        types: list[str] | None = None
        stats: dict[str, int] | None = None
        abilities: dict[str, str] | None = None

        for scan_gen in range(gen, 10):
            gen_key = f"gen{scan_gen}"
            overrides = self._ps_pokedex_overrides.get(gen_key, {}).get(ps_name)
            if not overrides:
                continue
            if types is None and "types" in overrides:
                types = overrides["types"]
            if stats is None and "baseStats" in overrides:
                stats = overrides["baseStats"]
            if abilities is None and "abilities" in overrides:
                abilities = overrides["abilities"]
            if types is not None and stats is not None and abilities is not None:
                break

        return (
            types if types is not None else base_types,
            stats if stats is not None else base_stats,
            abilities if abilities is not None else base_abilities,
        )

    def _get_event_moves(
        self, ps_name: str, pokeapi_move_slugs: set[str]
    ) -> list[EventMove]:
        """Return moves only learnable via events that PokéAPI does not list."""
        entry = self._event_learnsets.get(ps_name)
        if not entry:
            return []
        learnset = entry.get("learnset", {})
        # Convert PokéAPI move slugs to Showdown IDs for comparison.
        known_ps_ids = {slug.replace("-", "") for slug in pokeapi_move_slugs}
        result: list[EventMove] = []
        for move_id, sources in learnset.items():
            if move_id in known_ps_ids:
                continue
            # Keep only moves where at least one source is an event/distribution.
            event_gens = [
                int(src[0]) for src in sources
                if len(src) >= 2 and src[0].isdigit() and src[1].upper() == "S"
            ]
            if not event_gens:
                continue
            move_info = self._moves_index.get(move_id, {})
            result.append(EventMove(
                name=move_id,
                display_name=move_info.get("name", move_id),
                generations=sorted(set(event_gens)),
            ))
        return result

    def _get_smogon_analyses(self, display_name: str) -> list[SmogonFormatData] | None:
        """Look up all loaded Smogon formats for this display name."""
        if not self._smogon_loaded:
            return None
        results: list[SmogonFormatData] = []
        for fmt_id, sets_data in self._smogon_sets.items():
            pokemon_sets = sets_data.get(display_name)
            if not pokemon_sets:
                continue
            analyses_data = self._smogon_analyses.get(fmt_id, {})
            pokemon_analyses = analyses_data.get(display_name, {})
            set_analyses = (pokemon_analyses.get("sets") or {}) if pokemon_analyses else {}
            merged_sets: dict[str, SmogonSet] = {}
            for set_name, set_data in pokemon_sets.items():
                description = set_analyses.get(set_name, {}).get("description")
                merged_sets[set_name] = SmogonSet(
                    moves=set_data.get("moves", []),
                    ability=set_data.get("ability"),
                    item=set_data.get("item"),
                    nature=set_data.get("nature"),
                    evs=set_data.get("evs"),
                    ivs=set_data.get("ivs"),
                    teratypes=set_data.get("teratypes"),
                    level=set_data.get("level"),
                    description=description,
                )
            results.append(SmogonFormatData(format_id=fmt_id, sets=merged_sets))
        return results if results else None

    @staticmethod
    def _build_sprite_urls(sprites: dict) -> SpriteUrls:
        other = sprites.get("other") or {}
        artwork = other.get("official-artwork") or {}
        home = other.get("home") or {}
        return SpriteUrls(
            official_artwork=artwork.get("front_default"),
            official_artwork_shiny=artwork.get("front_shiny"),
            home=home.get("front_default"),
            home_shiny=home.get("front_shiny"),
            home_female=home.get("front_female"),
        )

    # ------------------------------------------------------------------
    # Main resolution
    # ------------------------------------------------------------------

    async def resolve(
        self, pokemon_id: int, gen: int, db: AsyncSession
    ) -> PokemonResolvedResponse:
        # 1. Cache hit
        result = await db.execute(
            select(PokemonResolved).where(
                PokemonResolved.pokemon_id == pokemon_id,
                PokemonResolved.gen == gen,
                PokemonResolved.resolved_at
                + text("(ttl_days * interval '1 day')")
                > func.now(),
            )
        )
        row = result.scalar_one_or_none()
        if row:
            return PokemonResolvedResponse(**row.data, resolved_at=row.resolved_at)

        # 2. Fetch from PokéAPI
        try:
            pokemon_r, species_info = await self._fetch_pokeapi(pokemon_id)
        except httpx.HTTPStatusError as exc:
            if exc.response.status_code == 404:
                raise HTTPException(404, detail=f"Pokémon {pokemon_id} not found in PokéAPI")
            raise
        except httpx.TimeoutException:
            raise HTTPException(503, detail="PokéAPI is unavailable; try again later")

        # 3. Unpack PokéAPI data
        pokemon_name: str = pokemon_r["name"]
        english_species_name: str = species_info["english_name"]
        species_gen: int = species_info["gen"]

        if gen < species_gen:
            raise HTTPException(
                404,
                detail=f"{english_species_name} was not introduced until Gen {species_gen}",
            )

        raw_types = [t["type"]["name"].title() for t in pokemon_r.get("types", [])]
        raw_stats = {
            s["stat"]["name"]: s["base_stat"] for s in pokemon_r.get("stats", [])
        }
        raw_abilities = {
            str(a["slot"]): a["ability"]["name"]
            for a in pokemon_r.get("abilities", [])
        }
        move_slugs: set[str] = {m["move"]["name"] for m in pokemon_r.get("moves", [])}
        forms = [f["name"] for f in pokemon_r.get("forms", [])]
        sprites = pokemon_r.get("sprites") or {}

        # 4. Gen-aware type/stat overrides from Showdown
        ps_id = _ps_name(pokemon_name)
        ps_entry = self._ps_pokedex.get(ps_id, {})
        ps_types = ps_entry.get("types", raw_types)
        ps_stats = ps_entry.get("baseStats", raw_stats)
        ps_abilities_raw = ps_entry.get("abilities", {})
        ps_abilities = {k: v for k, v in ps_abilities_raw.items()}

        types, base_stats, abilities = self._apply_gen_overrides(
            ps_id, ps_types, ps_stats, ps_abilities, gen
        )

        # 5. Event moves gap-fill
        event_moves = self._get_event_moves(ps_id, move_slugs)

        # 6. Smogon analyses (null while loading)
        display_name = _smogon_display_name(pokemon_name, english_species_name)
        smogon_analyses = self._get_smogon_analyses(display_name)

        # 7. Sprite URLs
        sprite_urls = self._build_sprite_urls(sprites)
        # Add Showdown battle sprite (simple path; form exceptions handled Flutter-side).
        sprite_urls.battle_front = f"{_SHOWDOWN_SPRITES}/dex/{pokemon_name}.png"
        sprite_urls.battle_front_shiny = f"{_SHOWDOWN_SPRITES}/dex-shiny/{pokemon_name}.png"

        # 8. Build response
        now = datetime.now(timezone.utc)
        response = PokemonResolvedResponse(
            pokemon_id=pokemon_id,
            gen=gen,
            name=pokemon_name,
            types=types,
            base_stats=base_stats,
            abilities=abilities,
            event_moves=event_moves,
            smogon_analyses=smogon_analyses,
            forms=forms,
            sprite_urls=sprite_urls,
            resolved_at=now,
        )

        # 9. Upsert to cache
        data_dict = response.model_dump(mode="json")
        data_dict.pop("resolved_at", None)
        stmt = (
            pg_insert(PokemonResolved)
            .values(
                pokemon_id=pokemon_id,
                gen=gen,
                data=data_dict,
                resolved_at=now,
                ttl_days=7,
            )
            .on_conflict_do_update(
                index_elements=["pokemon_id", "gen"],
                set_={"data": data_dict, "resolved_at": now},
            )
        )
        await db.execute(stmt)
        await db.commit()

        return response

    async def _fetch_pokeapi(self, pokemon_id: int) -> tuple[dict, dict]:
        """Fetch /pokemon/{id} and /pokemon-species/{species_id} in parallel."""
        pokemon_r = await self._pokeapi_http.get(f"{_POKEAPI_BASE}/pokemon/{pokemon_id}")
        pokemon_r.raise_for_status()
        pokemon_data = pokemon_r.json()

        species_url: str = pokemon_data["species"]["url"]
        species_r = await self._pokeapi_http.get(species_url)
        species_r.raise_for_status()
        species_data = species_r.json()

        english_name = next(
            (n["name"] for n in species_data.get("names", []) if n["language"]["name"] == "en"),
            species_data["name"].title(),
        )
        gen_name: str = species_data.get("generation", {}).get("name", "generation-ix")
        roman = {"i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5,
                 "vi": 6, "vii": 7, "viii": 8, "ix": 9}
        gen_num = roman.get(gen_name.split("-")[-1], 9)

        return pokemon_data, {"english_name": english_name, "gen": gen_num}


pokemon_resolver_service = PokemonResolverService()
