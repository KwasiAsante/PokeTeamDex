"""
pokemon_resolver.py — Backend aggregation service for GET /pokemon/{id}/resolved.

Merges:
  - PokéAPI  (types, stats, abilities, forms, sprites)
  - Showdown learnset_N.json  (moves PokéAPI doesn't know about — loaded by LearnsetService in sub-issue B)
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
from app.services.learnset_service import LearnsetService
from app.schemas.pokemon_resolved import (
    AbilityInfo,
    EventMove,
    FlavorTextEntry,
    FormData,
    MoveLearnDetail,
    MoveSummary,
    PokemonResolvedResponse,
    SmogonFormatData,
    SmogonResponse,
    SmogonSet,
    SpriteUrlsFull,
    VarietyData,
)

logger = logging.getLogger(__name__)

_STATIC_DIR = os.path.join(os.path.dirname(__file__), "..", "static")

# SHARED_DIR env var points to shared/ at the project root.
# Default "../shared" works when running uvicorn from backend/ locally.
# In Docker the env var is set explicitly to /app/shared.
_SHARED_DIR = os.environ.get("SHARED_DIR", "../shared")

# PS_DATA_DIR env var points to shared/ps_data/ at the project root.
# Default derives from SHARED_DIR so a single env var covers both.
_PS_DATA_DIR = os.environ.get("PS_DATA_DIR", os.path.join(_SHARED_DIR, "ps_data"))

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
_POKEAPI_PLAIN_SPRITES = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
_POKEAPI_HOME = f"{_POKEAPI_PLAIN_SPRITES}/other/home"
_POKEAPI_OA = f"{_POKEAPI_PLAIN_SPRITES}/other/official-artwork"

# PokeAPI/sprites: preferred subdir and extension per gen game
# (gen number → (game_path, subdir, ext, shiny_subdir))
_GEN_SPRITE_CONFIG: dict[int, tuple[str, str, str, str]] = {
    1: ("generation-i/yellow",                     "transparent", "png", ""),         # no shinies in gen 1
    2: ("generation-ii/crystal",                   "animated",    "gif", "animated/shiny"),
    3: ("generation-iii/emerald",                  "",            "png", "shiny"),
    4: ("generation-iv/heartgold-soulsilver",      "",            "png", "shiny"),
    5: ("generation-v/black-white",                "animated",    "gif", "animated/shiny"),
    6: ("generation-vi/omegaruby-alphasapphire",   "",            "png", "shiny"),
    7: ("generation-vii/ultra-sun-ultra-moon",     "",            "png", "shiny"),
    # gen 8 has no versioned sprite directories in the PokeAPI repo — Showdown fallback
    9: ("generation-ix/scarlet-violet",            "",            "png", ""),          # no shiny dir in gen 9 repo
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

# Version groups that exist in PokéAPI but represent side games with non-standard
# move availability. Excluded from gen-aware PokéAPI VG filtering.
_SIDE_GAME_VGS: frozenset[str] = frozenset({"colosseum", "xd", "stadium", "stadium-2"})

# Priority order for picking the "best" method when converting a supplement
# EventMove to a MoveSummary. Lower index = higher priority.
_SUPPLEMENT_METHOD_PRIORITY: dict[str, int] = {
    "level": 0, "machine": 1, "egg": 2, "tutor": 3,
    "event": 4, "relearn": 5, "transfer": 6, "other": 7,
}

# Maps PS learnset method labels (from _LEARNSET_METHOD_LABEL) to PokéAPI-style
# method strings used in MoveLearnDetail.method.
_SUPPLEMENT_TO_POKEAPI_METHOD: dict[str, str] = {
    "level": "level-up",
    "machine": "machine",
    "egg": "egg",
    "tutor": "tutor",
    "event": "event",
    "relearn": "level-up",
    "transfer": "transfer",
    "other": "other",
}

# Fallback for when pokemon_registry.json is absent (should not happen in prod).
_VARIETY_ICON_ID_OVERRIDES_DEFAULT: dict[str, str] = {
    "calyrex-ice":                "898-ice-rider",
    "calyrex-shadow":             "898-shadow-rider",
    "toxtricity-amped-gmax":      "849-gmax",
    "toxtricity-low-key-gmax":    "849-gmax",
    "urshifu-single-strike-gmax": "892-gmax",
    "urshifu-rapid-strike":       "892",       # no dedicated icon; shares 892.png with base
}

# PokéAPI form name suffix → PokeAPI/sprites repo suffix.
# The sprites repo uses shorter names for some forms whose PokéAPI slug is longer.
# e.g. "shellos-east-sea" → sprites use "422-east.png", not "422-east-sea.png".
_SPRITE_SUFFIX_REMAP: dict[str, str] = {
    "east-sea":      "east",
    "blue-flower":   "blue",
    "orange-flower": "orange",
    "red-flower":    "red",
    "white-flower":  "white",
    "yellow-flower": "yellow",
    "blue-petal":    "blue",
    "orange-petal":  "orange",
    "red-petal":     "red",
    "white-petal":   "white",
    "yellow-petal":  "yellow",
}

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
        if gen < 4:
            return None  # female versioned sprites only exist from gen 4
        parts.insert(-1, "female")
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


def _build_icon_url(pokemon_id: int | str, gen: int, female: bool = False) -> str:
    """Gen-specific icon sprite URL.

    Fallback chain:
      gen >= 8  → generation-viii/icons/{id}.png  (female/ subdir if female=True)
      gen == 7  → generation-vii/icons/{id}.png   (female/ subdir if female=True)
      gen <= 6  → plain front sprite (no icon directories; female/ subdir for female=True)
    """
    if gen is None or gen >= 8:
        subdir = "female/" if female else ""
        return f"{_POKEAPI_SPRITES}/generation-viii/icons/{subdir}{pokemon_id}.png"
    elif gen >= 7:
        subdir = "female/" if female else ""
        return f"{_POKEAPI_SPRITES}/generation-vii/icons/{subdir}{pokemon_id}.png"
    elif gen == 5:
        # Gen 5 icons use "{id}-female.png" suffix, not a female/ subdirectory
        suffix = "-female" if female else ""
        return f"{_POKEAPI_SPRITES}/generation-v/icons/{pokemon_id}{suffix}.png"
    else:
        subdir = "female/" if female else ""
        return f"{_POKEAPI_PLAIN_SPRITES}/{subdir}{pokemon_id}.png"


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



async def _probe_url(client: httpx.AsyncClient, url: str) -> str | None:
    """HEAD-check a URL. Returns the URL on 200, None otherwise."""
    try:
        r = await client.head(url, follow_redirects=True, timeout=5.0)
        return url if r.status_code == 200 else None
    except Exception:
        return None


class PokemonResolverService:
    def __init__(self) -> None:
        self._learnset_service = LearnsetService()
        self._moves_index: dict[str, dict] = {}
        self._ps_pokedex: dict[str, dict] = {}
        self._ps_pokedex_overrides: dict[str, dict[str, dict]] = {}
        self._ps_exceptions: dict[str, str] = {}
        # mega form name → mega stone item name  (inverse of megaStoneMap)
        self._mega_form_to_item: dict[str, str] = {}
        # mega form name → required move (e.g. rayquaza-mega → dragon-ascent)
        self._mega_form_to_move: dict[str, str] = {}
        # form name → required ability (from abilityGatingRules)
        self._form_to_ability: dict[str, str] = {}
        # variety name → icon sprite_id override (loaded from pokemon_registry.json)
        self._variety_icon_id_overrides: dict[str, str] = dict(_VARIETY_ICON_ID_OVERRIDES_DEFAULT)
        self._smogon_sets: dict[str, dict] = {}
        self._smogon_analyses: dict[str, dict] = {}
        self._smogon_loaded = False
        self._pokeapi_http = httpx.AsyncClient(
            timeout=10.0, limits=httpx.Limits(max_connections=100)
        )
        # Cap concurrent outgoing PokéAPI calls to avoid rate-limiting.
        # Probe requests go to raw.githubusercontent.com (different host, not capped).
        # 20 lets Vivillon's 17 form fetches complete in one batch while preventing
        # hundreds of simultaneous calls when the full Pokédex warms a cold cache.
        self._pokeapi_semaphore = asyncio.Semaphore(20)
        self._smogon_http = httpx.AsyncClient(
            timeout=30.0, limits=httpx.Limits(max_connections=20)
        )

    # ------------------------------------------------------------------
    # Startup loading
    # ------------------------------------------------------------------

    def load_ps_data(self) -> None:
        """Load PS data files from disk into memory. Called synchronously at startup."""
        self._learnset_service.load(_PS_DATA_DIR)
        for fname, attr in [
            ("moves.json", "_moves_index"),
            ("pokedex.json", "_ps_pokedex"),
        ]:
            path = os.path.join(_PS_DATA_DIR, fname)
            if os.path.exists(path):
                with open(path, encoding="utf-8") as f:
                    setattr(self, attr, json.load(f))
                logger.info("Loaded %s (%d entries)", fname, len(getattr(self, attr)))
            else:
                logger.warning("%s not found — run scripts/sync_ps_data.py", fname)

        overrides_path = os.path.join(_PS_DATA_DIR, "pokedex-gen-overrides.json")
        if os.path.exists(overrides_path):
            with open(overrides_path, encoding="utf-8") as f:
                self._ps_pokedex_overrides = json.load(f)
            logger.info("Loaded pokedex-gen-overrides.json")
        else:
            logger.warning("pokedex-gen-overrides.json not found")

        registry_path = os.path.join(_SHARED_DIR, "pokemon_registry.json")
        if os.path.exists(registry_path):
            with open(registry_path, encoding="utf-8") as f:
                registry = json.load(f)
            self._ps_exceptions = registry.get("psFormExceptions", {})
            # Build inverse mega stone map: megaForm → item
            self._mega_form_to_item = {
                entry["megaForm"]: item
                for item, entry in registry.get("megaStoneMap", {}).items()
            }
            self._mega_form_to_move = registry.get("megaFormMoveRequirements", {})
            self._form_to_ability = registry.get("abilityGatingRules", {})
            self._variety_icon_id_overrides = registry.get(
                "varietyIconIdOverrides", dict(_VARIETY_ICON_ID_OVERRIDES_DEFAULT)
            )
            logger.info("Loaded pokemon_registry.json (%d PS form exceptions)", len(self._ps_exceptions))
        else:
            logger.warning("pokemon_registry.json not found in shared/ — run sync or check SHARED_DIR")

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

    # Maps learnset method strings to the values used in EventMove.methods.
    _LEARNSET_METHOD_LABEL: dict[str, str] = {
        "level_up": "level",
        "machine": "machine",
        "egg": "egg",
        "tutor": "tutor",
        "relearn": "relearn",
        "event": "event",
        "transfer": "transfer",
        "other": "other",
    }

    def _get_supplement_moves(
        self, ps_name: str, gen: int, pokeapi_move_slugs: set[str]
    ) -> list[EventMove]:
        """Return moves from Showdown's gen-N learnset absent from PokéAPI's list.

        Covers event distributions, egg moves, and tutor moves that PokéAPI
        omits for some Pokémon or older generations. Moves inherited via
        pre-evolution (via_prevo) are included — PokéAPI may not list them on
        the evolved form.
        """
        learnset = self._learnset_service.get_learnset(ps_name, gen)
        if not learnset:
            return []
        known_ps_ids = {slug.replace("-", "") for slug in pokeapi_move_slugs}
        result: list[EventMove] = []
        for move_id, sources in learnset.items():
            if move_id in known_ps_ids:
                continue
            methods: set[str] = set()
            via_prevo: bool = False
            prevo: str | None = None
            for src in sources:
                raw = src.get("method", "other")
                methods.add(self._LEARNSET_METHOD_LABEL.get(raw, raw))
                if src.get("via_prevo") and not via_prevo:
                    via_prevo = True
                    prevo = src["via_prevo"]
            if not methods:
                continue
            move_info = self._moves_index.get(move_id, {})
            result.append(EventMove(
                name=move_id,
                display_name=move_info.get("name", move_id),
                generations=[gen],
                methods=sorted(methods),
                via_prevo=via_prevo,
                prevo=prevo,
            ))
        return result

    def _gen_vgs(self, gen: int) -> "frozenset[str] | None":
        """Return the PokéAPI version-group slugs for gen, excluding side-game VGs.

        Returns None when the VG map is not loaded (learnset data absent), so
        callers skip filtering rather than silently stripping all moves.
        """
        if not self._learnset_service._vg_to_gen:
            return None
        return frozenset(
            vg for vg, g in self._learnset_service._vg_to_gen.items()
            if g == gen and vg not in _SIDE_GAME_VGS
        )

    def _event_move_to_summary(self, ev: "EventMove", gen: int) -> "MoveSummary":
        """Convert a supplement EventMove to a MoveSummary for the moves endpoint."""
        from app.schemas.pokemon_resolved import MoveLearnDetail, MoveSummary
        best_label = min(
            ev.methods,
            key=lambda m: _SUPPLEMENT_METHOD_PRIORITY.get(m, 99),
            default="event",
        )
        method = _SUPPLEMENT_TO_POKEAPI_METHOD.get(best_label, best_label)
        last_vg = self._learnset_service.last_vg_for_gen(gen) or ""
        # Normalize PS ID to PokéAPI slug: "Extreme Speed" → "extreme-speed".
        # PS IDs are no-separator lowercase; display_name is the authoritative
        # human-readable form from Showdown's moves index.
        pokeapi_name = ev.display_name.lower().replace("'", "").replace(" ", "-")
        return MoveSummary(
            name=pokeapi_name,
            learn_details=[
                MoveLearnDetail(
                    version_group=last_vg,
                    method=method,
                    level=None,
                    via_prevo=ev.via_prevo,
                    prevo=ev.prevo,
                )
            ],
        )

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
        variety_name: str = "",
        base_pokemon_id: int | None = None,
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

        # Gen-specific game sprites: use versioned URLs when a gen was explicitly
        # requested; fall back to the plain root sprites when gen=None (Pokédex,
        # no-format teams) so we never return a constructed URL that may 404.
        sprite_id = gen_sprite_id_override or str(variety_id)
        game_front = game_front_shiny = game_front_female = game_front_female_shiny = None
        if gen is not None and gen in _GEN_SPRITE_CONFIG:
            gpath, subdir, _, _ = _GEN_SPRITE_CONFIG[gen]
            gen_key, game_key = gpath.split("/", 1)
            versioned = ((sprites.get("versions") or {})
                         .get(gen_key, {})
                         .get(game_key, {}))
            pool = versioned.get(subdir, {}) if subdir else versioned
            game_front = (
                pool.get("front_default")
                or _build_pokeapi_sprite_url(sprite_id, gen)
                or _build_showdown_sprite_url(ps_name, gen)
            )
            game_front_shiny = (
                pool.get("front_shiny")
                or _build_pokeapi_sprite_url(sprite_id, gen, shiny=True)
                or _build_showdown_sprite_url(ps_name, gen, shiny=True)
            )
            game_front_female = (
                pool.get("front_female")
                or _build_pokeapi_sprite_url(sprite_id, gen, female=True)
            )
            game_front_female_shiny = (
                pool.get("front_shiny_female")
                or pool.get("front_female_shiny")
                or _build_pokeapi_sprite_url(sprite_id, gen, shiny=True, female=True)
            )
        else:
            # gen=None (no gen in request): use root sprites — always non-null
            # for existing Pokémon and represent the canonical current-gen artwork.
            game_front = sprites.get("front_default")
            game_front_shiny = sprites.get("front_shiny")
            game_front_female = sprites.get("front_female")
            game_front_female_shiny = (sprites.get("front_shiny_female")
                                       or sprites.get("front_female_shiny"))

        has_female_home = bool(home.get("front_female"))

        # Icon: prefer PokéAPI's own icon URL from the sprites object.
        # Fall back to overrides and constructed paths when the API returns null.
        icons_versions = sprites.get("versions") or {}
        gen8_icon_api = icons_versions.get("generation-viii", {}).get("icons", {}).get("front_default")
        # Gen 5 female icons use "{id}-female.png" suffix; read from response to avoid constructing wrong URL.
        gen5_icon_female_api = icons_versions.get("generation-v", {}).get("icons", {}).get("front_female")
        icon_override_id = self._variety_icon_id_overrides.get(variety_name)
        if gen8_icon_api:
            icon = gen8_icon_api
        elif icon_override_id:
            # Static override for varieties whose icon uses a different sprite_id
            # than either the variety ID or the base_id-suffix pattern
            # (e.g. calyrex-ice → 898-ice-rider, not 898-ice or 10193).
            icon = _build_icon_url(icon_override_id, gen)
        elif variety_name.endswith("-female") and base_pokemon_id is not None:
            icon = _build_icon_url(base_pokemon_id, gen, female=True)
        else:
            icon = _build_icon_url(variety_id, gen)

        return SpriteUrlsFull(
            official_artwork=artwork.get("front_default"),
            official_artwork_shiny=artwork.get("front_shiny"),
            official_artwork_female=artwork.get("front_female"),
            official_artwork_female_shiny=artwork.get("front_shiny_female"),
            home=home.get("front_default"),
            home_shiny=home.get("front_shiny"),
            home_female=home.get("front_female"),
            home_female_shiny=home.get("front_female_shiny") or home.get("front_shiny_female"),
            game_front=game_front,
            game_front_shiny=game_front_shiny,
            game_front_female=game_front_female,
            game_front_female_shiny=game_front_female_shiny,
            icon=icon,
            icon_shiny=game_front_shiny,
            icon_female=(
                gen5_icon_female_api  # PokéAPI response (gen 5 "{id}-female.png" naming)
                or (_build_icon_url(variety_id, gen, female=True) if has_female_home else None)
            ),
            icon_female_shiny=None,
        )

    def _build_form_sprite_urls(
        self,
        form_name: str,
        base_id: int,
        species_name: str,
        ps_name: str,
        gen: int,
        is_default_form: bool = False,
        pokeapi_home: str | None = None,
        pokeapi_home_shiny: str | None = None,
        pokeapi_oa: str | None = None,
    ) -> SpriteUrlsFull:
        """Build full sprite URLs for a cosmetic form-entry (no /pokemon resource).

        is_default_form=True: the form IS the base Pokémon (index 0 in forms[]).
        PokeAPI root sprites and Showdown HOME/dex directories store the default
        form under the base name — NOT the suffixed name:
          sprites/pokemon/201-a.png  → 404   sprites/pokemon/201.png  → ✓
          home/unown-a.png           → 404   home/unown.png           → ✓

        However, the versioned PokeAPI sprite directories (gen 2 Crystal animated,
        gen 5 BW animated) DO use the suffixed ID, so those paths keep the suffix
        regardless of is_default_form:
          crystal/animated/201-a.gif → ✓   crystal/animated/201.gif → 404

        Non-default forms (B–Z, !, ? for Unown) are unaffected — suffixed paths
        work consistently across all directories for those.
        """
        suffix = _extract_form_suffix(form_name, species_name)
        # Use the remapped suffix for PokeAPI sprites repo paths (icons, versioned
        # game sprites). The sprites repo uses shorter names for some forms.
        repo_suffix = _SPRITE_SUFFIX_REMAP.get(suffix, suffix)
        sprite_id = f"{base_id}-{repo_suffix}" if repo_suffix else str(base_id)

        # HOME and dex Showdown paths: default form uses base species name.
        home_ps_name = species_name if is_default_form else ps_name

        # Versioned PokeAPI sprites (primary) still use the suffixed sprite_id —
        # crystal/animated/201-a.gif is correct even for the default/A form.
        # Showdown fallback uses home_ps_name (base name for default form).
        game_front = (
            _build_pokeapi_sprite_url(sprite_id, gen)
            or _build_showdown_sprite_url(home_ps_name, gen)
        )
        game_front_shiny = (
            _build_pokeapi_sprite_url(sprite_id, gen, shiny=True)
            or _build_showdown_sprite_url(home_ps_name, gen, shiny=True)
        )

        # Prefer PokeAPI CDN (no CORS on web). Fall back to Showdown (works on
        # mobile/desktop but blocked by CORS policy in browsers).
        home_url = pokeapi_home or f"{_SHOWDOWN_CDN}/home/{home_ps_name}.png"
        home_shiny_url = pokeapi_home_shiny or f"{_SHOWDOWN_CDN}/home-shiny/{home_ps_name}.png"

        return SpriteUrlsFull(
            official_artwork=pokeapi_oa,
            official_artwork_shiny=None,
            home=home_url,
            home_shiny=home_shiny_url,
            home_female=None,
            home_female_shiny=None,
            game_front=game_front,
            game_front_shiny=game_front_shiny,
            game_front_female=None,
            game_front_female_shiny=None,
            # Female form entries live at icons/female/{base_id}.png, not
            # icons/{base_id}-female.png — use the female=True path for those.
            icon=_build_icon_url(base_id, gen, female=True) if repo_suffix == "female"
                 else _build_icon_url(sprite_id, gen),
            icon_shiny=game_front_shiny,
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
        self, varieties: list[dict], species_name: str, gen: int, base_url: str = "",
        base_pokemon_id: int | None = None,
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

        async def _fetch_variety(url: str) -> httpx.Response:
            async with self._pokeapi_semaphore:
                return await self._pokeapi_http.get(url)

        responses = await asyncio.gather(
            *[_fetch_variety(v["pokemon"]["url"]) for v in non_defaults],
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
                data.get("sprites") or {}, ps_sprite_name, variety_id, gen,
                variety_name=variety_name, base_pokemon_id=base_pokemon_id,
            )

            # Form classification from PokéAPI + registry lookups
            form_data_json = data  # the /pokemon/{variety_id} response
            # is_mega and is_battle_only come from the pokemon-form endpoint;
            # detect gmax by name since PokéAPI doesn't have an explicit flag.
            is_gmax = "gmax" in variety_name
            is_mega = self._mega_form_to_item.get(variety_name) is not None or \
                      self._mega_form_to_move.get(variety_name) is not None
            is_battle_only = is_mega or is_gmax  # all megas/gmax are battle-only
            associated_item = self._mega_form_to_item.get(variety_name)
            associated_move = self._mega_form_to_move.get(variety_name)
            associated_ability = self._form_to_ability.get(variety_name)

            result.append(VarietyData(
                name=variety_name,
                pokemon_id=variety_id,
                is_default=False,
                resolved_url=f"{base_url}/pokemon/{variety_id}/resolved",
                types=types,
                base_stats=base_stats,
                abilities=abilities,
                sprite_urls=sprite_urls,
                is_mega=is_mega,
                is_battle_only=is_battle_only,
                is_gmax=is_gmax,
                associated_item=associated_item,
                associated_move=associated_move,
                associated_ability=associated_ability,
            ))
        return result

    async def _fetch_forms(
        self, form_names: list[str], base_id: int, species_name: str, gen: int
    ) -> list[FormData]:
        """Fetch /pokemon-form/{name} for each non-default cosmetic form.

        The default form (index 0 / species name) is always excluded — it is the
        base Pokémon itself and is already represented by the top-level response.
        Returns [] for Pokémon with no cosmetic variants.
        """
        non_defaults = [n for n in form_names if n != species_name and n != form_names[0]]
        if not non_defaults:
            non_defaults = form_names[1:] if len(form_names) > 1 else []

        if not non_defaults:
            return []

        def _form_home_paths(fn: str) -> tuple[str, str]:
            """Return (home_url, home_shiny_url) for a form entry.

            Female forms live at home/female/{id}.png, not home/{id}-female.png —
            same subdirectory pattern as icons/female/{id}.png.
            All other forms use the {id}-{mapped_suffix}.png pattern.
            """
            sfx = _extract_form_suffix(fn, species_name)
            mapped = _SPRITE_SUFFIX_REMAP.get(sfx, sfx)
            if mapped == "female":
                return (
                    f"{_POKEAPI_HOME}/female/{base_id}.png",
                    f"{_POKEAPI_HOME}/shiny/female/{base_id}.png",
                )
            home_id = f"{base_id}-{mapped}" if mapped else str(base_id)
            return (
                f"{_POKEAPI_HOME}/{home_id}.png",
                f"{_POKEAPI_HOME}/shiny/{home_id}.png",
            )

        # Batch: form-data fetches + PokeAPI sprite CDN probes (home, home_shiny,
        # official-artwork). All run in parallel; probes are HEAD-only, cheap.
        def _form_oa_url(fn: str) -> str:
            sfx = _extract_form_suffix(fn, species_name)
            mapped = _SPRITE_SUFFIX_REMAP.get(sfx, sfx)
            oa_id = f"{base_id}-{mapped}" if mapped else str(base_id)
            return f"{_POKEAPI_OA}/{oa_id}.png"

        async def _fetch_form(name: str) -> httpx.Response:
            async with self._pokeapi_semaphore:
                return await self._pokeapi_http.get(f"{_POKEAPI_BASE}/pokemon-form/{name}")

        _home_paths = [_form_home_paths(n) for n in non_defaults]
        form_tasks = [_fetch_form(n) for n in non_defaults]
        home_tasks = [_probe_url(self._pokeapi_http, p[0]) for p in _home_paths]
        home_shiny_tasks = [_probe_url(self._pokeapi_http, p[1]) for p in _home_paths]
        oa_tasks = [_probe_url(self._pokeapi_http, _form_oa_url(n)) for n in non_defaults]

        all_results = await asyncio.gather(
            *form_tasks, *home_tasks, *home_shiny_tasks, *oa_tasks,
            return_exceptions=True,
        )

        _n = len(non_defaults)
        form_responses = all_results[:_n]
        home_results = all_results[_n:2 * _n]
        home_shiny_results = all_results[2 * _n:3 * _n]
        oa_results = all_results[3 * _n:]

        result: list[FormData] = []
        for i, form_name in enumerate(non_defaults):
            resp = form_responses[i]
            ps_name = _to_showdown_name(form_name, self._ps_exceptions)
            suffix = _extract_form_suffix(form_name, species_name)
            sprite_id = f"{base_id}-{suffix}" if suffix else str(base_id)
            # front_sprite_url: prefer PokeAPI form API front_default, fall back to
            # PokeAPI home (which exists for most forms), then constructed sprite path.
            # Female forms: sprites/pokemon uses female/ subdir, not {id}-female.png.
            repo_suffix = _SPRITE_SUFFIX_REMAP.get(suffix, suffix)
            if repo_suffix == "female":
                fallback_front = f"{_POKEAPI_PLAIN_SPRITES}/female/{base_id}.png"
            else:
                fallback_front = f"{_POKEAPI_PLAIN_SPRITES}/{sprite_id}.png"

            pokeapi_home = home_results[i] if not isinstance(home_results[i], Exception) else None
            pokeapi_home_shiny = home_shiny_results[i] if not isinstance(home_shiny_results[i], Exception) else None
            pokeapi_oa = oa_results[i] if not isinstance(oa_results[i], Exception) else None

            if isinstance(resp, Exception) or resp.status_code != 200:
                logger.warning("Failed to fetch form %s: %s", form_name, resp)
                # Even without form-API data we may have probed home sprites successfully.
                sprite_urls = self._build_form_sprite_urls(
                    form_name, base_id, species_name, ps_name, gen,
                    pokeapi_home=pokeapi_home,
                    pokeapi_home_shiny=pokeapi_home_shiny,
                    pokeapi_oa=pokeapi_oa,
                )
                result.append(FormData(
                    name=form_name, form_id=base_id, is_default=False,
                    front_sprite_url=pokeapi_home or fallback_front,
                    sprite_urls=sprite_urls,
                ))
                continue

            form_data_json = resp.json()
            api_front = (form_data_json.get("sprites") or {}).get("front_default") or pokeapi_home or fallback_front
            form_id = form_data_json.get("id", base_id)
            sprite_urls = self._build_form_sprite_urls(
                form_name, base_id, species_name, ps_name, gen,
                pokeapi_home=pokeapi_home,
                pokeapi_home_shiny=pokeapi_home_shiny,
                pokeapi_oa=pokeapi_oa,
            )
            result.append(FormData(
                name=form_name,
                form_id=form_id,
                is_default=False,
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
        response: "PokemonResolvedResponse",
        includes: list[str],
        gen: int | None = None,
        *,
        filter_to_gen: int | None = None,
    ) -> "PokemonResolvedResponse":
        """Strip expanded fields not requested via includes, and gen-gate smogon/moves.

        resolved_url on VarietyData and front_sprite_url on FormData are
        always preserved — they exist specifically to support the slim response.

        smogon_analyses is always filtered to the requested gen (even slim
        format-id-only entries). Pass gen=None to skip filtering.

        filter_to_gen: the original gen param from the request (not data_gen).
        When provided, moves dict is narrowed to {filter_to_gen: [...]} only.
        When None, all gens are returned.
        """
        if "varieties" not in includes:
            response = response.model_copy(update={
                "varieties": [
                    VarietyData(
                        name=v.name,
                        pokemon_id=v.pokemon_id,
                        is_default=v.is_default,
                        resolved_url=v.resolved_url,
                        # Always preserve classification flags in slim response
                        # so clients can detect megas/gmax without fetching full data.
                        is_mega=v.is_mega,
                        is_battle_only=v.is_battle_only,
                        is_gmax=v.is_gmax,
                        associated_item=v.associated_item,
                        associated_move=v.associated_move,
                        associated_ability=v.associated_ability,
                    )
                    for v in response.varieties
                ]
            })
        if "forms" not in includes:
            response = response.model_copy(update={
                "forms": [
                    FormData(name=f.name, form_id=f.form_id, front_sprite_url=f.front_sprite_url)
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
        if "moves" not in includes:
            response = response.model_copy(update={"moves": {}})
        elif filter_to_gen is not None:
            gen_entry = response.moves.get(filter_to_gen, [])
            response = response.model_copy(update={
                "moves": {filter_to_gen: gen_entry} if gen_entry else {}
            })
        if "flavor" not in includes:
            response = response.model_copy(update={"flavor_text_entries": []})
        return response

    # ------------------------------------------------------------------
    # Main resolution
    # ------------------------------------------------------------------

    async def resolve(
        self, pokemon_id: int, gen: int | None, includes: list[str], db: AsyncSession,
        base_url: str = "",
    ) -> PokemonResolvedResponse:
        # gen=None means "no specific gen requested" — use gen 9 accuracy for
        # types/stats but skip versioned game sprites (use plain root sprites instead).
        data_gen = gen if gen is not None else 9

        # 1. Cache hit (full data always stored)
        result = await db.execute(
            select(PokemonResolved).where(
                PokemonResolved.pokemon_id == pokemon_id,
                PokemonResolved.gen == data_gen,
                PokemonResolved.resolved_at
                + text("(ttl_days * interval '1 day')")
                > func.now(),
            )
        )
        row = result.scalar_one_or_none()
        if row:
            try:
                response = PokemonResolvedResponse(**row.data, resolved_at=row.resolved_at)
                return self._trim_response(response, includes, data_gen, filter_to_gen=gen)
            except Exception:
                pass  # stale cache format; fall through to re-fetch

        # 2. Fetch from PokéAPI
        try:
            pokemon_data, species_data, species_info = await self._fetch_pokeapi(pokemon_id)
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

        if data_gen < species_gen:
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
        types, base_stats, abilities = self._apply_gen_overrides(ps_id, ps_types, ps_stats, ps_abilities, data_gen)

        # --- New fields ---
        # abilities as typed list — use gen-overridden names, keep is_hidden from PokéAPI.
        # PS ability keys use "0"/"1"/"H" (0-indexed + hidden marker); PokéAPI uses "1"/"2"/"3".
        # _apply_gen_overrides preserves whichever format was passed in, so handle both.
        _PS_TO_SLOT = {"0": 1, "1": 2, "H": 3}
        pokeapi_ability_map = {
            str(a["slot"]): {"is_hidden": a.get("is_hidden", False)}
            for a in pokemon_data.get("abilities", [])
        }
        abilities_list = []
        for key, ability_name in abilities.items():
            if key in _PS_TO_SLOT:
                pokeapi_slot = _PS_TO_SLOT[key]
            elif key.isdigit():
                pokeapi_slot = int(key)
            else:
                continue
            is_hidden = pokeapi_ability_map.get(str(pokeapi_slot), {}).get("is_hidden", key == "H")
            # Showdown uses display names ("Sand Veil"); normalise to PokéAPI slug.
            ability_slug = ability_name.lower().replace(" ", "-")
            abilities_list.append(AbilityInfo(name=ability_slug, is_hidden=is_hidden, slot=pokeapi_slot))
        abilities_list.sort(key=lambda a: a.slot)

        # Build moves as {gen: [MoveSummary, ...]}; trimmed to {} unless "moves" in includes.
        # Side-game VGs (colosseum, xd, stadium, stadium-2) are excluded.
        # When the VG map is not loaded (e.g. in tests), all moves fall back to data_gen.
        _vg_map_loaded = bool(self._learnset_service._vg_to_gen)
        _moves_by_gen: dict[int, dict[str, list[MoveLearnDetail]]] = {}
        for _m in pokemon_data.get("moves", []):
            _move_name: str = _m["move"]["name"]
            for _d in _m.get("version_group_details", []):
                _vg: str = _d["version_group"]["name"]
                if _vg in _SIDE_GAME_VGS:
                    continue
                if _vg_map_loaded:
                    _g = self._learnset_service.version_group_to_gen(_vg)
                    if _g is None:
                        continue
                else:
                    _g = data_gen
                _moves_by_gen.setdefault(_g, {}).setdefault(_move_name, []).append(
                    MoveLearnDetail(
                        version_group=_vg,
                        method=_d["move_learn_method"]["name"],
                        level=_d.get("level_learned_at", 0),
                    )
                )
        moves_dict: dict[int, list[MoveSummary]] = {
            _g: [
                MoveSummary(name=_name, learn_details=_details)
                for _name, _details in sorted(_move_map.items())
            ]
            for _g, _move_map in sorted(_moves_by_gen.items())
        }

        # species detail fields
        genus = next(
            (g["genus"] for g in species_data.get("genera", []) if g["language"]["name"] == "en"),
            None,
        )
        generation_name = species_data.get("generation", {}).get("name", "generation-ix")
        gender_rate = species_data.get("gender_rate")
        capture_rate = species_data.get("capture_rate")
        base_happiness = species_data.get("base_happiness")
        hatch_counter = species_data.get("hatch_counter")
        growth_rate_obj = species_data.get("growth_rate")
        growth_rate = growth_rate_obj.get("name") if growth_rate_obj else None
        egg_groups = [e["name"] for e in species_data.get("egg_groups", [])]
        flavor_text_entries_list = [
            FlavorTextEntry(
                text=e["flavor_text"].replace("\n", " ").replace("\f", " "),
                language=e["language"]["name"],
                version=e["version"]["name"],
            )
            for e in species_data.get("flavor_text_entries", [])
        ]
        is_baby = species_data.get("is_baby", False)
        is_legendary = species_data.get("is_legendary", False)
        is_mythical = species_data.get("is_mythical", False)
        chain_url = (species_data.get("evolution_chain") or {}).get("url")
        evolution_chain_id: int | None = None
        if chain_url:
            try:
                evolution_chain_id = int(chain_url.rstrip("/").split("/")[-1])
            except (ValueError, IndexError):
                pass

        # 5. Merge supplement moves (event/egg/tutor absent from PokéAPI) into moves_dict.
        # Use only the moves PokéAPI already has for data_gen as the exclusion set —
        # a move present in a later gen but absent from data_gen should still be included.
        move_slugs: set[str] = {ms.name for ms in moves_dict.get(data_gen, [])}
        supplements = self._get_supplement_moves(ps_id, data_gen, move_slugs)
        if supplements:
            _existing_names = {ms.name for ms in moves_dict.get(data_gen, [])}
            _extra = [
                self._event_move_to_summary(ev, data_gen)
                for ev in supplements
                if ev.name not in _existing_names
            ]
            if _extra:
                moves_dict = dict(moves_dict)
                moves_dict[data_gen] = list(moves_dict.get(data_gen, [])) + _extra

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
        all_forms = pokemon_data.get("forms") or []
        first_form = all_forms[0].get("name", "") if all_forms else ""
        # Only apply a form suffix to the sprite ID when the pokemon actually
        # has multiple forms — this handles Unown where "201-a.gif" is needed
        # in Gen-2 Crystal but "201.gif" does not exist. For variety pokemon
        # like Rotom-Wash (10009), the variety ID alone identifies the sprite
        # file; there is no "10009-wash.png" in the sprites repo.
        first_form_suffix = (
            _extract_form_suffix(first_form, species_name)
            if first_form and len(all_forms) > 1
            else None
        )
        # "male"/"female" don't appear in versioned front sprite filenames —
        # gender-variant Pokémon use the plain ID with a female/ subdirectory.
        # (-female suffix exists only in gen-5 icons, handled by _build_icon_url.)
        if first_form_suffix in {"male", "female"}:
            first_form_suffix = None
        gen_sprite_id = f"{pokemon_id}-{first_form_suffix}" if first_form_suffix else None
        sprite_urls = self._build_base_sprite_urls(
            pokemon_data.get("sprites") or {}, ps_sprite_name, pokemon_id, gen,
            gen_sprite_id=gen_sprite_id,
        )

        # 8. Varieties (always fetched on cache miss, trimmed at response time)
        raw_varieties = species_data.get("varieties", [])
        varieties = await self._fetch_varieties(raw_varieties, species_name, data_gen, base_url, base_pokemon_id=pokemon_id)
        # When resolving a variety directly (e.g. charizard-mega-x = 10034),
        # the species varieties list includes the pokemon itself — exclude it.
        varieties = [v for v in varieties if v.pokemon_id != pokemon_id]

        # 9. Forms (form-entry cosmetics)
        form_names = [f["name"] for f in pokemon_data.get("forms", [])]
        forms = await self._fetch_forms(form_names, pokemon_id, species_name, data_gen)

        # 10. Build full response (cache always stores this)
        now = datetime.now(timezone.utc)
        response = PokemonResolvedResponse(
            pokemon_id=pokemon_id,
            gen=data_gen,
            name=pokemon_name,
            types=types,
            base_stats=base_stats,
            abilities=abilities_list,                         # changed: list[AbilityInfo]
            height=pokemon_data.get("height", 0),             # new
            weight=pokemon_data.get("weight", 0),             # new
            base_experience=pokemon_data.get("base_experience"),  # new
            species_name=species_data.get("name"),            # new
            moves=moves_dict,                                 # trimmed to {} by _trim_response
            moves_url=f"{base_url}/pokemon/{pokemon_id}/moves",
            smogon_analyses=smogon_analyses,
            smogon_url=f"{base_url}/pokemon/{pokemon_id}/smogon",
            varieties=varieties,
            varieties_url=f"{base_url}/pokemon/{pokemon_id}/varieties",
            forms=forms,
            forms_url=f"{base_url}/pokemon/{pokemon_id}/forms",
            sprite_urls=sprite_urls,
            resolved_at=now,
            genus=genus,                                      # new
            generation_name=generation_name,                  # new
            gender_rate=gender_rate,                          # new
            capture_rate=capture_rate,                        # new
            base_happiness=base_happiness,                    # new
            hatch_counter=hatch_counter,                      # new
            growth_rate=growth_rate,                          # new
            egg_groups=egg_groups,                            # new
            flavor_text_entries=flavor_text_entries_list,     # new (trimmed to [] by _trim_response)
            flavor_text_url=f"{base_url}/pokemon/{pokemon_id}/flavor-text",  # new
            is_baby=is_baby,
            is_legendary=is_legendary,
            is_mythical=is_mythical,
            # Form classification for this pokemon itself (relevant for variety pokemon)
            is_mega=self._mega_form_to_item.get(pokemon_name) is not None or
                    self._mega_form_to_move.get(pokemon_name) is not None,
            is_battle_only="gmax" in pokemon_name or
                           self._mega_form_to_item.get(pokemon_name) is not None or
                           self._mega_form_to_move.get(pokemon_name) is not None,
            is_gmax="gmax" in pokemon_name,
            associated_item=self._mega_form_to_item.get(pokemon_name),
            associated_move=self._mega_form_to_move.get(pokemon_name),
            associated_ability=self._form_to_ability.get(pokemon_name),
            evolution_chain_id=evolution_chain_id,
        )

        # 11. Upsert full data to cache
        data_dict = response.model_dump(mode="json")
        data_dict.pop("resolved_at", None)
        stmt = (
            pg_insert(PokemonResolved)
            .values(
                pokemon_id=pokemon_id,
                gen=data_gen,
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
        return self._trim_response(response, includes, data_gen, filter_to_gen=gen)

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

    async def resolve_moves(
        self, name_or_id: str, gen: int | None, db: AsyncSession, base_url: str = ""
    ) -> "MovesResponse":
        from app.schemas.pokemon_resolved import MovesResponse, MoveSummary
        pokemon_id = await self._resolve_name_or_id(name_or_id)
        full = await self.resolve(pokemon_id, gen, ["moves"], db, base_url)

        if gen is not None:
            # Supplements already merged into full.moves[gen] by resolve().
            gen_moves = list(full.moves.get(gen, []))
            return MovesResponse(
                pokemon_id=pokemon_id, name=full.name, gen=gen,
                moves={gen: gen_moves} if gen_moves else {},
            )

        # No-gen: full.moves is already {gen: [MoveSummary, ...]} for all gens.
        # Append per-gen supplement moves on top.
        all_moves: dict[int, list[MoveSummary]] = {g: list(ms) for g, ms in full.moves.items()}
        ps_name = full.name.replace("-", "").lower()
        for g in range(1, 10):
            existing_slugs = {ms.name for ms in all_moves.get(g, [])}
            supplements = self._get_supplement_moves(ps_name, g, existing_slugs)
            if supplements:
                summaries = [self._event_move_to_summary(ev, g) for ev in supplements]
                if g in all_moves:
                    all_moves[g].extend(summaries)
                else:
                    all_moves[g] = summaries

        return MovesResponse(pokemon_id=pokemon_id, name=full.name, gen=None, moves=all_moves)

    async def resolve_flavor_text(
        self, name_or_id: str, lang: str | None, db: AsyncSession, base_url: str = ""
    ) -> "FlavorTextResponse":
        from app.schemas.pokemon_resolved import FlavorTextResponse
        pokemon_id = await self._resolve_name_or_id(name_or_id)

        result = await db.execute(
            select(PokemonResolved).where(
                PokemonResolved.pokemon_id == pokemon_id,
                PokemonResolved.gen == 9,
                PokemonResolved.resolved_at
                + text("(ttl_days * interval '1 day')")
                > func.now(),
            )
        )
        row = result.scalar_one_or_none()
        if row and row.data.get("flavor_text_entries"):
            entries = row.data["flavor_text_entries"]
            if lang:
                entries = [e for e in entries if e.get("language") == lang]
            return FlavorTextResponse(
                pokemon_id=pokemon_id,
                name=row.data.get("name", ""),
                flavor_text_entries=entries,
            )

        full = await self.resolve(pokemon_id, 9, ["flavor"], db, base_url)
        filtered = (
            [e for e in full.flavor_text_entries if e.language == lang]
            if lang else full.flavor_text_entries
        )
        return FlavorTextResponse(
            pokemon_id=pokemon_id, name=full.name, flavor_text_entries=filtered
        )

    async def _fetch_pokeapi(self, pokemon_id: int) -> tuple[dict, dict, dict]:
        """Returns (pokemon_data, species_data, meta) where meta = {english_name, gen, species_name}."""
        async with self._pokeapi_semaphore:
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

        return pokemon_data, species_data, {
            "english_name": english_name,
            "gen": gen_num,
            "species_name": species_name,
        }


def _smogon_display_name(pokeapi_pokemon_name: str, english_species_name: str) -> str:
    species_slug = english_species_name.lower().replace(" ", "-").replace(".", "").replace("'", "")
    if pokeapi_pokemon_name == species_slug or pokeapi_pokemon_name == species_slug.replace("-", ""):
        return english_species_name
    return "-".join(w.title() for w in pokeapi_pokemon_name.split("-"))


pokemon_resolver_service = PokemonResolverService()
