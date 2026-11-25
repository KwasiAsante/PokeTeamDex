# Backend Setup Guide

## Architecture

| Environment | API Host | Database |
|---|---|---|
| Local dev | Docker Compose (`localhost:8000`) | `postgres:16` container (`docker-compose.yml`) |
| Production | Self-hosted server, Docker Compose (`https://poketeamdex.duckdns.org`) | [Neon](https://neon.com) (Postgres 18, AWS `us-east-1`, free plan) |

The API and the database are independent. The production compose stack runs **only** the API
container; it reaches Neon over the internet via `DATABASE_URL`. See
[`docs/investigation/311-supabase-vs-alternatives-vs-local.md`](../docs/investigation/311-supabase-vs-alternatives-vs-local.md)
for why Neon was chosen (migrated from Supabase on 2026-11-25).

---

## Local Development

Requires: [Docker Desktop](https://www.docker.com/products/docker-desktop/)

```bash
cd backend
docker compose up          # API + local Postgres; start.sh runs migrations automatically
open http://localhost:8000/docs
```

To stop: `docker compose down`
To wipe the database and start clean: `docker compose down -v`

---

## Production

### Deploying

`.github/workflows/deploy-backend.yml` builds and pushes
`ghcr.io/kwasiasante/poketeamdex-backend:latest` on every push to `main` that touches
`backend/**`. On the server:

```bash
cd ~/docker/services/poketeamdex
docker compose pull && docker compose down && docker compose up -d
docker compose logs -f --tail=50
```

`start.sh` runs `alembic upgrade head` on every container start, so migrations never need
to be run by hand.

### Environment file

On the server the env file is `~/docker/services/poketeamdex/.env`. The repo's
`docker-compose.prod.yml` and `.env.prod.example` use the name `.env.prod`. The contents
are the same; only the file name differs. It is gitignored. Never commit it.

### Neon connection string

Neon dashboard → **Connect** → turn **Connection pooling off** (direct endpoint, no
`-pooler` in the host). Neon gives:

```
postgresql://neondb_owner:PASS@ep-xxx.c-11.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require
```

The app needs **two edits**:

```
postgresql+asyncpg://neondb_owner:PASS@ep-xxx.c-11.us-east-1.aws.neon.tech/neondb?ssl=require
```

| Edit | Why |
|---|---|
| `postgresql://` → `postgresql+asyncpg://` | Otherwise SQLAlchemy loads psycopg2 (not installed): `No module named 'psycopg2'` |
| `?sslmode=…&channel_binding=…` → `?ssl=require` | asyncpg's `connect()` only accepts `ssl`: `connect() got an unexpected keyword argument 'sslmode'` |

To convert one automatically:

```bash
echo "$NEON" | sed -E 's#^postgresql://#postgresql+asyncpg://#; s#\?.*#?ssl=require#'
```

> **The reverse applies to Postgres CLI tools** (`psql`, `pg_dump`, `pg_restore`): they
> need plain `postgresql://…?sslmode=require` and reject `?ssl=require`
> (`invalid URI query parameter: "ssl"`).

Use the **direct** endpoint for the app, migrations, and `pg_dump`/`pg_restore`. Neon
suspends compute after 5 minutes idle; the engine sets `pool_pre_ping=True`
(`app/database.py`) so the first request after an idle period doesn't fail on a dead
connection. The first query after a suspend takes slightly longer while compute resumes.

### Checking the database from a laptop

Alembic loads the app's settings, which require `SECRET_KEY` even though migrations don't
use it:

```bash
cd backend
SECRET_KEY=dummy DATABASE_URL='<asyncpg direct string>' alembic current   # prints current revision
alembic heads                                                              # latest revision in the repo
```

### Free plan limits to watch

1 GB storage per project, 100 CU-hours/month, scale-to-zero after 5 min (cannot be
disabled), 6 hours of point-in-time restore history.
Source: [Neon — Plans](https://neon.com/docs/introduction/plans).

---

## Dump / restore

Use the `postgres:18` Docker image so client tools match Neon's major version (a local
Homebrew `pg_dump` may be older). Run from any directory; the dump lands in `$PWD`.

```bash
# Dump (only the app's tables)
docker run --rm -v "$PWD":/dump postgres:18 \
  pg_dump -Fc -v -n public --no-owner --no-acl -d "$SOURCE" -f /dump/db.dump

# Restore
docker run --rm -v "$PWD":/dump postgres:18 \
  pg_restore -v --no-owner --no-acl -d "$TARGET" /dump/db.dump
```

`schema "public" already exists` during restore is expected and harmless. To wipe a target
before restoring: `DROP SCHEMA public CASCADE; CREATE SCHEMA public;`.

Verify by comparing exact row counts on both sides:

```bash
Q="SELECT table_name, (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM public.%I', table_name), false, true, '')))[1]::text::int FROM information_schema.tables WHERE table_schema='public' ORDER BY 1;"
docker run --rm postgres:18 psql -At -d "$SOURCE" -c "$Q" > a.txt
docker run --rm postgres:18 psql -At -d "$TARGET" -c "$Q" > b.txt
diff a.txt b.txt && echo MATCH
```

Delete dump files afterwards; they contain all user data.

---

## Backups (local Postgres copy of Neon)

Neon's free plan keeps only 6 hours of restore history, so `backend/backup/` runs a daily
off-Neon backup on the server (#323). It is a **backup target only**: the API never reads
from or writes to it.

| Container | Purpose |
|---|---|
| `poketeamdex_backup_db` | `postgres:18` holding the latest restored copy. No published port. |
| `poketeamdex_backup_runner` | Once at start, then daily at `BACKUP_HOUR_UTC`: `pg_dump` from Neon → restore into `backup-db` → exact per-table row-count check against Neon → keep newest `KEEP_DUMPS` files in `./dumps`. Retries once after 60s on any failure. |

### Install (server)

The runner image is built by `.github/workflows/deploy-backup.yml` and pushed to
`ghcr.io/kwasiasante/poketeamdex-backup:latest` whenever `backend/backup/**` changes on
`main`. The server only needs two files:

```bash
mkdir -p ~/docker/services/poketeamdex-backup && cd ~/docker/services/poketeamdex-backup
# copy backend/backup/docker-compose.yml and backend/backup/.env.example here (once)
cp .env.example .env && chmod 600 .env   # SOURCE_URL in plain postgresql://…?sslmode=require form
docker compose pull && docker compose up -d
docker compose logs -f backup-runner     # expect "backup succeeded … tables=[…]"
```

**Updating** (after a change to `backup.sh` merges and the workflow finishes):
`docker compose pull && docker compose up -d`. Re-copy `docker-compose.yml` only if it
changed.

**Testing a branch before merging:** any push to a branch that touches `backend/backup/`
builds an image tagged with the branch name (`/` → `-`). Set `BACKUP_IMAGE_TAG=<branch-with-dashes>` in
`.env` and `docker compose pull && docker compose up -d`.

### Checking it

```bash
docker ps --filter name=poketeamdex_backup_runner   # STATUS shows (unhealthy) if no success in 26h
ls -lh dumps/
docker exec poketeamdex_backup_db psql -U backup poketeamdex -c 'SELECT count(*) FROM teams;'
```

### Loki (optional)

Failures always appear in `docker compose logs`. To also push them to Loki, the runner must
be on the same Docker network as Loki. Find the API's networks and its Loki URL:

```bash
docker inspect poketeamdex_api --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
grep LOKI_URL ~/docker/services/poketeamdex/.env
```

Set `LOKI_URL` in the backup `.env` to that value, and add `docker-compose.override.yml`
next to the backup compose file (Compose loads it automatically):

```yaml
services:
  backup-runner:
    networks: [default, loki]
networks:
  loki:
    external: true
    name: <network name from docker inspect>
```

Log lines use `app="poketeamdex_backup"`. Query failures with
`{app="poketeamdex_backup", level="ERROR"}`.

### Restoring

**Stop the runner first** so a scheduled run can't overwrite `backup-db` while you work:
`docker compose stop backup-runner`.

**Option 1: restore into a new Neon project (preferred; keeps the normal architecture).**
Create a Neon project (Postgres 18, `us-east-1`), then:

```bash
cd ~/docker/services/poketeamdex-backup
NEW='postgresql://neondb_owner:PASS@ep-new….neon.tech/neondb?sslmode=require'
docker run --rm -v "$PWD/dumps":/dump postgres:18 \
  pg_restore -v --no-owner --no-acl -d "$NEW" /dump/$(ls -t dumps | grep '\.dump$' | head -1)
```

Then update the API's `DATABASE_URL` (asyncpg form; see above) and `docker compose up -d`
in the API directory. Update `SOURCE_URL` in the backup `.env` before restarting the runner.

**Option 2: emergency, point the API at the local copy.** Only use this if Neon is
unavailable and you can't wait. Data is as of the last successful backup.

```bash
cd ~/docker/services/poketeamdex
cp .env .env.neon.bak
# Edit .env (no SSL inside the Docker network):
# DATABASE_URL=postgresql+asyncpg://backup:<BACKUP_DB_PASSWORD>@backup-db:5432/poketeamdex
docker compose up -d                                                  # recreates the API container
docker network connect poketeamdex-backup_default poketeamdex_api     # join the backup network
docker restart poketeamdex_api                                        # start.sh can now reach backup-db
docker logs -f --tail=50 poketeamdex_api
```

Writes made in this mode only exist locally. To return to Neon, dump `backup-db` from inside
its network and restore it into Neon:

```bash
cd ~/docker/services/poketeamdex-backup
docker run --rm --network poketeamdex-backup_default -v "$PWD/dumps":/dump postgres:18 \
  pg_dump -Fc -n public --no-owner --no-acl -d "postgresql://backup:<BACKUP_DB_PASSWORD>@backup-db:5432/poketeamdex" -f /dump/failback.dump
# then restore /dump/failback.dump into Neon (wipe its public schema first), restore .env.neon.bak, docker compose up -d
```

---

## Generating Migrations

After changing `app/models/`:

```bash
# With docker compose running locally:
docker compose exec api alembic revision --autogenerate -m "describe your change"

# Review the generated file in alembic/versions/ before committing
```

---

## Pointing Flutter at the API

Development: `http://localhost:8000` (Settings → API Base URL).
Production: `https://poketeamdex.duckdns.org` (`BACKEND_URL` GitHub variable).
