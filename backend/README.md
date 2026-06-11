# Backend — FastAPI

Stateless REST API for PokeTeamDex. Stores team data in PostgreSQL and exposes a bidirectional sync API that the Flutter app uses to push and pull changes.

---

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | FastAPI 0.115 |
| Runtime | Python 3.12 |
| ORM | SQLAlchemy 2.0 (async) |
| DB | PostgreSQL 16 |
| Migrations | Alembic |
| Auth | JWT via `python-jose`, bcrypt password hashing |
| Server | Uvicorn |
| Container | Docker + Docker Compose |

---

## Structure

```
backend/
├── app/
│   ├── main.py           # FastAPI app, CORS, exception handler, GET /health
│   ├── database.py       # Async engine + session factory
│   ├── routers/
│   │   ├── auth.py       # POST /auth/register, POST /auth/login
│   │   ├── teams.py      # Teams CRUD + slot endpoints
│   │   ├── folders.py    # Team folders CRUD
│   │   ├── instances.py  # Pokémon instance CRUD
│   │   ├── sync.py       # GET /sync/pull, POST /sync/push
│   │   └── ps_data.py    # GET /ps-data/version, GET /ps-data/file/:name
│   ├── models/
│   │   ├── user.py       # User ORM model
│   │   └── team.py       # Team, TeamSlot, TeamFolder, PokemonInstance ORM models
│   ├── schemas/
│   │   ├── auth.py       # RegisterRequest, LoginRequest, TokenResponse
│   │   └── team.py       # SyncOp variants, SyncPushRequest, SyncPushResponse,
│   │                     # SyncPullResponse, TeamResponse, SlotResponse
│   └── core/
│       ├── config.py     # Pydantic Settings — reads from .env
│       ├── security.py   # create_access_token, verify_token, get_password_hash
│       └── deps.py       # get_current_user dependency (JWT → User)
├── alembic/
│   ├── env.py
│   └── versions/
│       ├── 0001_initial_schema.py
│       ├── 0002_nullable_folder_user_on_team.py
│       ├── 0003_add_is_deleted.py
│       ├── 0004_pokemon_instances.py
│       ├── 0005_full_slot_config.py
│       ├── 0006_add_format_label_to_teams.py
│       ├── 0007_add_tera_type_to_slots.py
│       └── 0008_add_sort_order_and_is_box.py
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── start.sh              # alembic upgrade head → uvicorn
```

---

## Running Locally

```bash
# Start PostgreSQL + API
docker-compose up -d

# Check health
curl http://localhost:8000/health
# → {"status": "ok"}

# View interactive API docs
open http://localhost:8000/docs
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | `postgresql+asyncpg://user:pass@host:5432/db` |
| `SECRET_KEY` | JWT signing secret (use `openssl rand -hex 32` for production) |
| `ALGORITHM` | `HS256` |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `43200` = 30 days |

## Migrations

```bash
alembic upgrade head      # Apply all
alembic downgrade -1      # Roll back one
alembic revision --autogenerate -m "description"  # Generate new migration
```

## Key Endpoints

### POST /sync/push

Accepts a batch of typed operations. Operations within the same batch can reference each other via `client_local_id` — the server resolves references and returns remoteId mappings.

Supported op types: `folder_create`, `folder_update`, `folder_delete`, `team_create`, `team_update`, `team_delete`, `instance_create`, `instance_update`, `slot_upsert`, `slot_delete`.

### GET /sync/pull?since=\<ISO8601\>

Returns all entities belonging to the authenticated user that were updated after `since`. Includes soft-deleted entities (so clients can hard-delete locally).

### GET /ps-data/version

Returns SHA-256 hashes of the bundled PS data files. The Flutter app compares these against its cached versions and downloads updates via `/ps-data/file/:name` if they differ.
