# lib/

Flutter application source. Organized into four top-level layers:

```
lib/
├── main.dart          # Entry point
├── router/            # Navigation
├── data/              # Unified Pokémon data resolution (sprites, form overrides)
├── database/          # Local persistence (Drift + SQLite)
├── features/          # Screen-level feature modules
├── services/          # Cross-feature services (sync, API, format engine)
└── shared/            # Reusable UI + utilities
```

---

## main.dart

Entry point. Responsibilities:
- Initialize Hive (cache store)
- Read stored auth token from Hive
- Register WorkManager periodic task (1-hour sync on Android/iOS)
- Initialize the system tray (desktop platforms)
- Mount `MyApp` — a `ConsumerStatefulWidget` that wires up the 15-minute in-process sync timer and `AppLifecycleState` listener

---

## router/

**`app_router.dart`** — GoRouter 17 configuration.

- `StatefulShellRoute` with 5 branches: Pokédex, Moves, Items, Reference, Teams
- Redirect guard: users already logged in skip `/login` → `/pokedex`
- `ScaffoldWithNavBar` switches between `BottomNavigationBar` (< 600dp), `NavigationRail` (600–840dp), and permanent `NavigationDrawer` (> 840dp)

---

## data/

Unified Pokémon data resolution layer — the canonical place for sprite URL and form-override logic, replacing what used to be scattered across `form_data.dart`, `form_filter.dart`, `evolution_chain_builder.dart`, `mega_forms_data.dart`, and `sprite_resolver.dart`.

| File | Purpose |
|------|---------|
| `pokemon_data_resolver.dart` | `PokemonDataResolver` — `resolveFormSprite()`, `resolvePokedexImageUrl()`, `resolveVersionedSprite()`, `genViiiIconFallbackUrl()` |
| `pokemon_data_registry.dart` | `PokemonDataRegistry` — singleton loaded once via `initialize()`; parses `assets/data/pokemon_registry.json` into the override maps consumed by `PokemonDataResolver` and other call sites (cosmetic form labels, base form names, mega stone map, version-group lookups, etc.) |

---

## database/

See [`database/README.md`](database/README.md).

---

## features/

See [`features/README.md`](features/README.md).

---

## services/

See [`services/README.md`](services/README.md).

---

## shared/

See [`shared/README.md`](shared/README.md).

---

## utils/

Top-level app utilities, separate from `shared/utils/`.

| File | Purpose |
|------|---------|
| `app_logger.dart` | Singleton `AppLogger` — three sinks: console (debug only), daily rotating file (non-web), HTTP push to backend `/logs/device`; call `AppLogger.configure(url)` and `AppLogger.configureToken(token)` after the DB loads |
