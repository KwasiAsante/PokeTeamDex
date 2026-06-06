import logging
import time

import httpx
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import settings
from app.core.logging import set_logs_token, setup_logging
from app.routers import admin, auth, folders, instances, meta, ps_data, sync, teams
from app.routers.teams import slots_router

setup_logging(settings.logs_api_base_url)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="PokeTeamDex API",
    version="1.0.0",
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
app.include_router(meta.router)


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


async def _logs_server_authenticate() -> str | None:
    """Register (ignore 409) then login to UtilityBillsServer; return the token."""
    if not settings.logs_api_email or not settings.logs_api_password:
        return None
    base = settings.logs_api_base_url.rstrip("/")
    creds = {"email": settings.logs_api_email, "password": settings.logs_api_password}
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            # Register — ignore 409 (account already exists)
            await client.post(f"{base}/auth/register", json=creds)
            # Login
            r = await client.post(
                f"{base}/auth/login",
                json={**creds, "deviceName": "poketeamdex-api"},
            )
            if r.status_code == 200:
                return r.json().get("token")
    except Exception as exc:
        logger.warning("Could not authenticate with UtilityBillsServer: %s", exc)
    return None


@app.on_event("startup")
async def _on_startup():
    logger.info("PokeTeamDex backend started (version=%s)", settings.app_version)
    token = await _logs_server_authenticate()
    if token:
        set_logs_token(token)
        logger.info("Authenticated with UtilityBillsServer for log forwarding")


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


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
