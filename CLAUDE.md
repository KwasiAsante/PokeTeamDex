# PokeTeamDex — Claude Instructions

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

---

## Database Migrations

When adding columns to Drift tables:
1. Add the column to the table class in `lib/database/tables/`
2. Bump `schemaVersion` in `lib/database/app_database.dart`
3. Add a migration in the `onUpgrade` handler
4. Wrap ALL migrations in `try/catch` for idempotency (dev builds may already have the column)
5. Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `app_database.g.dart`
6. Commit the generated `.g.dart` file alongside the migration

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

## Windows Installer

- **Known issue #96**: MSI "Launch after Finish" checkbox does not start the app — do not re-attempt without new information; use the EXE installer as the primary download for now
- WiX Toolset v4.0.5 (pinned — do not upgrade to v5+ without testing)
- `wix harvest` does not exist in v4.0.5 — components are generated via PowerShell in CI
- `Condition` in `<Custom>` elements uses attribute syntax, not inner text
- `BoolColumn` cannot be passed to `m.addColumn()` — use `customStatement` for boolean columns
