"""
learnset_service.py — In-memory per-gen learnset index from shared/ps_data/.

Loaded at startup by PokemonResolverService.load_ps_data().
Provides get_learnset(ps_name, gen) for supplement-move lookups.
"""

import json
import logging
import os
import re

logger = logging.getLogger(__name__)

# Maps PokéAPI version-group slugs to their generation number.
# Mirrors PokemonDataRegistry.genToVersionGroups on the Flutter frontend.
VERSION_GROUP_TO_GEN: dict[str, int] = {
    # Gen 1
    "red-blue": 1,
    "yellow": 1,
    # Gen 2
    "gold-silver": 2,
    "crystal": 2,
    # Gen 3
    "ruby-sapphire": 3,
    "emerald": 3,
    "firered-leafgreen": 3,
    "colosseum": 3,
    "xd": 3,
    # Gen 4
    "diamond-pearl": 4,
    "platinum": 4,
    "heartgold-soulsilver": 4,
    # Gen 5
    "black-white": 5,
    "black-2-white-2": 5,
    # Gen 6
    "x-y": 6,
    "omega-ruby-alpha-sapphire": 6,
    # Gen 7
    "sun-moon": 7,
    "ultra-sun-ultra-moon": 7,
    "lets-go-pikachu-lets-go-eevee": 7,
    # Gen 8
    "sword-shield": 8,
    "brilliant-diamond-and-shining-pearl": 8,
    "legends-arceus": 8,
    # Gen 9
    "scarlet-violet": 9,
}

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


def version_group_to_gen(version_group: str) -> int | None:
    """Return the generation for a PokéAPI version-group slug, or None if unknown."""
    return VERSION_GROUP_TO_GEN.get(version_group)


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
    """

    def __init__(self) -> None:
        # _learnsets[gen] = {ps_id: {move_id: [source_dict, …]}}
        self._learnsets: dict[int, dict[str, dict[str, list[dict]]]] = {}

    def load(self, ps_data_dir: str) -> None:
        """Load learnset_1.json … learnset_9.json from ps_data_dir into memory."""
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
