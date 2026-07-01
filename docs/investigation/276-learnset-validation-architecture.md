# Investigation #276 — Move/Item/Ability/Learnset Validation Architecture

## Context

A bug where Alolan Ninetales incorrectly appears able to learn Freeze-Dry in Gen 9 (Scarlet/Violet) opened a broader question about how we source and validate learnsets, moves, items, and abilities across the backend and frontend. This document traces the full data flow end-to-end, identifies where consolidation currently happens, and proposes an architecture where the backend owns the heavy work.

---

## 1. How a Pokémon's Move List Is Currently Built

### 1.1 Backend — `pokemon_resolver.py`

| Step | Source | Result |
|---|---|---|
| Primary | PokéAPI `/pokemon/{id}` | Full `moves` list with `version_group_details` (game, method, level) per move |
| Supplement | `event_learnsets.json` via `_get_supplement_moves()` | Moves PokéAPI has **no record of at all** (not filtered out — genuinely absent) |

The backend preserves all `version_group_details` from PokéAPI and serves the moves as `list[MoveSummary]` via `GET /pokemon/moves/{id}`. It does **not** filter by version group — that is left entirely to the frontend.

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

**The Freeze-Dry / Ninetales bug lives here.** PokéAPI knows about Freeze-Dry on Ninetales-Alola — but only for the Champions version group (`scarlet-violet-zero`), not `scarlet-violet`. Pass 1 therefore correctly excludes it. Pass 2 then looks up `ninetalesalola` in `learnsets.json` gen 9, finds `freezedry`, and adds it back — incorrectly overriding Pass 1's correct exclusion.

---

## 2. The Three PS Data Files and How They Differ

### 2.1 `learnsets.json` (gen-bucketed, lossy)

- **Fetch source:** `play.pokemonshowdown.com/data/learnsets.json` (compiled PS endpoint)
- **Transform (`transform_learnsets`):** Strips the method letter and level from every source code; keeps only the leading generation digit.
  ```
  Input:  { "tackle": ["9L1", "8L1", "7L1"] }
  Output: { "9": ["tackle"], "8": ["tackle"], "7": ["tackle"] }
  ```
- **Used by:** Frontend only — `FormatService._learnsets` → `learnsetForGen()` → Pass 2 supplementation
- **Cannot distinguish:** game within a generation, how a move is learned, or whether a move is carry-over vs directly learnable

### 2.2 `event_learnsets.json` (full source codes + eventData)

- **Fetch source:** `data/learnsets.ts` (main) + `data/mods/gen{1–9}/learnsets.ts` (all mods), merged
- **Transform (`transform_detailed_learnsets`):** Keeps the **full** source code string (`9L48`, `7E`, `8T`, `9M`, `2S1`) and `eventData` records
  ```
  Output: { "ninetalesalola": { "learnset": { "freezedry": ["9L1"] }, "eventData": [...] } }
  ```
- **Used by:** Backend — `_get_supplement_moves()` (checks if move is absent from PokéAPI entirely); Frontend — `eventMovesForGen()` (filters to `S`-coded sources + eventData only)
- **Critical:** Despite the name, this file contains **all** moves for **all** Pokémon — not just events. Source codes like `9L48` (level-up) and `8T` (tutor) appear alongside `2S1` (event).

### 2.3 `learnsets-g6-allowlist.json`

- **Fetch source:** `learnsets-g6.js` (compiled PS Gen 6 sim data)
- **Used by:** Frontend Gen 6 supplementation fallback only

### Key finding: `learnsets.json` is a lossy subset of `event_learnsets.json`

`event_learnsets.json` is built from the raw TypeScript (main file + all mods) and contains every move that `learnsets.json` has — plus full method codes and eventData. `learnsets.json`'s gen bucket for a Pokémon can be reconstructed from `event_learnsets.json` by taking the leading digit of each source code. `learnsets.json` adds no information that `event_learnsets.json` does not already carry.

This means we are currently fetching the compiled PS endpoint for `learnsets.json` only to produce a deliberately degraded version of data we already have in better form.

---

## 3. What "Using the TypeScript Source" Means in Practice

We **already** fetch from the `smogon/pokemon-showdown` GitHub TypeScript source for several files:

| File generated | TS source used |
|---|---|
| `event_learnsets.json` | `data/learnsets.ts` + all `data/mods/gen{N}/learnsets.ts` |
| `pokedex.json` | `data/pokedex.ts` |
| `pokedex-gen-overrides.json` | all `data/mods/gen{N}/pokedex.ts` |
| `formats-data.json` | `data/formats-data.ts` |

We still use **compiled PS endpoints** for:

| File generated | Current source | TS equivalent |
|---|---|---|
| `learnsets.json` | `play.pokemonshowdown.com/data/learnsets.json` | Already in `event_learnsets.json` (redundant) |
| `moves.json` | `play.pokemonshowdown.com/data/moves.json` | `data/moves.ts` |
| `items.json` | `play.pokemonshowdown.com/data/items.js` | `data/items.ts` |
| `abilities.json` | `play.pokemonshowdown.com/data/abilities.js` | `data/abilities.ts` |

The compiled endpoints for moves/items/abilities are already partially equivalent to their TS counterparts for the fields we extract (`name`, `gen`, `type`, `category`, etc.). Whether switching these to raw TS gives us meaningful new fields is worth confirming, but the learnset case is clear: we should drop the compiled `learnsets.json` fetch entirely since `event_learnsets.json` is a strict superset.

---

## 4. Where Consolidation Currently Happens

| Consolidation step | Where | At what time |
|---|---|---|
| PokéAPI + `event_learnsets.json` merge (supplement) | Backend (`_get_supplement_moves`) | On first resolve (cached 7 days) |
| PokéAPI version-group filtering (Pass 1) | Frontend (`_buildLearnset`) | At runtime, every render/rebuild |
| PS gen-bucket supplementation (Pass 2) | Frontend (`learnsetForGen`) | At runtime, every render/rebuild |
| PS event-source supplementation | Frontend (`eventMovesForGen`) | At runtime, every render/rebuild |
| Ability gen-gating | Frontend (`abilitiesForGen`) | At runtime, every render/rebuild |
| Item gen-gating | Frontend (`itemsForGen`) | At runtime, every render/rebuild |

All of the validation passes run on the frontend against multi-megabyte in-memory maps parsed from Hive. The backend's role for learnsets is currently limited to proxying PokéAPI data and supplementing with moves PokéAPI missed entirely — it does no version-group filtering or PS cross-referencing.

---

## 5. The Bug as a Case Study

**Alolan Ninetales + Freeze-Dry + Gen 9 (Scarlet/Violet)**

1. PokéAPI knows about Freeze-Dry for `ninetales-alola` — it is listed in `version_group_details`, but only under the Champions version group (`scarlet-violet-zero`), not under `scarlet-violet`.
2. `_buildLearnset` (Pass 1) correctly excludes it: no SV version group entry exists for this move on this Pokémon.
3. `learnsetForGen("ninetalesalola", 9)` (Pass 2) finds `freezedry` in the gen 9 bucket of `learnsets.json` and adds it back.
4. The source code for that entry in `event_learnsets.json` is `9L1` — a pre-evo carry-over marker (Ninetales inherits it from a Vulpix that learned it at level 48 in SV or Legends Z-A). But `learnsets.json` has already stripped this context; Pass 2 sees only "gen 9, Freeze-Dry" and treats it as valid for any Gen 9 format.
5. Result: the slot validator incorrectly shows Freeze-Dry as learnable in SV when it is only directly obtainable via Champions or (indirectly) via pre-evo carry-over.

**Why the backend supplement doesn't have this problem:** `_get_supplement_moves()` checks `if move_id in known_ps_ids: continue` — since PokéAPI already lists Freeze-Dry for Ninetales (even if only for Champions), the backend correctly skips it. The problem is entirely in the frontend's Pass 2.

**Short-term fix (pre-architecture change):** Before adding a move in Pass 2, check whether it appears anywhere in `pokemonMoves` (the PokéAPI-sourced list). If PokéAPI lists it at all — even for a different version group — Pass 2 should skip it. PokéAPI's presence means it knows about the move and already made a game-specific decision to exclude it from SV; PS should not override that decision.

---

## 6. Proposed Architecture

### 6.1 Backend: Learnset Consolidation Endpoint

A new `GET /pokemon/{id}/learnset?version_group=scarlet-violet` endpoint that:
1. Fetches the Pokémon's full PokéAPI moves (version_group_details) — already cached in the DB from the resolved endpoint
2. Filters to the requested version group (and optionally all earlier gens for carry-over)
3. Supplements with `event_learnsets.json` source codes — but only for moves PokéAPI genuinely does not list at all
4. Optionally walks the evolution chain to include pre-evo moves (requires evo chain lookup, already have `evolution_chain_id`)
5. Returns a structured response: `{ "moves": [{"name", "methods", "gen"}], "via_pre_evo": [...] }`
6. Result cached in DB keyed by `(pokemon_id, version_group)`

This moves all the expensive runtime parsing off the device and into a single cached backend call.

### 6.2 Backend: Ability and Item Validation

Currently the frontend filters `abilitiesForGen(gen)` and `itemsForGen(gen)` at runtime against in-memory maps. These are simpler than learnsets (just a gen integer comparison) but still happen on device against large maps. A `GET /game/{version_group}/abilities` and `GET /game/{version_group}/items` endpoint (or equivalent query param on existing endpoints) would let the backend serve pre-filtered lists the frontend caches and reuses.

### 6.3 `sync_ps_data.py` Cleanup

- **Drop the compiled `learnsets.json` fetch.** Derive the gen-bucketed data from `event_learnsets.json` directly in the script. This removes one HTTP request, eliminates a redundant file, and ensures the gen-bucket data and the detailed source-code data are always in sync.
- **Confirm or switch moves/items/abilities to TS source.** Check `data/moves.ts`, `data/items.ts`, `data/abilities.ts` against the compiled endpoints to see if there are fields (e.g., move flags, contest data, item fling power) that would be useful for future features. If yes, switch; if the compiled endpoints are equivalent for our current field set, leave them.

### 6.4 Frontend: Offline Fallback

When the backend is unavailable and the cache is empty:
- Keep `event_learnsets.json` locally (already in Hive); it is the richest source we have
- Replace the gen-bucket Pass 2 with a source-code-aware pass: filter by method letter when needed (e.g., skip `L1` carry-over entries for evolved forms when validating directly-learnable moves)
- The short-term fix in §5 (skip PS supplement if move already in `pokemonMoves`) applies immediately and independently of the backend work

---

## 7. Open Questions for Step-by-Step Investigation

1. **moves/items/abilities TS source:** Does switching to `data/moves.ts`, `data/items.ts`, `data/abilities.ts` give us any fields we currently lack from the compiled endpoints? Specifically — do we need move flags, Z-move base moves, or item fling/natural gift data for any planned feature?
2. **Pre-evo chain scope:** The learnset endpoint will need to traverse the evo chain to include pre-evo moves. Should this always include the full chain (e.g., Bulbasaur moves for Venusaur), or only the immediate pre-evo? What does PS's own legality checker do?
3. **version_group vs gen parameter:** Should the learnset endpoint take a specific version group (`scarlet-violet`) or a gen number (9) with an optional game filter? Gen number is simpler but preserves the same game-ambiguity problem.
4. **Caching strategy:** The learnset endpoint result depends on both pokemon_id and version_group. Cache in the existing `pokemon_resolved` table (new JSONB column) or a separate table? TTL should match the resolved data (7 days).
5. **Side games:** How do we formally define which PS version groups are in scope? Stadium, Colosseum, XD, Champions — these all have PS entries. We need an explicit allowlist tied to the `formats.json` game format definitions.
