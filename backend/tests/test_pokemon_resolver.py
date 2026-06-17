"""Unit tests for PokemonResolverService logic.

These tests cover the pure-Python methods — no database, no network.
The service's data attributes are populated manually with minimal fixtures
that mirror the shapes produced by sync_ps_data.py.
"""

import pytest

from app.services.pokemon_resolver import (
    PokemonResolverService,
    _ps_name,
    _smogon_display_name,
)
from app.schemas.pokemon_resolved import SpriteUrls


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_service(
    pokedex: dict | None = None,
    overrides: dict | None = None,
    event_learnsets: dict | None = None,
    moves_index: dict | None = None,
    smogon_sets: dict | None = None,
    smogon_analyses: dict | None = None,
    smogon_loaded: bool = True,
) -> PokemonResolverService:
    svc = PokemonResolverService()
    svc._ps_pokedex = pokedex or {}
    svc._ps_pokedex_overrides = overrides or {}
    svc._event_learnsets = event_learnsets or {}
    svc._moves_index = moves_index or {}
    svc._smogon_sets = smogon_sets or {}
    svc._smogon_analyses = smogon_analyses or {}
    svc._smogon_loaded = smogon_loaded
    return svc


# ---------------------------------------------------------------------------
# _ps_name
# ---------------------------------------------------------------------------

class TestPsName:
    def test_simple(self):
        assert _ps_name("venusaur") == "venusaur"

    def test_strips_hyphens(self):
        assert _ps_name("giratina-origin") == "giratinaorigin"

    def test_mr_mime(self):
        assert _ps_name("mr-mime") == "mrmime"

    def test_tapu_koko(self):
        assert _ps_name("tapu-koko") == "tapukoko"


# ---------------------------------------------------------------------------
# _smogon_display_name
# ---------------------------------------------------------------------------

class TestSmogonDisplayName:
    def test_base_species(self):
        assert _smogon_display_name("venusaur", "Venusaur") == "Venusaur"

    def test_form_variant(self):
        # "giratina-origin" with species "Giratina" → form name title-cased
        result = _smogon_display_name("giratina-origin", "Giratina")
        assert result == "Giratina-Origin"

    def test_rotom_wash(self):
        result = _smogon_display_name("rotom-wash", "Rotom")
        assert result == "Rotom-Wash"

    def test_species_name_with_special_chars(self):
        # "mr-mime" species name is "Mr. Mime"; species slug normalises to "mr-mime"
        result = _smogon_display_name("mr-mime", "Mr. Mime")
        assert result == "Mr. Mime"


# ---------------------------------------------------------------------------
# _apply_gen_overrides — cascade logic
# ---------------------------------------------------------------------------

class TestApplyGenOverrides:
    # Fairy type was introduced in Gen 6.  gen5/clefairy has types: ["Normal"].
    # Gen 4 has no Clefairy entry, so it must cascade to gen5's override.
    _OVERRIDES = {
        "gen5": {
            "clefairy": {"types": ["Normal"]},
            "mrmime": {"types": ["Psychic"]},
        },
        "gen4": {
            "rotomwash": {"types": ["Electric", "Ghost"]},
        },
        "gen1": {
            "charizard": {"baseStats": {"hp": 78, "atk": 84, "def": 78,
                                         "spa": 85, "spd": 85, "spe": 100}},
            "clefairy": {"baseStats": {"hp": 70, "atk": 45, "def": 48,
                                        "spa": 60, "spd": 60, "spe": 35}},
        },
    }
    _BASE_CLEFAIRY_TYPES = ["Normal", "Fairy"]   # modern base
    _BASE_CLEFAIRY_STATS = {"hp": 70, "atk": 45, "def": 48,
                             "spa": 95, "spd": 90, "spe": 60}  # modern
    _BASE_CHARIZARD_STATS = {"hp": 78, "atk": 84, "def": 78,
                              "spa": 109, "spd": 85, "spe": 100}

    def _svc(self):
        return _make_service(overrides=self._OVERRIDES)

    # --- type changes ---

    def test_clefairy_gen5_is_normal(self):
        svc = self._svc()
        types, _, _ = svc._apply_gen_overrides(
            "clefairy", self._BASE_CLEFAIRY_TYPES, self._BASE_CLEFAIRY_STATS, {}, 5
        )
        assert types == ["Normal"]

    def test_clefairy_gen4_cascades_to_gen5_normal(self):
        """gen4 has no Clefairy entry — must cascade up and use gen5's Normal."""
        svc = self._svc()
        types, _, _ = svc._apply_gen_overrides(
            "clefairy", self._BASE_CLEFAIRY_TYPES, self._BASE_CLEFAIRY_STATS, {}, 4
        )
        assert types == ["Normal"]

    def test_clefairy_gen1_cascades_to_gen5_normal(self):
        """gen1 has only a baseStats override for Clefairy, not types.
        Types should still cascade to gen5's Normal."""
        svc = self._svc()
        types, _, _ = svc._apply_gen_overrides(
            "clefairy", self._BASE_CLEFAIRY_TYPES, self._BASE_CLEFAIRY_STATS, {}, 1
        )
        assert types == ["Normal"]

    def test_clefairy_gen6_uses_base_fairy(self):
        """gen6 is when Fairy was introduced — no override means use base."""
        svc = self._svc()
        types, _, _ = svc._apply_gen_overrides(
            "clefairy", self._BASE_CLEFAIRY_TYPES, self._BASE_CLEFAIRY_STATS, {}, 6
        )
        assert types == ["Normal", "Fairy"]

    def test_clefairy_gen9_uses_base_fairy(self):
        svc = self._svc()
        types, _, _ = svc._apply_gen_overrides(
            "clefairy", self._BASE_CLEFAIRY_TYPES, self._BASE_CLEFAIRY_STATS, {}, 9
        )
        assert types == ["Normal", "Fairy"]

    # --- stat changes ---

    def test_charizard_gen1_uses_original_spa(self):
        svc = self._svc()
        _, stats, _ = svc._apply_gen_overrides(
            "charizard", ["Fire", "Flying"], self._BASE_CHARIZARD_STATS, {}, 1
        )
        assert stats["spa"] == 85

    def test_charizard_gen2_uses_modern_spa(self):
        """No override in gen2+; should fall through to modern base."""
        svc = self._svc()
        _, stats, _ = svc._apply_gen_overrides(
            "charizard", ["Fire", "Flying"], self._BASE_CHARIZARD_STATS, {}, 2
        )
        assert stats["spa"] == 109

    # --- appliance-form type change (gen4 → gen5) ---

    def test_rotom_wash_gen4_is_ghost(self):
        svc = self._svc()
        types, _, _ = svc._apply_gen_overrides(
            "rotomwash", ["Electric", "Water"], {}, {}, 4
        )
        assert types == ["Electric", "Ghost"]

    def test_rotom_wash_gen5_uses_base_water(self):
        """gen5 has no Rotom-Wash override, so it uses the modern Electric/Water."""
        svc = self._svc()
        types, _, _ = svc._apply_gen_overrides(
            "rotomwash", ["Electric", "Water"], {}, {}, 5
        )
        assert types == ["Electric", "Water"]

    # --- pokemon with no override at all ---

    def test_bulbasaur_gen1_uses_base(self):
        base_types = ["Grass", "Poison"]
        base_stats = {"hp": 45, "atk": 49, "def": 49, "spa": 65, "spd": 65, "spe": 45}
        svc = self._svc()
        types, stats, _ = svc._apply_gen_overrides(
            "bulbasaur", base_types, base_stats, {}, 1
        )
        assert types == base_types
        assert stats == base_stats

    # --- cascading stops at first match per field ---

    def test_gen1_clefairy_types_from_gen5_and_stats_from_gen1(self):
        """gen1 has only baseStats for Clefairy; types must come from gen5 cascade."""
        svc = self._svc()
        types, stats, _ = svc._apply_gen_overrides(
            "clefairy", self._BASE_CLEFAIRY_TYPES, self._BASE_CLEFAIRY_STATS, {}, 1
        )
        assert types == ["Normal"]
        # gen1 has an explicit baseStats override for Clefairy
        assert stats["spa"] == 60   # original, not modern 95


# ---------------------------------------------------------------------------
# _get_event_moves
# ---------------------------------------------------------------------------

class TestGetEventMoves:
    _EVENT_LEARNSETS = {
        "dratini": {
            "learnset": {
                # extremespeed only exists as a Gen 2 event ("2S1") — not in PokéAPI
                "extremespeed": ["2S1"],
                # wrap is in PokéAPI's normal learnset
                "wrap": ["1L1", "2L1"],
                # bind appears only via normal methods
                "bind": ["3L20", "4L20"],
            }
        }
    }
    _MOVES_INDEX = {
        "extremespeed": {"name": "Extreme Speed", "gen": 1},
        "wrap": {"name": "Wrap", "gen": 1},
    }

    def test_extremespeed_returned_as_event_move(self):
        svc = _make_service(
            event_learnsets=self._EVENT_LEARNSETS,
            moves_index=self._MOVES_INDEX,
        )
        # PokéAPI knows about wrap but not extremespeed
        result = svc._get_event_moves("dratini", {"wrap", "bind"})
        names = [m.name for m in result]
        assert "extremespeed" in names

    def test_wrap_excluded_because_pokeapi_has_it(self):
        svc = _make_service(
            event_learnsets=self._EVENT_LEARNSETS,
            moves_index=self._MOVES_INDEX,
        )
        result = svc._get_event_moves("dratini", {"wrap"})
        names = [m.name for m in result]
        assert "wrap" not in names

    def test_bind_excluded_because_no_s_source(self):
        """bind has level-up sources but no S (event) source — must be excluded."""
        svc = _make_service(
            event_learnsets=self._EVENT_LEARNSETS,
            moves_index=self._MOVES_INDEX,
        )
        result = svc._get_event_moves("dratini", set())
        names = [m.name for m in result]
        assert "bind" not in names

    def test_event_move_generations_extracted(self):
        svc = _make_service(
            event_learnsets=self._EVENT_LEARNSETS,
            moves_index=self._MOVES_INDEX,
        )
        result = svc._get_event_moves("dratini", set())
        extremespeed = next(m for m in result if m.name == "extremespeed")
        assert extremespeed.generations == [2]

    def test_display_name_from_moves_index(self):
        svc = _make_service(
            event_learnsets=self._EVENT_LEARNSETS,
            moves_index=self._MOVES_INDEX,
        )
        result = svc._get_event_moves("dratini", set())
        extremespeed = next(m for m in result if m.name == "extremespeed")
        assert extremespeed.display_name == "Extreme Speed"

    def test_pokeapi_slug_with_hyphen_excluded_correctly(self):
        """PokéAPI uses hyphens (acid-spray); Showdown uses acidspray.
        The service must strip hyphens before comparing."""
        learnsets = {
            "bulbasaur": {
                "learnset": {
                    "acidspray": ["5S0"],  # event only
                }
            }
        }
        svc = _make_service(event_learnsets=learnsets)
        # PokéAPI gives us "acid-spray"; should match "acidspray" and exclude it
        result = svc._get_event_moves("bulbasaur", {"acid-spray"})
        assert result == []

    def test_returns_empty_for_unknown_pokemon(self):
        svc = _make_service(event_learnsets=self._EVENT_LEARNSETS)
        assert svc._get_event_moves("unknownmon", set()) == []

    def test_multi_gen_event_move(self):
        learnsets = {
            "mew": {
                "learnset": {
                    "transform": ["1S0", "3S1", "7S2"],
                }
            }
        }
        svc = _make_service(event_learnsets=learnsets)
        result = svc._get_event_moves("mew", set())
        assert len(result) == 1
        assert sorted(result[0].generations) == [1, 3, 7]


# ---------------------------------------------------------------------------
# _get_smogon_analyses
# ---------------------------------------------------------------------------

class TestGetSmogonAnalyses:
    _SETS = {
        "gen9ou": {
            "Venusaur": {
                "Sun Sweeper": {
                    "moves": ["Growth", "Giga Drain"],
                    "ability": "Chlorophyll",
                    "item": "Life Orb",
                    "nature": "Timid",
                    "evs": {"spa": 252, "spe": 252, "def": 4},
                    "teratypes": ["Fire"],
                }
            }
        }
    }
    _ANALYSES = {
        "gen9ou": {
            "Venusaur": {
                "sets": {
                    "Sun Sweeper": {"description": "<p>Good in sun.</p>"}
                }
            }
        }
    }

    def test_returns_none_when_not_loaded(self):
        svc = _make_service(
            smogon_sets=self._SETS,
            smogon_analyses=self._ANALYSES,
            smogon_loaded=False,
        )
        assert svc._get_smogon_analyses("Venusaur") is None

    def test_returns_data_when_loaded(self):
        svc = _make_service(
            smogon_sets=self._SETS,
            smogon_analyses=self._ANALYSES,
        )
        result = svc._get_smogon_analyses("Venusaur")
        assert result is not None
        assert len(result) == 1
        assert result[0].format_id == "gen9ou"

    def test_set_fields_populated(self):
        svc = _make_service(
            smogon_sets=self._SETS,
            smogon_analyses=self._ANALYSES,
        )
        result = svc._get_smogon_analyses("Venusaur")
        sun_sweeper = result[0].sets["Sun Sweeper"]
        assert sun_sweeper.ability == "Chlorophyll"
        assert sun_sweeper.item == "Life Orb"
        assert "Growth" in sun_sweeper.moves

    def test_description_merged_from_analyses(self):
        svc = _make_service(
            smogon_sets=self._SETS,
            smogon_analyses=self._ANALYSES,
        )
        result = svc._get_smogon_analyses("Venusaur")
        assert result[0].sets["Sun Sweeper"].description == "<p>Good in sun.</p>"

    def test_returns_none_for_pokemon_with_no_sets(self):
        svc = _make_service(
            smogon_sets=self._SETS,
            smogon_analyses=self._ANALYSES,
        )
        assert svc._get_smogon_analyses("Missingno") is None

    def test_returns_none_empty_list_coerced_to_none(self):
        svc = _make_service(smogon_sets={}, smogon_analyses={})
        assert svc._get_smogon_analyses("Venusaur") is None


# ---------------------------------------------------------------------------
# _build_sprite_urls
# ---------------------------------------------------------------------------

class TestBuildSpriteUrls:
    def test_full_sprites_object(self):
        sprites = {
            "other": {
                "official-artwork": {
                    "front_default": "https://example.com/artwork/3.png",
                    "front_shiny": "https://example.com/artwork/shiny/3.png",
                },
                "home": {
                    "front_default": "https://example.com/home/3.png",
                    "front_shiny": "https://example.com/home/shiny/3.png",
                    "front_female": None,
                },
            }
        }
        result = PokemonResolverService._build_sprite_urls(sprites)
        assert result.official_artwork == "https://example.com/artwork/3.png"
        assert result.official_artwork_shiny == "https://example.com/artwork/shiny/3.png"
        assert result.home == "https://example.com/home/3.png"
        assert result.home_shiny == "https://example.com/home/shiny/3.png"
        assert result.home_female is None

    def test_empty_sprites_returns_all_none(self):
        result = PokemonResolverService._build_sprite_urls({})
        assert result.official_artwork is None
        assert result.home is None

    def test_missing_other_key(self):
        result = PokemonResolverService._build_sprite_urls({"front_default": "x.png"})
        assert result.official_artwork is None
