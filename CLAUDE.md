# PokeTeamDex — Claude Instructions

## README Maintenance

When making significant code changes, keep READMEs accurate:

- **New file or service added** → update the README for that directory (or create one if it doesn't exist and other sibling directories have READMEs).
- **Existing behaviour changed** (new endpoint, schema migration, new widget, config option, etc.) → update the relevant README to reflect the change.
- **Directory has no README but should** → create one when you first touch that directory significantly. Use the existing READMEs as style reference (tables for file lists, brief purpose descriptions, no multi-paragraph prose).

Directories that always have READMEs in this project: `lib/`, `lib/features/`, `lib/services/`, `lib/database/`, `lib/shared/`, `backend/`, `test/`, `scripts/`, `assets/`, `.github/workflows/`.

---

## TODO.md ↔ GitHub Issues Sync

`TODO.md` and GitHub issues are the single source of truth for planned and deferred work. Keep them in sync at all times.

### Adding work
- **Creating a GitHub issue** → add a matching `- [ ]` entry to the relevant section of `TODO.md` (or update an existing one to reference the issue).
- **Adding a `- [ ]` item to `TODO.md`** → open a corresponding GitHub issue with appropriate labels.

### Completing work
- **Closing a GitHub issue** → mark the matching `TODO.md` entry as `- [x]`.
- **Checking off a `TODO.md` item** → close the corresponding GitHub issue.

### Labels to use (existing labels)
`enhancement`, `bug`, `ui/ux`, `sync`, `pokémon-details`, `investigation`, `mobile`, `web`, `windows`, `documentation`

---

## Git Workflow

**Always use branches and PRs. Never commit directly to `main` unless explicitly told to.**

### For every task (feature, fix, refactor):
1. Pull latest main: `git pull origin main`
2. Create a branch: `git checkout -b <type>/<short-description>`
   - Examples: `feat/box-size-setting`, `fix/gen1-stat-preview`, `chore/update-deps`
3. Make changes, commit on the branch
4. Push: `git push origin <branch>`
5. Open a PR targeting `main`

### Exceptions (direct-to-main is OK):
- Single-line compile/build hotfixes that are blocking an in-flight CI run
- `CLAUDE.md` updates

### PR discipline — investigate first, then open one PR

Before opening any PR for a bug or feature:
1. **Trace the full path end-to-end first.** For a sync field: Flutter local table → `_buildOp` → backend push schema → backend push handler → backend model/migration → backend pull schema → Flutter `_mergeX`. For a UI bug: read all affected widgets and their data sources. Do this before writing any code.
2. **Identify every layer that needs to change.** Write down the list before touching any file.
3. **Commit all related changes to one branch and one PR.** Do not open incremental PRs as each layer of the problem is revealed — that produces a chain of dependent, half-finished PRs.
4. **Only open a separate PR** for a genuinely unrelated issue discovered during investigation (a bug in a completely different subsystem). If it is the same root cause or required for the same feature to work, it belongs in the same PR.

### Commit messages
Follow conventional commits: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`

### Releases
- Tags are version-based: `v1.0.0`, `v1.0.1`, etc.
- Before tagging: `git pull origin main` first so the tag points to the latest commit
- Tag command: `git tag vX.Y.Z && git push origin vX.Y.Z`
- To retag: `git tag -d vX.Y.Z && git push origin :vX.Y.Z` then re-tag

---

## Project Structure

- **Frontend**: Flutter app (`lib/`)
- **Backend**: FastAPI + PostgreSQL (`backend/`)
- **Database**: Drift ORM, schema version tracked in `lib/database/app_database.dart`
- **CI/CD**: GitHub Actions (`.github/workflows/`)
  - `deploy-web.yml` — deploys web to Firebase Hosting on push to `main` or tag
  - `release.yml` — builds APK, Windows MSI/EXE, Docker image, and notifies backend on tag
- **Web hosting**: Firebase Hosting → `https://poketeamdex.web.app`
- **Backend hosting**: Self-hosted server via Docker Compose, `https://poketeamdex.duckdns.org`
  - **Deploying**: `docker compose down && docker compose up -d` is all that's needed — `start.sh` runs `alembic upgrade head` automatically on every container start, so migrations never need to be run by hand.
  - **Local vs prod DB**: local `docker-compose.yml` spins up a `postgres:16` container alongside the API. `docker-compose.prod.yml` runs only the API container and connects to an external PostgreSQL via `DATABASE_URL` in `.env.prod` (no Postgres container in prod).

---

## Database Migrations (SQLite / Drift)

### Checklist for every schema change
1. Add/change the column in the table class (`lib/database/tables/`)
2. Bump `schemaVersion` in `lib/database/app_database.dart` (increment by 1)
3. Add a migration step in the `onUpgrade` handler — one `if (from < N)` block per version
4. Wrap **every** migration statement in `try/catch` (see pattern below)
5. Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `app_database.g.dart`
6. Commit the generated `.g.dart` alongside the hand-written migration

### onUpgrade pattern

```dart
MigrationStrategy(
  onCreate: (m, details) async {
    await m.createAll();
  },
  onUpgrade: (m, from, to) async {
    // Step through each version in order.
    // Never skip a version or merge two steps into one block.
    if (from < 2) {
      try {
        await m.addColumn(teams, teams.formatLabel);
      } catch (_) {
        // Column may already exist on dev builds that were ahead of this migration.
      }
    }
    if (from < 3) {
      try {
        await m.addColumn(teamSlots, teamSlots.isAlpha);
      } catch (_) {}
    }
    // … add a new `if (from < N)` block for every future version
  },
)
```

### Rules
- **Always step through versions sequentially.** A user upgrading from v2 to v4 will hit `from < 3` and `from < 4` in order. Never merge two steps.
- **Wrap every statement in `try/catch`.** Dev builds often apply migrations manually before the version number is bumped, leaving the column already present. A bare `addColumn` will crash on those builds. Catch silently — the column already existing is the desired end state.
- **Only catch `Exception` / `_` — never swallow logic errors silently in non-migration code.**
- **`BoolColumn` cannot be passed to `m.addColumn()`.** Use `customStatement('ALTER TABLE … ADD COLUMN … INTEGER NOT NULL DEFAULT 0')` for boolean columns.
- **`schemaVersion` must be a single monotonically increasing integer.** Never reset or reuse a version number.
- **Test both paths:** fresh install (onCreate) and upgrade from the previous version (onUpgrade).

---

## Android Build Notes

- **AGP**: 8.11.1 | **Kotlin**: 2.1.21 | **Gradle**: 8.14.4 | **minSdk**: 24 | **Java**: 17
- Keystore at `android/release.jks` (gitignored)
- Signing config in `android/key.properties` (gitignored)
- If Gradle fails to find the APK: check `android/build.gradle` has the `rootProject.buildDir = "../build"` redirect

---

## Secrets & Environment

- GitHub Secrets: `KEYSTORE_BASE64`, `KEY_STORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `NOTIFY_UPDATE_SECRET`
- GitHub Variables: `BACKEND_URL=https://poketeamdex.duckdns.org`
- Backend env: `backend/.env` (local), `backend/.env.prod` (server) — both gitignored
- Never commit `.env`, `.env.prod`, `*.jks`, `key.properties`, or `*firebase-adminsdk*.json`

---

## Research & Documentation

When stuck on a build error, unfamiliar API, or tool behaviour, search online before guessing.
Prefer in this order:

1. **Official docs** — Flutter/Dart (docs.flutter.dev, api.dart.dev), WiX (wixtoolset.org/docs), Firebase (firebase.google.com/docs), GitHub Actions (docs.github.com)
2. **Package pub.dev pages** — README, changelog, and example tabs for any Dart/Flutter package
3. **GitHub issues & source** — the package or tool's own repo; search closed issues for the exact error message
4. **Community** — Stack Overflow, Reddit r/FlutterDev, WiX mailing list / Discussions

Apply this whenever:
- A CI build fails with an error that isn't immediately obvious from the code
- A package API doesn't behave as expected
- A tool flag or syntax seems off (e.g. WiX 3 vs WiX 4 differences)
- The fix would benefit from knowing the canonical/recommended approach

---

## Frontend ↔ Backend Data Contract

**Any change to a synced field must be updated in ALL of the following places. Never update one without the others.**

### Adding or changing a field on a synced entity (Team, TeamFolder, TeamSlot, PokemonInstance):

| Layer | File | What to update |
|---|---|---|
| Backend DB model | `backend/app/models/team.py` | Add/change the column |
| Backend migration | `backend/alembic/versions/<next>.py` | `op.add_column` / `op.alter_column` |
| Backend push schema | `backend/app/schemas/team.py` | Add field to the Op schema (CreateOp / UpdateOp) |
| Backend push handler | `backend/app/routers/sync.py` | Read the field from `op.*` and write it to the model |
| Backend pull schema | `backend/app/schemas/team.py` | Add field to the Response schema |
| Flutter push (_buildOp) | `lib/services/sync/sync_service.dart` | Include the field in the op map |
| Flutter pull (_mergeX) | `lib/services/sync/sync_service.dart` | Read the field from the response map and write it to the local DB |
| Flutter local table | `lib/database/tables/*.dart` | Add/change the Drift column (then bump schema version + migration) |

### Rules
- The backend **Op schemas** define what the server accepts on push. If a field isn't there, the server silently ignores it.
- The backend **Response schemas** define what the server returns on pull. If a field isn't there, Flutter never receives it.
- The Flutter **_mergeX** functions define what Flutter actually writes locally from pull data. A field in the Response schema that isn't read here is silently discarded.
- Use `update_<field>: bool = False` flag pattern (like `update_folder`) when a field can be legitimately absent from an update op (to distinguish "not changing this field" from "setting it to null").
- After any backend schema or model change, run the Alembic migration before testing.
- After any Flutter table change, bump `schemaVersion`, add a migration, and run `dart run build_runner build --delete-conflicting-outputs`.

---

## Pokémon Detail Screen as the Source of Truth

`pokemon_detail_screen.dart` is the canonical implementation for all Pokémon data display. **Before writing any new display code** (list cards, grid cards, team slots, etc.), read the relevant section of the detail screen and replicate its logic exactly. Do not invent your own approach.

### Mandatory pre-implementation audit

When a new widget needs to display Pokémon form data, run this checklist before writing a single line:

1. **Read the detail screen's image handling** — grep for `cosmeticHomeUrlFor`, `kCosmeticFormHomeUrlOverrides`, and the female form special case (`formName == 'female'`). Every new image-displaying widget must replicate this logic.
2. **Check all constant maps** — `kCosmeticFormHomeUrlOverrides`, `kCosmeticFormHomeShinyUrlOverrides`, `kBaseFormCosmeticHomeUrls`, `kBaseFormNameOverrides`, `kCosmeticFormLabels`. If the detail screen uses them, the new widget must too.
3. **Understand the two cosmetic form sources** — `cosmeticFormsProvider` (form-entry cosmetics: Shellos, Cherrim, Frillish, Vivillon, etc.) AND `kCosmeticVarietyNames` (variety-based cosmetics: Wormadam, Mimikyu, etc.). Both must be included; scoping out one produces visible missing chips.

### Female form URL pattern

Female HOME artwork is at `sprites/pokemon/other/home/female/{id}.png` — **not** `sprites/pokemon/other/home/{id}-female.png`. The generic `cosmeticFormHomeUrl(id, suffix)` generates the wrong path for female forms. Always check `formName == 'female'` before calling `cosmeticFormHomeUrl`, exactly as `cosmeticHomeUrlFor` does in the detail screen.

### Navigation from list cards

Only pass `?form=` in navigation for **battle-meaningful variety forms** (`battleForms` list). Cosmetic variety forms (in `kCosmeticVarietyNames`) and form-entry cosmetics (from `cosmeticFormsProvider`) must navigate to the base detail screen without a form param — the detail screen's `initialFormName` mechanism only handles battle-meaningful forms. Passing a cosmetic form name as `initialFormName` suppresses the cosmetic chip row and breaks the header image.

---

## Flutter List Widget Rules

### Stateful list items must have identity keys

Any `ConsumerStatefulWidget` rendered inside a `ListView.builder` or `GridView.builder` **must** receive `key: ValueKey(pokemon.id)` (or equivalent unique identifier) at the call site. Without a key, Flutter reuses widget state across position changes — a form selection on item 0 leaks into a different Pokémon when the list reorders or filters. This is not optional.

### Scrollable bottom sheets for variable-length content

When a `showModalBottomSheet` may display a variable number of items (form pickers, option lists), always use `isScrollControlled: true` and wrap the sheet content in a height-capped `SingleChildScrollView` or `DraggableScrollableSheet`. A fixed-height sheet with many items (e.g. Vivillon's 20 forms, Unown's 28 letters) will overflow.

---

## PokéAPI Data Patterns

### Totem form names are not always suffix-based

PokéAPI names some Totem forms with `-totem-` as an **infix**, not a suffix. For example, Raticate's Alolan Totem form is `raticate-totem-alola`, not `raticate-alola-totem`. Any filter that excludes Totem forms must use `.contains('-totem')`, not `.endsWith('-totem')`.

### `speciesName` vs `name` for form suffix stripping

When deriving a form label suffix from a variety name (e.g. extracting `"sandy"` from `"wormadam-sandy"`), always strip the **species name** prefix, not the pokemon name. For default varieties that include a form infix (e.g. `wormadam-plant`), `pokemon.name = "wormadam-plant"` but `pokemon.speciesName = "wormadam"`. Stripping the wrong prefix produces labels like "Wormadam Sandy" instead of "Sandy". Always use `basePokemon.speciesName ?? basePokemon.name` as the prefix.

### Base form labels for form-based cosmetic species

`computeBaseFormLabel` returns `'Normal'` when `battleForms` is empty and no override exists. Form-based cosmetic species (Shellos, Arceus, Deerling, Vivillon, etc.) whose default form is **not** Normal must have an explicit entry in `kBaseFormNameOverrides`. Before shipping any form chip implementation, check every species that reaches `cosmeticFormsProvider` and verify its base label is correct. Never rely on the `'Normal'` fallback without confirming it is actually accurate for that species.

### Variety names — always verify before coding

PokéAPI variety names are often **shorter than the colloquial form name** and must be verified before adding them to `_kBattleMeaningfulNames`, `kBaseFormNameOverrides`, or `kCosmeticVarietyNames`. Never guess based on the form's display name.

```bash
curl -s "https://pokeapi.co/api/v2/pokemon-species/{id}" | python3 -c \
  "import sys,json; [print(v['pokemon']['name'], '| default:', v['is_default']) for v in json.load(sys.stdin)['varieties']]"
```

Known traps:
- `necrozma-dusk` (not `necrozma-dusk-mane`), `necrozma-dawn` (not `necrozma-dawn-wings`)
- `ogerpon` (not `ogerpon-teal-mask`) — default variety has no mask suffix even though all forms are mask-based

The key used in `kBaseFormNameOverrides` must be the exact default variety name returned by this endpoint.

### Battle-meaningful vs cosmetic — classification rules

**Battle-meaningful** (`_kBattleMeaningfulNames` in `form_filter.dart`) — the form switcher badge; switches Stats, Abilities, Moves, and Locations tabs:
- Different base stats
- Different type(s)
- Different ability (not just ability slot order)

**Cosmetic** (`kCosmeticVarietyNames` / `cosmeticFormsProvider`) — header sprite chip only; tabs do not change:
- Identical stats, type, and ability
- Visual/sprite difference only, or a move requirement that doesn't change the Pokémon's data

When in doubt: look up both forms on Bulbapedia and compare the stat totals and type lines. If they match, it's cosmetic.

### Test coverage for form display widgets

When writing tests for form picker or form display widgets, **tests must cover both form types**:
1. **Variety forms** (e.g. Giratina-Origin) — have a `/pokemon` resource; `pokemonByNameProvider` works.
2. **Form-entry cosmetics** (e.g. Shellos-East-Sea) — have no `/pokemon` resource; `pokemonByNameProvider` will fail. These forms must receive a pre-resolved sprite override so no provider call is made.

A test suite that only covers variety forms provides false confidence. Always include at least one test that verifies `pokemonByNameProvider` is **not** called for a form-entry cosmetic tile.

---

## Windows Installer

- **Known issue #96**: MSI "Launch after Finish" checkbox does not start the app — do not re-attempt without new information; use the EXE installer as the primary download for now
- WiX Toolset v4.0.5 (pinned — do not upgrade to v5+ without testing)
- `wix harvest` does not exist in v4.0.5 — components are generated via PowerShell in CI
- `Condition` in `<Custom>` elements uses attribute syntax, not inner text
- `BoolColumn` cannot be passed to `m.addColumn()` — use `customStatement` for boolean columns
