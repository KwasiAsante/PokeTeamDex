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
│   │   ├── ps_data.py    # GET /ps-data/version, GET /ps-data/file/:name
│   │   ├── admin.py      # POST /admin/notify-update, GET /admin/version, DELETE /admin/cache/pokemon, DELETE /admin/cache/catalog
│   │   ├── logs.py       # POST /logs/device — forwards Flutter device logs to Loki
│   │   ├── pokemon.py    # GET /pokemon/{id}/resolved, /varieties, /forms, /smogon, /moves, /flavor-text
│   │   └── catalog.py    # GET /moves, /items, /abilities (list + single-entry)
│   ├── models/
│   │   ├── user.py       # User ORM model
│   │   ├── team.py       # Team, TeamSlot, TeamFolder, PokemonInstance ORM models
│   │   └── pokemon_resolved.py  # PokemonResolved cache table
│   ├── schemas/
│   │   ├── auth.py       # RegisterRequest, LoginRequest, TokenResponse
│   │   ├── team.py       # SyncOp variants, SyncPushRequest, SyncPushResponse,
│   │   │                 # SyncPullResponse, TeamResponse, SlotResponse
│   │   ├── pokemon_resolved.py  # PokemonResolvedResponse, VarietiesResponse, FormsResponse,
│   │   │   # SmogonResponse, MovesResponse, FlavorTextResponse, SmogonSet, EventMove, SpriteUrls
│   │   └── catalog.py    # MoveEntry, ItemEntry, AbilityEntry + their paginated list responses
│   ├── services/
│   │   ├── pokemon_resolver.py  # PokemonResolverService — PS data loader + aggregation logic
│   │   ├── catalog_service.py   # CatalogService — moves/items/abilities PokéAPI+PS consolidation
│   │   └── learnset_service.py  # LearnsetService — in-memory per-gen learnset index from shared/ps_data/
│   ├── static/           # Stale pre-migration snapshot — PS data now lives in shared/ps_data/ (project root); nothing reads this directory anymore
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
│       ├── 0008_add_sort_order_and_is_box.py
│       ├── 0009_add_pokemon_resolved.py
│       └── 0010_add_catalog_cache.py
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

### GET /pokemon/{name_or_id}/resolved?gen=N&includes=varieties,forms,smogon

Aggregates PokéAPI + Showdown event learnsets + Smogon competitive data for one Pokémon.

- `name_or_id` — PokéAPI **pokemon** name or ID (not species). Form variants have their own names/IDs (e.g. Rotom-Wash = `rotom-wash` / 10009).
- `gen` — generation to resolve for (1–9). When omitted, types/base stats use gen 9 accuracy and `game_front` uses the plain PokéAPI front sprite instead of a versioned game directory.
- `includes` — comma-separated list of fields to expand inline: `varieties`, `forms`, `smogon`. Omitted by default to keep the response slim and avoid extra API calls; use the dedicated sub-endpoints below instead, or pass `includes` when you need everything in one round trip.

Results are cached in `pokemon_resolved` (PostgreSQL, 7-day TTL). `smogon_analyses` is `null` while the background Smogon preload is in progress (~15 s after cold start) or when the Pokémon has no data in any loaded competitive format.

No authentication required.

### GET /pokemon/varieties/{name_or_id}?gen=N

Returns all non-default varieties for a species (Mega evolutions, regional forms, Gigantamax, battle-state forms) with fully expanded types/base_stats/abilities/sprite_urls. Cached alongside the full resolved data.

### GET /pokemon/forms/{name_or_id}?gen=N

Returns all cosmetic form-entries for a Pokémon (Unown letters, Shellos East/West, Burmy cloaks, Alcremie decorations) with full sprite data per form. These share types/stats/abilities with the base — only the visuals differ.

### GET /pokemon/smogon/{name_or_id}?gen=N

Returns Smogon competitive analyses. Omit `gen` for every format across every generation; pass `gen` (1–9) to scope to that generation's formats (e.g. `gen=5` → `gen5ou`, `gen5uu`, `gen5ubers`, ...).

### GET /pokemon/moves/{name_or_id}?gen=N

Returns the moves list for a Pokémon. Without `gen`, all version groups from PokéAPI are returned, plus Showdown learnset supplement moves (event/egg/tutor moves absent from PokéAPI) for every generation. With `gen=N`, moves are filtered to that generation's version groups, with the same PS supplement applied. Served from the PostgreSQL cache when available; triggers a full resolve on miss.

### GET /pokemon/flavor-text/{name_or_id}?lang=en

Returns Pokédex flavor text entries. Omit `lang` for every language.

### POST /admin/notify-update

Called by `release.yml`'s `notify-backend` job after a tagged release finishes building. Requires `X-Notify-Secret` header (`NOTIFY_UPDATE_SECRET`). Updates the in-memory "latest version" the app's update checker reads via `GET /admin/version`, and sends an FCM push to the `app-updates` topic if Firebase is configured.

### GET /moves, GET /items, GET /abilities

Paginated catalogs (`page`/`page_size`, default 50/max 200), consolidated from PokéAPI + Pokémon Showdown. The Pokémon Showdown data (`shared/ps_data/{moves,items,abilities}.json`) defines the canonical set of entries — PokéAPI's own full item list also includes key items, mail, etc. that aren't relevant to a team builder, so it's used only to enrich PS-known entries, not to enumerate them.

A one-time background task fetches PokéAPI detail for every entry at startup (same idea as the Smogon preload above). List endpoints return `503` for a short window after a cold start while this is in progress. Single-entry endpoints (`GET /moves/{id_or_name}`, `/items/{id_or_name}`, `/abilities/{id_or_name}`) are always available — they fall back to a live PokéAPI fetch when an entry isn't in the in-memory catalog yet.

- `GET /moves?gen=9&damage_class=physical&is_z_move=false` — filters: `gen`, `damage_class` (physical/special/status), `contest_type`, `is_z_move`, `is_max_move`.
- `GET /items?category=mega-stones&is_berry=true` — filters: `gen`, `category` (PokéAPI item-category name), `is_mega_stone`, `is_z_crystal`, `is_berry`, `is_plate`, `is_memory`.
- `GET /abilities?pokemon=pikachu` — with `pokemon` (name or Pokédex species number), ignores pagination/`gen` and returns that Pokémon's abilities directly with `slot` (1, 2, or 3=hidden) populated. Without it, paginated by `gen`.

No authentication required. Backed by the `catalog_cache` PostgreSQL table (`kind`, `name`, `pokeapi_id`, `data` JSONB, `fetched_at`, `ttl_days` — 7-day TTL, same pattern as `pokemon_resolved`): on startup `CatalogService.load_from_db()` populates the in-memory maps from any fresh cached rows before falling back to a full PokéAPI+PS preload, and `preload_and_persist()` batch-upserts newly resolved entries back to the table.

### DELETE /admin/cache/pokemon?ids=6&ids=10034&all=false

Evicts rows from the `pokemon_resolved` cache table by ID (repeatable `ids` query param) or entirely (`?all=true`). Requires `X-Admin-Secret` header. Use after fixing a sprite/registry override so the fix is visible immediately instead of waiting out the 7-day TTL.

### DELETE /admin/cache/catalog?kinds=move&kinds=item&all=false

Evicts rows from the `catalog_cache` table by kind (repeatable `kinds` query param: `move`/`item`/`ability`) or entirely (`?all=true`); resets the matching in-memory state and kicks off a background re-preload. Requires `X-Admin-Secret` header. Use after running `sync_ps_data.py` with updated move/item/ability data, or after fixing a catalog-affecting bug (e.g. gen-derivation logic), so it's reflected immediately instead of waiting out the 7-day TTL.
