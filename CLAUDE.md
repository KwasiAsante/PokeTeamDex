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

## Windows Installer

- WiX Toolset v4.0.5 (pinned — do not upgrade to v5+ without testing)
- `wix harvest` does not exist in v4.0.5 — components are generated via PowerShell in CI
- `Condition` in `<Custom>` elements uses attribute syntax, not inner text
- `BoolColumn` cannot be passed to `m.addColumn()` — use `customStatement` for boolean columns
