#!/usr/bin/env python3
"""
sync_ps_data.py — Download and trim Pokémon Showdown data for offline use.

Fetches learnsets, moves, items, and abilities from PS TypeScript source on
GitHub, strips fields the app doesn't need, and writes trimmed JSON to
shared/ps_data/ at the project root.  Both Flutter (via pubspec.yaml asset
directory) and the backend (via PS_DATA_DIR env var) read from this single
location — no copy step needed.

Usage:
    pip install requests json5
    python scripts/sync_ps_data.py

Run whenever you want to pick up PS data changes.
Commit the updated shared/ps_data/ files.
"""

import hashlib
import json
import logging
import os
import re
import sys
from datetime import datetime, timezone

try:
    import requests
except ImportError:
    sys.exit("Install dependencies first:  pip install requests json5")

try:
    import json5
except ImportError:
    sys.exit("Install dependencies first:  pip install requests json5")

logging.basicConfig(level=logging.WARNING, format="%(message)s")
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

# Raw TypeScript source on GitHub — richer than compiled endpoints:
# full per-move source codes, eventData, prevo/evos chains, new move fields.
PS_GITHUB_RAW = "https://raw.githubusercontent.com/smogon/pokemon-showdown/master"
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "shared", "ps_data")
os.makedirs(OUT_DIR, exist_ok=True)


# ---------------------------------------------------------------------------
# Fetch helpers
# ---------------------------------------------------------------------------

def fetch_js_endpoint(path: str, base: str = PS_GITHUB_RAW) -> dict:
    """
    Fetch a JS/TS data file containing a single object-literal export and parse
    it via json5. Handles both PS's compiled format
    ('use strict';\nexports.BattleX={unquotedKey:{...},...};) and raw TypeScript
    source (export const Learnsets: SomeType = {unquotedKey:{...},...};) — in
    both cases we just locate the first '{' and hand the rest to json5, which
    tolerates unquoted keys, single-quoted strings, and trailing commas.

    Extra step: json5 does not support bare numeric property keys (e.g. `0:`,
    `1:`), which PS uses for ability slots.  We quote them before parsing.
    """
    url = f"{base}/{path}"
    print(f"  GET {url}")
    r = requests.get(url, timeout=60)
    r.raise_for_status()
    text = r.text.strip()
    start = text.index("{")
    js_str = text[start:].rstrip(";").strip()
    # Quote bare numeric keys: `0: ` → `"0": ` (json5 requires string/identifier keys).
    js_str = re.sub(r'\b(\d+)\s*:', r'"\1":', js_str)
    return json5.loads(js_str)


# ---------------------------------------------------------------------------
# Normalization helpers
# ---------------------------------------------------------------------------

def _normalize_ps_id(name: str) -> str:
    """Normalize a PS display name or ID to a lookup key (lowercase, alphanum only)."""
    return re.sub(r'[^a-z0-9]', '', name.lower())


def _get_prevo_chain(ps_id: str, pokedex: dict) -> list[str]:
    """
    Walk the prevo chain in the PS pokedex and return ordered list of ancestor
    PS IDs (immediate parent first).
    """
    chain: list[str] = []
    current = ps_id
    seen: set[str] = {ps_id}
    while True:
        entry = pokedex.get(current)
        if not entry:
            break
        raw_prevo = entry.get("prevo")
        if not raw_prevo:
            break
        prevo_id = _normalize_ps_id(raw_prevo)
        if prevo_id in seen:
            break
        seen.add(prevo_id)
        chain.append(prevo_id)
        current = prevo_id
    return chain


def _parse_source_entry(code: str, gen: int) -> dict | None:
    """
    Parse one PS source-code string into a {method, level?} dict for gen N.

    Returns None if the code does not belong to this generation.
    Unknown method letters map to "other" and are logged once.
    """
    if not code or not code[0].isdigit():
        return None
    if int(code[0]) != gen:
        return None

    tail = code[1:]
    if tail.startswith('L'):
        level_str = tail[1:]
        try:
            level = int(level_str)
        except ValueError:
            level = 1
        return {"method": "level_up", "level": level}
    if tail == 'T':
        return {"method": "tutor"}
    if tail == 'E':
        return {"method": "egg"}
    if tail == 'M':
        return {"method": "machine"}
    if tail.startswith('S'):
        return {"method": "event"}
    logger.warning("Unknown PS source code %r for gen %d — mapped to 'other'", code, gen)
    return {"method": "other"}


# ---------------------------------------------------------------------------
# Transformations
# ---------------------------------------------------------------------------

def generate_learnset_by_gen(
    main_raw: dict,
    mod_raws: dict[int, dict],
    pokedex: dict,
) -> dict[int, dict]:
    """
    Generate per-gen learnset dicts from PS TypeScript source data.

    Each learnset_N dict covers only gen-N native moves — entries whose source
    codes begin with digit N.  Not cumulative.

    via_prevo detection: for every level-1 entry on an evolved Pokémon, walk
    the prevo chain (from pokedex) and find the first ancestor that has the
    same move in gen N at level > 1.  If found, annotate "via_prevo": ps_id.

    Returns { gen: { ps_id: { move: [entry, ...] } } }
    where entry = {"method": str, "level"?: int, "via_prevo"?: str}
    """
    # Merge main + mod learnsets (same union logic as the former
    # transform_detailed_learnsets, but without eventData).
    sources: list[dict] = [main_raw] + [mod_raws[g] for g in sorted(mod_raws)]
    merged: dict[str, dict[str, set[str]]] = {}
    for raw in sources:
        for pokemon, data in raw.items():
            for move, codes in (data.get("learnset") or {}).items():
                merged.setdefault(pokemon, {}).setdefault(move, set()).update(
                    c for c in codes if c and c[0].isdigit()
                )

    result: dict[int, dict] = {}
    for gen in range(1, 10):
        gen_data: dict[str, dict[str, list[dict]]] = {}

        for ps_id, moves_codes in merged.items():
            pokemon_gen_moves: dict[str, list[dict]] = {}
            for move, codes in moves_codes.items():
                entries: list[dict] = []
                seen_entries: set[tuple] = set()
                for code in sorted(codes):
                    entry = _parse_source_entry(code, gen)
                    if entry is None:
                        continue
                    # Deduplicate by (method, level) — a move may have both
                    # e.g. "9L1" and "9L1" from merged mod files.
                    key = (entry.get("method"), entry.get("level"))
                    if key not in seen_entries:
                        seen_entries.add(key)
                        entries.append(entry)
                if entries:
                    pokemon_gen_moves[move] = entries

            if pokemon_gen_moves:
                gen_data[ps_id] = pokemon_gen_moves

        result[gen] = gen_data

    # via_prevo pass: for every level-1 entry, check the prevo chain.
    for gen in range(1, 10):
        gen_data = result[gen]
        for ps_id, moves in gen_data.items():
            prevo_chain = _get_prevo_chain(ps_id, pokedex)
            if not prevo_chain:
                continue
            for move, entries in moves.items():
                for entry in entries:
                    if entry.get("method") != "level_up" or entry.get("level") != 1:
                        continue
                    for prevo_id in prevo_chain:
                        prevo_move_entries = gen_data.get(prevo_id, {}).get(move, [])
                        for pe in prevo_move_entries:
                            if pe.get("method") == "level_up" and pe.get("level", 0) > 1:
                                entry["via_prevo"] = prevo_id
                                break
                        if "via_prevo" in entry:
                            break

    return result


def transform_moves(raw: dict) -> dict:
    """Keep fields needed for gen-filtering, slot-config display, and validation."""
    result: dict[str, dict] = {}
    for move_id, d in raw.items():
        if not isinstance(d.get("num"), int) or d["num"] <= 0:
            continue
        result[move_id] = {
            "name": d.get("name", move_id),
            "gen": d.get("gen", 1),
            "type": (d.get("type") or "Normal").lower(),
            "category": d.get("category", "Status"),
            "base_power": d.get("basePower") or 0,
            # PS uses True (bool) for moves that always hit; normalise to None.
            # Must check bool first — bool is a subclass of int in Python.
            "accuracy": (
                d.get("accuracy")
                if isinstance(d.get("accuracy"), int) and not isinstance(d.get("accuracy"), bool)
                else None
            ),
            "pp": d.get("pp", 0),
            "is_z_move": bool(d.get("isZ")),
            "is_max_move": bool(d.get("isMax")),
            "priority": d.get("priority", 0),
            "flags": d.get("flags") or {},
            "secondary": d.get("secondary"),
            "z_move_base": d.get("zMoveFrom"),
            "max_move_base": d.get("maxMoveBase"),
        }
    return result


def transform_items(raw: dict) -> dict:
    """Keep gen and special-item flags."""
    result: dict[str, dict] = {}
    for item_id, d in raw.items():
        if not isinstance(d.get("num"), int) or d["num"] <= 0:
            continue
        result[item_id] = {
            "name": d.get("name", item_id),
            "gen": d.get("gen", 1),
            "is_mega_stone": bool(d.get("megaStone")),
            "mega_species": d.get("megaStone"),         # e.g. "Venusaur-Mega"
            "is_z_crystal": bool(
                d.get("zMove") or d.get("zMoveType") or d.get("zMoveFrom")
            ),
            "is_berry": bool(d.get("isBerry")),
            "is_plate": bool(d.get("onPlate")),         # Arceus plates
            "is_memory": bool(d.get("onMemory")),       # Silvally memories
        }
    return result


def transform_abilities(raw: dict) -> dict:
    """Keep gen only — effect text comes from PokéAPI on demand."""
    result: dict[str, dict] = {}
    for ability_id, d in raw.items():
        if not isinstance(d.get("num"), int) or d["num"] <= 0:
            continue
        result[ability_id] = {
            "name": d.get("name", ability_id),
            "gen": d.get("gen", 3),
        }
    return result


# Non-standard tags that indicate the Pokémon is not part of the main series.
# "Past" means retired from competitive but real — keep it.
_NONSTANDARD_SKIP = {"CAP", "Custom", "Gigantamax", "LGPE", "NFE"}


def transform_pokedex(raw: dict) -> dict:
    """
    Transform data/pokedex.ts into a compact species index for the backend.

    Keeps: num, name, types, baseStats, abilities, prevo, evos, gen (derived
    from num when absent).  prevo and evos are needed for via_prevo detection
    in the learnset service (sub-issue B) and are preserved for future use.

    Skips CAP / Custom / non-main-series entries (negative num or isNonstandard
    in the skip set).
    """
    result: dict[str, dict] = {}
    for ps_id, d in raw.items():
        num = d.get("num")
        if not isinstance(num, int) or num <= 0:
            continue
        nonstandard = d.get("isNonstandard")
        if nonstandard in _NONSTANDARD_SKIP:
            continue
        entry: dict = {
            "num": num,
            "name": d.get("name", ps_id),
            "types": d.get("types", ["Normal"]),
            "baseStats": d.get("baseStats", {}),
            "abilities": d.get("abilities", {}),
        }
        if "prevo" in d:
            entry["prevo"] = d["prevo"]
        if "evos" in d:
            entry["evos"] = d["evos"]
        # Explicit gen tag present on a few entries (Pokestar, etc.); otherwise
        # derive from Dex number so callers can filter "didn't exist yet".
        if "gen" in d:
            entry["gen"] = d["gen"]
        result[ps_id] = entry
    return result


def transform_pokedex_mods(mod_raws: dict[int, dict]) -> dict:
    """
    Build a nested gen-override index from data/mods/gen{N}/pokedex.ts files.

    Each mod entry uses `inherit: true` (delta pattern) — only fields that differ
    from the modern base are present.  We extract only the battle-relevant fields
    that can vary across generations:
        types, baseStats, abilities, unreleasedHidden, maleOnlyHidden

    Output: { "gen1": { "psId": { "types": [...], "baseStats": {...} } }, ... }
    """
    result: dict[str, dict] = {}
    _OVERRIDE_FIELDS = {"types", "baseStats", "abilities", "unreleasedHidden", "maleOnlyHidden"}
    for gen, raw in sorted(mod_raws.items()):
        gen_overrides: dict[str, dict] = {}
        for ps_id, d in raw.items():
            if not d.get("inherit"):
                continue
            override = {k: v for k, v in d.items() if k in _OVERRIDE_FIELDS}
            if override:
                gen_overrides[ps_id] = override
        if gen_overrides:
            result[f"gen{gen}"] = gen_overrides
    return result


def transform_formats_data(raw: dict) -> dict:
    """
    Transform data/formats-data.ts into a compact tier index.

    Keeps: tier, doublesTier, isNonstandard, nfe.
    Stored for future use (tier display, format validation).
    """
    result: dict[str, dict] = {}
    _TIER_FIELDS = {"tier", "doublesTier", "isNonstandard", "nfe"}
    for ps_id, d in raw.items():
        entry = {k: v for k, v in d.items() if k in _TIER_FIELDS}
        if entry:
            result[ps_id] = entry
    return result


# ---------------------------------------------------------------------------
# Write helpers
# ---------------------------------------------------------------------------

def write_json(filename: str, data: dict | list) -> str:
    """Write compact JSON to shared/ps_data/ and return 16-char sha256 prefix."""
    path = os.path.join(OUT_DIR, filename)
    text = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    sha = hashlib.sha256(text.encode()).hexdigest()[:16]
    print(f"  -> {filename}  ({len(text) // 1024} KB, sha256[:16]={sha})")
    return sha


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    print("\n=== Syncing Pokemon Showdown data ===\n")

    # Fetch learnset TS sources — needed for generate_learnset_by_gen.
    # Fetched early so pokedex (for via_prevo walk) is available.
    print("Learnsets (raw TS source on GitHub)…")
    try:
        main_learnset_raw = fetch_js_endpoint("data/learnsets.ts")
        learnset_mod_raws: dict[int, dict] = {}
        for gen in range(1, 10):
            try:
                learnset_mod_raws[gen] = fetch_js_endpoint(
                    f"data/mods/gen{gen}/learnsets.ts"
                )
            except Exception:
                continue  # no mod-specific learnset override for this gen
        print(f"  Fetched main + mods for gens {sorted(learnset_mod_raws)}")
    except Exception as e:
        sys.exit(f"FATAL: Could not fetch learnsets TS source: {e}")

    print("\nPokédex (raw TS source on GitHub)…")
    try:
        pokedex_raw = fetch_js_endpoint("data/pokedex.ts")
        pokedex = transform_pokedex(pokedex_raw)
        pd_sha = write_json("pokedex.json", pokedex)
        print(f"  Built Pokédex index for {len(pokedex)} species")
    except Exception as e:
        print(f"  WARNING: Could not build Pokédex: {e}")
        pd_sha = "0" * 16
        pokedex = {}

    print("\nPer-gen learnsets (learnset_1.json … learnset_9.json)…")
    learnsets_by_gen = generate_learnset_by_gen(
        main_learnset_raw, learnset_mod_raws, pokedex
    )
    learnset_shas: dict[str, str] = {}
    for gen in range(1, 10):
        fname = f"learnset_{gen}.json"
        gen_data = learnsets_by_gen[gen]
        sha = write_json(fname, gen_data)
        learnset_shas[f"learnset_{gen}"] = sha
        via_prevo_count = sum(
            1
            for moves in gen_data.values()
            for entries in moves.values()
            for e in entries
            if e.get("via_prevo")
        )
        print(f"  gen {gen}: {len(gen_data)} Pokémon, {via_prevo_count} via_prevo entries")

    print("\nMoves (raw TS source on GitHub)…")
    moves = transform_moves(fetch_js_endpoint("data/moves.ts"))
    mv_sha = write_json("moves.json", moves)

    print("\nItems (raw TS source on GitHub)…")
    items = transform_items(fetch_js_endpoint("data/items.ts"))
    it_sha = write_json("items.json", items)

    print("\nAbilities (raw TS source on GitHub)…")
    abilities = transform_abilities(fetch_js_endpoint("data/abilities.ts"))
    ab_sha = write_json("abilities.json", abilities)

    print("\nPokédex gen overrides (raw TS mods on GitHub)…")
    try:
        pokedex_mod_raws: dict[int, dict] = {}
        for gen in range(1, 10):
            try:
                pokedex_mod_raws[gen] = fetch_js_endpoint(
                    f"data/mods/gen{gen}/pokedex.ts"
                )
            except Exception:
                continue  # no mod-specific Pokédex override for this gen
        pokedex_mods = transform_pokedex_mods(pokedex_mod_raws)
        pdm_sha = write_json("pokedex-gen-overrides.json", pokedex_mods)
        total_overrides = sum(len(v) for v in pokedex_mods.values())
        print(f"  Built gen overrides for gens {sorted(pokedex_mods.keys())} "
              f"({total_overrides} total entries)")
    except Exception as e:
        print(f"  WARNING: Could not build Pokédex gen overrides: {e}")
        pdm_sha = "0" * 16

    print("\nFormats data (raw TS source on GitHub)…")
    try:
        formats_raw = fetch_js_endpoint("data/formats-data.ts")
        formats_data = transform_formats_data(formats_raw)
        fd_sha = write_json("formats-data.json", formats_data)
        print(f"  Built formats data for {len(formats_data)} species")
    except Exception as e:
        print(f"  WARNING: Could not build formats data: {e}")
        fd_sha = "0" * 16

    # Version manifest — must match _ALLOWED_FILES in backend/app/routers/ps_data.py
    # and the fileMap in FormatService._checkForUpdates.
    version = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sha": {
            **learnset_shas,              # learnset_1 … learnset_9
            "moves":                 mv_sha,
            "items":                 it_sha,
            "abilities":             ab_sha,
            "pokedex":               pd_sha,
            "pokedex_gen_overrides": pdm_sha,
            "formats_data":          fd_sha,
        },
    }
    version_path = os.path.join(OUT_DIR, "version.json")
    with open(version_path, "w", encoding="utf-8") as f:
        json.dump(version, f, indent=2)
    print(f"\n  -> version.json  ({version['generated_at']})")
    print("\nSync complete. Commit shared/ps_data/ changes.\n")


if __name__ == "__main__":
    main()
