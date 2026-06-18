# Task E — Flutter Hybrid Integration Design

**Issue:** [#238](https://github.com/KwasiAsante/PokeTeamDex/issues/238)  
**Date:** 2026-06-18  
**Part of:** Investigation #201 — Unified Pokémon Data Resolution Layer

---

## 1. Goal

`resolvedPokemonProvider` currently assembles `ResolvedPokemon` from three separate PokéAPI calls
(`/pokemon/{id}`, `/pokemon-species/{id}`, `/pokemon-form/{name}`×N). Task E makes the backend
`GET /pokemon/{id}/resolved` endpoint the primary source, with a Hive offline copy and the
existing PokéAPI path as fallback.

---

## 2. Architecture

```
Online path
───────────
  resolvedPokemonProvider(id)
    │
    ├─ 1. Check pokemon_resolved_cache (Hive) ─→ hit: return ResolvedPokemon immediately
    │
    └─ 2. GET /pokemon/{id}/resolved (backend)
           │   PostgreSQL 7-day cache on backend
           └─→ map response → ResolvedPokemon
               write to pokemon_resolved_cache (Hive, 7-day TTL)

Offline / error path
─────────────────────
  resolvedPokemonProvider(id)
    │
    └─ existing Task C behavior:
         pokemonDetailProvider → PokeApiRepository → pokeapi_cache (Hive)
         pokemonSpeciesProvider → PokeApiRepository → pokeapi_cache (Hive)
         cosmeticFormsProvider  → PokeApiRepository → pokeapi_cache (Hive)

Lazy-loaded detail data (new, separate providers)
──────────────────────────────────────────────────
  pokemonMovesProvider(id)        → GET /pokemon/{id}/moves   (or PokeApiRepository fallback)
  pokemonFlavorTextProvider(id)   → GET /pokemon/{id}/flavor-text (or PokeApiRepository fallback)
```

---

## 3. Backend Changes

### 3.1 New Pydantic Models (`backend/app/schemas/pokemon_resolved.py`)

```python
class AbilityInfo(BaseModel):
    name: str
    is_hidden: bool
    slot: int

class MoveLearnDetail(BaseModel):
    version_group: str   # "sword-shield", "red-blue"
    method: str          # "level-up", "machine", "egg", "tutor"
    level: int           # 0 for non-level-up methods

class MoveSummary(BaseModel):
    name: str
    learn_details: list[MoveLearnDetail]

class FlavorTextEntry(BaseModel):
    text: str
    language: str
    version: str

class MovesResponse(BaseModel):
    pokemon_id: int
    name: str
    moves: list[MoveSummary]

class FlavorTextResponse(BaseModel):
    pokemon_id: int
    name: str
    flavor_text_entries: list[FlavorTextEntry]
```

### 3.2 `PokemonResolvedResponse` — changes and additions

**Changed field:**
- `abilities: dict[str, str]` → `abilities: list[AbilityInfo]`

**Added fields — pokemon detail** (all sourced from `pokemon_data` in `_fetch_pokeapi`):
- `height: int`
- `weight: int`
- `base_experience: int | None`
- `species_name: str | None` — bare species name (e.g. `"wormadam"` when name is `"wormadam-plant"`)
- `moves: list[MoveSummary]` — **slim by default: `[]`**; full via `?includes[]=moves`
- `moves_url: str | None` — absolute URL to `GET /pokemon/{id}/moves`

**Added fields — species detail** (sourced from `species_data` in `_fetch_pokeapi`):
- `genus: str | None` — English genus (e.g. `"Flame Pokémon"`)
- `generation_name: str` — e.g. `"generation-i"` (string form used by Flutter)
- `gender_rate: int | None` — `-1` genderless, `0` male-only, `8` female-only
- `capture_rate: int | None`
- `base_happiness: int | None`
- `hatch_counter: int | None`
- `growth_rate: str | None`
- `egg_groups: list[str]`
- `flavor_text_entries: list[FlavorTextEntry]` — **slim by default: `[]`**; full via `?includes[]=flavor`
- `flavor_text_url: str | None` — absolute URL to `GET /pokemon/{id}/flavor-text`
- `is_baby: bool`
- `is_legendary: bool`
- `is_mythical: bool`
- `evolution_chain_id: int | None`

**Note:** `form_names: list[str]` is NOT added — `forms: list[FormData]` already carries the form
names via `FormData.name`. Flutter derives `formNames` as `forms.map((f) => f.name).toList()`.

### 3.3 New Endpoints (`backend/app/routers/pokemon.py`)

Both follow the same slim/full pattern as existing endpoints. Results are served from the
PostgreSQL `pokemon_resolved` cache when available.

```
GET /pokemon/{name_or_id}/moves
    Response: MovesResponse
    Always returns full moves list (no includes param needed — this IS the full endpoint).

GET /pokemon/{name_or_id}/flavor-text
    Response: FlavorTextResponse
    Returns all languages by default.
    Optional: ?lang=en to filter to English only.
```

These endpoints must be declared **before** `/{name_or_id}/resolved` in the router file
(same rule as the existing `varieties`, `forms`, `smogon` routes — literal segments before
parameterised ones to avoid FastAPI route swallowing).

### 3.4 `_fetch_pokeapi` changes (`backend/app/services/pokemon_resolver.py`)

Currently returns a slim `species_info` dict. Change to return the full `species_data` dict:

```python
# Before
return pokemon_data, {
    "english_name": english_name,
    "gen": gen_num,
    "species_name": species_name,
    "varieties": species_data.get("varieties", []),
}

# After
return pokemon_data, species_data, {
    "english_name": english_name,
    "gen": gen_num,
    "species_name": species_name,
}
```

All callers of `_fetch_pokeapi` updated to unpack three values.

### 3.5 `resolve()` changes

Extract and populate all new fields during the existing resolution flow. No new PokéAPI
fetches required — all data is already in `pokemon_data` and `species_data`:

```python
# abilities (changed)
abilities = [
    AbilityInfo(
        name=a["ability"]["name"],
        is_hidden=a["is_hidden"],
        slot=a["slot"],
    )
    for a in pokemon_data.get("abilities", [])
]

# moves (slim by default; always built for cache storage)
moves = [
    MoveSummary(
        name=m["move"]["name"],
        learn_details=[
            MoveLearnDetail(
                version_group=d["version_group"]["name"],
                method=d["move_learn_method"]["name"],
                level=d["level_learned_at"],
            )
            for d in m.get("version_group_details", [])
        ],
    )
    for m in pokemon_data.get("moves", [])
]

# flavor text (slim by default; always built for cache storage)
flavor_text_entries = [
    FlavorTextEntry(
        text=e["flavor_text"].replace("\n", " ").replace("\f", " "),
        language=e["language"]["name"],
        version=e["version"]["name"],
    )
    for e in species_data.get("flavor_text_entries", [])
]
```

Full data is always stored in the PostgreSQL JSONB cache. `_trim_response` sets
`moves=[]` and `flavor_text_entries=[]` when not in `includes`.

### 3.6 `_trim_response` changes

Add trim logic for the two new slim fields:

```python
if "moves" not in includes:
    response = response.model_copy(update={"moves": []})
if "flavor" not in includes:
    response = response.model_copy(update={"flavor_text_entries": []})
```

### 3.7 Database

No Alembic migration needed. The `pokemon_resolved.data` column is JSONB — new fields
are added to the stored JSON object automatically when rows are next refreshed.
Existing cached rows (without the new fields) will return default/empty values until
they expire and are re-resolved (7-day TTL).

---

## 4. Flutter Changes

### 4.1 New Hive box

Open `pokemon_resolved_cache` in `main.dart` alongside `pokeapi_cache`:

```dart
await Hive.openBox('pokemon_resolved_cache');
```

Not opened in the WorkManager background isolate — `resolvedPokemonProvider` is not
called from the sync background task.

### 4.2 New service: `lib/services/pokemon_resolved/`

**`pokemon_resolved_cache.dart`** — wraps the Hive box, same TTL pattern as `PokeApiCache`:

```dart
class PokemonResolvedCache {
  Box get _hive => Hive.box('pokemon_resolved_cache');

  Map<String, dynamic>? getIfValid(String key) { ... }
  void putWithTTL(String key, Map<String, dynamic> value, Duration ttl) { ... }
}
```

**`models.dart`** — Dart models for the new backend response fields:

```dart
class AbilityInfo {
  final String name;
  final bool isHidden;
  final int slot;
}

class MoveLearnDetail {
  final String versionGroup;
  final String method;   // "level-up", "machine", "egg", "tutor"
  final int level;
}

class MoveSummary {
  final String name;
  final List<MoveLearnDetail> learnDetails;
}

class FlavorTextEntry {
  final String text;
  final String language;
  final String version;
}
```

**`pokemon_backend_repository.dart`** — calls the backend:

```dart
class PokemonBackendRepository {
  PokemonBackendRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<PokemonResolvedBackendResponse> fetchResolved(int id) async { ... }
  Future<List<MoveSummary>> fetchMoves(int id) async { ... }
  Future<List<FlavorTextEntry>> fetchFlavorText(int id, {String? lang}) async { ... }
}
```

`PokemonResolvedBackendResponse` is a Dart model matching the full backend response.

**`pokemon_resolved_providers.dart`** — Riverpod providers:

```dart
final pokemonResolvedCacheProvider = Provider<PokemonResolvedCache>(...);
final pokemonBackendRepositoryProvider = Provider<PokemonBackendRepository>(...);

// Lazy-loaded moves (used by detail Moves tab and slot config move picker)
final pokemonMovesProvider =
    FutureProvider.family<List<MoveSummary>, int>((ref, id) async { ... });

// Lazy-loaded flavor text (used by detail Overview tab)
final pokemonFlavorTextProvider =
    FutureProvider.family<List<FlavorTextEntry>, int>((ref, id) async { ... });
```

Both `pokemonMovesProvider` and `pokemonFlavorTextProvider` check their own Hive
entries before calling the backend, and fall back to `PokeApiRepository` when offline.

### 4.3 `ResolvedPokemon` model changes

Add two new fields for data that has no existing Flutter equivalent:

```dart
class ResolvedPokemon {
  // existing — unchanged
  final PokemonEntry detail;
  final PokemonSpeciesEntry species;
  final List<PokemonFormEntry> cosmeticForms;

  // new — backend-only data, no PokéAPI equivalent
  final List<MoveSummary> supplementMoves; // event/egg/tutor moves missing from PokéAPI
  final List<Map<String, dynamic>>? smogonAnalyses; // raw JSON; typed model deferred to Smogon UI task
}
```

`detail` and `species` remain the primary typed models. The online path constructs
them from the backend response fields using the mapping layer described in §4.4.
The offline path constructs them from PokéAPI via `PokeApiRepository` as before.

`detail.abilities`, `detail.moves`, `detail.types`, `detail.stats` field types are
unchanged (raw maps) — consumer refactoring is deferred to Task F.

`detail.moves` and `species.flavorTextEntries` are no longer read by the Moves tab
or Overview tab — those consumers switch to `pokemonMovesProvider` and
`pokemonFlavorTextProvider`. The fields remain on `PokemonEntry` / `PokemonSpeciesEntry`
for the offline path.

**Mapping layer** — when constructing `PokemonEntry` from the backend response
(online path), `AbilityInfo` objects are converted back to the raw map format that
existing consumers expect:

```dart
// AbilityInfo → raw map for PokemonEntry.abilities backward compat
final abilitiesMaps = response.abilities.map((a) => {
  'ability': {'name': a.name, 'url': ''},
  'is_hidden': a.isHidden,
  'slot': a.slot,
}).toList();
```

This keeps all existing ability consumers working without changes.

### 4.4 `resolvedPokemonProvider` changes

```
1. Check pokemon_resolved_cache (Hive) for key "resolved_{id}"
   → hit within TTL: deserialise → build ResolvedPokemon → return

2. Call backend GET /pokemon/{id}/resolved (no includes — slim response)
   → success: map to ResolvedPokemon
              write raw response JSON to pokemon_resolved_cache (7-day TTL)
              return
   → failure (offline / error): fall through to step 3

3. Offline fallback (current Task C behavior):
   pokemonDetailProvider(id)    → PokemonEntry     (from pokeapi_cache)
   pokemonSpeciesProvider(id)   → PokemonSpeciesEntry (from pokeapi_cache)
   cosmeticFormsProvider(name)  → List<PokemonFormEntry> (from pokeapi_cache)
   return ResolvedPokemon with empty supplementMoves / null smogonAnalyses
```

Backend call runs in parallel with the Hive check to minimise latency on first load.

### 4.5 Consumer updates

**`pokemon_detail_screen.dart`**
- Moves tab: switch from `resolved.detail.moves` → `ref.watch(pokemonMovesProvider(id))`
- Overview tab (flavor text): switch from `resolved.species.flavorTextEntries` → `ref.watch(pokemonFlavorTextProvider(id))`

**`slot_config_screen.dart`**
- Move picker: switch from `resolved.detail.moves` → `ref.watch(pokemonMovesProvider(id))`

**`pokemon_list_tile.dart`, `pokemon_grid_card.dart`**
- No changes — these never read moves or flavor text from `resolvedPokemonProvider`

---

## 5. Data Flow Summary

```
First load (cold cache, online)
  resolvedPokemonProvider(6)                    // Charizard
    → Hive miss
    → GET /pokemon/6/resolved                   // backend: Postgres hit or PokéAPI+Showdown+Smogon
    → ResolvedPokemon (no moves, no flavor)     // slim response
    → write to pokemon_resolved_cache

  pokemonMovesProvider(6)                        // only when Moves tab or slot config opens
    → GET /pokemon/6/moves                       // backend: served from Postgres JSONB
    → List<MoveSummary>

  pokemonFlavorTextProvider(6)                   // only when Overview tab opens
    → GET /pokemon/6/flavor-text
    → List<FlavorTextEntry>

Subsequent loads (warm cache)
  resolvedPokemonProvider(6)
    → Hive hit → return immediately (no network)

  pokemonMovesProvider(6)
    → provider keepAlive → no re-fetch within session

Offline
  resolvedPokemonProvider(6)
    → Hive hit (if previously fetched): return cached result
    → Hive miss: backend call fails → Task C PokéAPI fallback (pokeapi_cache)
```

---

## 6. Testing

- Unit: `PokemonResolvedBackendResponse.fromJson` round-trip for all new fields
- Unit: `resolvedPokemonProvider` with backend success → correct `ResolvedPokemon`
- Unit: `resolvedPokemonProvider` with backend failure → falls back to PokéAPI, returns valid result without supplement fields
- Unit: `pokemonMovesProvider` with backend success and with backend failure (PokéAPI fallback)
- Unit: new `AbilityInfo`, `MoveSummary`, `FlavorTextEntry` `fromJson` / `toJson`
- Widget: `PokemonDetailScreen` Moves tab renders from `pokemonMovesProvider` (not `resolved.detail.moves`)
- Backend: `GET /pokemon/{id}/resolved` response includes all new fields
- Backend: slim response has `moves: []` + `moves_url`; `?includes[]=moves` returns full list
- Backend: `GET /pokemon/{id}/moves` and `GET /pokemon/{id}/flavor-text` return expected data

---

## 7. Out of Scope

- Refactoring `PokemonEntry.types`, `PokemonEntry.stats`, `PokemonEntry.abilities`,
  `PokemonEntry.moves` to typed models — consumers use raw maps today; clean migration
  is Task F territory
- Smogon UI rendering — `smogonAnalyses` is stored on `ResolvedPokemon` but not displayed yet
- Sprite self-hosting (#244)
- Format-sync and custom-formats (deferred post-release)
