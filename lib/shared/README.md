# lib/shared/

Cross-feature utilities, widgets, and theme definitions. Nothing in `shared/` imports from `features/` — dependencies only flow inward.

---

## theme/

| File | Contents |
|------|----------|
| `app_theme.dart` | `AppTheme.buildTheme(colorScheme, brightness)` — Material 3 theme builder; seeds `ColorScheme` from a user-selected accent colour |
| `pokemon_type_colors.dart` | `kTypeColors` — map of all 18 Pokémon type names to their hex colour; used by `TypeBadge`, slot card gradients, and detail page accents |

---

## widgets/

Reusable UI components used across multiple features.

| File | Widget | Purpose |
|------|--------|---------|
| `async_value_states.dart` | `LoadingState`, `ErrorState`, `EmptyState` | Standard loading / error / empty placeholders with consistent Material 3 styling |
| `type_badge.dart` | `TypeBadge` | Coloured pill chip for a single Pokémon type (`labelSmall`, 11sp); uses `kTypeColors` |
| `pokemon_sprite.dart` | `PokemonSprite` | Sprite image with generation-aware URL resolution; falls back gracefully on load error |
| `favorite_button.dart` | `FavoriteButton` | Star `IconButton` that reads/writes the `Favorites` Drift table |
| `connectivity_status_button.dart` | `ConnectivityStatusButton` | AppBar wifi icon + coloured dot (green/amber/red); tapping opens connectivity status bottom sheet |
| `settings_button.dart` | `SettingsButton` | AppBar settings `IconButton` that navigates to `/settings` |
| `update_banner.dart` | `UpdateBanner` | Persistent banner shown when `updateCheckProvider` returns a newer version; links to per-platform download URL |
| `skeleton_box.dart` | `SkeletonBox` | Animated shimmer placeholder for loading states in list tiles and detail screens |
| `stat_bar.dart` | `StatBar` | Animated progress bar for base stat display; fill animates on first render via `AnimationController` |
| `move_type_chip.dart` | `MoveTypeChip` | Compact type-coloured chip for move list tiles |
| `shutdown_dialog.dart` | `ShutdownDialog` | Confirmation dialog shown on desktop when the window is closed while a sync is in progress |

---

## providers/

| File | Providers | Output |
|------|-----------|--------|
| `app_provider.dart` | `themeProvider`, `accentColourProvider` | Read from `AppConfigs` Drift table; apply instantly app-wide via `MaterialApp` rebuild |

---

## utils/

| File | Exports | Purpose |
|------|---------|---------|
| `stat_calculator.dart` | `StatCalculator` | Gen III+ stat formula for HP and non-HP stats; used by the slot config real-time stat preview |
| `snack_bar.dart` | `showAppSnackBar()`, `snackBarError()` | Floating `SnackBar` helpers with `SnackBarBehavior.floating` applied consistently |
