# .github/workflows/

GitHub Actions CI/CD. Three workflows cover all automated build, deploy, and release tasks.

---

## deploy-web.yml — Web deploy

**Trigger:** push to `main` or any `v*.*.*` tag

Builds the Flutter web target and deploys to Firebase Hosting at **https://poketeamdex.web.app**. Uses a `concurrency` group so a fast follow-up push cancels the in-progress run rather than queuing behind it.

**Secrets required:** `FIREBASE_SERVICE_ACCOUNT_JSON`

---

## deploy-backend.yml — Backend Docker image

**Trigger:** push to `main` when any file under `backend/` changes; also manually dispatchable via `workflow_dispatch`

Builds the FastAPI Docker image and pushes it to GHCR as `ghcr.io/kwasiasante/poketeamdex-backend:latest`.

> This workflow publishes the image only — it does **not** deploy to the server. Pull and restart manually on the server:
> ```bash
> docker compose -f docker-compose.prod.yml down && docker compose -f docker-compose.prod.yml up -d
> ```

---

## release.yml — Release builds

**Trigger:** push of any `v*.*.*` tag

Creates a GitHub Release, then runs 4 jobs in parallel:

| Job | Output | Notes |
|-----|--------|-------|
| `build-android` | `PokeTeamDex-vX.Y.Z.apk` | Signed with release keystore from Secrets |
| `build-windows` | `PokeTeamDex-vX.Y.Z-Setup.msi` + `PokeTeamDex-vX.Y.Z-Setup.exe` | WiX v4.0.5 (MSI) + Inno Setup (EXE); see known issue #96 for MSI launch bug |
| `build-backend-docker` | GHCR image tagged `vX.Y.Z` + `latest` | Same Dockerfile as `deploy-backend.yml` but version-tagged |
| `notify-backend` | — | POSTs to `/admin/notify-update` so the backend can surface the new version for in-app update checks |

All build artifacts are uploaded directly to the GitHub Release via `gh release upload`.

**Secrets required:** `KEYSTORE_BASE64`, `KEY_STORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, `NOTIFY_UPDATE_SECRET`  
**Variables required:** `BACKEND_URL`

> **Why `notify-backend` is in `release.yml` and not a separate workflow:** GitHub Actions blocks cross-workflow triggers fired by `GITHUB_TOKEN`. The notify step must run in the same workflow as the release creation to avoid the permission restriction.
