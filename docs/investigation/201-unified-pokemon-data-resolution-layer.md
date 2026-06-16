# Investigation: Unified Pokémon Data Resolution Layer

**Issue:** [#201](https://github.com/KwasiAsante/PokeTeamDex/issues/201)  
**Branch:** `investigation/unified-pokemon-data-resolution-layer`  
**Status:** Investigation complete — ready for implementation

---

## 1. Research Findings

### 1.1 Scattered Override Maps (22 maps across 7 files)

The codebase currently maintains over 22 separate override maps spread across 7 files with no central registry:

| File | Maps | Purpose |
|------|------|---------|
| `lib/features/teams/data/form_data.dart` | `kPsFormExceptions`, `kCosmeticSpriteStems` | PS↔PokéAPI name mismatches; cosmetic form sprite stems (62 nested entries) |
| `lib/features/teams/data/form_filter.dart` | `kAbilityGatingRules`, `kItemGatingRules`, `kMutableFormSpeciesIds` | Form availability gated by ability/item; in-battle mutable species |
| `lib/features/pokedex/logic/evolution_chain_builder.dart` | `kBaseFormNameOverrides`, `kCosmeticFormLabels`, `kCosmeticFormHomeUrlOverrides`, `kCosmeticFormHomeShinyUrlOverrides`, `kBaseFormCosmeticHomeUrls`, `kBaseFormSuffixOverrides`, `kRegionalFormLookup` | Display labels, HOME artwork URL overrides, regional suffix routing |
| `lib/features/pokedex/logic/form_filter.dart` | `_kBattleMeaningfulNames`, `kCosmeticVarietyNames`, `kNoCosmeticFormsPokemon`, `kCosmeticGenderDiffPokemon` | Form classification (battle vs. cosmetic) |
| `lib/features/teams/data/mega_forms_data.dart` | `kMegaStoneMap` | Mega stone → (baseSpecies, megaForm) mapping (48 entries) |
| `lib/services/format/format_models.dart` | `kFormatToVersionGroup`, `kGenToVersionGroups` | Format game id ↔ version-group mapping |
| `lib/services/format/sprite_resolver.dart` | `_gameIdToVersionPath`, `_genToDefaultGameId` | Format game id → PokéAPI versions path |
| `lib/features/pokedex/presentation/widget/pokemon_list_tile.dart` | `_kVgToSubpath`, `_kGenToLastVg` | Version-group → sprite subpath for compact list icons |

Every new game, DLC release, or edge-case Pokémon requires hunting across multiple files to add override entries. There is no single place to look.

### 1.2 Sprite URL Resolution Duplicated in 4 Places

| Location | What it does differently |
|----------|--------------------------|
| `lib/services/format/sprite_resolver.dart` | Format-aware; Gen 1–5 versioned paths, Gen 6+ HOME/artwork, Gen 2 crystal fallback chain, female variants |
| `lib/features/pokedex/presentation/widget/pokemon_list_tile.dart` | Compact list icon; maps filter.game → subpath; no cosmetic form hint support |
| `lib/features/teams/presentation/team_detail_screen.dart` | Orchestrates multiple `resolveSprite` calls for base + cosmetic + Mega/Gmax forms; builds `SpriteHint` inline |
| `lib/features/pokedex/presentation/widget/pokemon_grid_card.dart` | Own `_buildImageUrl` method; duplicates cosmetic HOME URL construction and override map lookups independently of `form_descriptor.dart` |

Each implementation has slightly different logic and handles different edge cases. A fix in one place does not propagate to the others.

### 1.3 Cache Architecture

```
HTTP (PokéAPI)
    ↓
Hive Box ('pokeapi_cache')   ← TTL-based, raw JSON
    ↓
PokeApiRepository            ← in-memory parsed object memoization (app lifetime)
    ↓
FutureProvider.autoDispose   ← disposed when widget leaves screen
```

**TTLs:** 24 hours for the full Pokémon list; 7 days for individual Pokémon, species, forms, abilities, evolution chains.

**Critical gap:** The *resolved* result — the final merged picture of a Pokémon after all override lookups, cross-source gap-filling, and sprite URL construction — is never persisted. It is recomputed from scratch every time a provider rebuilds.

**autoDispose behaviour:** Because all data providers are `.autoDispose`, scrolling a Pokédex list tile off-screen disposes its providers. Scrolling back rebuilds them. The in-memory memoization in `PokeApiRepository` prevents repeat HTTP calls, but it still triggers Hive reads and object re-parsing on every scroll cycle. With 50 tiles per page and 4–6 provider subscriptions per tile, this adds up to 200–300 provider rebuilds on a single scroll pass through the list.

### 1.4 Provider Lifecycle on List Screens

`PokemonGridCard` and `PokemonListTile` both unconditionally watch `pokemonDetailProvider` and `pokemonSpeciesProvider` for every rendered tile. Both are legitimately needed on initial render: `pokemonDetailProvider` supplies the type gradient and gates the cosmetic form fetch via `formNames.length`; `pokemonSpeciesProvider` supplies `battleForms` and `cosmeticVarietyForms`, which determine whether the form chip is shown at all and what `baseFormLabel` reads. Neither can be deferred to user interaction.

`cosmeticFormsProvider` is already properly gated — it only fires when `basePokemon.formNames.length > 1`. `pokemonByNameProvider` for selected alternate forms fires only on explicit user form selection. Both are correct.

The real issue is **provider disposal**: all of these are `.autoDispose`, so when a tile scrolls off-screen, its providers are torn down. Scrolling back rebuilds them from scratch. The in-memory memoization in `PokeApiRepository` prevents repeat HTTP calls, but it still triggers Hive reads and object re-parsing on every scroll cycle. With 50 tiles per page and 2 unconditional provider subscriptions per tile, every full list scroll generates ~100 provider rebuild cycles.

### 1.5 Backend Is Purely a Sync/Storage Layer

The FastAPI backend (`backend/app/`) handles only team sync and user data. It performs no Pokémon data aggregation and makes no calls to PokéAPI, Showdown, or Smogon. All data resolution — including cross-source gap-filling — happens entirely on-device in Flutter.

### 1.6 Cross-Source Data Gaps

PokéAPI is missing data that Showdown and Smogon have: event-exclusive moves (e.g. Gen 2 Dratini's ExtremeSpeed from a GameBoy Colour event), Smogon competitive sets and tier placements, and some sprite/artwork URLs that do not follow PokéAPI's standard path patterns. These gaps are currently either silently missing or patched ad-hoc via override maps.

Showdown's data ships as static JSON files in [smogon/pokemon-showdown](https://github.com/smogon/pokemon-showdown) — not a live API — so it can be downloaded once and kept in backend storage. Smogon analysis data is available via [data.pkmn.cc](https://data.pkmn.cc) (refreshed every 24 hours for analyses, monthly for stats).

---

## 2. Answers to Investigation Questions

### Where should the unified data live — backend or client-side?

**Hybrid.** The backend handles cross-source aggregation (PokéAPI + Showdown + Smogon), stores the resolved result in PostgreSQL, and exposes a `/pokemon/{id}/resolved` endpoint. Flutter consumes that endpoint, caches the resolved result in Hive, and falls back to client-side resolution when offline. This eliminates repeated on-device cross-source mapping while preserving offline capability.

### What is the right caching strategy?

**Two-tier with explicit keepAlive:**

- **Backend:** PostgreSQL table `pokemon_resolved` stores the aggregated result per Pokémon with a 7-day TTL. A background task refreshes stale rows lazily (on first user request after expiry). No scheduled full-population job is required — the table warms naturally as users browse.
- **Flutter:** Hive stores the resolved result per Pokémon ID (not per raw API endpoint). Riverpod providers for resolved data use `keepAlive: true` so the in-memory result survives navigation and scroll cycles for the app session.

### Which screens/providers need to be refactored?

All screens that currently watch `pokemonDetailProvider`, `pokemonSpeciesProvider`, `cosmeticFormsProvider`, or `pokemonByNameProvider` directly:

- `pokemon_detail_screen.dart`
- `pokemon_list_tile.dart`
- `pokemon_grid_card.dart`
- `team_detail_screen.dart`
- `slot_config_screen.dart`
- `form_picker_sheet.dart`

These switch to a single `resolvedPokemonProvider(id)` that delivers the merged data in one shot.

### Can existing override maps be migrated into the unified model?

**Yes — via a JSON seed file.** All 22 maps are suitable for a single `assets/data/pokemon_registry.json` file. They are structurally flat (String → String, String → nested map) and stable — they only change when new games or DLC are released. The JSON asset:

- Loads once at startup, parsed into a `PokemonDataRegistry` singleton
- Replaces all scattered Dart `const Map<>` declarations
- Can later be fetched from the backend to update without an app release, once the backend aggregation layer is mature enough to auto-derive most entries

Some maps (`kMutableFormSpeciesIds`, `kAbilityGatingRules`, `kItemGatingRules`) encode game logic rules rather than data patches. These are good candidates to remain in the JSON but may eventually be superseded by Showdown's own form availability data.

---

## 3. Implementation Plan

Six tasks, each independently shippable. Tasks A–C are pure Flutter refactors with no backend dependency. Tasks D–E introduce the backend aggregation layer. Task F is an optional cleanup pass.

---

### Task A — Consolidate override maps into a JSON asset and `PokemonDataRegistry`

**Goal:** Single source of truth for all Pokémon override data.

**Scope:**
- Create `assets/data/pokemon_registry.json` containing all 22 maps currently scattered across `form_data.dart`, `form_filter.dart`, `evolution_chain_builder.dart`, `mega_forms_data.dart`, `format_models.dart`, `sprite_resolver.dart`, and `pokemon_list_tile.dart`
- Create `lib/data/pokemon_data_registry.dart` — a singleton class that parses the JSON at startup and exposes typed getters (`cosmeticSpriteStems`, `battleMeaningfulNames`, `baseFormNameOverrides`, etc.)
- Add `assets/data/pokemon_registry.json` to `pubspec.yaml`
- Update all existing Dart references to use the registry; delete the original `const Map<>` declarations
- Pure refactor — zero behavior change, zero new features

**Effort:** Medium. The migration is mechanical but touches 7 files and requires matching all existing call sites.

**Labels:** `enhancement`, `refactor`

---

### Task B — Unified sprite resolver (`PokemonDataResolver`)

**Goal:** One entry point for all sprite URL resolution, eliminating the 4 divergent implementations.

**Scope:**
- Create `lib/data/pokemon_data_resolver.dart` with a single `resolveFormSprite({required int pokemonId, required String? formName, required String baseSpecies, required GameFormat? format, required bool useFormatSprites, required bool isShiny, required String? gender})` method
- Reads cosmetic stems, HOME URL overrides, versioned path maps, and female sprite paths from `PokemonDataRegistry` (Task A must be complete first)
- Replaces the sprite URL construction logic in:
  - `lib/services/format/sprite_resolver.dart` (keep the file but thin it to call the resolver)
  - `lib/features/pokedex/presentation/widget/pokemon_list_tile.dart` (`_kVgToSubpath` inline logic)
  - `lib/features/pokedex/presentation/widget/pokemon_grid_card.dart` (`_buildImageUrl` method)
  - `lib/features/teams/data/form_descriptor.dart` (`spriteHint` method)
  - `lib/features/teams/presentation/team_detail_screen.dart` (multiple `resolveSprite` call sites)
- All call sites updated to use `PokemonDataResolver`

**Effort:** Medium-high. The 4 implementations have subtle differences that must be preserved in the unified resolver (Gen 2 crystal fallback, female HOME URL pattern, cosmetic form stem logic).

**Labels:** `enhancement`, `refactor`

---

### Task C — `resolvedPokemonProvider` with `keepAlive` caching

**Goal:** Eliminate redundant provider rebuilds on the Pokédex list and reduce per-tile provider subscriptions from 4–6 to 1.

**Scope:**
- Define a `ResolvedPokemon` value object containing: base stats, types, abilities, species data, cosmetic forms, battle forms, and resolved sprite URLs for the current format
- Create `resolvedPokemonProvider(int id)` as a `keepAlive` `FutureProvider.family` that:
  - Fetches `pokemonDetailProvider`, `pokemonSpeciesProvider`, and `cosmeticFormsProvider` internally
  - Merges the results into `ResolvedPokemon`
  - Stays alive for the app session (no autoDispose)
- Update `PokemonListTile`, `PokemonGridCard`, `pokemon_detail_screen.dart`, `slot_config_screen.dart`, and `form_picker_sheet.dart` to watch `resolvedPokemonProvider` instead of 4–6 individual providers
- The `pokemonByNameProvider` for user-selected alternate forms (Mega, Gmax) remains a separate `autoDispose` provider — those are on-demand fetches, not baseline data

**Effort:** Medium. Defining `ResolvedPokemon` and migrating call sites is straightforward; the main care is not breaking the form-selection flow in `team_detail_screen.dart`.

**Labels:** `enhancement`, `performance`

---

### Task D — Backend cross-source aggregation endpoint

**Goal:** Fill PokéAPI data gaps (event moves, Smogon analyses, Showdown competitive data) in one place rather than on every client.

**Scope:**
- New PostgreSQL table `pokemon_resolved` (via Alembic migration): `pokemon_id`, `data JSONB`, `resolved_at TIMESTAMP`, `ttl_days INTEGER`
- Download Showdown's static data JSON files (moves, species, items from `smogon/pokemon-showdown`) at backend startup and keep in memory — not a per-request fetch
- New FastAPI endpoint `GET /pokemon/{id}/resolved`:
  - Cache hit (row exists and not expired): return `data` directly
  - Cache miss: fetch PokéAPI for base data → merge Showdown move/ability supplement → fetch Smogon analyses from `data.pkmn.cc` → store merged result in `pokemon_resolved` → return
- The response schema includes: `pokemon_id`, `name`, `types`, `stats`, `abilities`, `moves` (PokéAPI + Showdown supplement merged), `smogon_analyses` (nullable), `forms`, `sprite_urls`
- No authentication required — read-only public endpoint

**Effort:** High. Showdown and Smogon data schemas require careful mapping to PokéAPI names (the same cross-source mismatch problem the client currently has). The backend now owns that mapping work. `kPsFormExceptions` in the registry (Task A) feeds directly into this mapping layer.

**Labels:** `enhancement`, `backend`

---

### Task E — Flutter hybrid integration

**Goal:** Flutter consumes the backend resolved endpoint; Hive becomes the offline copy.

**Scope:**
- Update `resolvedPokemonProvider` (Task C) to:
  1. Check Hive for a resolved entry for this `pokemonId` — if present and within TTL, return it
  2. On miss: call `GET /pokemon/{id}/resolved` on the backend
  3. Write the response to Hive with a TTL matching the backend's (7 days)
  4. Fall back to client-side resolution (current Task C behaviour) if the backend is unreachable (offline or error)
- New Hive box `pokemon_resolved_cache` separate from the existing `pokeapi_cache` — avoids TTL collisions with raw API responses
- No change to the existing `PokeApiRepository` or `PokeApiCache` — they remain as the offline fallback path

**Effort:** Low-medium. The provider structure from Task C is already in place; this task swaps the data source and adds the Hive write path.

**Labels:** `enhancement`, `sync`

---

### Task F *(optional)* — Frontend lazy loading and provider hygiene audit

**Goal:** Identify and fix places where the frontend loads more data than needed, fires providers too eagerly, or resolves URLs redundantly outside the unified resolver.

**Scope (to be determined during implementation — audit-first task):**
- Audit all screens and list widgets for `autoDispose` providers that should be `keepAlive` given their usage frequency
- Identify tiles or cards that watch providers for data not needed until user interaction (note: `pokemonDetailProvider` and `pokemonSpeciesProvider` are both legitimately needed on initial render for type gradients and form chip visibility — any deferral opportunity is likely elsewhere)
- Find any remaining inline sprite URL construction not yet covered by Task B
- Implement fixes for findings — each fix should be a small, independently reviewable change within the same PR

**Effort:** Unknown until audit. Expected low-to-medium per finding; audit itself is a few hours.

**Labels:** `enhancement`, `performance`

---

## 4. Sprite Hosting (Deferred)

The issue mentions self-hosting sprite assets on the backend (cloning `smogon/sprites` and `PokeAPI/sprites` into the FastAPI container). This is **not** part of this implementation plan.

The main blocker resolved by self-hosting is the Pokémon Showdown CORS restriction on Flutter Web for Gen 2 shiny sprites — `sprite_resolver.dart` already has a `kIsWeb` branch to work around this. Self-hosting would make that branch unnecessary and reduce dependency on GitHub raw URL availability.

**Follow-up:** Once all sub-issues of #201 are closed, open a new `investigation` issue for sprite hosting. That investigation should cover: storage cost of cloning `smogon/sprites` + `PokeAPI/sprites` into the backend container, serving strategy (static files via FastAPI vs. a dedicated CDN), cache-busting when upstream repos update, and whether the unified resolver from Task B makes the migration straightforward.

---

## 5. Risk and Open Questions

| Risk | Severity | Notes |
|------|----------|-------|
| Showdown ↔ PokéAPI name mapping in Task D | High | `kPsFormExceptions` covers known cases but Showdown's naming is not fully documented. Expect edge cases to surface during implementation. |
| Backend cold-start latency for un-cached Pokémon (Task D) | Medium | First request for a Pokémon triggers 3–5 external calls. Add a loading state on the Flutter side; do not block UI. |
| `resolvedPokemonProvider` memory footprint (Task C) | Low | keepAlive providers accumulate for the app session. With ~1025 species and one `ResolvedPokemon` per species in memory at once (worst case full-scroll), total memory is acceptable — these are small value objects, not raw sprite data. |
| JSON asset parse time at startup (Task A) | Low | The registry JSON will be ~100–200KB. One-time parse at startup adds negligible time. |
