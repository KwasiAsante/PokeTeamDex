# lib/database/

Local persistence layer built on [Drift](https://drift.simonbinder.eu/) — a type-safe SQLite ORM with code generation.

---

## Files

| File | Purpose |
|------|---------|
| `app_database.dart` | `AppDatabase` class — registers all tables, defines v1–v10 migrations |
| `database_providers.dart` | Riverpod providers: `appDatabaseProvider`, repository providers |
| `tables/` | One Dart file per Drift table definition |
| `repositories/` | Data access objects — typed query + mutation methods |

---

## Tables

### Core entities

| Table | Key columns | Notes |
|-------|-------------|-------|
| `Teams` | id, folderId, name, remoteId, formatLabel, sortOrder | Soft-deleted via `isDeleted` |
| `TeamSlots` | id, teamId, slot (1–6), pokemonId, 40+ config cols | All EV/IV/moves/ribbons/gimmicks |
| `TeamFolders` | id, name, remoteId | Organizes teams |
| `PokemonInstances` | id, pokemonId, parentInstanceId (self-ref) | Cross-team Pokémon identity |

### Sync infrastructure

| Table | Purpose |
|-------|---------|
| `PendingSyncOps` | Queue of unsynced mutations (op type, payload JSON, attempt count) |
| `Meta` | Key-value store (`last_pull_at`, `device_id`) |

### App state

| Table | Purpose |
|-------|---------|
| `AppConfigs` | Persistent settings (API base URL, theme) |
| `Favorites` | Starred Pokémon IDs |

---

## Schema Migrations

Migrations live in `app_database.dart` as a `MigrationStrategy`:

```
v1  Initial schema
v2  Form + sprite config columns on TeamSlots
v3  is_deleted + sync_status on all entities; format_label + sort_order on Teams
v4  PS import tracking fields
v5  AppConfigs table
v6  Favorites table
v7  6 contest stat columns on TeamSlots
v8  ribbons JSON + isMegaEvolved + hasGigantamax + isAlpha on TeamSlots
v9  PokemonInstances table + instance_id FK on TeamSlots
v10 gigantamax_enabled column on TeamSlots
```

---

## Repositories

Each repository wraps typed Drift queries:

| Repository | Methods |
|-----------|---------|
| `TeamRepository` | `watchAll()`, `watchById()`, `insert()`, `update()`, `softDelete()` |
| `TeamSlotRepository` | `watchForTeam()`, `upsert()`, `softDelete()` |
| `PokemonInstanceRepository` | `getChain()`, `getDirectChildren()`, CRUD |
| `SyncQueueRepository` | `enqueue()`, `fetchPending()`, `incrementAttempts()`, `delete()` |

---

## Code Generation

After changing any table definition, regenerate Drift code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generated files (`.g.dart`) are committed to the repo so no build step is needed to run the app.
