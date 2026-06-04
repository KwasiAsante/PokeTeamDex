# test/

Automated test suite. Three layers: unit, widget, and integration.

---

## Structure

```
test/
├── unit/                           # Pure Dart — no Flutter framework dependency
├── widget/                         # Flutter widget tests — in-memory Drift DB
├── integration/                    # Multi-layer tests against real Drift DB
└── helpers/                        # Shared test utilities
```

---

## Running Tests

```bash
# All tests
flutter test

# By layer
flutter test test/unit/
flutter test test/widget/
flutter test test/integration/

# Single file
flutter test test/unit/stat_calculator_test.dart

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## Unit Tests (`test/unit/`)

Pure logic tests — no Flutter, no Drift, no network.

| File | Tests | What it covers |
|------|-------|---------------|
| `stat_calculator_test.dart` | ~20 | Gen III+ stat formula for HP and non-HP stats; edge cases (min/max EVs, neutral/boosting/lowering natures) |
| `showdown_export_test.dart` | ~15 | `buildShowdownExport()` — Showdown text format, EV zero-omission, shiny flag, nickname handling |
| `sync_service_test.dart` | ~25 | Push drain (happy path, retry, discard after 5), pull merge (create/update/delete), conflict resolution (local newer / remote newer / remote deleted) |
| `format_models_test.dart` | ~20 | `GameFormat.fromJson()`, `GenerationMechanics.forGen()`, `PsMoveEntry`/`PsItemEntry`/`PsAbilityEntry` parsing |
| `form_filter_test.dart` | ~18 | `filterFormChips()` — regional variants, Mega, Gigantamax, alternate forms |
| `gimmicks_test.dart` | ~25 | `resolveZMove()`, `gmaxMoveForSpecies()`, `resolveMaxMove()`, exclusive Z-move lookup |

---

## Widget Tests (`test/widget/`)

Flutter widget tests pumped via `pumpTestApp()`. Each test:
1. Opens a fresh in-memory Drift DB
2. Seeds required data
3. Pumps the screen under test inside a full ProviderScope + GoRouter
4. Asserts on the rendered widget tree

| File | Tests | What it covers |
|------|-------|---------------|
| `teams_screen_test.dart` | 7 | Empty state, FAB, folder name, team name, multiple teams, team under folder, offline indicator |
| `team_detail_screen_test.dart` | 4 | Team name in AppBar, empty team, format label, AppBar action icons |
| `pokemon_detail_screen_test.dart` | 4 | Renders without crash, Pokémon name, tab bar, stats section |
| `slot_config_ev_iv_test.dart` | 5 | Renders without crash, Save button, EV overflow snackbar, EV total display, IV defaults |

**Key helper**: `pumpTestApp(tester, screen, db: db, extraOverrides: [...])` in `helpers/test_app.dart` — wraps the screen in a minimal `ProviderScope` + `GoRouter` + `MaterialApp.router`.

**Timer cleanup pattern** — each test ends with:
```dart
await tester.pumpWidget(const SizedBox());
await tester.pump(const Duration(milliseconds: 1));
```
This disposes the Drift stream subscriptions during the test body (before `_verifyInvariants()` checks for pending timers).

---

## Integration Tests (`test/integration/`)

Tests that exercise multiple layers together against a real in-memory SQLite database.

| File | Tests | What it covers |
|------|-------|---------------|
| `crud_flow_test.dart` | ~15 | Create folder → team → slot; rename; soft-delete; cascade delete |
| `sync_conflict_test.dart` | ~12 | Last-write-wins (local newer wins, remote newer wins), remote delete propagation, folder cascade, instance chain updates |

---

## Helpers (`test/helpers/`)

| File | Exports | Purpose |
|------|---------|---------|
| `test_app.dart` | `pumpTestApp()` | Minimal widget harness: ProviderScope with DB + auth + connectivity overrides, GoRouter with stub routes |
| `test_database.dart` | `openTestDatabase()` | Returns `AppDatabase(NativeDatabase.memory())` — fully isolated, no file system |

### pumpTestApp signature

```dart
Future<void> pumpTestApp(
  WidgetTester tester,
  Widget screen, {
  required AppDatabase db,
  String? authToken,           // null = logged out
  List<dynamic> extraOverrides = const [],
})
```

Standard overrides always applied:
- `appDatabaseProvider` → the provided in-memory DB
- `authTokenProvider` → `authToken` (null by default)
- `isOnlineProvider` → `Stream.value(false)` (offline by default)
