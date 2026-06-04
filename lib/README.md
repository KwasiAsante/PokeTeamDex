# lib/

Flutter application source. Organized into four top-level layers:

```
lib/
├── main.dart          # Entry point
├── router/            # Navigation
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

Cross-feature UI components and utilities.

| Folder | Contents |
|--------|----------|
| `theme/` | `AppTheme.buildTheme()`, type colour palette (18 types), accent colour swatches |
| `widgets/` | `AsyncValueStates` (loading/error/empty), `TypeBadge`, `PokemonSprite`, `FavoriteButton`, `ConnectivityStatusButton`, `SettingsButton`, `SkeletonBox` |
| `providers/` | `appStateProvider`, `themeProvider`, `accentColourProvider` |
| `utils/` | `StatCalculator` (Gen III+ formula), `showAppSnackBar()`, `snackBarError()` |
