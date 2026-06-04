import json
import logging
from typing import Any

from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel

from app.core.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["admin"])

# In-memory store for the latest release info (persists for process lifetime).
# On restart, the version falls back to the env-configured APP_VERSION.
_latest_version: str = settings.app_version
_latest_release_url: str = ""


class NotifyUpdateRequest(BaseModel):
    version: str
    release_url: str


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


@router.post("/notify-update", status_code=status.HTTP_200_OK)
async def notify_update(
    body: NotifyUpdateRequest,
    x_notify_secret: str = Header(default=""),
) -> dict:
    if not settings.notify_update_secret or x_notify_secret != settings.notify_update_secret:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid secret")

    global _latest_version, _latest_release_url
    _latest_version = body.version.lstrip("v")
    _latest_release_url = body.release_url

    _send_fcm_notification(body.version, body.release_url)

    return {"status": "ok", "version": _latest_version}


@router.get("/version")
async def get_version() -> dict:
    return {
        "latest_version": _latest_version,
        "release_url": _latest_release_url,
    }


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
