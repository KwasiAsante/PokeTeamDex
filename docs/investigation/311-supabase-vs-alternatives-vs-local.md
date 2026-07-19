# Investigation: Supabase vs Alternatives vs Local Hosting

**Issue:** [#311](https://github.com/KwasiAsante/PokeTeamDex/issues/311)
**Branch:** `investigation/supabase-vs-alternatives-vs-local`
**Status:** Investigation complete — ready for a decision + implementation sub-issues

---

## 1. Research Findings

### 1.1 What Supabase is actually used for today

The backend talks to Supabase purely as a hosted Postgres instance. There is no Supabase
SDK, Auth, Storage, Realtime, or Edge Functions usage anywhere in `backend/app/` — the
only integration point is a standard `DATABASE_URL` connection string consumed by
SQLAlchemy (async) + `asyncpg`:

```python
# backend/app/core/config.py
class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")
    database_url: str
    ...
```

```python
# backend/app/database.py
engine = create_async_engine(settings.database_url, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)
```

Schema is managed entirely by Alembic (`backend/alembic/versions/`), which runs
automatically via `backend/start.sh` on every container start. None of this cares what's
on the other end of `DATABASE_URL` — **swapping the database is a drop-in configuration
change**, not a code migration.

### 1.2 Confirming the live production setup

Two compose files exist, split cleanly by environment:

- **`backend/docker-compose.yml`** (local dev) — runs its own `postgres:16` container
  (`db` service) and points the API at it: `DATABASE_URL:
  postgresql+asyncpg://dev:dev@db:5432/poketeamdex`.
- **`backend/docker-compose.prod.yml`** (prod) — defines **only** the `api` service, no
  `db` service. The database is entirely external, supplied via `env_file: .env.prod`.

The real (gitignored) `backend/.env.prod` file's `DATABASE_URL` points at a
`*.pooler.supabase.com` host — confirming production currently runs on Supabase's Session
mode connection pooler, exactly as `backend/.env.prod.example` documents:

```
# Supabase connection string (Session mode pooler, port 5432)
DATABASE_URL=postgresql+asyncpg://postgres.xxxx:your-password@aws-0-eu-west-2.pooler.supabase.com:5432/postgres
```

So today: **API is self-hosted via Docker Compose on the user's own server
(`poketeamdex.duckdns.org`); the database is Supabase.** These are independent — nothing
requires them to be coupled, and nothing in the API code assumes the database is
co-located with it.

### 1.3 Stale documentation found during research

`backend/SETUP.md` describes a **Fly.io + Supabase** production architecture (`fly deploy`,
`fly ssh console` for migrations, a leftover `backend/fly.toml`). This predates the actual
current setup — `.github/workflows/deploy-backend.yml` only builds/pushes a Docker image to
GHCR, and deployment happens manually via `docker compose down && docker compose up -d` on
the self-hosted server (per `CLAUDE.md`'s "Backend hosting" section and
`.github/workflows/README.md`). `SETUP.md` should be corrected as part of whichever
implementation task follows this investigation, regardless of which database option is
chosen.

No architecture decision record exists for why Supabase was originally picked — the only
place it's mentioned pre-adoption is `docs/PokeTeamDex_PRD.md`, which lists it as one of
several candidate managed-Postgres options (alongside Neon, Railway) at the planning stage,
with no comparison or rationale recorded.

### 1.4 Supabase's actual pause policy

Per Supabase's own documentation: Free Plan projects are paused after **7 days without
database activity**. The pause is a hard stop — the project becomes completely
inaccessible until someone manually logs into the Supabase dashboard and clicks unpause.
Free tier also caps at 500MB database storage × 2 projects, 1GB file storage, and 5GB
bandwidth.

Source: [Supabase — Project Pausing docs](https://supabase.com/docs/guides/platform/free-project-pausing), [Supabase — Pricing & Fees](https://supabase.com/pricing)

### 1.5 Alternative researched: Neon

Neon's free tier also "suspends" idle compute — after **5 minutes** of inactivity, which
sounds stricter than Supabase's 7 days. But the mechanism is fundamentally different: it's
a fully automatic, transparent suspend/resume. The next query against the database resumes
compute in roughly 300–800ms with **no manual dashboard action and no periodic keep-alive
ping required** — the project never becomes inaccessible the way a paused Supabase project
does.

> "Scale to zero is always enabled [on the free plan] and suspends computes after 5 minutes
> of inactivity... once you query the database again, it reactivates automatically."

Source: [Neon — Scale to Zero docs](https://neon.com/docs/introduction/scale-to-zero)

Neon has no documented policy of deleting or dashboard-gating free projects for
inactivity. The one real limit to watch is a separate **0.5GB storage cap** — if exceeded,
the project is suspended until the next billing window or an upgrade, but that's a size
concern unrelated to activity/pinging.

Source: [Neon — Free plan limits & quotas FAQ](https://neon.com/faqs/free-plan-limits-and-quotas), [Neon — Plans docs](https://neon.com/docs/introduction/plans)

### 1.6 Alternative researched: Railway

Railway does **not** have an ongoing free tier as of 2026. New accounts get a one-time,
30-day $5 trial credit; after that, usage is billed (Hobby plan minimum ~$5/month, or a
Free plan capped at $1/month of credit). This is confirmed directly from Railway's own
docs, not a third party:

> "When you sign up for the free Trial, you will receive a one-time grant of $5 in credits
> ... credits ... expire in 30 days."

Source: [Railway — Free Trial docs](https://docs.railway.com/pricing/free-trial), [Railway — Pricing Plans docs](https://docs.railway.com/reference/pricing/plans)

**Railway is ruled out** — it doesn't solve "avoid recurring cost/administrative overhead
for a free-tier hobby project," it just delays the same problem by 30 days.

### 1.7 Alternative researched: self-hosting

Since the API already runs on the user's own server via Docker Compose, and already has a
working local-dev pattern for a self-hosted Postgres container
(`backend/docker-compose.yml`'s `db` service), self-hosting prod is technically
straightforward. There are two distinct designs, though, with a real trade-off the user
flagged during this investigation:

- **Coupled** — add a `db` service directly into `docker-compose.prod.yml`, same shape as
  the local dev file. Simplest to stand up, but ties the database's location to wherever
  the API container happens to run. Moving the API to a different server means
  re-provisioning Postgres there too; running two API instances (e.g. for redundancy or
  scaling) would mean two separate databases, not one source of truth.
- **Decoupled (recommended if self-hosting is chosen)** — run Postgres as its own
  standalone service (its own compose stack, or its own dedicated small host), independent
  of the API's location. Any number of API instances point at that one `DATABASE_URL` over
  the network. Moving or scaling the API never touches the database. This requires a
  private network path to the DB host (e.g. Tailscale/WireGuard, an SSH tunnel, or a
  firewalled IP allowlist) instead of exposing port 5432 to the public internet.

Either design makes the user responsible for backups, Postgres version upgrades, disk
capacity, and security hardening — work a managed provider currently does for free.

---

## 2. Answered Investigation Questions

The issue proposed three ideas. Here's how each holds up:

**Idea 1 — periodic keep-alive read/write to Supabase.**
Technically feasible (a scheduled GitHub Action or cron hitting the DB every few days
would keep the 7-day inactivity timer from firing). It's the cheapest to implement, but it
only treats the symptom: the 500MB/2-project storage cap remains, the single point of
vendor dependency remains, and it adds a piece of infrastructure whose only job is to
outsmart the platform's own policy — which could change again (Supabase's window was
reportedly tightened before; it could tighten further).

**Idea 2 — alternative provider.**
Neon is the strongest candidate found: same Postgres-over-`DATABASE_URL` integration,
transparent auto-resume with no manual unpause step, comparable or better free-tier
behavior for a low-traffic single-user app. Railway was evaluated and ruled out — it no
longer has a real ongoing free tier.

**Idea 3 — self-host / no hosted DB provider needed.**
Fully viable given the API's existing self-hosted Docker Compose setup, and in fact the
local dev environment already implements the pattern. The *decoupled* design (Postgres as
its own service, not bundled with whichever server runs the API) is necessary to satisfy
"one Postgres source of truth" regardless of how many API instances exist or where they
run — a plain merge of the local dev compose file into prod would not have satisfied that.

---

## 3. Comparison Table

| | **Supabase (status quo) + keep-alive** | **Neon** | **Self-hosted Postgres (decoupled)** |
|---|---|---|---|
| Recurring cost | $0 (free tier) | $0 (free tier) | $0 (uses existing server) or cost of a new small host |
| Pause/downtime risk | Removed by the ping, but fragile — depends on the ping never failing and Supabase's policy not tightening further | None — compute auto-resumes transparently in <1s, no dashboard action ever required | None — always on, entirely under the user's control |
| Storage limit | 500MB × 2 projects | 0.5GB (suspends project if exceeded, not deleted) | Limited only by the host's disk |
| Operational burden | Low, but must maintain the keep-alive job itself | None — backups, upgrades, and infra are Neon's responsibility | High — user owns backups, Postgres version upgrades, security hardening, disk monitoring |
| Migration effort | None (status quo) | One-time `pg_dump`/`pg_restore` + `DATABASE_URL` swap | One-time `pg_dump`/`pg_restore` + provisioning a new Postgres service + private network setup |
| Code changes required | New keep-alive script/workflow only | None — `DATABASE_URL` change only | None — `DATABASE_URL` change only |
| Vendor dependency | Yes (Supabase) | Yes (Neon) | No |

---

## 4. Recommendation

**Neon.** For a solo-developer side project, it's close to a strict improvement over the
status quo: it's a drop-in `DATABASE_URL` swap with zero code changes (same
SQLAlchemy/asyncpg integration path), it has no "pause until you manually log in and
unpause" failure mode the way Supabase does, and it hands off backups/upgrades/infra
management for free — none of which the user has to build or maintain.

Self-hosting (decoupled design) is the right call if a *future* goal is eliminating
third-party dependencies entirely, or if the user is already planning to run other
infrastructure on their own server anyway. It's not justified purely to solve the pausing
problem in isolation, given the ongoing backup/upgrade/security-hardening burden it
permanently transfers to the user.

The keep-alive-ping idea is the weakest option — it's the cheapest to build today, but it
treats the symptom rather than the cause, still leaves the 500MB/2-project cap and the
single vendor dependency in place, and adds a maintenance burden (a job whose only purpose
is to work around a platform policy that could change again).

---

## 5. Data Migration Plan

Real user data exists in the current Supabase database (this is a live, synced,
multi-device app), so **any** option other than the keep-alive ping requires moving data,
not just standing up a fresh schema. This plan applies to both the Neon and self-hosted
paths:

1. **Dump** — `pg_dump` against the current Supabase Session-pooler connection string
   (the same `DATABASE_URL` already in `.env.prod`), producing a full schema + data dump.
2. **Restore** — `pg_restore` (or `psql < dump.sql`) into the new target (Neon project, or
   the new self-hosted Postgres instance). Run Alembic (`alembic upgrade head`) against the
   new target first if starting from an empty database, to confirm schema drift is zero
   before restoring data — or restore directly and let Alembic's version table confirm it
   matches `backend/alembic/versions/` head.
3. **Cutover window** — since there is no dual-write mechanism between old and new
   databases, this needs a brief maintenance window: stop the API container (or put it in
   a maintenance mode), take a final incremental dump to catch any writes since step 1,
   restore that delta, update `.env.prod`'s `DATABASE_URL` to the new target, restart the
   API.
4. **Verification** — compare row counts per table between source and target
   (`SELECT count(*) FROM <table>` for each), spot-check a few real records (e.g. a team
   and its slots) round-trip correctly through the API against the new database.
5. **Rollback plan** — keep the Supabase project intact (even if paused) for a short window
   post-cutover as a fallback; reverting is just pointing `DATABASE_URL` back at it, since
   nothing about it will have been deleted yet.

---

## 6. Implementation Plan

Task breakdown depends on which option is chosen. Both lists below assume the decision is
made based on the recommendation in Section 4, but are written to stand alone regardless of
which path is picked, since the sub-issues created after this PR merges will only cover the
chosen path.

### If Neon is chosen

1. **Task 1** — Provision a Neon project + database, matching the current schema (run
   `alembic upgrade head` against it or restore from a dump).
2. **Task 2** — Migrate data per Section 5's dump/restore/cutover steps.
3. **Task 3** — Update `.env.prod` (and `.env.prod.example`'s documentation comment) to
   point `DATABASE_URL` at Neon; remove the Supabase-specific pooler-mode comment.
4. **Task 4** — Update `backend/SETUP.md` to reflect the current self-hosted-API + Neon
   architecture (also fixing the stale Fly.io references found in Section 1.3), and update
   `CLAUDE.md`'s "Backend hosting" section.
5. **Task 5** — Decommission the Supabase project once the cutover is verified stable.

### If self-hosting (decoupled) is chosen

1. **Task 1** — Stand up a standalone Postgres service (its own compose stack or a
   dedicated small host) with a persistent volume, plus a private network path to it
   (Tailscale/WireGuard, SSH tunnel, or firewalled IP allowlist) — not a publicly exposed
   port 5432.
2. **Task 2** — Migrate data per Section 5's dump/restore/cutover steps.
3. **Task 3** — Update `docker-compose.prod.yml`/`.env.prod` so the API's `DATABASE_URL`
   points at the new Postgres host over the private network.
4. **Task 4** — Add an automated backup job (e.g. a scheduled `pg_dump` to durable
   storage) — the user is now responsible for backups that Supabase previously handled.
5. **Task 5** — Update `backend/SETUP.md` (fixing the stale Fly.io/Supabase references)
   and `CLAUDE.md`'s "Backend hosting" section to document the new architecture.
6. **Task 6** — Decommission the Supabase project once the cutover is verified stable.

No implementation code is included in this investigation PR — sub-issues will be created
for the chosen path's tasks after this PR merges, per the project's investigation issue
workflow.

---

## Sources

- [Supabase — Project Pausing docs](https://supabase.com/docs/guides/platform/free-project-pausing)
- [Supabase — Pricing & Fees](https://supabase.com/pricing)
- [Neon — Scale to Zero docs](https://neon.com/docs/introduction/scale-to-zero)
- [Neon — Free plan limits & quotas FAQ](https://neon.com/faqs/free-plan-limits-and-quotas)
- [Neon — Plans docs](https://neon.com/docs/introduction/plans)
- [Railway — Free Trial docs](https://docs.railway.com/pricing/free-trial)
- [Railway — Pricing Plans docs](https://docs.railway.com/reference/pricing/plans)
- [Neon vs Supabase vs Railway comparison (third-party synthesis, used for framing only)](https://codelesssync.com/blog/supabase-vs-neon-vs-railway-postgresql-for-saas)
