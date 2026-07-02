#!/usr/bin/env python3
"""
sync_ps_data.py — Download and trim Pokémon Showdown data for offline use.

Fetches learnsets, moves, items, and abilities from PS data endpoints,
strips fields the app doesn't need, and writes trimmed JSON to
assets/data/ps/.  Also writes version.json and copies it to the backend
so GET /ps-data/version can serve it.

Usage:
    pip install requests json5
    python scripts/sync_ps_data.py

Run whenever you want to pick up PS data changes.
Commit the updated assets/data/ps/ files.
"""

import hashlib
import json
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

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

PS_BASE = "https://play.pokemonshowdown.com/data"
# Raw TypeScript source on GitHub — carries data the compiled /data endpoints strip out,
# notably `eventData` (gift/event-Pokémon movesets) and full per-move source codes
# (e.g. "2S1" = Gen 2 event/special source — the compiled endpoints collapse this to "2").
PS_GITHUB_RAW = "https://raw.githubusercontent.com/smogon/pokemon-showdown/master"
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "ps")
os.makedirs(OUT_DIR, exist_ok=True)


# ---------------------------------------------------------------------------
# Fetch helpers
# ---------------------------------------------------------------------------

def fetch_json_endpoint(path: str) -> dict:
    """Fetch a PS endpoint that returns proper JSON."""
    url = f"{PS_BASE}/{path}"
    print(f"  GET {url}")
    r = requests.get(url, timeout=60)
    r.raise_for_status()
    return r.json()


def fetch_js_endpoint(path: str, base: str = PS_BASE) -> dict:
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
# Transformations
# ---------------------------------------------------------------------------

def transform_learnsets(raw: dict) -> dict:
    """
    Input:  { "bulbasaur": { "learnset": { "tackle": ["9L1","8L1",...] } } }
    Output: { "bulbasaur": { "1": ["growl","tackle",...], "9": [...] } }

    Each source string starts with the generation digit (1–9).
    Stores per-generation sets; the app unions them to get cumulative learnsets.
    """
    result: dict[str, dict[str, list[str]]] = {}
    for pokemon, data in raw.items():
        learnset = data.get("learnset") or {}
        by_gen: dict[int, set[str]] = {}
        for move, sources in learnset.items():
            for src in sources:
                if not src or not src[0].isdigit():
                    continue
                gen = int(src[0])
                if 1 <= gen <= 9:
                    by_gen.setdefault(gen, set()).add(move)
        if by_gen:
            result[pokemon] = {
                str(g): sorted(moves) for g, moves in sorted(by_gen.items())
            }
    return result


def transform_detailed_learnsets(main_raw: dict, mod_raws: dict[int, dict]) -> dict:
    """
    Build a full-fidelity learnset dataset from PS's raw TypeScript sources —
    the main `data/learnsets.ts` plus any per-generation mod overrides
    (`data/mods/gen{N}/learnsets.ts`).

    Unlike `transform_learnsets` (which keeps only the leading generation digit
    of each source code, discarding the method letter), this keeps the full
    source-code string — e.g. "2S1" — so a later layer can tell genuine
    event/gift sources (S) apart from level-up/egg/tutor/machine (L/E/T/M).
    It also carries through each species' `eventData`: structured records of
    real gift/event Pokémon encounters (generation, level, moveset, shininess,
    etc.) that PokéAPI has no equivalent category for at all.

    Merge rule — union, never drop: a mod file's data for a generation is
    *complementary* to the main file's (e.g. the gen2 mod covers gens 1-2 with
    its own accurate "2S1"/"2E"/"2M" codes, while main's Dratini entry only has
    gen-3+ sources — no overlap for the motivating case). Even where overlap
    could occur for other species, unioning can only ever add legality
    information, never incorrectly suppress it — the right bias for a
    supplementary gap-filling source.

    Input:  main_raw  = { "dratini": { "learnset": {...}, "eventData": [...] } }
            mod_raws  = { 2: { "dratini": { "learnset": {...}, "eventData": [...] } } }
    Output: { "dratini": { "learnset": { "extremespeed": ["2S1","4E",...] },
                           "eventData": [ {"generation": 2, "level": 15, ...} ] } }
    """
    sources: list[dict] = [main_raw] + [mod_raws[g] for g in sorted(mod_raws)]

    species: set[str] = set()
    for raw in sources:
        species.update(raw.keys())

    result: dict[str, dict] = {}
    for pokemon in species:
        learnset: dict[str, set[str]] = {}
        event_data: list[dict] = []
        for raw in sources:
            data = raw.get(pokemon)
            if not data:
                continue
            for move, codes in (data.get("learnset") or {}).items():
                learnset.setdefault(move, set()).update(
                    c for c in codes if c and c[0].isdigit()
                )
            for ev in (data.get("eventData") or []):
                entry = {
                    k: ev[k]
                    for k in ("generation", "level", "moves", "shiny", "gender",
                              "isHidden", "pokeball")
                    if k in ev
                }
                if entry not in event_data:
                    event_data.append(entry)
        if not learnset and not event_data:
            continue
        entry: dict = {}
        if learnset:
            entry["learnset"] = {m: sorted(c) for m, c in sorted(learnset.items())}
        if event_data:
            entry["eventData"] = event_data
        result[pokemon] = entry
    return result


def build_g6_allowlist(raw: dict) -> dict[str, list[str]]:
    """
    Build a Gen-6 move allow-list from learnsets-g6.js.

    learnsets-g6.js is PS's Gen 6 simulation data file.  Any move that
    appears for a Pokémon in this file (regardless of its source-code
    generation digit) is considered valid in a Gen 6 format by PS.

    This covers two important cases:
    1. Moves that are listed only as Gen 7/8 in the main learnsets.json
       but were actually available in Gen 6 (e.g. Dragon Dance on
       Charizard via ORAS tutor or Gen 6 egg move — the Gen 6 sources
       are missing from PS's modern data but the move is still in the G6
       allow-list file).
    2. Moves that CAN transfer forward into Gen 6 simulation from older
       games that PS Gen 6 allows.

    Returns { "charizard": ["dragondance", "fly", ...], ... }
    """
    result: dict[str, list[str]] = {}
    for pokemon, data in raw.items():
        learnset = data.get("learnset") or {}
        # Include every move that has at least one non-empty source.
        moves = sorted(
            move for move, sources in learnset.items()
            if any(s for s in sources)  # at least one real source entry
        )
        if moves:
            result[pokemon.lower()] = moves
    return result


def transform_moves(raw: dict) -> dict:
    """Keep only the fields needed for gen-filtering and slot-config display."""
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
            "accuracy": d.get("accuracy") if isinstance(d.get("accuracy"), int) and not isinstance(d.get("accuracy"), bool) else None,
            "pp": d.get("pp", 0),
            "is_z_move": bool(d.get("isZ")),
            "is_max_move": bool(d.get("isMax")),
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

    Keeps: num, name, types, baseStats, abilities, gen (derived from num when absent).
    Skips CAP / Custom / non-main-series entries (negative num or isNonstandard in
    the skip set).

    Output key is the PS lowercase ID (e.g. "bulbasaur", "mrmime", "giratinaorigin").
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
    """Write compact JSON to assets/data/ps/ and return 16-char sha256 prefix."""
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

    print("Learnsets (JSON endpoint)…")
    learnsets = transform_learnsets(fetch_json_endpoint("learnsets.json"))

    ls_sha = write_json("learnsets.json", learnsets)

    print("\nLearnsets-G6 allow-list (JS endpoint)…")
    try:
        g6_raw = fetch_js_endpoint("learnsets-g6.js")
        g6_allowlist = build_g6_allowlist(g6_raw)
        write_json("learnsets-g6-allowlist.json", g6_allowlist)
        print(f"  Built Gen 6 allow-list for {len(g6_allowlist)} Pokémon")
    except Exception as e:
        print(f"  WARNING: Could not fetch learnsets-g6.js: {e}")
        g6_allowlist = {}

    print("\nMoves (JSON endpoint)…")
    moves = transform_moves(fetch_json_endpoint("moves.json"))
    mv_sha = write_json("moves.json", moves)

    print("\nItems (JS endpoint, parsed via json5)…")
    items = transform_items(fetch_js_endpoint("items.js"))
    it_sha = write_json("items.json", items)

    print("\nAbilities (JS endpoint, parsed via json5)…")
    abilities = transform_abilities(fetch_js_endpoint("abilities.js"))
    ab_sha = write_json("abilities.json", abilities)

    print("\nEvent learnsets (raw TS source on GitHub)…")
    try:
        main_raw = fetch_js_endpoint("data/learnsets.ts", base=PS_GITHUB_RAW)
        learnset_mod_raws: dict[int, dict] = {}
        for gen in range(1, 10):
            try:
                learnset_mod_raws[gen] = fetch_js_endpoint(
                    f"data/mods/gen{gen}/learnsets.ts", base=PS_GITHUB_RAW
                )
            except Exception:
                continue  # no mod-specific learnset override for this gen
        detailed = transform_detailed_learnsets(main_raw, learnset_mod_raws)
        ev_sha = write_json("event_learnsets.json", detailed)
        with_events = sum(1 for d in detailed.values() if d.get("eventData"))
        print(f"  Built detailed learnsets for {len(detailed)} Pokémon "
              f"({with_events} with eventData; mods found for gens {sorted(learnset_mod_raws)})")
    except Exception as e:
        print(f"  WARNING: Could not build event learnsets: {e}")
        ev_sha = "0" * 16

    print("\nPokédex (raw TS source on GitHub)…")
    try:
        pokedex_raw = fetch_js_endpoint("data/pokedex.ts", base=PS_GITHUB_RAW)
        pokedex = transform_pokedex(pokedex_raw)
        pd_sha = write_json("pokedex.json", pokedex)
        print(f"  Built Pokédex index for {len(pokedex)} species")
    except Exception as e:
        print(f"  WARNING: Could not build Pokédex: {e}")
        pd_sha = "0" * 16
        pokedex = {}

    print("\nPokédex gen overrides (raw TS mods on GitHub)…")
    try:
        pokedex_mod_raws: dict[int, dict] = {}
        for gen in range(1, 10):
            try:
                pokedex_mod_raws[gen] = fetch_js_endpoint(
                    f"data/mods/gen{gen}/pokedex.ts", base=PS_GITHUB_RAW
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

    print("\nFormats data (raw TS source on GitHub — stored for future use)…")
    try:
        formats_raw = fetch_js_endpoint("data/formats-data.ts", base=PS_GITHUB_RAW)
        formats_data = transform_formats_data(formats_raw)
        fd_sha = write_json("formats-data.json", formats_data)
        print(f"  Built formats data for {len(formats_data)} species")
    except Exception as e:
        print(f"  WARNING: Could not build formats data: {e}")
        fd_sha = "0" * 16

    # Version manifest
    version = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sha": {
            "learnsets":             ls_sha,
            "moves":                 mv_sha,
            "items":                 it_sha,
            "abilities":             ab_sha,
            "event_learnsets":       ev_sha,
            "pokedex":               pd_sha,
            "pokedex_gen_overrides": pdm_sha,
            "formats_data":          fd_sha,
        },
    }
    version_path = os.path.join(OUT_DIR, "version.json")
    with open(version_path, "w", encoding="utf-8") as f:
        json.dump(version, f, indent=2)
    print(f"\n  -> version.json  ({version['generated_at']})")

    # Copy version + data files to backend static dir so /ps-data/version and
    # /ps-data/file/:name (see backend/app/routers/ps_data.py) can serve them —
    # this is how the Flutter app refreshes its Hive cache post-install.
    backend_static = os.path.join(
        os.path.dirname(__file__), "..", "backend", "app", "static"
    )
    os.makedirs(backend_static, exist_ok=True)
    backend_ver = os.path.join(backend_static, "ps_data_version.json")
    with open(backend_ver, "w", encoding="utf-8") as f:
        json.dump(version, f, indent=2)
    print(f"  -> backend/app/static/ps_data_version.json")

    # Must match the _ALLOWED_FILES set in backend/app/routers/ps_data.py and
    # the fileMap in FormatService._checkForUpdates.
    served_files = [
        "learnsets.json",
        "moves.json",
        "items.json",
        "abilities.json",
        "event_learnsets.json",
        # New backend-only files (not served to Flutter via /ps-data/file/:name):
        "pokedex.json",
        "pokedex-gen-overrides.json",
        "formats-data.json",
    ]
    for filename in served_files:
        src = os.path.join(OUT_DIR, filename)
        if not os.path.exists(src):
            continue
        with open(src, encoding="utf-8") as f:
            contents = f.read()
        with open(os.path.join(backend_static, filename), "w", encoding="utf-8") as f:
            f.write(contents)
    print(f"  -> backend/app/static/{{{', '.join(served_files)}}}")

    print("\nSync complete. Commit assets/data/ps/ and backend/app/static/.\n")


if __name__ == "__main__":
    main()
