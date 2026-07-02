"""Unit tests for sync_ps_data.py transformation functions.

These test the pure data-transformation logic that runs inside sync_ps_data.py
without requiring network access.
"""

import re
import sys
import os

import pytest

# Make scripts/ importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "scripts"))

from sync_ps_data import (
    transform_pokedex,
    transform_pokedex_mods,
    transform_formats_data,
    transform_moves,
)


# ---------------------------------------------------------------------------
# Numeric key quoting (used inside fetch_js_endpoint)
# ---------------------------------------------------------------------------

class TestNumericKeyQuoting:
    """Verify the regex used to quote numeric property keys before json5 parsing."""

    _PATTERN = re.compile(r"\b(\d+)\s*:")

    def _quote(self, text: str) -> str:
        return self._PATTERN.sub(r'"\1":', text)

    def test_quotes_ability_slot_zero(self):
        raw = '{ 0: "Overgrow", H: "Chlorophyll" }'
        assert self._quote(raw) == '{ "0": "Overgrow", H: "Chlorophyll" }'

    def test_quotes_slot_one(self):
        raw = '{ 0: "A", 1: "B", H: "C" }'
        result = self._quote(raw)
        assert '"0":' in result
        assert '"1":' in result
        assert 'H:' in result  # unquoted string key unchanged

    def test_does_not_quote_numeric_values(self):
        """Values like `num: 1` must not be altered."""
        raw = "num: 1, base: 45"
        result = self._quote(raw)
        assert result == "num: 1, base: 45"


# ---------------------------------------------------------------------------
# transform_pokedex
# ---------------------------------------------------------------------------

class TestTransformPokedex:
    _RAW = {
        "bulbasaur": {
            "num": 1,
            "name": "Bulbasaur",
            "types": ["Grass", "Poison"],
            "genderRatio": {"M": 0.875, "F": 0.125},
            "baseStats": {"hp": 45, "atk": 49, "def": 49, "spa": 65, "spd": 65, "spe": 45},
            "abilities": {"0": "Overgrow", "H": "Chlorophyll"},
            "heightm": 0.7,
            "weightkg": 6.9,
            "color": "Green",
            "evos": ["Ivysaur"],
            "eggGroups": ["Monster", "Grass"],
        },
        "venusaurmega": {
            "num": 3,
            "name": "Venusaur-Mega",
            "baseSpecies": "Venusaur",
            "forme": "Mega",
            "types": ["Grass", "Poison"],
            "baseStats": {"hp": 80, "atk": 100, "def": 123, "spa": 122, "spd": 120, "spe": 80},
            "abilities": {"0": "Thick Fat"},
        },
        # CAP Pokémon — should be filtered out
        "syclant": {
            "num": 1,
            "name": "Syclant",
            "types": ["Ice", "Bug"],
            "baseStats": {"hp": 70, "atk": 116, "def": 70, "spa": 114, "spd": 64, "spe": 121},
            "abilities": {"0": "Compound Eyes"},
            "isNonstandard": "CAP",
        },
        # Negative num — should be filtered
        "missingno": {
            "num": -1,
            "name": "Missingno.",
            "types": ["Normal", "Bird"],
            "baseStats": {"hp": 33, "atk": 136, "def": 0, "spa": 6, "spd": 6, "spe": 29},
            "abilities": {},
        },
    }

    def test_includes_real_pokemon(self):
        result = transform_pokedex(self._RAW)
        assert "bulbasaur" in result
        assert "venusaurmega" in result

    def test_excludes_cap(self):
        result = transform_pokedex(self._RAW)
        assert "syclant" not in result

    def test_excludes_negative_num(self):
        result = transform_pokedex(self._RAW)
        assert "missingno" not in result

    def test_entry_fields(self):
        result = transform_pokedex(self._RAW)
        entry = result["bulbasaur"]
        assert entry["num"] == 1
        assert entry["name"] == "Bulbasaur"
        assert entry["types"] == ["Grass", "Poison"]
        assert entry["baseStats"]["hp"] == 45
        assert entry["abilities"]["0"] == "Overgrow"
        assert entry["abilities"]["H"] == "Chlorophyll"

    def test_no_extra_fields(self):
        """Only the fields we keep should be present (no heightm, weightkg, etc.)."""
        result = transform_pokedex(self._RAW)
        entry = result["bulbasaur"]
        assert "heightm" not in entry
        assert "weightkg" not in entry
        assert "genderRatio" not in entry
        assert "eggGroups" not in entry


# ---------------------------------------------------------------------------
# transform_pokedex_mods
# ---------------------------------------------------------------------------

class TestTransformPokedexMods:
    _MOD_RAWS = {
        5: {
            "clefairy": {
                "inherit": True,
                "types": ["Normal"],
            },
            "mrmime": {
                "inherit": True,
                "types": ["Psychic"],
            },
        },
        1: {
            "charizard": {
                "inherit": True,
                "baseStats": {"hp": 78, "atk": 84, "def": 78,
                               "spa": 85, "spd": 85, "spe": 100},
            },
            # Entry WITHOUT inherit — should be skipped
            "somefakemon": {
                "types": ["Fire"],
            },
        },
    }

    def test_gens_present(self):
        result = transform_pokedex_mods(self._MOD_RAWS)
        assert "gen1" in result
        assert "gen5" in result

    def test_type_override_stored(self):
        result = transform_pokedex_mods(self._MOD_RAWS)
        assert result["gen5"]["clefairy"]["types"] == ["Normal"]

    def test_stat_override_stored(self):
        result = transform_pokedex_mods(self._MOD_RAWS)
        assert result["gen1"]["charizard"]["baseStats"]["spa"] == 85

    def test_entry_without_inherit_excluded(self):
        """Entries without `inherit: true` are not deltas — skip them."""
        result = transform_pokedex_mods(self._MOD_RAWS)
        assert "somefakemon" not in result.get("gen1", {})

    def test_non_battle_fields_excluded(self):
        """Fields like color, heightm etc. must not appear in overrides."""
        mod_raws = {
            3: {
                "pikachu": {
                    "inherit": True,
                    "types": ["Electric"],
                    "color": "Yellow",   # should be excluded
                    "heightm": 0.4,      # should be excluded
                }
            }
        }
        result = transform_pokedex_mods(mod_raws)
        entry = result["gen3"]["pikachu"]
        assert "types" in entry
        assert "color" not in entry
        assert "heightm" not in entry

    def test_empty_mod_gen_not_included(self):
        """A gen whose overrides produce no entries should not appear in output."""
        mod_raws = {
            2: {
                "unown": {
                    "inherit": True,
                    # no fields we care about
                }
            }
        }
        result = transform_pokedex_mods(mod_raws)
        assert "gen2" not in result


# ---------------------------------------------------------------------------
# transform_formats_data
# ---------------------------------------------------------------------------

class TestTransformFormatsData:
    _RAW = {
        "venusaur": {"tier": "UU", "doublesTier": "DOU"},
        "clefable": {"tier": "OU", "nfe": False},
        "charizardmegax": {"tier": "Uber", "isNonstandard": "Past"},
        # Entry with no tier fields — should still be included if any field present
        "somemon": {"unrelatedField": "value"},
    }

    def test_tier_stored(self):
        result = transform_formats_data(self._RAW)
        assert result["venusaur"]["tier"] == "UU"

    def test_doubles_tier_stored(self):
        result = transform_formats_data(self._RAW)
        assert result["venusaur"]["doublesTier"] == "DOU"

    def test_non_standard_stored(self):
        result = transform_formats_data(self._RAW)
        assert result["charizardmegax"]["isNonstandard"] == "Past"

    def test_unrelated_fields_excluded(self):
        result = transform_formats_data(self._RAW)
        # "somemon" has no tier fields so should produce an empty entry (excluded)
        assert "somemon" not in result or result["somemon"] == {}


# ---------------------------------------------------------------------------
# transform_moves (regression — ensure numeric key quoting didn't break it)
# ---------------------------------------------------------------------------

class TestTransformMoves:
    _RAW = {
        "tackle": {
            "num": 33,
            "name": "Tackle",
            "gen": 1,
            "type": "Normal",
            "category": "Physical",
            "basePower": 40,
            "accuracy": 100,
            "pp": 35,
        },
        # Z-move — is_z_move flag
        "10000000voltthunderbolt": {
            "num": 719,
            "name": "10,000,000 Volt Thunderbolt",
            "gen": 1,
            "type": "Electric",
            "category": "Special",
            "basePower": 195,
            "accuracy": True,  # always hits
            "pp": 1,
            "isZ": "pikaniumz",
        },
        # Negative num — filtered
        "shadowhold": {
            "num": -1,
            "name": "Shadow Hold",
            "gen": 3,
            "type": "Shadow",
            "category": "Status",
            "basePower": 0,
            "accuracy": True,
            "pp": 1,
        },
    }

    def test_tackle_included(self):
        result = transform_moves(self._RAW)
        assert "tackle" in result

    def test_negative_num_excluded(self):
        result = transform_moves(self._RAW)
        assert "shadowhold" not in result

    def test_z_move_flag(self):
        result = transform_moves(self._RAW)
        assert result["10000000voltthunderbolt"]["is_z_move"] is True

    def test_always_hit_accuracy_normalised_to_none(self):
        result = transform_moves(self._RAW)
        assert result["10000000voltthunderbolt"]["accuracy"] is None
