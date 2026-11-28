#!/usr/bin/env python3
"""
build_icon_map.py — Map PokéAPI Pokémon/form names to PokeSprite / bamq box icons.

Sources (both pinned to a commit SHA so upstream restructures can't break us —
see docs/investigation/231-use-pokesprite-for-icons.md):
  ps  msikma/pokesprite        pokemon-gen8/{regular,shiny}/[female/]{slug}.png
                               Gen 1–8 (dex 1–905), Megas, G-Max, cosmetic forms.
  bq  bamq/pokemon-sprites     pokemon/{regular,shiny}/[female/]{slug}.png
                               Gen 9 + Paldean forms, 68×56 to match PokeSprite.

Names come from PokéAPI's /pokemon (varieties) and /pokemon-form (form entries)
lists. Each name is split into species + form suffix (longest species-name
prefix), then resolved against PokeSprite's data/pokemon.json form table
(following `is_alias_of`), then against the bamq file list. Every candidate is
checked against the pinned git tree, so the map never points at a missing file.

Output: shared/pokesprite_icons.json
  {
    "sources": {"ps": {"repo", "sha", "base"}, "bq": {...}},
    "icons":   {"<pokeapi-name>": {"src": "ps"|"bq", "slug": "...",
                                    "female": bool, "shiny": bool}}
  }
  Regular URL: {base}/regular/{slug}.png
  Shiny URL:   {base}/shiny/{slug}.png          (when "shiny")
  Female URL:  {base}/regular/female/{slug}.png (when "female")

Names with no icon in either source are printed (and omitted); callers fall
back to the PokéAPI icon chain for those.

Usage:
    pip install requests
    python scripts/build_icon_map.py            # write the map
    python scripts/build_icon_map.py --check    # exit 1 if the committed map is stale

Set GITHUB_TOKEN to avoid the unauthenticated GitHub API rate limit.
"""

import argparse
import json
import os
import sys

try:
    import requests
except ImportError:
    sys.exit("Install dependencies first:  pip install requests")

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

SOURCES = {
    "ps": {
        "repo": "msikma/pokesprite",
        "sha": "c5aaa610ff2acdf7fd8e2dccd181bca8be9fcb3e",
        "dir": "pokemon-gen8",
    },
    "bq": {
        "repo": "bamq/pokemon-sprites",
        "sha": "c1958e7260a4bce93bd104e79966a27fb333c7aa",
        "dir": "pokemon",
    },
}

POKEAPI = "https://pokeapi.co/api/v2"
OUT_PATH = os.path.join(os.path.dirname(__file__), "..", "shared", "pokesprite_icons.json")

# PokéAPI form suffix → icon-repo form suffix ("$" = the bare species icon),
# applied to every species. Mostly PokéAPI using a longer slug than the icon
# repos (same idea as the resolver's `_SPRITE_SUFFIX_REMAP`).
SUFFIX_OVERRIDES: dict[str, str] = {
    "east-sea": "east",
    "west-sea": "west",
    "galar-standard": "galar",       # darmanitan-galar-standard
    "amped-gmax": "gmax",            # toxtricity-amped-gmax
    # Same artwork as the plain form — only the ability / underside stamp
    # differs. Power Construct Zygarde only changes form in battle, so it uses
    # its Aura Break counterpart's icon (Totems likewise use their non-Totem
    # counterpart, via PokeSprite's is_alias_of table).
    "10-power-construct": "10",
    "50-power-construct": "$",
    "antique": "$",                  # sinistea / polteageist
    "artisan": "$",                  # poltchageist
    "masterpiece": "$",              # sinistcha
}

# Suffix overrides scoped to one species, where a global entry could mis-map
# another species' form with the same suffix.
SPECIES_SUFFIX_OVERRIDES: dict[str, dict[str, str]] = {
    "calyrex": {"ice": "ice-rider", "shadow": "shadow-rider"},
    # The games use one icon for every size. PokeSprite's per-size Pumpkaboo
    # icons are flagged is_unofficial_icon, and it already aliases every
    # Gourgeist size to the base icon.
    "pumpkaboo": {"small": "$", "large": "$", "super": "$"},
    "maushold": {"family-of-three": "$"},   # bamq's bare "maushold" is the family of three
    "ogerpon": {"": "teal-mask"},           # default variety has no mask suffix
}

# Full PokéAPI name → (source, slug). Highest priority; for names whose
# structure doesn't follow species + suffix in either repo.
NAME_OVERRIDES: dict[str, tuple[str, str]] = {}

# PokéAPI "-sweet" suffixes on Alcremie form entries
# (alcremie-ruby-cream-star-sweet); the icon repos omit it.
_STRIP_SUFFIX_TAILS = ("-sweet",)


# ---------------------------------------------------------------------------
# Fetch helpers
# ---------------------------------------------------------------------------

_session = requests.Session()
if os.environ.get("GITHUB_TOKEN"):
    _session.headers["Authorization"] = f"Bearer {os.environ['GITHUB_TOKEN']}"


def _get_json(url: str):
    r = _session.get(url, timeout=60)
    r.raise_for_status()
    return r.json()


def fetch_tree(key: str) -> set[str]:
    """All blob paths under the source's icon dir, relative to that dir, minus `.png`."""
    src = SOURCES[key]
    tree = _get_json(
        f"https://api.github.com/repos/{src['repo']}/git/trees/{src['sha']}?recursive=1"
    )
    if tree.get("truncated"):
        sys.exit(f"{src['repo']} tree listing was truncated")
    prefix = src["dir"] + "/"
    return {
        t["path"][len(prefix):-4]
        for t in tree["tree"]
        if t["type"] == "blob" and t["path"].startswith(prefix) and t["path"].endswith(".png")
    }


def fetch_pokesprite_data() -> dict:
    src = SOURCES["ps"]
    return _get_json(
        f"https://raw.githubusercontent.com/{src['repo']}/{src['sha']}/data/pokemon.json"
    )


def _id_from_url(url: str) -> int:
    return int(url.rstrip("/").rsplit("/", 1)[-1])


def fetch_pokeapi_names() -> tuple[dict[str, int], dict[str, int]]:
    """(species name → dex id, pokemon/form name → resource id)."""
    species = {
        r["name"]: _id_from_url(r["url"])
        for r in _get_json(f"{POKEAPI}/pokemon-species?limit=5000")["results"]
    }
    names: dict[str, int] = {}
    for endpoint in ("pokemon", "pokemon-form"):
        for r in _get_json(f"{POKEAPI}/{endpoint}?limit=5000")["results"]:
            names.setdefault(r["name"], _id_from_url(r["url"]))
    return species, names


# ---------------------------------------------------------------------------
# Resolution
# ---------------------------------------------------------------------------


def split_species(name: str, species: dict[str, int]) -> tuple[str, str] | None:
    """Longest species-name prefix → (species, suffix). Handles hyphenated
    species like mr-mime, tapu-koko, ho-oh."""
    best = None
    for sp in species:
        if name == sp or name.startswith(sp + "-"):
            if best is None or len(sp) > len(best):
                best = sp
    if best is None:
        return None
    return best, name[len(best) + 1:]


def _entry(key: str, slug: str, files: set[str]) -> dict:
    return {
        "src": key,
        "slug": slug,
        # A slug already inside female/ has no separate female variant.
        "female": not slug.startswith("female/") and f"regular/female/{slug}" in files,
        "shiny": f"shiny/{slug}" in files,
    }


def form_candidates(sp: str, suffix: str, is_default: bool) -> list[str]:
    """Ordered icon-repo form suffixes to try ("$" = bare species icon)."""
    for tail in _STRIP_SUFFIX_TAILS:
        if suffix.endswith(tail):
            suffix = suffix[: -len(tail)]
    species_map = SPECIES_SUFFIX_OVERRIDES.get(sp, {})
    if suffix in species_map:
        out = [species_map[suffix]]
    elif suffix:
        out = [SUFFIX_OVERRIDES.get(suffix, suffix), suffix]
    else:
        out = ["$"]
    if is_default:
        # Default varieties/forms often carry a suffix in PokéAPI
        # (deoxys-normal, wormadam-plant) but are the bare slug in the repos.
        out.append("$")
    return list(dict.fromkeys(out))


def _pick(slug: str, forms: list[str], files: set[str]) -> str | None:
    for form in forms:
        if form == "female":
            # Gender-difference icons live in a female/ subdirectory.
            file = f"female/{slug}"
        else:
            file = slug if form == "$" else f"{slug}-{form}"
        if f"regular/{file}" in files:
            return file
    return None


def resolve_pokesprite(
    forms: list[str], dex: int, ps_data: dict, ps_files: set[str]
) -> str | None:
    entry = ps_data.get(f"{dex:03d}")
    if entry is None:
        return None
    table = entry.get("gen-8", {}).get("forms", {})

    def unalias(form: str) -> str:
        seen = set()
        while form in table and form not in seen:
            seen.add(form)
            alias = table[form].get("is_alias_of")
            if not alias:
                break
            form = alias
        return form

    return _pick(entry["slug"]["eng"], [unalias(f) for f in forms], ps_files)


def resolve_bamq(sp: str, forms: list[str], bq_files: set[str]) -> str | None:
    # bamq has no data file; its slugs follow PokéAPI species names.
    return _pick(sp, forms, bq_files)


def build() -> tuple[dict, list[str]]:
    print("Fetching PokeSprite / bamq trees and PokéAPI name lists…", file=sys.stderr)
    ps_files = fetch_tree("ps")
    bq_files = fetch_tree("bq")
    ps_data = fetch_pokesprite_data()
    species, names = fetch_pokeapi_names()

    icons: dict[str, dict] = {}
    uncovered: list[str] = []
    for name in sorted(names):
        if name in NAME_OVERRIDES:
            key, slug = NAME_OVERRIDES[name]
            files = ps_files if key == "ps" else bq_files
            if f"regular/{slug}" not in files:
                sys.exit(f"NAME_OVERRIDES[{name!r}] → {key}:{slug} does not exist")
            icons[name] = _entry(key, slug, files)
            continue

        split = split_species(name, species)
        if split is None:
            uncovered.append(name)
            continue
        sp, suffix = split
        dex = species[sp]
        # Resource ids ≤ the species count are default varieties/forms.
        is_default = names[name] <= len(species)

        forms = form_candidates(sp, suffix, is_default)

        slug = resolve_pokesprite(forms, dex, ps_data, ps_files)
        if slug:
            icons[name] = _entry("ps", slug, ps_files)
            continue
        slug = resolve_bamq(sp, forms, bq_files)
        if slug:
            icons[name] = _entry("bq", slug, bq_files)
            continue
        uncovered.append(name)

    out = {
        "sources": {
            key: {
                "repo": src["repo"],
                "sha": src["sha"],
                "base": f"https://raw.githubusercontent.com/{src['repo']}/{src['sha']}/{src['dir']}",
            }
            for key, src in SOURCES.items()
        },
        "icons": icons,
    }
    return out, uncovered


def _dump(data: dict) -> str:
    """Pretty top level, one icon entry per line — small asset, readable diffs."""
    def compact(v) -> str:
        return json.dumps(v, sort_keys=True, ensure_ascii=False, separators=(",", ":"))

    sources = ",\n".join(f'  {compact(k)}:{compact(v)}' for k, v in sorted(data["sources"].items()))
    icons = ",\n".join(f'  {compact(k)}:{compact(v)}' for k, v in sorted(data["icons"].items()))
    return '{\n "sources":{\n' + sources + '\n },\n "icons":{\n' + icons + "\n }\n}\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--check", action="store_true",
                        help="exit 1 if the committed map differs from a fresh build")
    args = parser.parse_args()

    out, uncovered = build()
    text = _dump(out)

    counts = {k: sum(1 for v in out["icons"].values() if v["src"] == k) for k in SOURCES}
    print(f"Mapped {len(out['icons'])} names (ps={counts['ps']}, bq={counts['bq']}); "
          f"{len(uncovered)} uncovered:", file=sys.stderr)
    for name in uncovered:
        print(f"  {name}", file=sys.stderr)

    if args.check:
        try:
            current = open(OUT_PATH, encoding="utf-8").read()
        except FileNotFoundError:
            current = ""
        if current != text:
            sys.exit(f"{OUT_PATH} is stale — re-run scripts/build_icon_map.py")
        print("Icon map is up to date.", file=sys.stderr)
        return

    with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"Wrote {os.path.normpath(OUT_PATH)}", file=sys.stderr)


if __name__ == "__main__":
    main()
