"""
pokemon_resolver.py — Backend aggregation service for GET /pokemon/{id}/resolved.

Merges:
  - PokéAPI  (types, stats, abilities, forms, sprites)
  - Showdown event_learnsets  (moves PokéAPI doesn't know about)
  - Showdown pokedex / gen-overrides  (gen-accurate types & stats)
  - Smogon pkmn.github.io  (competitive sets, fetched in background)
"""

import asyncio
import json
import logging
import os
import re
from datetime import datetime, timezone

import httpx
from fastapi import HTTPException
from sqlalchemy import func, select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.pokemon_resolved import PokemonResolved
from app.schemas.pokemon_resolved import (
    EventMove,
    FormData,
    PokemonResolvedResponse,
    SmogonFormatData,
    SmogonResponse,
    SmogonSet,
    SpriteUrlsFull,
    VarietyData,
)

logger = logging.getLogger(__name__)

_STATIC_DIR = os.path.join(os.path.dirname(__file__), "..", "static")

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
_SHOWDOWN_CDN = "https://play.pokemonshowdown.com/sprites"
_POKEAPI_SPRITES = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions"

# PokeAPI/sprites: preferred subdir and extension per gen game
# (gen number → (game_path, subdir, ext, shiny_subdir))
_GEN_SPRITE_CONFIG: dict[int, tuple[str, str, str, str]] = {
    1: ("generation-i/yellow",                     "transparent", "png", ""),         # no shinies in gen 1
    2: ("generation-ii/crystal",                   "animated",    "gif", "animated/shiny"),
    3: ("generation-iii/emerald",                  "",            "png", "shiny"),
    4: ("generation-iv/heartgold-soulsilver",      "",            "png", "shiny"),
    5: ("generation-v/black-white",                "animated",    "gif", "animated/shiny"),
}

# Showdown gen-specific sprite dirs (gen number → dir name)
_SHOWDOWN_GEN_DIRS: dict[int, str] = {
    1: "gen1", 2: "gen2", 3: "gen3", 4: "gen4", 5: "gen5", 6: "gen6",
}
_SHOWDOWN_GEN_SHINY_DIRS: dict[int, str] = {
    2: "gen2-shiny", 3: "gen3-shiny", 4: "gen4-shiny", 5: "gen5-shiny",
}

_ROMAN = {"i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5,
          "vi": 6, "vii": 7, "viii": 8, "ix": 9}

_GEN_RANGES = [(151, 1), (251, 2), (386, 3), (493, 4), (649, 5),
               (721, 6), (809, 7), (905, 8), (10000, 9)]


def _num_to_gen(num: int) -> int:
    for limit, gen in _GEN_RANGES:
        if num <= limit:
            return gen
    return 9

_SOURCE_METHOD = {"S": "event", "E": "egg", "T": "tutor", "L": "level", "M": "machine"}

# Name-pattern → introduction gen for variety forms.
# Patterns are checked in order; first match wins.
# Battle-state and origin forms (zen, blade, origin, etc.) fall through
# to the base pokemon's gen via _num_to_gen().
_VARIETY_GEN_PATTERNS: list[tuple[str, int]] = [
    ("-mega", 6), ("-primal", 6),
    ("-alola", 7), ("-totem", 7),
    ("-galar", 8), ("-gmax", 8), ("-eternamax", 8), ("-hisui", 8),
    ("-paldea", 9),
]


def _variety_intro_gen(variety_name: str, base_num: int | None) -> int:
    """Return the generation a variety was introduced.

    Uses name patterns for form types with known introduction gens (megas in
    gen 6, Alolan forms in gen 7, etc.).  Falls back to the base species'
    gen (via _num_to_gen) for battle-state forms that were introduced
    alongside the base pokemon (Zen Darmanitan gen 5, Aegislash-Blade gen 6).
    """
    for pattern, gen in _VARIETY_GEN_PATTERNS:
        if pattern in variety_name:
            return gen
    return _num_to_gen(base_num or 0)


def _gen_from_name(generation_name: str) -> int:
    return _ROMAN.get(generation_name.split("-")[-1], 9)


def _to_showdown_name(pokeapi_name: str, ps_exceptions: dict[str, str]) -> str:
    """Convert a PokéAPI pokemon name to its Showdown CDN sprite filename stem.

    Most names work as-is (Showdown's dex/ accepts hyphenated slugs).
    Special cases:
      - psFormExceptions registry overrides (e.g. ogerpon mask forms)
      - Mega evolutions: charizard-mega-x → charizard-megax
    """
    if pokeapi_name in ps_exceptions:
        return ps_exceptions[pokeapi_name]
    # Collapse -mega-x / -mega-y into -megax / -megay
    name = re.sub(r"-mega-([a-z])$", r"-mega\1", pokeapi_name)
    return name


def _build_pokeapi_sprite_url(
    sprite_id: str, gen: int, shiny: bool = False, female: bool = False
) -> str | None:
    """Construct a PokeAPI/sprites versioned URL for a given gen.

    sprite_id is either a numeric ID string ("10034") for varieties or
    an ID-suffix string ("201-b") for cosmetic forms.
    Returns None for gen 6+ (no versioned sprites) or gen 1 shiny (no shinies).
    """
    if gen not in _GEN_SPRITE_CONFIG:
        return None
    game_path, subdir, ext, shiny_subdir = _GEN_SPRITE_CONFIG[gen]
    if shiny:
        if not shiny_subdir:
            return None  # gen 1 has no shinies
        parts = [_POKEAPI_SPRITES, game_path, shiny_subdir, f"{sprite_id}.{ext}"]
    else:
        if subdir:
            parts = [_POKEAPI_SPRITES, game_path, subdir, f"{sprite_id}.{ext}"]
        else:
            parts = [_POKEAPI_SPRITES, game_path, f"{sprite_id}.{ext}"]
    if female:
        # Female variants: insert "female" before filename (non-standard; best effort)
        return None
    return "/".join(parts)


def _build_showdown_sprite_url(
    ps_name: str, gen: int, shiny: bool = False
) -> str | None:
    """Construct a Showdown CDN URL for a given gen.
    Returns None for gen 1 shiny (shinies did not exist in Gen 1)."""
    if shiny and gen == 1:
        return None  # no shinies in Gen 1
    if gen <= 5:
        gen_dir = _SHOWDOWN_GEN_DIRS.get(gen, "dex")
        if shiny:
            shiny_dir = _SHOWDOWN_GEN_SHINY_DIRS.get(gen, "dex-shiny")
            return f"{_SHOWDOWN_CDN}/{shiny_dir}/{ps_name}.png"
        return f"{_SHOWDOWN_CDN}/{gen_dir}/{ps_name}.png"
    elif gen == 6:
        dir_name = "gen6-shiny" if shiny else "gen6"
        return f"{_SHOWDOWN_CDN}/{dir_name}/{ps_name}.png"
    else:
        dir_name = "dex-shiny" if shiny else "dex"
        return f"{_SHOWDOWN_CDN}/{dir_name}/{ps_name}.png"


def _extract_form_suffix(form_name: str, species_name: str) -> str | None:
    """Derive the PokeAPI/sprites suffix from a form name.

    unown-b + unown → b
    shellos-east + shellos → east
    Returns None if the form name doesn't start with the species prefix.
    """
    prefix = species_name + "-"
    if form_name.startswith(prefix):
        return form_name[len(prefix):]
    return None


class PokemonResolverService:
    def __init__(self) -> None:
        self._event_learnsets: dict[str, dict] = {}
        self._moves_index: dict[str, dict] = {}
        self._ps_pokedex: dict[str, dict] = {}
        self._ps_pokedex_overrides: dict[str, dict[str, dict]] = {}
        self._ps_exceptions: dict[str, str] = {}
        self._smogon_sets: dict[str, dict] = {}
        self._smogon_analyses: dict[str, dict] = {}
        self._smogon_loaded = False
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
            logger.info("Loaded pokedex-gen-overrides.json")
        else:
            logger.warning("pokedex-gen-overrides.json not found")

        registry_path = os.path.join(_STATIC_DIR, "pokemon_registry.json")
        if os.path.exists(registry_path):
            with open(registry_path, encoding="utf-8") as f:
                registry = json.load(f)
            self._ps_exceptions = registry.get("psFormExceptions", {})
            logger.info("Loaded pokemon_registry.json (%d PS form exceptions)", len(self._ps_exceptions))
        else:
            logger.warning("pokemon_registry.json not found in static/ — copy from assets/data/")

    async def load_smogon_data(self) -> None:
        """Fetch Smogon sets + analyses for curated formats. Runs as background task."""
        logger.info("Starting Smogon data preload (%d formats)…", len(_SMOGON_FORMATS))

        async def _fetch(fmt: str) -> tuple[str, dict, dict]:
            try:
                sets_r, analyses_r = await asyncio.gather(
                    self._smogon_http.get(f"{_SMOGON_BASE}/sets/{fmt}.json"),
                    self._smogon_http.get(f"{_SMOGON_BASE}/analyses/{fmt}.json"),
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
    # Gen-aware type/stat overrides
    # ------------------------------------------------------------------

    def _apply_gen_overrides(
        self, ps_name: str,
        base_types: list[str], base_stats: dict[str, int], base_abilities: dict[str, str],
        gen: int,
    ) -> tuple[list[str], dict[str, int], dict[str, str]]:
        """Apply gen-accurate overrides. Scans upward from requested gen to find
        the nearest override for each field (handles cascade: gen5 Clefairy Normal
        applies to gen4 too since gen4 has no Clefairy override)."""
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
            if all(x is not None for x in [types, stats, abilities]):
                break

        return (
            types if types is not None else base_types,
            stats if stats is not None else base_stats,
            abilities if abilities is not None else base_abilities,
        )

    # ------------------------------------------------------------------
    # Move supplementation
    # ------------------------------------------------------------------

    def _get_supplement_moves(
        self, ps_name: str, pokeapi_move_slugs: set[str]
    ) -> list[EventMove]:
        """Return moves from Showdown that are absent from PokéAPI's list.

        Covers event distributions (S), but also egg (E) and tutor (T) moves
        that PokéAPI omits for older generations.
        """
        entry = self._event_learnsets.get(ps_name)
        if not entry:
            return []
        learnset = entry.get("learnset", {})
        known_ps_ids = {slug.replace("-", "") for slug in pokeapi_move_slugs}
        result: list[EventMove] = []
        for move_id, sources in learnset.items():
            if move_id in known_ps_ids:
                continue
            gen_methods: dict[int, set[str]] = {}
            for src in sources:
                if not src or not src[0].isdigit():
                    continue
                gen_n = int(src[0])
                method_code = src[1].upper() if len(src) >= 2 else "L"
                method = _SOURCE_METHOD.get(method_code, "level")
                gen_methods.setdefault(gen_n, set()).add(method)
            if not gen_methods:
                continue
            move_info = self._moves_index.get(move_id, {})
            result.append(EventMove(
                name=move_id,
                display_name=move_info.get("name", move_id),
                generations=sorted(gen_methods.keys()),
                methods=sorted({m for methods in gen_methods.values() for m in methods}),
            ))
        return result

    # ------------------------------------------------------------------
    # Smogon analyses
    # ------------------------------------------------------------------

    def _get_smogon_analyses(self, display_name: str) -> list[SmogonFormatData] | None:
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

    # ------------------------------------------------------------------
    # Sprite URL builders
    # ------------------------------------------------------------------

    def _build_variety_sprite_urls(
        self,
        sprites: dict,
        ps_name: str,
        variety_id: int,
        gen: int,
        gen_sprite_id_override: str | None = None,
    ) -> SpriteUrlsFull:
        """Build full sprite URLs for a variety (has its own /pokemon resource).

        gen_sprite_id_override replaces the numeric ID in the versioned sprite
        path only — home and official artwork still use variety_id.  Use this
        when the Pokémon's default form has a suffix (e.g. Unown "unown-a"
        → "201-a" instead of "201" for Gen 2 Crystal sprites).
        """
        other = sprites.get("other") or {}
        artwork = other.get("official-artwork") or {}
        home = other.get("home") or {}

        # Gen-specific game sprite: PokeAPI/sprites versioned (primary) or Showdown (fallback)
        sprite_id = gen_sprite_id_override or str(variety_id)
        game_front = (
            _build_pokeapi_sprite_url(sprite_id, gen)
            or _build_showdown_sprite_url(ps_name, gen)
        )
        game_front_shiny = (
            _build_pokeapi_sprite_url(sprite_id, gen, shiny=True)
            or _build_showdown_sprite_url(ps_name, gen, shiny=True)
        )

        return SpriteUrlsFull(
            official_artwork=artwork.get("front_default"),
            official_artwork_shiny=artwork.get("front_shiny"),
            home=home.get("front_default"),
            home_shiny=home.get("front_shiny"),
            home_female=home.get("front_female"),
            home_female_shiny=home.get("front_female_shiny") or home.get("front_shiny_female"),
            game_front=game_front,
            game_front_shiny=game_front_shiny,
            game_front_female=None,        # derivable but out of scope for now
            game_front_female_shiny=None,
        )

    def _build_form_sprite_urls(
        self, form_name: str, base_id: int, species_name: str, ps_name: str, gen: int
    ) -> SpriteUrlsFull:
        """Build full sprite URLs for a cosmetic form-entry (no /pokemon resource)."""
        suffix = _extract_form_suffix(form_name, species_name)
        sprite_id = f"{base_id}-{suffix}" if suffix else str(base_id)

        # Gen-specific: PokeAPI/sprites (primary), Showdown gen{N} (fallback)
        game_front = (
            _build_pokeapi_sprite_url(sprite_id, gen)
            or _build_showdown_sprite_url(ps_name, gen)
        )
        game_front_shiny = (
            _build_pokeapi_sprite_url(sprite_id, gen, shiny=True)
            or _build_showdown_sprite_url(ps_name, gen, shiny=True)
        )

        return SpriteUrlsFull(
            official_artwork=None,
            official_artwork_shiny=None,
            home=f"{_SHOWDOWN_CDN}/home/{ps_name}.png",
            home_shiny=f"{_SHOWDOWN_CDN}/home-shiny/{ps_name}.png",
            home_female=None,
            home_female_shiny=None,
            game_front=game_front,
            game_front_shiny=game_front_shiny,
            game_front_female=None,
            game_front_female_shiny=None,
        )

    def _build_base_sprite_urls(
        self,
        sprites: dict,
        ps_name: str,
        pokemon_id: int,
        gen: int,
        gen_sprite_id: str | None = None,
    ) -> SpriteUrlsFull:
        """Build full sprite URLs for the base pokemon.

        gen_sprite_id overrides the ID used for gen-specific versioned sprites
        only.  Pass it when the Pokémon's default form has a suffix in the
        PokeAPI/sprites repo so that the correct versioned file is used.

        Unown (201) is the canonical example.  Its default form in PokéAPI is
        "unown-a" (suffix "a"), and the PokeAPI/sprites versioned directories
        are inconsistent about whether "201" or "201-a" is the right filename:

          Gen 2 Crystal animated  → 201.gif does NOT exist; 201-a.gif MUST be used
          Gen 2-4 static          → both 201.png and 201-a.png exist (either works)
          Gen 5 BW animated       → both 201.gif and 201-a.gif exist
          Gen 5 BW static         → only 201.png exists (201-a.png is missing)
          HOME / official artwork → only 201.png exists

        Our _GEN_SPRITE_CONFIG prefers the animated/ subdir for Gen 2 and Gen 5,
        so the gen_sprite_id="201-a" is correct for those paths (animated/201-a.gif
        exists in both Crystal and BW).  HOME and official artwork are extracted
        from the PokéAPI sprites object directly (always 201.png) and are not
        affected by gen_sprite_id.

        If a Pokémon with a similar pattern is added in future, check the
        PokeAPI/sprites repo to confirm which ID exists in the animated/ subdir
        for the gens supported by _GEN_SPRITE_CONFIG before passing an override.
        """
        return self._build_variety_sprite_urls(
            sprites, ps_name, pokemon_id, gen,
            gen_sprite_id_override=gen_sprite_id,
        )

    # ------------------------------------------------------------------
    # Variety + form fetching
    # ------------------------------------------------------------------

    async def _fetch_varieties(
        self, varieties: list[dict], species_name: str, gen: int, base_url: str = ""
    ) -> list[VarietyData]:
        """Parallel fetch /pokemon/{id} for each non-default variety.

        Varieties introduced after the requested gen are excluded.
        """
        # Get base pokemon's dex number for battle-state form gen fallback
        base_ps_id = species_name.replace("-", "").lower()
        base_num: int | None = self._ps_pokedex.get(base_ps_id, {}).get("num")

        non_defaults = [
            v for v in varieties
            if not v.get("is_default", True)
            and _variety_intro_gen(v["pokemon"]["name"], base_num) <= gen
        ]
        if not non_defaults:
            return []

        responses = await asyncio.gather(
            *[self._pokeapi_http.get(v["pokemon"]["url"]) for v in non_defaults],
            return_exceptions=True,
        )

        result: list[VarietyData] = []
        for variety_meta, resp in zip(non_defaults, responses):
            variety_name = variety_meta["pokemon"]["name"]
            if isinstance(resp, Exception) or resp.status_code != 200:
                logger.warning("Failed to fetch variety %s: %s", variety_name, resp)
                # Still include slim entry
                url = variety_meta["pokemon"]["url"]
                variety_id = int(url.rstrip("/").split("/")[-1])
                result.append(VarietyData(
                    name=variety_name,
                    pokemon_id=variety_id,
                    is_default=False,
                    resolved_url=f"{base_url}/pokemon/{variety_id}/resolved",
                ))
                continue

            data = resp.json()
            variety_id = data["id"]
            ps_id = data["name"].replace("-", "").lower()
            ps_sprite_name = _to_showdown_name(data["name"], self._ps_exceptions)

            ps_entry = self._ps_pokedex.get(ps_id, {})
            ps_types = ps_entry.get("types", [t["type"]["name"].title() for t in data.get("types", [])])
            ps_stats = ps_entry.get("baseStats", {s["stat"]["name"]: s["base_stat"] for s in data.get("stats", [])})
            ps_abilities_raw = ps_entry.get("abilities", {})
            ps_abilities = ps_abilities_raw if ps_abilities_raw else {
                str(a["slot"]): a["ability"]["name"] for a in data.get("abilities", [])
            }

            types, base_stats, abilities = self._apply_gen_overrides(
                ps_id, ps_types, ps_stats, ps_abilities, gen
            )

            sprite_urls = self._build_variety_sprite_urls(
                data.get("sprites") or {}, ps_sprite_name, variety_id, gen
            )

            result.append(VarietyData(
                name=variety_name,
                pokemon_id=variety_id,
                is_default=False,
                resolved_url=f"{base_url}/pokemon/{variety_id}/resolved",
                types=types,
                base_stats=base_stats,
                abilities=abilities,
                sprite_urls=sprite_urls,
            ))
        return result

    async def _fetch_forms(
        self, form_names: list[str], base_id: int, species_name: str, gen: int
    ) -> list[FormData]:
        """Parallel fetch /pokemon-form/{name} for each non-default form."""
        # Determine which form is the default (usually has same name as species or is index 0)
        non_defaults = [n for n in form_names if n != species_name and n != form_names[0]]
        if not non_defaults:
            non_defaults = form_names[1:] if len(form_names) > 1 else []

        # Build sprite data for the default form (index 0) the same way as non-defaults.
        # The default form may have a suffix (e.g. "unown-a") — its gen sprite is
        # "201-a.gif" not "201.gif".
        default_form_name = form_names[0]
        default_ps_name = _to_showdown_name(default_form_name, self._ps_exceptions)
        default_suffix = _extract_form_suffix(default_form_name, species_name)
        default_sprite_id = f"{base_id}-{default_suffix}" if default_suffix else str(base_id)
        default_front_sprite = (
            f"https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/{default_sprite_id}.png"
        )
        default_sprite_urls = self._build_form_sprite_urls(
            default_form_name, base_id, species_name, default_ps_name, gen
        )

        if not non_defaults:
            return [
                FormData(
                    name=n,
                    front_sprite_url=default_front_sprite,
                    sprite_urls=default_sprite_urls,
                )
                for n in form_names
            ]

        responses = await asyncio.gather(
            *[self._pokeapi_http.get(f"{_POKEAPI_BASE}/pokemon-form/{n}") for n in non_defaults],
            return_exceptions=True,
        )

        # Default form gets the same full sprite treatment as non-defaults
        result: list[FormData] = [FormData(
            name=default_form_name,
            front_sprite_url=default_front_sprite,
            sprite_urls=default_sprite_urls,
        )]
        for form_name, resp in zip(non_defaults, responses):
            ps_name = _to_showdown_name(form_name, self._ps_exceptions)
            # Construct the front sprite URL from the base_id + suffix pattern
            suffix = _extract_form_suffix(form_name, species_name)
            sprite_id = f"{base_id}-{suffix}" if suffix else str(base_id)
            front_sprite = f"https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/{sprite_id}.png"

            if isinstance(resp, Exception) or resp.status_code != 200:
                logger.warning("Failed to fetch form %s: %s", form_name, resp)
                result.append(FormData(name=form_name, front_sprite_url=front_sprite))
                continue

            # Use the API response's front_default if available (more authoritative)
            api_front = (resp.json().get("sprites") or {}).get("front_default") or front_sprite
            sprite_urls = self._build_form_sprite_urls(
                form_name, base_id, species_name, ps_name, gen
            )
            result.append(FormData(
                name=form_name,
                front_sprite_url=api_front,
                sprite_urls=sprite_urls,
            ))
        return result

    # ------------------------------------------------------------------
    # Response trimming based on includes
    # ------------------------------------------------------------------

    @staticmethod
    def _filter_smogon_by_gen(
        analyses: "list[SmogonFormatData] | None", gen: int | None
    ) -> "list[SmogonFormatData] | None":
        """Filter Smogon analyses to only the formats for a specific gen.

        gen=None returns all formats.
        Format IDs are all prefixed with gen{N} (e.g. "gen5ou", "gen9doublesou").
        """
        if analyses is None or gen is None:
            return analyses
        prefix = f"gen{gen}"
        return [f for f in analyses if f.format_id.startswith(prefix)] or None

    @staticmethod
    def _trim_response(
        response: "PokemonResolvedResponse", includes: list[str], gen: int | None = None
    ) -> "PokemonResolvedResponse":
        """Strip expanded fields not requested via includes, and gen-gate smogon.

        resolved_url on VarietyData and front_sprite_url on FormData are
        always preserved — they exist specifically to support the slim response.

        smogon_analyses is always filtered to the requested gen (even slim
        format-id-only entries). Pass gen=None to skip filtering.
        """
        if "varieties" not in includes:
            response = response.model_copy(update={
                "varieties": [
                    VarietyData(
                        name=v.name,
                        pokemon_id=v.pokemon_id,
                        is_default=v.is_default,
                        resolved_url=v.resolved_url,
                    )
                    for v in response.varieties
                ]
            })
        if "forms" not in includes:
            response = response.model_copy(update={
                "forms": [
                    FormData(name=f.name, front_sprite_url=f.front_sprite_url)
                    for f in response.forms
                ]
            })
        # Gen-filter smogon first, then strip sets if not in includes
        filtered = PokemonResolverService._filter_smogon_by_gen(response.smogon_analyses, gen)
        if "smogon" not in includes and filtered is not None:
            response = response.model_copy(update={
                "smogon_analyses": [
                    SmogonFormatData(format_id=f.format_id)
                    for f in filtered
                ]
            })
        elif filtered is not response.smogon_analyses:
            # smogon IS in includes but gen filtering changed the list
            response = response.model_copy(update={"smogon_analyses": filtered})
        return response

    # ------------------------------------------------------------------
    # Main resolution
    # ------------------------------------------------------------------

    async def resolve(
        self, pokemon_id: int, gen: int, includes: list[str], db: AsyncSession,
        base_url: str = "",
    ) -> PokemonResolvedResponse:
        # 1. Cache hit (full data always stored)
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
            response = PokemonResolvedResponse(**row.data, resolved_at=row.resolved_at)
            return self._trim_response(response, includes, gen)

        # 2. Fetch from PokéAPI
        try:
            pokemon_data, species_info = await self._fetch_pokeapi(pokemon_id)
        except httpx.HTTPStatusError as exc:
            if exc.response.status_code == 404:
                raise HTTPException(404, detail=f"Pokémon {pokemon_id} not found in PokéAPI")
            raise
        except httpx.TimeoutException:
            raise HTTPException(503, detail="PokéAPI is unavailable; try again later")

        # 3. Unpack base data
        pokemon_name: str = pokemon_data["name"]
        english_species_name: str = species_info["english_name"]
        species_gen: int = species_info["gen"]
        species_name: str = species_info["species_name"]

        if gen < species_gen:
            raise HTTPException(
                404,
                detail=f"{english_species_name} was not introduced until Gen {species_gen}",
            )

        # 4. Gen-aware types/stats from Showdown
        ps_id = pokemon_name.replace("-", "").lower()
        ps_entry = self._ps_pokedex.get(ps_id, {})
        raw_types = [t["type"]["name"].title() for t in pokemon_data.get("types", [])]
        raw_stats = {s["stat"]["name"]: s["base_stat"] for s in pokemon_data.get("stats", [])}
        raw_abilities = {str(a["slot"]): a["ability"]["name"] for a in pokemon_data.get("abilities", [])}
        ps_types = ps_entry.get("types", raw_types)
        ps_stats = ps_entry.get("baseStats", raw_stats)
        ps_abilities_raw = ps_entry.get("abilities", {})
        ps_abilities = ps_abilities_raw if ps_abilities_raw else raw_abilities
        types, base_stats, abilities = self._apply_gen_overrides(ps_id, ps_types, ps_stats, ps_abilities, gen)

        # 5. Move supplementation
        move_slugs: set[str] = {m["move"]["name"] for m in pokemon_data.get("moves", [])}
        supplement_moves = self._get_supplement_moves(ps_id, move_slugs)

        # 6. Smogon analyses
        display_name = _smogon_display_name(pokemon_name, english_species_name)
        smogon_analyses = self._get_smogon_analyses(display_name)

        # 7. Sprite URLs for base pokemon
        # Derive the gen-specific sprite ID from the first form name suffix.
        # When the default form has a suffix (e.g. PokéAPI names Unown's base
        # form "unown-a"), the versioned sprite dirs use "{id}-{suffix}" not
        # just "{id}" — Gen 2 Crystal animated has 201-a.gif but no 201.gif.
        # See _build_base_sprite_urls docstring for the full compatibility matrix.
        ps_sprite_name = _to_showdown_name(pokemon_name, self._ps_exceptions)
        first_form = (pokemon_data.get("forms") or [{}])[0].get("name", "")
        first_form_suffix = _extract_form_suffix(first_form, species_name) if first_form else None
        gen_sprite_id = f"{pokemon_id}-{first_form_suffix}" if first_form_suffix else None
        sprite_urls = self._build_base_sprite_urls(
            pokemon_data.get("sprites") or {}, ps_sprite_name, pokemon_id, gen,
            gen_sprite_id=gen_sprite_id,
        )

        # 8. Varieties (always fetched on cache miss, trimmed at response time)
        raw_varieties = species_info["varieties"]
        varieties = await self._fetch_varieties(raw_varieties, species_name, gen, base_url)

        # 9. Forms (form-entry cosmetics)
        form_names = [f["name"] for f in pokemon_data.get("forms", [])]
        forms = await self._fetch_forms(form_names, pokemon_id, species_name, gen)

        # 10. Build full response (cache always stores this)
        now = datetime.now(timezone.utc)
        response = PokemonResolvedResponse(
            pokemon_id=pokemon_id,
            gen=gen,
            name=pokemon_name,
            types=types,
            base_stats=base_stats,
            abilities=abilities,
            supplement_moves=supplement_moves,
            smogon_analyses=smogon_analyses,
            smogon_url=f"{base_url}/pokemon/{pokemon_id}/smogon",
            varieties=varieties,
            varieties_url=f"{base_url}/pokemon/{pokemon_id}/varieties",
            forms=forms,
            forms_url=f"{base_url}/pokemon/{pokemon_id}/forms",
            sprite_urls=sprite_urls,
            resolved_at=now,
        )

        # 11. Upsert full data to cache
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

        # 12. Trim and return
        return self._trim_response(response, includes)

    # ------------------------------------------------------------------
    # Name-or-ID resolution + convenience endpoints
    # ------------------------------------------------------------------

    async def _resolve_name_or_id(self, name_or_id: str) -> int:
        """Resolve a pokemon name or numeric string to a PokéAPI pokemon ID.

        "6" → 6 (numeric, no network call)
        "charizard-mega-x" → 10034 (name lookup via PokéAPI)
        """
        if name_or_id.isdigit():
            return int(name_or_id)
        try:
            r = await self._pokeapi_http.get(f"{_POKEAPI_BASE}/pokemon/{name_or_id}")
            r.raise_for_status()
            return r.json()["id"]
        except httpx.HTTPStatusError as exc:
            if exc.response.status_code == 404:
                raise HTTPException(404, detail=f"Pokémon '{name_or_id}' not found")
            raise
        except httpx.TimeoutException:
            raise HTTPException(503, detail="PokéAPI is unavailable; try again later")

    async def resolve_varieties(
        self, name_or_id: str, gen: int, db: AsyncSession, base_url: str = ""
    ) -> "VarietiesResponse":
        from app.schemas.pokemon_resolved import VarietiesResponse
        pokemon_id = await self._resolve_name_or_id(name_or_id)

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
            return VarietiesResponse(
                pokemon_id=pokemon_id,
                gen=gen,
                name=row.data.get("name", ""),
                varieties=row.data.get("varieties", []),
            )

        full = await self.resolve(pokemon_id, gen, ["varieties", "forms"], db, base_url)
        return VarietiesResponse(
            pokemon_id=pokemon_id,
            gen=gen,
            name=full.name,
            varieties=full.varieties,
        )

    async def resolve_smogon(
        self, name_or_id: str, gen: int | None, db: AsyncSession, base_url: str = ""
    ) -> SmogonResponse:
        """Return Smogon analyses, optionally filtered to a single generation.

        gen=None → all formats returned.
        gen=N   → only formats whose ID starts with "gen{N}" (e.g. gen5ou).

        The DB cache is keyed by (pokemon_id, resolved_gen=9) for the all-formats
        case.  When gen is specified we look up the cache for that gen.
        """
        # Resolve the gen for DB lookup: None → use gen 9 row (stores all formats)
        db_gen = gen if gen is not None else 9
        pokemon_id = await self._resolve_name_or_id(name_or_id)

        result = await db.execute(
            select(PokemonResolved).where(
                PokemonResolved.pokemon_id == pokemon_id,
                PokemonResolved.gen == db_gen,
                PokemonResolved.resolved_at
                + text("(ttl_days * interval '1 day')")
                > func.now(),
            )
        )
        row = result.scalar_one_or_none()
        if row:
            all_analyses = row.data.get("smogon_analyses")
            filtered = self._filter_smogon_by_gen(all_analyses, gen)
            return SmogonResponse(
                pokemon_id=pokemon_id,
                gen=gen,
                name=row.data.get("name", ""),
                smogon_analyses=filtered,
            )

        full = await self.resolve(pokemon_id, db_gen, ["smogon"], db, base_url)
        filtered = self._filter_smogon_by_gen(full.smogon_analyses, gen)
        return SmogonResponse(
            pokemon_id=pokemon_id,
            gen=gen,
            name=full.name,
            smogon_analyses=filtered,
        )

    async def resolve_forms(
        self, name_or_id: str, gen: int, db: AsyncSession, base_url: str = ""
    ) -> "FormsResponse":
        from app.schemas.pokemon_resolved import FormsResponse
        pokemon_id = await self._resolve_name_or_id(name_or_id)

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
            return FormsResponse(
                pokemon_id=pokemon_id,
                gen=gen,
                name=row.data.get("name", ""),
                forms=row.data.get("forms", []),
            )

        full = await self.resolve(pokemon_id, gen, ["varieties", "forms"], db, base_url)
        return FormsResponse(
            pokemon_id=pokemon_id,
            gen=gen,
            name=full.name,
            forms=full.forms,
        )

    async def _fetch_pokeapi(self, pokemon_id: int) -> tuple[dict, dict]:
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
        gen_suffix = species_data.get("generation", {}).get("name", "generation-ix").split("-")[-1]
        gen_num = _ROMAN.get(gen_suffix, 9)
        species_name: str = species_data["name"]

        return pokemon_data, {
            "english_name": english_name,
            "gen": gen_num,
            "species_name": species_name,
            "varieties": species_data.get("varieties", []),
        }


def _smogon_display_name(pokeapi_pokemon_name: str, english_species_name: str) -> str:
    species_slug = english_species_name.lower().replace(" ", "-").replace(".", "").replace("'", "")
    if pokeapi_pokemon_name == species_slug or pokeapi_pokemon_name == species_slug.replace("-", ""):
        return english_species_name
    return "-".join(w.title() for w in pokeapi_pokemon_name.split("-"))


pokemon_resolver_service = PokemonResolverService()
