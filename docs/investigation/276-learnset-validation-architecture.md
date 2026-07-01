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
  → fallback: pokemonDetailProvider(id).moves  (direct PokéAPI call)
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

### 2.1 `learnsets.json` (gen-bucketed, lossy)

- **Fetch source:** `play.pokemonshowdown.com/data/learnsets.json` (compiled endpoint)
- **Transform:** Strips method letter and level; keeps only the leading generation digit
- **Used by:** Frontend only — `learnsetForGen()` → Pass 2 supplementation
- **Cannot distinguish:** game within a generation, how a move is learned, or whether a move is a carry-over vs directly learnable

### 2.2 `event_learnsets.json` (full source codes + eventData)

- **Fetch source:** `data/learnsets.ts` + all `data/mods/gen{1–9}/learnsets.ts`, merged
- **Transform:** Keeps full source code strings (`9L48`, `7E`, `8T`, `9M`, `2S1`) and `eventData` records
- **Used by:** Backend — `_get_supplement_moves()` (moves absent from PokéAPI entirely); Frontend — `eventMovesForGen()` (S-coded + eventData only)
- **Critical:** Contains ALL moves for ALL Pokémon with full method codes — not just event moves despite the name

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

**Generation rule:** `learnset_N.json` is cumulative — it includes every move entry where the source code's leading digit is ≤ N. A Pokémon introduced in gen 7 (e.g. Ninetales-Alola) appears in `learnset_7.json` through `learnset_9.json`.

**Pre-processing rule:** Convert raw PS source codes to structured entries. Each move becomes an array of `{gen, method, level}` objects:

```json
{
  "ninetalesalola": {
    "freezedry": [
      { "gen": 7, "method": "egg",      "level": null },
      { "gen": 8, "method": "egg",      "level": null },
      { "gen": 9, "method": "level_up", "level": 1    }
    ],
    "icebeam": [
      { "gen": 7, "method": "machine",  "level": null },
      { "gen": 9, "method": "level_up", "level": 45   }
    ]
  }
}
```

Source code → method mapping:

| PS code letter | method |
|---|---|
| `L` | `level_up` (level extracted from the number; `L1` on an evolved form is handled by backend pre-evo detection) |
| `E` | `egg` |
| `T` | `tutor` |
| `M` | `machine` |
| `S` | `event` |

A helper function in the script handles the conversion with fallback for unknown codes.

**Also update `transform_pokedex`** to preserve the `prevo` field (and `evos` for completeness). Currently these are stripped; the backend needs `prevo` for evolution chain traversal without PokéAPI calls.

**File destinations:** Per-gen files go to `backend/app/static/` only (not served to Flutter via `/ps-data/file/:name` and not bundled as Flutter assets — these are backend-only). `learnsets.json` remains for frontend offline fallback for now; it can be removed once the frontend fallback is updated to use `event_learnsets.json` source codes directly.

### 4.2 Backend — Learnset Service

A new `LearnsetService` (or methods on the existing resolver) loaded at startup:

- Loads `learnset_1.json` through `learnset_9.json` into memory
- Loads the updated `pokedex.json` (now includes `prevo`)
- Provides `get_learnset(ps_name, gen)` → the pre-processed entry for that Pokémon in that gen
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

Add an optional `gen` query parameter (integer, 1–9). The existing `resolve_moves()` flow is replaced by a consolidation routine:

**With `?gen=N`:**
1. Get PokéAPI moves from DB cache (or resolve fresh if not cached)
2. Filter PokéAPI moves to version groups belonging to gen N; for each keep the best `version_group` and `method`/`level` detail
3. Supplement with `learnset_N.json`: for each move in the PS file not already in the PokéAPI result, add it (PokéAPI is always the primary source — PS only fills genuine gaps)
4. Build pre-evo chain via `get_prevo_chain(ps_name)`; get each ancestor's gen-N learnset; any move present in an ancestor but not in the Pokémon's direct PokéAPI+PS learnset is marked `via_prevo: true, prevo: "<ancestor_name>"`
5. Return:

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
    },
    {
      "name": "icebeam",
      "learn_details": {
        "version_group": "scarlet-violet",
        "method": "machine",
        "level": null,
        "via_prevo": false,
        "prevo": null
      }
    }
  ]
}
```

**Without `gen` parameter:**
- Run the same consolidation for each generation 1–9
- Return `moves: []` and populate `gen_moves`:

```json
{
  "pokemon_id": 38,
  "name": "ninetales-alola",
  "gen": null,
  "moves": [],
  "gen_moves": {
    "9": [ /* same structure as above */ ],
    "8": [ ... ],
    "7": [ ... ]
  }
}
```

The same gen param behaviour applies to `/pokemon/{id}/resolved?gen=N&includes[]=moves`.

### 4.4 Backend — Updated Schemas

Extend `MoveLearnDetail` and `MoveSummary` in `schemas/pokemon_resolved.py`:

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
    moves: list[MoveSummary]           # populated when gen is provided
    gen_moves: dict[str, list[MoveSummary]] | None = None  # populated when gen is omitted
```

### 4.5 Frontend — Model + Provider Updates

- Update `MoveLearnDetail` in `models.dart` to add `via_prevo` (bool) and `prevo` (String?)
- Update `pokemonMovesProvider` to accept and forward an optional gen parameter
- Update `MoveSummary.fromJson` / `MoveLearnDetail.fromJson` for the new schema
- Update `slot_config_screen.dart` to pass the active format's gen to `pokemonMovesProvider`

### 4.6 Frontend — Slot Validator Refactor

- Remove Pass 2 PS gen-bucket supplementation (`learnsetForGen` call) — the backend now handles this
- The backend `moves` response already contains `via_prevo` moves so no separate pre-evo comparison needed on the frontend
- Offline fallback (backend unavailable + empty cache): fall back to local validation using `event_learnsets.json` source codes with method-aware filtering (not gen-bucket). Specifically: skip adding a move via PS if it already appears in `pokemonMoves` from PokéAPI — this alone fixes the Ninetales bug in the offline path
- Ability and item validation (gen-gating) remain local for now; they are simple integer comparisons and not worth a network round-trip

---

## 5. Sub-Issues

| # | Title | Scope |
|---|---|---|
| A | `sync_ps_data.py`: generate `learnset_1–9.json` + add `prevo`/`evos` to pokedex transform | Script only |
| B | Backend: learnset service + PS ID normalization + prevo chain traversal | New service, no endpoint changes |
| C | Backend: update `/pokemon/moves` with `gen` param + full consolidation logic + new schemas | Endpoint + schemas |
| D | Frontend: update move models, `pokemonMovesProvider`, and slot validator | Flutter only |

Sub-issues are created after this investigation PR is merged.

---

## 6. Open Items (Deferred)

- **moves/items/abilities TS source:** Evaluate whether `data/moves.ts`, `data/items.ts`, `data/abilities.ts` give fields the compiled endpoints don't (move flags, item fling power, etc.). Separate investigation or folded into a future task.
- **Ability and item gen-gating on backend:** Simple integer comparison; low priority for backend migration.
- **Side-game allowlist:** Formal definition of which PS version groups are in scope (excludes Stadium, Colosseum, XD, Champions). Needed eventually to prevent out-of-scope version groups from polluting supplements.
- **`learnsets.json` removal from frontend:** Once the offline fallback is updated to use `event_learnsets.json` source codes directly, `learnsets.json` can be dropped from Hive and the Flutter asset bundle.
