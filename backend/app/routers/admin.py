import asyncio
import json
import logging
from typing import Any

from fastapi import APIRouter, Header, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import delete

from app.core.config import settings
from app.core.deps import DB
from app.models.catalog_cache import CatalogCache
from app.models.pokemon_resolved import PokemonResolved

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["admin"])

# In-memory store for the latest release info (persists for process lifetime).
# On restart, the version falls back to the env-configured APP_VERSION.
_latest_version: str = settings.app_version
_latest_release_url: str = ""


class NotifyUpdateRequest(BaseModel):
    version: str
    release_url: str


def _require_admin_secret(secret: str) -> None:
    if not settings.notify_update_secret or secret != settings.notify_update_secret:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid secret")


def _get_fcm_app() -> Any | None:
    """Lazily initialise Firebase Admin SDK. Returns None if unconfigured."""
    try:
        import firebase_admin
        from firebase_admin import credentials

        sa_json = settings.firebase_service_account_json.strip()
        if not sa_json or sa_json == "{}":
            return None

        # Return existing app if already initialised.
        try:
            return firebase_admin.get_app()
        except ValueError:
            pass

        sa_dict = json.loads(sa_json)
        cred = credentials.Certificate(sa_dict)
        return firebase_admin.initialize_app(cred)
    except Exception as exc:
        logger.warning("Firebase Admin SDK not available: %s", exc)
        return None


@router.post(
    "/notify-update",
    status_code=status.HTTP_200_OK,
    summary="Notify new app release",
)
async def notify_update(
    body: NotifyUpdateRequest,
    x_notify_secret: str = Header(default=""),
) -> dict:
    """
    Called by CI after a new GitHub release is published.

    Updates the in-memory latest version and release URL, then sends an FCM
    push notification to the `app-updates` topic so devices are alerted
    immediately. Requires `X-Notify-Secret` header.
    """
    _require_admin_secret(x_notify_secret)

    global _latest_version, _latest_release_url
    _latest_version = body.version.lstrip("v")
    _latest_release_url = body.release_url

    _send_fcm_notification(body.version, body.release_url)

    return {"status": "ok", "version": _latest_version}


@router.get("/version", summary="Get latest app version")
async def get_version() -> dict:
    """
    Returns the most-recently-notified app version and its release URL.

    Polled by the Flutter app at startup to decide whether to prompt the
    user to update. Falls back to the server's `APP_VERSION` env var
    until `POST /admin/notify-update` is called for the first time.
    """
    return {
        "latest_version": _latest_version,
        "release_url": _latest_release_url,
    }


@router.delete("/cache/catalog", status_code=status.HTTP_200_OK, summary="Evict catalog cache entries")
async def clear_catalog_cache(
    db: DB,
    kinds: list[str] = Query(
        default=[],
        description="Catalog kinds to evict: 'move', 'item', 'ability' (repeatable).",
    ),
    clear_all: bool = Query(default=False, alias="all", description="Evict all catalog entries."),
    x_admin_secret: str = Header(default=""),
) -> dict:
    """Evict rows from the catalog_cache table and reset in-memory state.

    After running sync_ps_data.py with updated move/item/ability data, evict
    the affected kinds here so the server reloads fresh data from PokéAPI
    rather than serving the stale DB cache until TTL expires.
    A background re-preload starts automatically after eviction.
    """
    from app.services.catalog_service import catalog_service

    _require_admin_secret(x_admin_secret)
    if not kinds and not clear_all:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide ?kind=move (repeatable) or ?all=true",
        )

    stmt = delete(CatalogCache)
    if kinds:
        stmt = stmt.where(CatalogCache.kind.in_(kinds))
    result = await db.execute(stmt)
    await db.commit()

    catalog_service.evict(kinds if kinds else None)
    asyncio.create_task(catalog_service.preload_and_persist())

    return {"status": "ok", "deleted": result.rowcount}


@router.delete("/cache/pokemon", status_code=status.HTTP_200_OK, summary="Evict Pokémon cache entries")
async def clear_pokemon_cache(
    db: DB,
    ids: list[int] = Query(default=[], description="Pokémon IDs to evict (species or variety IDs)."),
    clear_all: bool = Query(default=False, alias="all", description="Evict every cached entry."),
    x_admin_secret: str = Header(default=""),
) -> dict:
    """Evict rows from the pokemon_resolved cache table.

    Resolved data (incl. nested varieties) is cached for ttl_days=7. After
    fixing a sprite/registry override, the affected pokemon_id(s) must be
    evicted here for the fix to show up before the TTL expires.
    """
    _require_admin_secret(x_admin_secret)
    if not ids and not clear_all:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide ?ids=<id> (repeatable) or ?all=true",
        )

    stmt = delete(PokemonResolved)
    if ids:
        stmt = stmt.where(PokemonResolved.pokemon_id.in_(ids))
    result = await db.execute(stmt)
    await db.commit()
    return {"status": "ok", "deleted": result.rowcount}


def _send_fcm_notification(version: str, release_url: str) -> None:
    app = _get_fcm_app()
    if app is None:
        logger.info("FCM not configured — skipping push notification")
        return

    try:
        from firebase_admin import messaging

        message = messaging.Message(
            topic="app-updates",
            data={
                "version": version,
                "release_url": release_url,
                "type": "app_update",
            },
            notification=messaging.Notification(
                title=f"PokeTeamDex {version} available",
                body="A new update is ready. Tap to download.",
            ),
        )
        response = messaging.send(message)
        logger.info("FCM notification sent: %s", response)
    except Exception as exc:
        logger.error("FCM send failed: %s", exc)
