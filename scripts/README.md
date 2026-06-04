# scripts/

Maintenance scripts. Run locally by the developer — not part of the Flutter build or CI pipeline.

---

## sync_ps_data.py

Downloads, trims, and bundles Pokémon Showdown data for use by the format engine.

### What it does

1. Fetches raw data files from `https://play.pokemonshowdown.com/data/`
2. Trims fields the app doesn't need (reduces file sizes significantly)
3. Writes processed JSON to `assets/data/ps/` (bundled into the Flutter app)
4. Computes SHA-256 hashes and writes `version.json`
5. Copies `version.json` to `backend/app/static/` so the backend can serve it via `GET /ps-data/version`

### Output files

| File | Source | Description |
|------|--------|-------------|
| `assets/data/ps/learnsets.json` | PS learnsets.js | Per-Pokémon move lists by learn method |
| `assets/data/ps/moves.json` | PS moves.js | Move stats (type, power, accuracy, PP, Z/Max data) |
| `assets/data/ps/items.json` | PS items.js | Item data (gen introduced, Mega/Z mappings) |
| `assets/data/ps/abilities.json` | PS abilities.js | Ability data (gen introduced) |
| `assets/data/ps/formats.json` | Manually curated | 32 competitive format definitions |
| `assets/data/ps/learnsets-g6-allowlist.json` | Derived | Gen 6 legality cross-reference |
| `assets/data/ps/version.json` | Computed | SHA-256 of each above file |
| `backend/app/static/version.json` | Copied | Served by `GET /ps-data/version` |

### Usage

```bash
# Install dependencies (one-time)
pip install requests json5

# Run
python scripts/sync_ps_data.py

# Commit the output
git add assets/data/ps/ backend/app/static/
git commit -m "chore: update PS data"
```

### When to run

- After a new Pokémon generation or DLC releases (new Pokémon / moves / items)
- When Pokémon Showdown updates their format definitions
- After catching a learnset validation bug (stale data)

After committing and deploying the backend, any app instance that fetches `/ps-data/version` will detect the SHA change and download the updated files automatically in the background.
