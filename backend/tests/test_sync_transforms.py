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

import logging

from sync_ps_data import (
    _normalize_ps_id,
    _get_prevo_chain,
    _parse_source_entry,
    _warned_source_codes,
    generate_learnset_by_gen,
    transform_pokedex,
    transform_pokedex_mods,
    transform_formats_data,
    transform_moves,
    transform_items,
    transform_abilities,
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
# _normalize_ps_id
# ---------------------------------------------------------------------------

class TestNormalizePsId:
    def test_lowercase(self):
        assert _normalize_ps_id("Bulbasaur") == "bulbasaur"

    def test_strips_hyphens(self):
        assert _normalize_ps_id("Vulpix-Alola") == "vulpixalola"

    def test_strips_spaces(self):
        assert _normalize_ps_id("Mr. Mime") == "mrmime"

    def test_strips_apostrophes(self):
        assert _normalize_ps_id("Farfetch'd") == "farfetchd"

    def test_strips_dots(self):
        assert _normalize_ps_id("Mr. Mime") == "mrmime"

    def test_already_normalised(self):
        assert _normalize_ps_id("ninetalesalola") == "ninetalesalola"

    def test_nidoran_female(self):
        assert _normalize_ps_id("Nidoran-F") == "nidoranf"


# ---------------------------------------------------------------------------
# _get_prevo_chain
# ---------------------------------------------------------------------------

class TestGetProvoChain:
    _POKEDEX = {
        "ninetalesalola": {"num": 38, "name": "Ninetales-Alola", "prevo": "Vulpix-Alola"},
        "vulpixalola":    {"num": 37, "name": "Vulpix-Alola"},
        "charizard":      {"num": 6,  "name": "Charizard", "prevo": "Charmeleon"},
        "charmeleon":     {"num": 5,  "name": "Charmeleon", "prevo": "Charmander"},
        "charmander":     {"num": 4,  "name": "Charmander"},
        "bulbasaur":      {"num": 1,  "name": "Bulbasaur"},
    }

    def test_single_prevo(self):
        chain = _get_prevo_chain("ninetalesalola", self._POKEDEX)
        assert chain == ["vulpixalola"]

    def test_two_stage_chain(self):
        chain = _get_prevo_chain("charizard", self._POKEDEX)
        assert chain == ["charmeleon", "charmander"]

    def test_no_prevo(self):
        assert _get_prevo_chain("bulbasaur", self._POKEDEX) == []

    def test_unknown_pokemon(self):
        assert _get_prevo_chain("unknownmon", self._POKEDEX) == []

    def test_no_infinite_loop_on_bad_data(self):
        """Self-referential prevo must not loop forever."""
        bad = {"loopmon": {"num": 1, "prevo": "Loopmon"}}
        chain = _get_prevo_chain("loopmon", bad)
        assert chain == []


# ---------------------------------------------------------------------------
# _parse_source_entry
# ---------------------------------------------------------------------------

class TestParseSourceEntry:
    def test_level_up(self):
        assert _parse_source_entry("9L48", 9) == {"method": "level_up", "level": 48}

    def test_level_1(self):
        assert _parse_source_entry("9L1", 9) == {"method": "level_up", "level": 1}

    def test_tutor(self):
        assert _parse_source_entry("9T", 9) == {"method": "tutor"}

    def test_egg(self):
        assert _parse_source_entry("9E", 9) == {"method": "egg"}

    def test_machine(self):
        assert _parse_source_entry("9M", 9) == {"method": "machine"}

    def test_event(self):
        assert _parse_source_entry("9S0", 9) == {"method": "event"}

    def test_event_multi_digit_index(self):
        assert _parse_source_entry("2S12", 2) == {"method": "event"}

    def test_wrong_gen_returns_none(self):
        assert _parse_source_entry("8L30", 9) is None

    def test_non_digit_prefix_returns_none(self):
        assert _parse_source_entry("EM", 9) is None

    def test_empty_string_returns_none(self):
        assert _parse_source_entry("", 9) is None

    def test_older_gen_code_returns_none_for_newer_gen(self):
        assert _parse_source_entry("7T", 9) is None

    def test_relearn_method(self):
        assert _parse_source_entry("3R", 3) == {"method": "relearn"}

    def test_relearn_gen4(self):
        assert _parse_source_entry("4R", 4) == {"method": "relearn"}

    def test_dream_world_method(self):
        assert _parse_source_entry("5D", 5) == {"method": "event"}

    def test_virtual_console_method(self):
        assert _parse_source_entry("7V", 7) == {"method": "transfer"}

    def test_relearn_wrong_gen_returns_none(self):
        assert _parse_source_entry("4R", 9) is None

    def test_dream_world_wrong_gen_returns_none(self):
        assert _parse_source_entry("5D", 9) is None

    def test_unknown_code_warns_once(self, caplog):
        """Same unknown code must emit a warning only on the first call."""
        _warned_source_codes.discard("9Z")
        with caplog.at_level(logging.WARNING, logger="sync_ps_data"):
            r1 = _parse_source_entry("9Z", 9)
            r2 = _parse_source_entry("9Z", 9)
        assert r1 == {"method": "other"}
        assert r2 == {"method": "other"}
        warnings_for_code = [
            r for r in caplog.records if "9Z" in r.message
        ]
        assert len(warnings_for_code) == 1


# ---------------------------------------------------------------------------
# generate_learnset_by_gen
# ---------------------------------------------------------------------------

# Minimal fixture modelled on the real Vulpix-Alola / Ninetales-Alola case.
_MAIN_LEARNSETS = {
    "vulpixalola": {
        "learnset": {
            "freezedry": ["7L28", "8L28", "9L48"],
            "icebeam":   ["7M", "8M", "9M"],
            "powder snow": ["7L1", "9L1"],   # via_prevo candidate for ninetales
        }
    },
    "ninetalesalola": {
        "learnset": {
            "freezedry": ["7L1", "8L1", "9L1"],  # L1 → via_prevo from vulpixalola
            "icebeam":   ["7M", "8M", "9M"],
            "nastyplot": ["9T"],                   # tutor, no L1
            "moonblast": ["7E", "9E"],             # egg
        }
    },
    "eevee": {
        "learnset": {
            "tackle": ["1L1", "2L1", "3L1", "4L1", "5L1", "6L1", "7L1", "8L1", "9L1"],
            "growl":  ["1L1", "7L1", "9L1"],
        }
    },
}

_POKEDEX_FIXTURE = {
    "vulpixalola":    {"num": 37, "name": "Vulpix-Alola"},
    "ninetalesalola": {"num": 38, "name": "Ninetales-Alola", "prevo": "Vulpix-Alola"},
    "eevee":          {"num": 133, "name": "Eevee"},
}


class TestGenerateLearnsetByGen:

    def _run(self, main=None, mods=None, pokedex=None):
        return generate_learnset_by_gen(
            main or _MAIN_LEARNSETS,
            mods or {},
            pokedex or _POKEDEX_FIXTURE,
        )

    # --- basic gen filtering ---

    def test_returns_all_nine_gens(self):
        result = self._run()
        assert set(result.keys()) == set(range(1, 10))

    def test_gen9_only_contains_gen9_codes(self):
        result = self._run()
        gen9 = result[9]
        # icebeam appears in gen 9 (9M)
        assert "icebeam" in gen9.get("ninetalesalola", {})
        # moonblast appears as 9E (egg) — included
        assert "moonblast" in gen9.get("ninetalesalola", {})

    def test_gen7_move_absent_from_gen9(self):
        # nastyplot is 9T so should be in gen9
        # but powder snow appears as 7L1 (gen 7) and 9L1 (gen 9)
        result = self._run()
        # gen7 has powder snow for vulpixalola (7L1)
        assert "powder snow" in result[7].get("vulpixalola", {})
        # gen9 also has it (9L1)
        assert "powder snow" in result[9].get("vulpixalola", {})

    def test_gen8_code_absent_from_gen9(self):
        # icebeam is 8M for vulpixalola — should appear in gen8, not gen9 via that code
        # (also appears as 9M so will be in gen9 via that code)
        result = self._run()
        gen8_vulpix = result[8].get("vulpixalola", {})
        assert "icebeam" in gen8_vulpix
        entries = gen8_vulpix["icebeam"]
        assert all(e["method"] == "machine" for e in entries)

    # --- method mapping ---

    def test_level_up_method(self):
        result = self._run()
        entries = result[9]["vulpixalola"]["freezedry"]
        methods = [e["method"] for e in entries]
        assert "level_up" in methods

    def test_level_extracted_correctly(self):
        result = self._run()
        entries = result[9]["vulpixalola"]["freezedry"]
        lu = next(e for e in entries if e["method"] == "level_up")
        assert lu["level"] == 48

    def test_tutor_method(self):
        result = self._run()
        entries = result[9]["ninetalesalola"]["nastyplot"]
        assert entries[0]["method"] == "tutor"
        assert "level" not in entries[0]

    def test_egg_method(self):
        result = self._run()
        entries = result[9]["ninetalesalola"]["moonblast"]
        assert entries[0]["method"] == "egg"

    def test_machine_method(self):
        result = self._run()
        entries = result[9]["ninetalesalola"]["icebeam"]
        assert entries[0]["method"] == "machine"

    # --- via_prevo detection ---

    def test_via_prevo_annotated_for_ninetales_freezedry(self):
        """The motivating bug: Ninetales-Alola freezedry 9L1 inherits from Vulpix-Alola 9L48."""
        result = self._run()
        entries = result[9]["ninetalesalola"]["freezedry"]
        l1 = next(e for e in entries if e["method"] == "level_up" and e["level"] == 1)
        assert l1.get("via_prevo") == "vulpixalola"

    def test_via_prevo_not_set_when_prevo_also_l1(self):
        """If prevo only has L1 too, via_prevo is not annotated (no ancestor at level > 1)."""
        main = {
            "vulpixalola":    {"learnset": {"tackle": ["9L1"]}},
            "ninetalesalola": {"learnset": {"tackle": ["9L1"]}},
        }
        result = self._run(main=main)
        entries = result[9]["ninetalesalola"]["tackle"]
        l1 = next(e for e in entries if e["method"] == "level_up" and e["level"] == 1)
        assert "via_prevo" not in l1

    def test_via_prevo_not_set_when_prevo_lacks_move(self):
        """If prevo doesn't have the move at all, no via_prevo."""
        main = {
            "vulpixalola":    {"learnset": {"icebeam": ["9M"]}},
            "ninetalesalola": {"learnset": {"freezedry": ["9L1"]}},
        }
        result = self._run(main=main)
        entries = result[9]["ninetalesalola"]["freezedry"]
        l1 = next(e for e in entries if e["method"] == "level_up" and e["level"] == 1)
        assert "via_prevo" not in l1

    def test_via_prevo_not_set_on_base_species(self):
        """Eevee has no prevo — its L1 entries are never via_prevo."""
        result = self._run()
        entries = result[9]["eevee"]["tackle"]
        for e in entries:
            assert "via_prevo" not in e

    def test_via_prevo_not_set_for_non_level1(self):
        """Level-up entries above L1 are never via_prevo, even on evolved Pokémon."""
        result = self._run()
        entries = result[9]["vulpixalola"]["freezedry"]
        lu = next(e for e in entries if e["method"] == "level_up")
        assert lu["level"] == 48
        assert "via_prevo" not in lu

    def test_via_prevo_walks_two_stage_chain(self):
        """via_prevo detection works across a two-stage evo chain."""
        main = {
            "charmander":  {"learnset": {"ember": ["1L7"]}},
            "charmeleon":  {"learnset": {"ember": ["1L1"]}},
            "charizard":   {"learnset": {"ember": ["1L1"]}},
        }
        pokedex = {
            "charmander":  {"num": 4, "name": "Charmander"},
            "charmeleon":  {"num": 5, "name": "Charmeleon", "prevo": "Charmander"},
            "charizard":   {"num": 6, "name": "Charizard",  "prevo": "Charmeleon"},
        }
        result = generate_learnset_by_gen(main, {}, pokedex)
        # charmeleon: L1 ember, charmander has L7 → via_prevo = charmander
        charmeleon_entries = result[1]["charmeleon"]["ember"]
        l1 = next(e for e in charmeleon_entries if e["level"] == 1)
        assert l1.get("via_prevo") == "charmander"
        # charizard: L1 ember; walk chain → charmeleon also L1 → check charmander → L7 → via_prevo = charmander
        charizard_entries = result[1]["charizard"]["ember"]
        l1_char = next(e for e in charizard_entries if e["level"] == 1)
        assert l1_char.get("via_prevo") == "charmander"

    # --- mod merging ---

    def test_mod_moves_merged_into_gen(self):
        """Moves from mod files are merged with main-file data."""
        main = {"dratini": {"learnset": {"wrap": ["1L1"]}}}
        mods = {2: {"dratini": {"learnset": {"extremespeed": ["2S1"]}}}}
        result = generate_learnset_by_gen(main, mods, {})
        assert "extremespeed" in result[2].get("dratini", {})
        assert "wrap" in result[1].get("dratini", {})

    def test_duplicate_codes_deduplicated(self):
        """Same source code appearing in main + mod produces a single entry."""
        main = {"pikachu": {"learnset": {"thunderbolt": ["9M"]}}}
        mods = {9: {"pikachu": {"learnset": {"thunderbolt": ["9M"]}}}}
        result = generate_learnset_by_gen(main, mods, {})
        entries = result[9]["pikachu"]["thunderbolt"]
        assert len(entries) == 1

    # --- edge cases ---

    def test_pokemon_with_no_gen9_moves_absent_from_gen9(self):
        main = {"mew": {"learnset": {"transform": ["1S0"]}}}
        result = generate_learnset_by_gen(main, {}, {})
        assert "mew" not in result[9]

    def test_non_digit_codes_ignored(self):
        """Codes without a leading digit (e.g. empty strings) are silently skipped."""
        main = {"pikachu": {"learnset": {"thunder": ["", "9M"]}}}
        result = generate_learnset_by_gen(main, {}, {})
        assert "thunder" in result[9]["pikachu"]
        # Non-digit codes must not produce entries
        assert len(result[9]["pikachu"]["thunder"]) == 1


# ---------------------------------------------------------------------------
# transform_pokedex  (including new prevo / evos fields)
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
        "ivysaur": {
            "num": 2,
            "name": "Ivysaur",
            "types": ["Grass", "Poison"],
            "baseStats": {"hp": 60, "atk": 62, "def": 63, "spa": 80, "spd": 80, "spe": 60},
            "abilities": {"0": "Overgrow", "H": "Chlorophyll"},
            "prevo": "Bulbasaur",
            "evos": ["Venusaur"],
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
        "syclant": {
            "num": 1,
            "name": "Syclant",
            "types": ["Ice", "Bug"],
            "baseStats": {"hp": 70, "atk": 116, "def": 70, "spa": 114, "spd": 64, "spe": 121},
            "abilities": {"0": "Compound Eyes"},
            "isNonstandard": "CAP",
        },
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

    def test_evos_preserved(self):
        result = transform_pokedex(self._RAW)
        assert result["bulbasaur"]["evos"] == ["Ivysaur"]

    def test_prevo_preserved(self):
        result = transform_pokedex(self._RAW)
        assert result["ivysaur"]["prevo"] == "Bulbasaur"

    def test_prevo_absent_when_not_in_source(self):
        result = transform_pokedex(self._RAW)
        assert "prevo" not in result["bulbasaur"]

    def test_evos_absent_when_not_in_source(self):
        result = transform_pokedex(self._RAW)
        assert "evos" not in result["venusaurmega"]

    def test_no_extra_fields(self):
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
            "clefairy": {"inherit": True, "types": ["Normal"]},
            "mrmime":   {"inherit": True, "types": ["Psychic"]},
        },
        1: {
            "charizard": {
                "inherit": True,
                "baseStats": {"hp": 78, "atk": 84, "def": 78,
                               "spa": 85, "spd": 85, "spe": 100},
            },
            "somefakemon": {"types": ["Fire"]},  # no inherit — should be skipped
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
        result = transform_pokedex_mods(self._MOD_RAWS)
        assert "somefakemon" not in result.get("gen1", {})

    def test_non_battle_fields_excluded(self):
        mod_raws = {
            3: {"pikachu": {"inherit": True, "types": ["Electric"], "color": "Yellow"}}
        }
        result = transform_pokedex_mods(mod_raws)
        assert "types" in result["gen3"]["pikachu"]
        assert "color" not in result["gen3"]["pikachu"]

    def test_empty_mod_gen_not_included(self):
        mod_raws = {2: {"unown": {"inherit": True}}}
        result = transform_pokedex_mods(mod_raws)
        assert "gen2" not in result


# ---------------------------------------------------------------------------
# transform_formats_data
# ---------------------------------------------------------------------------

class TestTransformFormatsData:
    _RAW = {
        "venusaur":     {"tier": "UU", "doublesTier": "DOU"},
        "clefable":     {"tier": "OU", "nfe": False},
        "charizardmegax": {"tier": "Uber", "isNonstandard": "Past"},
        "somemon":      {"unrelatedField": "value"},
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
        assert "somemon" not in result or result["somemon"] == {}


# ---------------------------------------------------------------------------
# transform_moves  (including new fields)
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
            "priority": 0,
            "flags": {"contact": 1, "protect": 1},
        },
        "swordsdance": {
            "num": 14,
            "name": "Swords Dance",
            "gen": 1,
            "type": "Normal",
            "category": "Status",
            "basePower": 0,
            "accuracy": True,   # always hits
            "pp": 20,
            "priority": 0,
            "flags": {"snatch": 1},
        },
        # Z-move with zMoveFrom
        "catastropika": {
            "num": 658,
            "name": "Catastropika",
            "gen": 7,
            "type": "Electric",
            "category": "Physical",
            "basePower": 210,
            "accuracy": True,
            "pp": 1,
            "isZ": "pikaniumz",
            "zMoveFrom": "voltTackle",
            "priority": 0,
            "flags": {"contact": 1},
        },
        # Max move with maxMoveBase
        "maxlightning": {
            "num": 779,
            "name": "Max Lightning",
            "gen": 8,
            "type": "Electric",
            "category": "Physical",
            "basePower": 130,
            "accuracy": True,
            "pp": 10,
            "isMax": True,
            "priority": 0,
            "flags": {},
        },
        # secondary effect
        "flamethrower": {
            "num": 53,
            "name": "Flamethrower",
            "gen": 1,
            "type": "Fire",
            "category": "Special",
            "basePower": 90,
            "accuracy": 100,
            "pp": 15,
            "priority": 0,
            "flags": {"protect": 1},
            "secondary": {"chance": 10, "status": "brn"},
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
        assert result["catastropika"]["is_z_move"] is True

    def test_max_move_flag(self):
        result = transform_moves(self._RAW)
        assert result["maxlightning"]["is_max_move"] is True

    def test_always_hit_accuracy_normalised_to_none(self):
        result = transform_moves(self._RAW)
        assert result["swordsdance"]["accuracy"] is None
        assert result["catastropika"]["accuracy"] is None

    def test_int_accuracy_preserved(self):
        result = transform_moves(self._RAW)
        assert result["tackle"]["accuracy"] == 100

    def test_priority_field(self):
        result = transform_moves(self._RAW)
        assert result["tackle"]["priority"] == 0

    def test_flags_field(self):
        result = transform_moves(self._RAW)
        assert result["tackle"]["flags"] == {"contact": 1, "protect": 1}

    def test_flags_defaults_to_empty_dict_when_absent(self):
        raw = {"splash": {"num": 150, "name": "Splash", "gen": 1,
                          "type": "Normal", "category": "Status",
                          "basePower": 0, "pp": 40}}
        result = transform_moves(raw)
        assert result["splash"]["flags"] == {}

    def test_secondary_effect_preserved(self):
        result = transform_moves(self._RAW)
        assert result["flamethrower"]["secondary"] == {"chance": 10, "status": "brn"}

    def test_secondary_none_when_absent(self):
        result = transform_moves(self._RAW)
        assert result["tackle"]["secondary"] is None

    def test_z_move_base_field(self):
        result = transform_moves(self._RAW)
        assert result["catastropika"]["z_move_base"] == "voltTackle"

    def test_z_move_base_none_for_regular_move(self):
        result = transform_moves(self._RAW)
        assert result["tackle"]["z_move_base"] is None

    def test_max_move_base_none_when_absent(self):
        result = transform_moves(self._RAW)
        assert result["maxlightning"]["max_move_base"] is None


# ---------------------------------------------------------------------------
# transform_items
# ---------------------------------------------------------------------------

class TestTransformItems:
    _RAW = {
        "leftovers": {
            "num": 234,
            "name": "Leftovers",
            "gen": 2,
        },
        "venusaurite": {
            "num": 666,
            "name": "Venusaurite",
            "gen": 6,
            "megaStone": "Venusaur-Mega",
        },
        "grassiumz": {
            "num": 782,
            "name": "Grassium Z",
            "gen": 7,
            "zMoveType": "Grass",
        },
        "sitrusberry": {
            "num": 174,
            "name": "Sitrus Berry",
            "gen": 3,
            "isBerry": True,
        },
        "earthplate": {
            "num": 301,
            "name": "Earth Plate",
            "gen": 4,
            "onPlate": "Ground",
        },
        "groundmemory": {
            "num": 900,
            "name": "Ground Memory",
            "gen": 7,
            "onMemory": "Ground",
        },
        "shadowball_tm": {  # negative num — filtered
            "num": -1,
            "name": "TM30",
            "gen": 1,
        },
    }

    def test_regular_item_included(self):
        result = transform_items(self._RAW)
        assert "leftovers" in result

    def test_negative_num_excluded(self):
        result = transform_items(self._RAW)
        assert "shadowball_tm" not in result

    def test_mega_stone_flag(self):
        result = transform_items(self._RAW)
        assert result["venusaurite"]["is_mega_stone"] is True
        assert result["venusaurite"]["mega_species"] == "Venusaur-Mega"

    def test_regular_item_not_mega_stone(self):
        result = transform_items(self._RAW)
        assert result["leftovers"]["is_mega_stone"] is False
        assert result["leftovers"]["mega_species"] is None

    def test_z_crystal_flag(self):
        result = transform_items(self._RAW)
        assert result["grassiumz"]["is_z_crystal"] is True

    def test_berry_flag(self):
        result = transform_items(self._RAW)
        assert result["sitrusberry"]["is_berry"] is True
        assert result["leftovers"]["is_berry"] is False

    def test_plate_flag(self):
        result = transform_items(self._RAW)
        assert result["earthplate"]["is_plate"] is True
        assert result["leftovers"]["is_plate"] is False

    def test_memory_flag(self):
        result = transform_items(self._RAW)
        assert result["groundmemory"]["is_memory"] is True
        assert result["leftovers"]["is_memory"] is False

    def test_gen_field(self):
        result = transform_items(self._RAW)
        assert result["leftovers"]["gen"] == 2


# ---------------------------------------------------------------------------
# transform_abilities
# ---------------------------------------------------------------------------

class TestTransformAbilities:
    _RAW = {
        "overgrow": {
            "num": 65,
            "name": "Overgrow",
            "gen": 3,
        },
        "chlorophyll": {
            "num": 34,
            "name": "Chlorophyll",
            "gen": 3,
        },
        "baddreams": {
            "num": 123,
            "name": "Bad Dreams",
            "gen": 4,
        },
        # Negative num — filtered
        "noability": {
            "num": -1,
            "name": "No Ability",
            "gen": 1,
        },
    }

    def test_real_ability_included(self):
        result = transform_abilities(self._RAW)
        assert "overgrow" in result
        assert "chlorophyll" in result

    def test_negative_num_excluded(self):
        result = transform_abilities(self._RAW)
        assert "noability" not in result

    def test_name_field(self):
        result = transform_abilities(self._RAW)
        assert result["baddreams"]["name"] == "Bad Dreams"

    def test_gen_field(self):
        result = transform_abilities(self._RAW)
        assert result["baddreams"]["gen"] == 4

    def test_no_extra_fields(self):
        result = transform_abilities(self._RAW)
        assert set(result["overgrow"].keys()) == {"name", "gen"}
