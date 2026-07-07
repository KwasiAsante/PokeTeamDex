import asyncio
import logging
import time

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import settings
from app.core.logging import setup_logging
from app.database import AsyncSessionLocal
from app.routers import admin, auth, folders, instances, logs, ps_data, sync, teams
from app.routers.catalog import router as catalog_router
from app.routers.pokemon import router as pokemon_router
from app.routers.teams import slots_router
from app.services.catalog_service import catalog_service
from app.services.pokemon_resolver import pokemon_resolver_service

setup_logging(settings.loki_url)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="PokeTeamDex API",
    version="1.0.0",
    description=(
        "Backend for the PokeTeamDex Flutter app.\n\n"
        "Provides Pokémon data aggregation (PokéAPI + Pokémon Showdown + Smogon), "
        "team/folder/slot CRUD, cross-device sync, and PS data distribution.\n\n"
        "**Authentication**: JWT bearer tokens — obtain one via `POST /auth/login` "
        "or `POST /auth/register`, then pass `Authorization: Bearer <token>` on "
        "all protected endpoints."
    ),
    openapi_tags=[
        {"name": "health", "description": "Liveness probe — no auth required."},
        {"name": "auth", "description": "Register, log in, and identify the current user."},
        {"name": "teams", "description": "Create and manage Pokémon teams and their metadata."},
        {"name": "slots", "description": "Read or write individual Pokémon slots within a team."},
        {"name": "folders", "description": "Organise teams into named folders."},
        {
            "name": "instances",
            "description": (
                "Pokémon instances — individual caught/bred Pokémon that carry "
                "lineage, nickname aliases, and ribbon history across teams."
            ),
        },
        {
            "name": "sync",
            "description": (
                "Bidirectional offline-first sync. Pull returns the full server state "
                "(optionally delta-filtered by `since`). Push applies a batch of typed "
                "ops (create/update/delete) atomically and returns server-assigned IDs."
            ),
        },
        {
            "name": "pokemon",
            "description": (
                "Aggregate Pokémon data from PokéAPI, Pokémon Showdown, and Smogon "
                "with 7-day PostgreSQL caching. Covers resolved details, varieties, "
                "cosmetic forms, competitive analyses, moves, and Pokédex flavor text."
            ),
        },
        {
            "name": "ps-data",
            "description": (
                "Serve versioned Pokémon Showdown data files (moves, learnsets, items, "
                "abilities) so the Flutter client can refresh its local cache on demand."
            ),
        },
        {
            "name": "catalog",
            "description": (
                "Standalone move/item/ability catalog — paginated lists and single-entry "
                "lookups, consolidated from PokéAPI + Pokémon Showdown. Backed by a "
                "7-day PostgreSQL cache; loaded from DB on warm starts to eliminate the "
                "startup 503 window."
            ),
        },
        {
            "name": "logs",
            "description": "Ingest structured log lines from Flutter devices and forward to Loki.",
        },
        {
            "name": "admin",
            "description": (
                "Internal admin operations. All endpoints require either "
                "`X-Notify-Secret` or `X-Admin-Secret` header matching the server "
                "secret — not authenticated via JWT."
            ),
        },
    ],
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
    openapi_url="/openapi.json" if settings.debug else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

app.include_router(auth.router)
app.include_router(folders.router)
app.include_router(instances.router)
app.include_router(teams.router)
app.include_router(slots_router)
app.include_router(sync.router)
app.include_router(ps_data.router)
app.include_router(admin.router)
app.include_router(logs.router)
app.include_router(pokemon_router)
app.include_router(catalog_router)


@app.middleware("http")
async def _log_requests(request: Request, call_next):
    # Skip health-check and CORS preflight to keep logs clean.
    if request.url.path == "/health" or request.method == "OPTIONS":
        return await call_next(request)
    start = time.perf_counter()
    response = await call_next(request)
    ms = (time.perf_counter() - start) * 1000
    level = logging.WARNING if response.status_code >= 400 else logging.INFO
    logger.log(level, "%s %s → %d (%.0fms)", request.method, request.url.path, response.status_code, ms)
    return response


@app.on_event("startup")
async def _on_startup():
    logger.info("PokeTeamDex backend started (version=%s)", settings.app_version)
    pokemon_resolver_service.load_ps_data()
    asyncio.create_task(pokemon_resolver_service.load_smogon_data())
    catalog_service.load_ps_data()
    async with AsyncSessionLocal() as db:
        loaded = await catalog_service.load_from_db(db)
    if not loaded:
        asyncio.create_task(catalog_service.preload_and_persist())


@app.on_event("shutdown")
async def _on_shutdown():
    logger.info("PokeTeamDex backend shutting down")


# Ensure CORS headers are present on all error responses.
# Starlette's CORSMiddleware sometimes omits them on auth errors (403/401)
# raised before the route handler runs, which causes browsers to report
# a misleading "connection error" instead of the actual HTTP status.
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Allow-Methods": "*",
        },
    )


@app.get("/health", summary="Health check", tags=["health"])
async def health() -> dict:
    """Returns 200 OK when the server is up. Used by load balancers and uptime monitors."""
    return {"status": "ok"}
