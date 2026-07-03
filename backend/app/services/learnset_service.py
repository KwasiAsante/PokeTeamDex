"""
learnset_service.py — In-memory per-gen learnset index from shared/ps_data/.

Loaded at startup by PokemonResolverService.load_ps_data().
Provides get_learnset(ps_name, gen) for supplement-move lookups and
version_group_to_gen(vg) for mapping PokéAPI version-group slugs to gens.
The version-group→gen map is derived from genToVersionGroups in
pokemon_registry.json rather than hardcoded, so the two stay in sync.
"""

import json
import logging
import os
import re

logger = logging.getLogger(__name__)

# Points to shared/ at the project root.
# Default "../shared" works when running uvicorn from backend/ locally.
# In Docker the env var is set explicitly to /app/shared.
_SHARED_DIR = os.environ.get("SHARED_DIR", "../shared")

# Canonical form of regional adjectives as they appear as learnset key suffixes.
# Maps both the bare region name and its adjectival form to the canonical suffix.
_REGION_CANONICAL: dict[str, str] = {
    "alola": "alola",
    "alolan": "alola",
    "galar": "galar",
    "galarian": "galar",
    "hisui": "hisui",
    "hisuian": "hisui",
    "paldea": "paldea",
    "paldean": "paldea",
}


def normalize_ps_id(name: str) -> list[str]:
    """Return lookup candidates for a PS learnset key from a Pokémon name.

    PS learnset keys use the no-separator lowercase format (e.g. 'vulpixalola').
    Returns candidates in priority order so the lookup short-circuits early.

    Candidates tried:
    1. No separators (primary PS format): vulpixalola
    2. As-is lowercase: vulpix-alola
    3. Underscored: vulpix_alola
    4. Spaced: vulpix alola
    5. Regional-prefix reversal: alolan-vulpix → vulpixalola
    """
    clean = name.strip().lower()
    no_sep = re.sub(r"[-_ ]", "", clean)
    candidates: list[str] = [
        no_sep,
        clean,
        clean.replace("-", "_"),
        clean.replace("-", " "),
    ]

    # Detect "region-species" prefix ordering (e.g. "alola-vulpix", "alolan-vulpix")
    # and append the reversed "speciesregion" form.
    parts = re.split(r"[-_ ]", clean)
    if len(parts) >= 2:
        canonical = _REGION_CANONICAL.get(parts[0])
        if canonical:
            species = "".join(parts[1:])
            candidates.append(species + canonical)

    seen: set[str] = set()
    result: list[str] = []
    for c in candidates:
        if c not in seen:
            seen.add(c)
            result.append(c)
    return result


class LearnsetService:
    """Holds all per-gen learnset data loaded from learnset_1.json … learnset_9.json.

    Each learnset file maps PS Pokémon IDs to their learnable moves for that
    generation. Entries have the shape::

        {
          "ps_id": {
            "move_id": [{"method": "level_up", "level": 10}, ...]
          }
        }

    ``via_prevo`` is pre-computed by the sync script so no chain traversal is
    needed at query time.

    The version-group→gen map is derived from ``genToVersionGroups`` in
    ``pokemon_registry.json`` rather than hardcoded here.
    """

    def __init__(self) -> None:
        # _learnsets[gen] = {ps_id: {move_id: [source_dict, …]}}
        self._learnsets: dict[int, dict[str, dict[str, list[dict]]]] = {}
        # version_group_slug → gen number (populated by load())
        self._vg_to_gen: dict[str, int] = {}
        # gen → canonical last version-group for that gen (e.g. 9 → "scarlet-violet")
        self._gen_to_last_vg: dict[int, str] = {}

    def load(self, ps_data_dir: str) -> None:
        """Load learnset_1.json … learnset_9.json and derive the VG→gen map from the registry."""
        self._load_vg_map()
        self._load_learnset_files(ps_data_dir)

    def _load_vg_map(self) -> None:
        registry_path = os.path.join(_SHARED_DIR, "pokemon_registry.json")
        if not os.path.exists(registry_path):
            logger.warning(
                "pokemon_registry.json not found at %s — version_group_to_gen will return None for all inputs",
                registry_path,
            )
            return
        try:
            with open(registry_path, encoding="utf-8") as f:
                registry = json.load(f)
            vg_map: dict[str, int] = {}
            for gen_str, vg_list in registry.get("genToVersionGroups", {}).items():
                gen = int(gen_str)
                for vg in vg_list:
                    vg_map[vg] = gen
            self._vg_to_gen = vg_map
            self._gen_to_last_vg = {
                int(gen_str): vg
                for gen_str, vg in registry.get("genToLastVg", {}).items()
            }
            logger.info(
                "Derived version-group→gen map (%d entries) and gen→last-vg map (%d entries) from registry",
                len(vg_map),
                len(self._gen_to_last_vg),
            )
        except (json.JSONDecodeError, ValueError, OSError) as exc:
            logger.warning("Failed to load genToVersionGroups from registry: %s", exc)

    def _load_learnset_files(self, ps_data_dir: str) -> None:
        loaded = 0
        for gen in range(1, 10):
            path = os.path.join(ps_data_dir, f"learnset_{gen}.json")
            if os.path.exists(path):
                with open(path, encoding="utf-8") as f:
                    self._learnsets[gen] = json.load(f)
                logger.info(
                    "Loaded learnset_%d.json (%d entries)", gen, len(self._learnsets[gen])
                )
                loaded += 1
            else:
                logger.warning(
                    "learnset_%d.json not found — run scripts/sync_ps_data.py", gen
                )
        logger.info("LearnsetService ready: %d/9 gen files loaded", loaded)

    def version_group_to_gen(self, version_group: str) -> int | None:
        """Return the generation for a PokéAPI version-group slug, or None if unknown."""
        return self._vg_to_gen.get(version_group)

    def last_vg_for_gen(self, gen: int) -> str | None:
        """Return the canonical last version-group slug for a generation (e.g. 9 → 'scarlet-violet')."""
        return self._gen_to_last_vg.get(gen)

    def get_learnset(self, ps_name: str, gen: int) -> dict[str, list[dict]]:
        """Return the learnset entry for ps_name in gen, or {} if not found.

        Tries multiple name variants via normalize_ps_id so hyphenated PokéAPI
        names and regional prefix orderings are handled transparently.

        Args:
            ps_name: PS Pokémon ID (e.g. 'vulpixalola', 'vulpix-alola',
                     'alolan-vulpix' — all resolve to the same entry).
            gen: Generation number (1–9).

        Returns:
            Dict of move_id → list of source dicts, e.g.
            ``{"freezedry": [{"method": "level_up", "level": 1, "via_prevo": "vulpixalola"}]}``.
            Empty dict if the Pokémon has no entry in that gen file.
        """
        gen_data = self._learnsets.get(gen, {})
        for candidate in normalize_ps_id(ps_name):
            entry = gen_data.get(candidate)
            if entry is not None:
                return entry
        return {}
