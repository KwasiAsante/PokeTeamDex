# Investigation #276 — Move/Item/Ability/Learnset Validation Architecture

## Context

A bug where Alolan Ninetales incorrectly appears able to learn Freeze-Dry in Gen 9 (Scarlet/Violet) opened a broader question about how we source and validate learnsets, moves, items, and abilities across the backend and frontend. This document traces the full data flow end-to-end, identifies where consolidation currently happens, and defines the target architecture where the backend owns the heavy work.

---

## 1. How a Pokémon's Move List Is Currently Built

### 1.1 Backend — `pokemon_resolver.py`

| Step | Source | Result |
|---|---|---|
| Primary | PokéAPI `/pokemon/{id}` | Full `moves` list with `version_group_details` (game, method, level) per move |
| Supplement | `event_learnsets.json` via `_get_supplement_moves()` | Moves PokéAPI has **no record of at all** (not filtered out — genuinely absent) |

The backend preserves all `version_group_details` from PokéAPI and serves the moves as `list[MoveSummary]` via `GET /pokemon/moves/{id}`. It does **not** filter by version group or generation — that is left entirely to the frontend.

The supplement path in `_get_supplement_moves()` is intentionally narrow: it only adds a move when `move_id not in pokeapi_move_slugs`. If PokéAPI knows about a move for this Pokémon (even if only for a different version group), the backend does **not** supplement it.

### 1.2 Frontend — `pokemonMovesProvider`

```
pokemonMovesProvider(id)
  → GET /pokemon/moves/{id}      (backend, prefers cache)
  → fallback: pokemonDetailProvider(id).moves  (direct PokéAPI call, no consolidation)
```

Result: `List<MoveSummary>` with full `learn_details` (version_group, method, level) per move. This is exactly what PokéAPI returns, proxied through the backend with no filtering.

### 1.3 Frontend — Learnset Validation (`slot_validator.dart`)

`slot_config_screen.dart` calls `buildLearnsetForFormat(effectivePokemonMoves, format, pokemonName, formatService)`, which runs two passes:

**Pass 1 — PokéAPI version-group filter (`_buildLearnset`, line 168):**
- Iterates `pokemonMoves` (from `pokemonMovesProvider`)
- Accepts a move if any of its `version_group_details` entries belongs to a version group in gens 1–N
- This correctly excludes moves a Pokémon can only learn in a **different** game within the same generation

**Pass 2 — PS supplementation (lines 176–207):**
- Calls `formatService.learnsetForGen(name, gen)` → queries `learnsets.json` gen bucket
- Calls `formatService.eventMovesForGen(name, gen)` → queries `event_learnsets.json` for `S`-coded sources
- Adds any PS move that matches a move already in `pokemonMoves` (by PS id)
- Also adds genuine event-exclusive moves that never appear in `pokemonMoves` at all

**The Freeze-Dry / Ninetales bug lives in Pass 2.** PokéAPI knows about Freeze-Dry on Ninetales-Alola — but only for the Champions version group, not `scarlet-violet`. Pass 1 correctly excludes it. Pass 2 then finds `freezedry` in `learnsets.json` gen 9 and adds it back, incorrectly overriding Pass 1's correct exclusion.

Note: Freeze-Dry on Ninetales-Alola IS legal in Gen 9 competitive (Vulpix-Alola learns it at level 48 in SV, and the move is inherited on evolution — the `9L1` code in PS). The bug is not that it is shown at all, but that it is shown as directly learnable rather than `via_prevo`.

---

## 2. The Current PS Data Files

### 2.1 `learnsets.json` (gen-bucketed, lossy) — **to be eliminated**

- **Fetch source:** `play.pokemonshowdown.com/data/learnsets.json` (compiled endpoint)
- **Transform:** Strips method letter and level; keeps only the leading generation digit
- **Used by:** Frontend only — `learnsetForGen()` → Pass 2 supplementation
- **Cannot distinguish:** game within a generation, how a move is learned, or whether a move is a carry-over vs directly learnable
- **Status:** Redundant once `learnset_N.json` files replace it. Remove from sync script and Hive.

### 2.2 `event_learnsets.json` (full source codes + eventData) — **to be eliminated**

- **Fetch source:** `data/learnsets.ts` + all `data/mods/gen{1–9}/learnsets.ts`, merged
- **Transform:** Keeps full source code strings (`9L48`, `7E`, `8T`, `9M`, `2S1`) and `eventData` records
- **Used by:** Backend — `_get_supplement_moves()` (moves absent from PokéAPI entirely); Frontend — `eventMovesForGen()` (S-coded sources only; `eventData` records are never actually read)
- **Critical:** Contains ALL moves for ALL Pokémon with full method codes — not just event moves despite the name
- **What transfers to `learnset_N.json`:** All learnset/source-code data. The new per-gen files capture the same information in structured form (method strings, level integers) — no data is lost.
- **What does NOT transfer:** `eventData` records (specific event distribution details — OT, shininess, pokeball, moveset per distribution). These are not currently consumed by any part of the app. They are dropped. If a future feature needs them (e.g. showing event legality detail), a separate `event_data.json` can be generated then.
- **Status:** Eliminated once `learnset_N.json` files are in place and the backend consolidation is updated.

### 2.3 `learnset_N.json` files (new, gen-specific, pre-processed) — **to be generated**

One file per generation (1–9). **Each file covers only that generation's native moves** — i.e., entries whose PS source codes begin with that generation's digit. Not cumulative.

`learnset_9.json` contains only moves learnable in gen 9 games (source codes `9L…`, `9T`, `9E`, `9M`, `9S…`). It does not include gen 7 egg moves or gen 8 tutors for the same Pokémon — those live in `learnset_7.json` and `learnset_8.json` respectively. The backend (or frontend fallback) combines the relevant gen files based on the format's transfer rules.

Format:
```json
{
  "ninetalesalola": {
    "freezedry": [{"method": "level_up", "level": 1}],
    "auroraveil": [{"method": "level_up", "level": 1}],
    "blizzard":   [{"method": "machine"}]
  }
}
```

Source code → method mapping:

| PS code | `method` | Notes |
|---|---|---|
| `9L48` | `"level_up"`, `level: 48` | Level-up at 48 in gen 9 |
| `9L1` | `"level_up"`, `level: 1` | Pre-evo inherit marker — backend detects this + prevo chain = `via_prevo` |
| `9T` | `"tutor"` | |
| `9E` | `"egg"` | |
| `9M` | `"machine"` | |
| `9S0` | `"event"` | |

A move can have multiple entries if learnable by multiple methods in the same gen:
```json
"tackle": [{"method": "level_up", "level": 1}, {"method": "egg"}]
```

`via_prevo` detection happens at **backend consolidation time**, not in the script. A level-1 entry for an evolved form whose pre-evo can learn the same move in the same gen at a higher level is flagged `via_prevo` by the backend using `pokedex.json`'s `prevo` field.

**File destinations:** Per-gen files are written to BOTH `assets/data/ps/` and `backend/app/static/` — the same pattern already used for `moves.json`, `items.json`, etc. Flutter downloads updated files via `/ps-data/file/:name` and stores them in Hive. The backend loads them at startup. Both sides read identically formatted files from the same generation of data.

### Key finding: `learnsets.json` is a lossy subset of `event_learnsets.json`

`event_learnsets.json` is built from the raw TypeScript (main + all mods) and contains every move `learnsets.json` has, plus full method codes and eventData. `learnsets.json` can be derived from it entirely. It is a redundant file.

### What "using the TypeScript source" means for us

We already fetch from `smogon/pokemon-showdown` GitHub for `event_learnsets.json`, `pokedex.json`, `pokedex-gen-overrides.json`, and `formats-data.json`. The remaining compiled endpoints are `learnsets.json` (redundant), `moves.json`, `items.json`, and `abilities.json` (worth evaluating separately whether switching gives useful new fields).

---

## 3. Where Consolidation Currently Happens

| Step | Where | When |
|---|---|---|
| PokéAPI + `event_learnsets.json` supplement | Backend | On first resolve (cached 7 days) |
| PokéAPI version-group filtering (Pass 1) | Frontend | Runtime, every render |
| PS gen-bucket supplementation (Pass 2) | Frontend | Runtime, every render |
| PS event-source supplementation | Frontend | Runtime, every render |
| Pre-evo move comparison | Frontend | Runtime, every render |
| Ability gen-gating | Frontend | Runtime, every render |
| Item gen-gating | Frontend | Runtime, every render |

All validation runs on the frontend against multi-megabyte in-memory maps parsed from Hive.

---

## 4. Finalized Implementation Plan

### 4.1 `sync_ps_data.py` — Per-Gen Learnset Files

Generate `learnset_1.json` through `learnset_9.json` from the existing `event_learnsets.json` data (no new fetches needed — source codes are already in hand).

**Generation rule:** `learnset_N.json` is **gen-N specific** — it includes only move entries where the source code's leading digit equals N. A Pokémon introduced in gen 7 (e.g. Ninetales-Alola) has `learnset_7.json` entries (gen 7 moves), `learnset_8.json` entries (gen 8 moves), and `learnset_9.json` entries (gen 9 moves) as three separate files. Cross-gen transfer logic (e.g. "what moves can this Pokémon have in gen 9 via home transfer from gen 7?") is handled by the backend combining relevant gen files based on format rules.

**Pre-processing rule:** Convert raw PS source codes to structured entries. Each move becomes an array of `{method, level?}` objects (no gen field needed since the file itself names the gen):

```json
{
  "ninetalesalola": {
    "freezedry": [{"method": "level_up", "level": 1}],
    "icebeam":   [{"method": "machine"}]
  }
}
```

A helper function handles the conversion; unknown codes are mapped to `"other"` and logged.

**Also update `transform_pokedex`** to preserve the `prevo` field (and `evos` for completeness). Currently these are stripped; the backend needs `prevo` for evolution chain traversal without PokéAPI calls.

**File destinations:** All per-gen files go to `assets/data/ps/` AND `backend/app/static/`. They are added to the `served_files` list and the `version.json` SHA manifest. Flutter downloads them via `/ps-data/file/:name` for Hive refresh; the backend loads them at startup. Both sides read identically formatted files.

Remove the compiled `learnsets.json` fetch and the `transform_learnsets` function from the script once the frontend fallback (§4.6) no longer needs it.

### 4.2 Backend — Learnset Service

A new `LearnsetService` (or methods on the existing resolver) loaded at startup:

- Loads `learnset_1.json` through `learnset_9.json` into memory
- Loads the updated `pokedex.json` (now includes `prevo`)
- Provides `get_learnset(ps_name, gen)` → the pre-processed entry for that Pokémon in that gen file
- Provides `get_prevo_chain(ps_name)` → ordered list of pre-evo PS names by walking `prevo` pointers up the chain

**PS ID fallback normalization** — when a lookup fails, try these variants in order:
1. `vulpixalola` (original — no separators)
2. `vulpix-alola` (hyphenated)
3. `vulpix_alola` (underscored)
4. `vulpix alola` (spaced)
5. Regional prefix variants: `alola-vulpix`, `alolan-vulpix`

A single `_normalize_ps_id(name)` helper returns a list of candidates to try.

**Version group → generation mapping** hardcoded in the backend (mirrors `PokemonDataRegistry.genToVersionGroups` on the frontend).

### 4.3 Backend — Updated `/pokemon/moves/{id}` Endpoint

**No new endpoint.** Add an optional `gen` query parameter (integer, 1–9) to the existing `GET /pokemon/moves/{id}`.

**Consolidation logic (with `?gen=N`):**

1. **Primary — PokéAPI `version_group_details`:** Map the requested gen to its version groups (via hardcoded `gen → version_group` map). Filter `version_group_details` to those groups. This is the authoritative source. Side-game version groups (`scarlet-violet-zero` / Champions, `colosseum`, `xd`, `stadium`, `stadium-2`) are excluded from the filter.
2. **Supplement — `learnset_N.json`:** For any move in the PS gen-N file that PokéAPI has **no record of at all** for any version group for this Pokémon, add it as a supplement (PS fills genuine PokéAPI gaps, not game-level exclusions).
3. **Pre-evo detection:** Walk `get_prevo_chain(ps_name)`. For each level-1 move in the consolidated list, check if the immediate pre-evo can learn the same move in gen N at a higher level. If yes, flag `via_prevo: true, prevo: "<ps_id>"`.

**With `?gen=N` response:**
```json
{
  "pokemon_id": 38,
  "name": "ninetales-alola",
  "gen": 9,
  "moves": [
    {
      "name": "freezedry",
      "learn_details": {
        "version_group": "scarlet-violet",
        "method": "level_up",
        "level": 1,
        "via_prevo": true,
        "prevo": "vulpix-alola"
      }
    }
  ]
}
```

**Without `gen` parameter** — run consolidation for each gen 1–9 and return keyed by gen:
```json
{
  "pokemon_id": 38,
  "name": "ninetales-alola",
  "gen": null,
  "moves": [],
  "gen_moves": {
    "9": [ ... ],
    "8": [ ... ],
    "7": [ ... ]
  }
}
```

### 4.4 Backend — Updated Schemas

```python
class MoveLearnDetail(BaseModel):
    version_group: str
    method: str          # "level_up", "machine", "egg", "tutor", "event"
    level: int | None
    via_prevo: bool = False
    prevo: str | None = None   # PokéAPI hyphenated name of the ancestor

class MoveSummary(BaseModel):
    name: str
    learn_details: MoveLearnDetail   # single best detail (gen-filtered response)

class MovesResponse(BaseModel):
    pokemon_id: int
    name: str
    gen: int | None
    moves: list[MoveSummary]                             # populated when gen is provided
    gen_moves: dict[str, list[MoveSummary]] | None = None  # populated when gen is omitted
```

### 4.5 Frontend — Model + Provider Updates

- Update `MoveLearnDetail` in `models.dart` to add `via_prevo` (bool) and `prevo` (String?)
- Update `pokemonMovesProvider` to accept and forward an optional gen parameter
- Update `MoveSummary.fromJson` / `MoveLearnDetail.fromJson` for the new schema
- Update `slot_config_screen.dart` and `pokemon_detail_screen.dart` to pass the active format's gen to `pokemonMovesProvider`

### 4.6 Frontend — Slot Validator and Offline Fallback Refactor

**Backend path (happy path):**
- Remove Pass 2 PS gen-bucket supplementation (`learnsetForGen` call) — the backend now handles this
- The backend `moves` response already contains `via_prevo` moves so no separate pre-evo comparison is needed on the frontend

**New `validLearnsetProvider(pokemonId, gen)`** — wraps the backend call and enforces the fallback chain:
```
try:
  GET /pokemon/moves/{id}?gen=N   (backend, 7-day cache)
catch (backend unreachable):
  check Hive cache (allow up to 24h expired)
  if cache hit: return cached
  if no cache + internet available:
    PokéAPI version_group_details + learnset_N.json (local) consolidation
    cache result with 24-hour TTL (flagged as fallback-sourced)
  if no cache + no internet:
    throw user-visible error ("Could not load move data — check your connection")
```

This replaces the inline `buildLearnsetForFormat(...)` call in `slot_config_screen.dart`. No inline consolidation in screens.

**Offline fallback consolidation** replicates backend logic locally using the per-gen files in Hive. Key rule: skip adding a PS move if PokéAPI already lists it for this Pokémon in any version group — this alone fixes the Ninetales/Freeze-Dry bug in the offline path.

**Other provider fixes:**
- `pokemonVarietiesProvider` and `pokemonFormsProvider` currently return `[]` on error — replace with PokéAPI fallback or a meaningful throw. No silent empty fallbacks.

### 4.7 Items, Moves, and Abilities — New Standalone Endpoints

Three pairs of endpoints, one pair per resource. Each consolidates PokéAPI (base) + PS TypeScript source (supplement). All results cached in PostgreSQL DB with 7-day TTL (same pattern as resolved Pokémon data).

#### Data sources

PS TS source replaces the remaining compiled endpoints in `sync_ps_data.py`:

| Current file | Current source | New source |
|---|---|---|
| `moves.json` | `play.pokemonshowdown.com/data/moves.json` | `data/moves.ts` |
| `items.json` | `play.pokemonshowdown.com/data/items.js` | `data/items.ts` |
| `abilities.json` | `play.pokemonshowdown.com/data/abilities.js` | `data/abilities.ts` |

All three use the existing `fetch_js_endpoint()` pattern — no special handling needed.

**Move transform — new fields from `data/moves.ts`:**
- `priority` (int)
- `flags` (object — `contact`, `protect`, `sound`, `mirror`, `heal`, etc.)
- `secondary` (secondary effect detail — chance, stat changes, status conditions)
- `z_move_base` (move name this Z-move is based on, if applicable)
- `max_move_base` (move name this Max/G-Max move is based on, if applicable)

Item and ability transforms already capture the fields we need from the TS source.

#### Endpoints

**Moves:**
- `GET /moves` — paginated list; optional query params: `gen`, `damage_class` (physical/special/status), `contest_type`, `is_z_move` (bool), `is_max_move` (bool)
- `GET /moves/{id_or_name}` — single move; consolidated PokéAPI + PS

**Items:**
- `GET /items` — paginated list; optional query params: `gen`, `category` (PokéAPI item-category taxonomy), PS flag params: `is_mega_stone`, `is_z_crystal`, `is_berry`, `is_plate`, `is_memory`
- `GET /items/{id_or_name}` — single item; consolidated PokéAPI + PS

**Abilities:**
- `GET /abilities` — paginated list; optional query params: `gen`, `pokemon` (name or id — returns the full ability models for each of that Pokémon's abilities, including which slot: 1, 2, or hidden)
- `GET /abilities/{id_or_name}` — single ability; consolidated PokéAPI + PS

#### Caching scope

PostgreSQL DB caching is applied to **all** data endpoints — both new and existing:

| Endpoint | Cached? |
|---|---|
| `GET /pokemon/{id}/resolved` | ✅ existing |
| `GET /pokemon/moves/{id}` | extend to DB |
| `GET /pokemon/varieties/{id}` | extend to DB |
| `GET /pokemon/forms/{id}` | extend to DB |
| `GET /pokemon/smogon/{id}` | extend to DB |
| `GET /pokemon/flavor-text/{id}` | extend to DB |
| `GET /moves` / `GET /moves/{id}` | new, DB-cached |
| `GET /items` / `GET /items/{id}` | new, DB-cached |
| `GET /abilities` / `GET /abilities/{id}` | new, DB-cached |

#### Frontend migration scope

Once the backend endpoints exist, the frontend migrates away from local PS data for all three resources:

- **Pickers** (slot config): item picker, move picker, ability picker → call backend list endpoints with local PS data fallback
- **List screens**: moves list, items list, abilities list → call backend paginated endpoints
- **Detail screens**: move detail, item detail, ability detail → call backend single-entry endpoints
- **`FormatService` methods** `itemsForGen()`, `movesForGen()`, `abilitiesForGen()` → replaced by backend calls; local PS data retained as offline fallback only

---

## 5. Sub-Issues

| # | Title | Scope |
|---|---|---|
| A | `sync_ps_data.py`: generate `learnset_1–9.json` + update pokedex transform (`prevo`/`evos`) + switch moves/items/abilities from compiled endpoints to TS source + add new move fields | Script only |
| B | Backend: learnset service + PS ID normalization + prevo chain traversal | New service, no endpoint changes |
| C | Backend: update `/pokemon/moves` with `gen` param + full consolidation + new learnset schemas | Endpoint + schemas |
| D | Frontend: update move models, `pokemonMovesProvider`, `validLearnsetProvider`, slot validator refactor, `pokemon_detail_screen.dart` Moves tab audit | Flutter only |
| E | Backend: new `/items`, `/moves`, `/abilities` list + single-entry endpoints with PokéAPI+PS consolidation | New endpoints + schemas |
| F | Backend: extend PostgreSQL DB caching to `/pokemon/moves`, `/pokemon/varieties`, `/pokemon/forms`, `/pokemon/smogon`, `/pokemon/flavor-text`, and all new endpoints from sub-issue E | Backend infra |
| G | Frontend: migrate item/move/ability pickers + list/detail screens to backend endpoints with offline fallback; retire `FormatService` gen-gating methods | Flutter only |

Sub-issues are created after this investigation PR is merged.

---

## 6. Open Items (Deferred)

- **`eventData` detail:** Not currently consumed anywhere. Dropped with `event_learnsets.json`. If a future feature needs event distribution details (OT, shininess, pokeball), generate a separate `event_data.json` at that point.
- **Side-game allowlist:** Formal definition of which PS version groups are in scope. Initial blocklist: `scarlet-violet-zero` (Champions), `colosseum`, `xd`, `stadium`, `stadium-2`.
