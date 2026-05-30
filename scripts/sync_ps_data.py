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


def fetch_js_endpoint(path: str) -> dict:
    """
    Fetch a PS .js data file (JS object literal) and parse it via json5.
    Format: 'use strict';\nexports.BattleX={unquotedKey:{...},...};
    """
    url = f"{PS_BASE}/{path}"
    print(f"  GET {url}")
    r = requests.get(url, timeout=60)
    r.raise_for_status()
    text = r.text.strip()
    start = text.index("{")
    js_str = text[start:].rstrip(";").strip()
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
            "accuracy": d.get("accuracy"),   # None = always hits (e.g. Swift)
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

    print("\nMoves (JSON endpoint)…")
    moves = transform_moves(fetch_json_endpoint("moves.json"))
    mv_sha = write_json("moves.json", moves)

    print("\nItems (JS endpoint, parsed via json5)…")
    items = transform_items(fetch_js_endpoint("items.js"))
    it_sha = write_json("items.json", items)

    print("\nAbilities (JS endpoint, parsed via json5)…")
    abilities = transform_abilities(fetch_js_endpoint("abilities.js"))
    ab_sha = write_json("abilities.json", abilities)

    # Version manifest
    version = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "sha": {
            "learnsets": ls_sha,
            "moves":     mv_sha,
            "items":     it_sha,
            "abilities": ab_sha,
        },
    }
    version_path = os.path.join(OUT_DIR, "version.json")
    with open(version_path, "w", encoding="utf-8") as f:
        json.dump(version, f, indent=2)
    print(f"\n  -> version.json  ({version['generated_at']})")

    # Copy version to backend static dir for the /ps-data/version endpoint
    backend_static = os.path.join(
        os.path.dirname(__file__), "..", "backend", "app", "static"
    )
    os.makedirs(backend_static, exist_ok=True)
    backend_ver = os.path.join(backend_static, "ps_data_version.json")
    with open(backend_ver, "w", encoding="utf-8") as f:
        json.dump(version, f, indent=2)
    print(f"  -> backend/app/static/ps_data_version.json")

    print("\nSync complete. Commit assets/data/ps/ and "
          "backend/app/static/ps_data_version.json.\n")


if __name__ == "__main__":
    main()
