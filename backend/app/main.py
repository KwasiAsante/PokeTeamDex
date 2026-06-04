from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import settings
from app.routers import admin, auth, folders, instances, ps_data, sync, teams
from app.routers.teams import slots_router

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
