"""Unit tests for learnset_service — normalize_ps_id, LearnsetService."""

import json
import pytest
from unittest.mock import patch

from app.services.learnset_service import LearnsetService, normalize_ps_id


# ---------------------------------------------------------------------------
# normalize_ps_id
# ---------------------------------------------------------------------------

class TestNormalizePsId:
    def test_plain_name_returns_no_sep_first(self):
        candidates = normalize_ps_id("dratini")
        assert candidates[0] == "dratini"

    def test_hyphenated_no_sep_is_first(self):
        candidates = normalize_ps_id("vulpix-alola")
        assert candidates[0] == "vulpixalola"

    def test_hyphenated_form_included(self):
        candidates = normalize_ps_id("vulpix-alola")
        assert "vulpix-alola" in candidates

    def test_underscored_variant_included(self):
        candidates = normalize_ps_id("vulpix-alola")
        assert "vulpix_alola" in candidates

    def test_spaced_variant_included(self):
        candidates = normalize_ps_id("vulpix-alola")
        assert "vulpix alola" in candidates

    def test_regional_prefix_reversed(self):
        """'alolan-vulpix' should produce 'vulpixalola' as a candidate."""
        candidates = normalize_ps_id("alolan-vulpix")
        assert "vulpixalola" in candidates

    def test_galarian_prefix_reversed(self):
        candidates = normalize_ps_id("galarian-meowth")
        assert "meowthgalar" in candidates

    def test_hisuian_prefix_reversed(self):
        candidates = normalize_ps_id("hisuian-zorua")
        assert "zoruahisui" in candidates

    def test_paldean_prefix_reversed(self):
        candidates = normalize_ps_id("paldean-tauros")
        assert "taurospaldea" in candidates

    def test_no_duplicate_candidates(self):
        """Plain names like 'dratini' should not repeat the same string."""
        candidates = normalize_ps_id("dratini")
        assert len(candidates) == len(set(candidates))

    def test_case_normalized_to_lowercase(self):
        candidates = normalize_ps_id("Vulpix-Alola")
        assert all(c == c.lower() for c in candidates)

    def test_leading_trailing_whitespace_stripped(self):
        candidates = normalize_ps_id("  dratini  ")
        assert "dratini" in candidates

    def test_non_regional_prefix_not_reversed(self):
        """A hyphenated name whose first part is not a region gets no reversal candidate."""
        candidates = normalize_ps_id("charizard-mega-x")
        # no reversal — "charizard" is not a region name
        assert "megaxcharizard" not in candidates


# ---------------------------------------------------------------------------
# version_group_to_gen (instance method on LearnsetService)
# ---------------------------------------------------------------------------

class TestVersionGroupToGen:
    # Full VG map matching the registry — used to populate _vg_to_gen in tests
    # without requiring a real registry file.
    _VG_MAP = {
        "red-blue": 1, "yellow": 1,
        "gold-silver": 2, "crystal": 2,
        "ruby-sapphire": 3, "emerald": 3, "firered-leafgreen": 3, "colosseum": 3, "xd": 3,
        "diamond-pearl": 4, "platinum": 4, "heartgold-soulsilver": 4,
        "black-white": 5, "black-2-white-2": 5,
        "x-y": 6, "omega-ruby-alpha-sapphire": 6,
        "sun-moon": 7, "ultra-sun-ultra-moon": 7, "lets-go-pikachu-lets-go-eevee": 7,
        "sword-shield": 8, "brilliant-diamond-and-shining-pearl": 8, "legends-arceus": 8,
        "scarlet-violet": 9,
    }

    def _make_svc(self) -> LearnsetService:
        svc = LearnsetService()
        svc._vg_to_gen = dict(self._VG_MAP)
        return svc

    def test_red_blue_is_gen1(self):
        assert self._make_svc().version_group_to_gen("red-blue") == 1

    def test_yellow_is_gen1(self):
        assert self._make_svc().version_group_to_gen("yellow") == 1

    def test_gold_silver_is_gen2(self):
        assert self._make_svc().version_group_to_gen("gold-silver") == 2

    def test_sword_shield_is_gen8(self):
        assert self._make_svc().version_group_to_gen("sword-shield") == 8

    def test_scarlet_violet_is_gen9(self):
        assert self._make_svc().version_group_to_gen("scarlet-violet") == 9

    def test_legends_arceus_is_gen8(self):
        assert self._make_svc().version_group_to_gen("legends-arceus") == 8

    def test_colosseum_is_gen3(self):
        assert self._make_svc().version_group_to_gen("colosseum") == 3

    def test_xd_is_gen3(self):
        assert self._make_svc().version_group_to_gen("xd") == 3

    def test_lgpe_is_gen7(self):
        assert self._make_svc().version_group_to_gen("lets-go-pikachu-lets-go-eevee") == 7

    def test_unknown_version_group_returns_none(self):
        assert self._make_svc().version_group_to_gen("nonexistent-game") is None

    def test_all_gens_1_through_9_covered(self):
        assert set(self._VG_MAP.values()) == {1, 2, 3, 4, 5, 6, 7, 8, 9}


# ---------------------------------------------------------------------------
# LearnsetService
# ---------------------------------------------------------------------------

class TestLearnsetServiceLoad:
    def _write_learnset(self, directory, gen: int, data: dict) -> None:
        path = directory / f"learnset_{gen}.json"
        path.write_text(json.dumps(data), encoding="utf-8")

    def _write_registry(self, directory, gen_to_vg: dict) -> None:
        path = directory / "pokemon_registry.json"
        path.write_text(json.dumps({"genToVersionGroups": gen_to_vg}), encoding="utf-8")

    def test_loads_single_gen_file(self, tmp_path):
        data = {"dratini": {"extremespeed": [{"method": "event"}]}}
        self._write_learnset(tmp_path, 2, data)

        svc = LearnsetService()
        with patch("app.services.learnset_service._SHARED_DIR", str(tmp_path)):
            svc.load(str(tmp_path))

        assert svc._learnsets[2] == data

    def test_loads_multiple_gen_files(self, tmp_path):
        for gen in [1, 2, 9]:
            self._write_learnset(tmp_path, gen, {f"mon{gen}": {}})

        svc = LearnsetService()
        with patch("app.services.learnset_service._SHARED_DIR", str(tmp_path)):
            svc.load(str(tmp_path))

        assert 1 in svc._learnsets
        assert 2 in svc._learnsets
        assert 9 in svc._learnsets

    def test_missing_gen_file_does_not_crash(self, tmp_path):
        svc = LearnsetService()
        with patch("app.services.learnset_service._SHARED_DIR", str(tmp_path)):
            svc.load(str(tmp_path))  # must not raise
        assert svc._learnsets == {}

    def test_partial_gen_files_loads_available(self, tmp_path):
        self._write_learnset(tmp_path, 1, {"bulbasaur": {}})

        svc = LearnsetService()
        with patch("app.services.learnset_service._SHARED_DIR", str(tmp_path)):
            svc.load(str(tmp_path))

        assert 1 in svc._learnsets
        assert 2 not in svc._learnsets

    def test_derives_vg_map_from_registry(self, tmp_path):
        """load() builds _vg_to_gen by inverting genToVersionGroups from the registry."""
        self._write_registry(tmp_path, {"1": ["red-blue", "yellow"], "2": ["gold-silver"]})

        svc = LearnsetService()
        with patch("app.services.learnset_service._SHARED_DIR", str(tmp_path)):
            svc.load(str(tmp_path))

        assert svc._vg_to_gen["red-blue"] == 1
        assert svc._vg_to_gen["yellow"] == 1
        assert svc._vg_to_gen["gold-silver"] == 2

    def test_missing_registry_leaves_vg_map_empty(self, tmp_path):
        """load() must not crash if pokemon_registry.json is absent."""
        svc = LearnsetService()
        with patch("app.services.learnset_service._SHARED_DIR", str(tmp_path)):
            svc.load(str(tmp_path))  # must not raise

        assert svc._vg_to_gen == {}


class TestLearnsetServiceGetLearnset:
    def _make_svc(self, learnsets: dict) -> LearnsetService:
        svc = LearnsetService()
        svc._learnsets = learnsets
        return svc

    def test_exact_no_sep_key(self):
        svc = self._make_svc({2: {"dratini": {"extremespeed": [{"method": "event"}]}}})
        result = svc.get_learnset("dratini", 2)
        assert "extremespeed" in result

    def test_hyphenated_name_resolves(self):
        """'vulpix-alola' should resolve to the 'vulpixalola' key."""
        svc = self._make_svc({7: {"vulpixalola": {"freezedry": [{"method": "level_up"}]}}})
        result = svc.get_learnset("vulpix-alola", 7)
        assert "freezedry" in result

    def test_regional_prefix_name_resolves(self):
        """'alolan-vulpix' should also resolve to 'vulpixalola'."""
        svc = self._make_svc({7: {"vulpixalola": {"freezedry": [{"method": "level_up"}]}}})
        result = svc.get_learnset("alolan-vulpix", 7)
        assert "freezedry" in result

    def test_wrong_gen_returns_empty(self):
        svc = self._make_svc({7: {"vulpixalola": {"freezedry": [{"method": "level_up"}]}}})
        result = svc.get_learnset("vulpix-alola", 1)
        assert result == {}

    def test_unknown_pokemon_returns_empty(self):
        svc = self._make_svc({2: {"dratini": {"extremespeed": [{"method": "event"}]}}})
        result = svc.get_learnset("missingno", 2)
        assert result == {}

    def test_no_learnsets_loaded_returns_empty(self):
        svc = LearnsetService()
        assert svc.get_learnset("dratini", 2) == {}
