# Backend Setup Guide

## Architecture

| Environment | API Host | Database |
|---|---|---|
| Local dev | Docker Compose (localhost:8000) | Postgres in Docker |
| Production | Fly.io | Supabase (PostgreSQL) |

The Flutter app points to `localhost:8000` during development and `https://poketeamdex-api.fly.dev` in production.

---

## Local Development

Requires: [Docker Desktop](https://www.docker.com/products/docker-desktop/)

```bash
# 1. Start the API and local Postgres
cd backend
docker compose up

# 2. Run migrations (first time only, or after adding new migrations)
docker compose exec api alembic upgrade head

# 3. Open interactive API docs
open http://localhost:8000/docs
```

To stop: `docker compose down`
To wipe the database and start clean: `docker compose down -v`

---

## Production Deployment (Fly.io + Supabase)

### Prerequisites

- [Fly.io account](https://fly.io) (free tier)
- [Supabase account](https://supabase.com) (free tier)
- flyctl CLI

```bash
brew install flyctl
# or
curl -L https://fly.io/install.sh | sh
```

---

### Step 1 — Create a Supabase project

1. Go to [supabase.com](https://supabase.com) → **New project**
2. Choose a name, password, and region (pick one close to your Fly.io region)
3. Wait for the project to finish provisioning (~2 min)
4. Go to **Settings → Database → Connection string**
5. Select **URI** mode and copy the string:
   ```
   postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-REF].supabase.co:5432/postgres
   ```
6. Change the scheme to `postgresql+asyncpg://` (required for the async driver):
   ```
   postgresql+asyncpg://postgres:[YOUR-PASSWORD]@db.[YOUR-REF].supabase.co:5432/postgres
   ```
   Keep this — you'll need it in Step 3.

---

### Step 2 — Create the Fly app (once only)

```bash
fly auth login
cd backend
fly launch --no-deploy   # registers the app name from fly.toml without deploying
```

If the app name `poketeamdex-api` in `fly.toml` is taken, pick a unique name and update `fly.toml`.

**Fly.io regions** — update `primary_region` in `fly.toml` to the closest:

| Code | Location |
|---|---|
| `lhr` | London |
| `iad` | Virginia (US East) |
| `ord` | Chicago |
| `lax` | Los Angeles |
| `sin` | Singapore |
| `syd` | Sydney |

---

### Step 3 — Set secrets

Secrets are environment variables stored securely by Fly — never in code or `fly.toml`.

```bash
fly secrets set \
  DATABASE_URL="postgresql+asyncpg://postgres:[YOUR-PASSWORD]@db.[YOUR-REF].supabase.co:5432/postgres" \
  SECRET_KEY="$(openssl rand -hex 32)"
```

To verify secrets are set (values are hidden):
```bash
fly secrets list
```

---

### Step 4 — Deploy

```bash
fly deploy
```

This builds the Docker image and deploys it. Takes ~2 minutes on first deploy, faster after that.

---

### Step 5 — Run migrations against Supabase

```bash
fly ssh console -C "alembic upgrade head"
```

Run this after every deploy that includes new migrations.

---

### Step 6 — Verify

```bash
# Check the app is running
fly status

# Check logs
fly logs

# Open API docs in browser
fly open /docs
```

Your API is live at: `https://poketeamdex-api.fly.dev`

---

## Subsequent Deploys

After the initial setup, deploying new changes is just:

```bash
cd backend
fly deploy
# then if there are new migrations:
fly ssh console -C "alembic upgrade head"
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

In development, the base URL is `http://localhost:8000`.
In production, it is `https://poketeamdex-api.fly.dev` (or whatever name you chose).

These will be wired up in Epic 7 (sync engine).
