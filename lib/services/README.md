# lib/services/

Cross-feature services. These are pure logic / IO layers — no Flutter widgets, no direct UI dependencies.

---

## `api/`

Thin wrappers around Dio for backend communication.

| File | Class | Purpose |
| ---- | ----- | ------- |
| `api_client.dart` | `ApiClient` | Dio instance; injects `Authorization: Bearer <token>` header on every request; base URL from `AppConfigs` |
| `auth_api.dart` | `AuthApiClient` | `login(email, password)`, `register(email, password)` — returns JWT token |
| `team_sync_api.dart` | `TeamSyncApi` | `push(ops)` → `SyncPushResponse`, `pull(since)` → `SyncPullResponse` |

---

## `connectivity/`

| File | Provider | Output |
| ---- | -------- | ------ |
| `connectivity_provider.dart` | `isOnlineProvider` | `Stream<bool>` via `connectivity_plus`; emits `false` on no connection |

Used by `SyncService` to gate sync attempts and by `TeamsScreen` to show the offline banner.

---

## `format/`

The format engine — the most complex service. Validates team slots against Pokémon Showdown competitive rules.

| File | Purpose |
| ---- | ------- |
| `format_service.dart` | Loads PS JSON data, exposes learnset/item/ability/format queries |
| `format_models.dart` | `GameFormat`, `GenerationMechanics`, `PsMoveEntry`, `PsItemEntry`, `PsAbilityEntry` |
| `format_providers.dart` | Riverpod: `allFormatsProvider`, `generalFormatsProvider`, `gameFormatsProvider`, `learnsetProvider`, `itemsForGenProvider`, `abilitiesForGenProvider`, `slotValidationProvider` |
| `slot_validator.dart` | `validateSlot()` → `SlotValidation` (per-move/item/ability legality flags) |
| `sprite_resolver.dart` | Thin wrapper kept for call-site compatibility; sprite/form resolution itself lives in `PokemonDataResolver` (`lib/data/pokemon_data_resolver.dart`, outside `lib/services/` — see [`lib/README.md`](../README.md#data)) |

### FormatService data loading flow

```text
initialize()
├── Try Hive cache for each JSON file
│   └── Cache miss → load from assets/data/ps/
├── Parse into in-memory maps (_learnsets, _moves, _items, _abilities, _formats)
└── Background: GET /ps-data/version
    ├── SHA unchanged → done
    └── SHA changed → download from /ps-data/file/:name → save to Hive → re-parse
```

### Key methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `learnsetForGen(pokemon, gen)` | `List<String>` | All moves legal in gens 1–gen |
| `itemsForGen(gen)` | `List<PsItemEntry>` | Items available in that generation |
| `abilitiesForGen(gen)` | `List<PsAbilityEntry>` | Abilities available in that generation |
| `formatById(id)` | `GameFormat?` | Look up a format by its PS ID |
| `mechanicsForGen(gen)` | `GenerationMechanics` | Which mechanics exist (abilities, held items, Z-crystals, etc.) |
| `isInG6Allowlist(pokemon, move)` | `bool` | Gen 6 legality cross-reference |

---

## `pokeapi/`

PokéAPI integration with Hive TTL cache.

| File | Purpose |
| ---- | ------- |
| `poke_api_client.dart` | Dio configured for `https://pokeapi.co/api/v2` |
| `poke_api_repository.dart` | `fetchPokemon(id)`, `fetchPokemonSpecies(id)`, `fetchPokemonByName(name)`, `fetchPokemonEncounters(id)`, `fetchMove(name)`, `fetchItem(name)`, `fetchItemsByCategory(category)` |
| `poke_api_cache.dart` | Hive box wrapper; TTL = 24h for list data, 7d for detail data |
| `poke_api_providers.dart` | `pokeApiRepositoryProvider` (injectable in tests via override) |
| `models/` | `PokemonEntry`, `PokemonSpeciesEntry`, `PokemonEncounterEntry` — JSON deserialization |

`PokeApiRepository` keeps an in-memory map per entity type (`_pokemonById`, `_speciesById`, `_abilityByName`, `_evolutionChainById`, `_formByName`, `_moveByName`, `_itemByName`) layered on top of the Hive cache, so repeat lookups of the same Pokémon/move/item/ability skip re-parsing the cached JSON. `fetchItemsByCategory` exists separately from the pocket-based fetch because PokéAPI's `"held-items"` filter is an item *category* nested inside the `misc` pocket, not a pocket itself — calling the pocket endpoint with `"held-items"` 404s.

---

## `pokemon_resolved/`

Backend-resolved Pokémon data infrastructure — the Flutter-side counterpart to the backend's `/pokemon/{id}/resolved` aggregation endpoint (see [`backend/README.md`](../../backend/README.md#key-endpoints)). Provides the cache, repository, and models that other layers build on; the merging provider that consumers actually `watch()` lives in `lib/features/pokedex/` (see below), not here.

| File | Purpose |
| ---- | ------- |
| `models.dart` | `AbilityInfo`, `MoveLearnDetail` (+ `viaPrev`/`prevo` fields), `MoveSummary`, `SupplementMove`, `SpriteUrlsFull`, `VarietyBackendData`, `FormBackendData`, `PokemonResolvedBackendResponse` — typed models for the backend response, plus `toPokemonEntry()`/`toPokemonSpeciesEntry()`/`toCosmeticForms()` converters |
| `pokemon_resolved_cache.dart` | Hive box wrapper for backend-resolved responses (7-day TTL, versioned cache key) |
| `pokemon_backend_repository.dart` | `PokemonBackendRepository` — HTTP calls to `GET /pokemon/{id}/resolved` and the `varieties`/`forms`/`smogon`/`moves`/`flavor-text` sub-endpoints; `fetchMoves(id, {gen})` accepts an optional gen param and parses the backend's gen-keyed dict response |
| `pokemon_resolved_providers.dart` | `pokemonResolvedCacheProvider`, `pokemonBackendRepositoryProvider`, and lazy-loaded sub-resource providers (`pokemonMovesProvider({id, gen?})`, `pokemonVarietiesProvider`, `pokemonFormsProvider`, `pokemonFlavorTextProvider`, `validLearnsetProvider({id, gen})`) — each checks the Hive cache, then the backend, then falls back to PokéAPI |

### Where `resolvedPokemonProvider` lives

The provider most screens actually consume, `resolvedPokemonProvider` (`FutureProvider.family`, `keepAlive`), and its return type `ResolvedPokemon`, live in the `pokedex` feature module rather than here — see [`features/README.md` → pokedex](../features/README.md#pokedex):

- `lib/features/pokedex/models/resolved_pokemon.dart` — `ResolvedPokemon`: merges `PokemonEntry` + `PokemonSpeciesEntry` + cosmetic forms + `SpriteUrlsFull` (+ optional Smogon analyses) into one object, kept alive for the app session
- `lib/features/pokedex/providers/resolved_pokemon_provider.dart` — builds a `ResolvedPokemon`:
  ```text
  resolvedPokemonProvider(id, gen)
  ├── Hive cache hit (pokemon_resolved_cache) → return
  ├── Backend reachable → GET /pokemon/{id}/resolved → cache in Hive → return
  └── Backend unreachable → assemble from PokeApiRepository (fetchPokemon + fetchPokemonSpecies + cosmeticFormsProvider) → return
  ```

`PokemonEntry.types`/`stats`/`abilities`/`moves` are typed (`List<String>`, `Map<String,int>`, `List<AbilityInfo>`, `List<MoveSummary>`) regardless of which path populates them, so consumers (detail screen, slot config, team screens) don't need to know which source served the data.

---

## `catalog/`

Dart models for the standalone `/moves`, `/items`, `/abilities` catalog endpoints.

| File | Purpose |
| ---- | ------- |
| `catalog_models.dart` | `BackendMoveEntry`, `BackendItemEntry`, `BackendAbilityEntry`, `PaginatedCatalogResponse<T>` |

Fetch methods are in `pokemon_resolved/pokemon_backend_repository.dart`.
Riverpod providers and backend-first + fallback logic live in the respective `lib/features/*/providers/` files.

---

## `sync/`

Bidirectional sync engine.

| File | Purpose |
| ---- | ------- |
| `sync_service.dart` | `SyncService.run(token)` — orchestrates push then pull |
| `sync_providers.dart` | `syncServiceProvider`; `triggerSync(ref)` helper called from screens |
| `sync_status.dart` | `SyncResult` (success/failure/partial), `SyncPhase` enum |

### Push phase (`_drain`)

1. Fetch all `PendingSyncOps` from Drift
2. Discard ops with `attempts >= 5` (permanent failure)
3. Heal orphaned ops (enqueue missing parent creates)
4. Build op payload dicts; resolve `client_local_id` references within batch
5. `POST /sync/push`
6. On success: update `remoteId` fields in Drift, delete ops from queue
7. On network error: `attempts++`, retry next run
8. On malformed op (`StateError`): discard silently

### Pull phase (`_pull`)

1. Read `last_pull_at` from `Meta` table
2. `GET /sync/pull?since=last_pull_at`
3. Merge folders → teams → instances → slots (last-write-wins on `updated_at`)
4. Remote `is_deleted: true` → hard-delete locally (cascade where needed)
5. Write new `last_pull_at` to `Meta`

---

## `tray/`

Desktop-only system tray integration via `tray_manager`.

| File | Purpose |
| ---- | ------- |
| `tray_service.dart` | `TrayService.init()` — sets tray icon + menu (Sync Now, Quit); routes tray events to `SyncService` |

Active only on macOS, Windows, and Linux. No-op on iOS/Android/Web.

---

## `update/`

In-app update checker. Queries the GitHub Releases API and compares against the running app version.

| File | Class / Provider | Purpose |
| ---- | ---------------- | ------- |
| `update_service.dart` | `UpdateService` | `checkForUpdate()` — fetches latest GitHub release, semver-compares against current version, returns `UpdateInfo?` if newer |
| `update_info.dart` | `UpdateInfo` | Data class: version string + per-platform download URLs (APK, MSI, EXE, web) |
| `update_provider.dart` | `updateCheckProvider` | `FutureProvider<UpdateInfo?>` — consumed by `UpdateBanner` in `shared/widgets/` |

`platformDownloadUrl(info)` selects the correct URL for the running platform (APK on Android, EXE/MSI on Windows, web URL on web, release page otherwise).

---

## `logs/`

Remote log forwarding to the backend `/logs/device` endpoint.

| File | Class | Purpose |
| ---- | ----- | ------- |
| `logs_server_output.dart` | `LogsServerOutput` | `LogOutput` subclass (from the `logger` package); buffers lines by level and flushes every 3 s or when 20 lines accumulate; drops silently on network failure |

Used by `AppLogger` in `lib/utils/app_logger.dart`. Requires a valid auth token — lines are dropped when unauthenticated. Call `updateToken(token)` after login/logout.
