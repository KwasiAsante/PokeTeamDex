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
