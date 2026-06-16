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
| `sprite_resolver.dart` | Thin wrapper; sprite resolution has moved to `PokemonDataResolver.resolveFormSprite()` in `lib/data/pokemon_data_resolver.dart` |

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
| `poke_api_repository.dart` | `fetchPokemon(id)`, `fetchPokemonSpecies(id)`, `fetchPokemonByName(name)`, `fetchPokemonEncounters(id)` |
| `poke_api_cache.dart` | Hive box wrapper; TTL = 24h for list data, 7d for detail data |
| `poke_api_providers.dart` | `pokeApiRepositoryProvider` (injectable in tests via override) |
| `models/` | `PokemonEntry`, `PokemonSpeciesEntry`, `PokemonEncounterEntry` — JSON deserialization |

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
