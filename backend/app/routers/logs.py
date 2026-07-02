from fastapi import APIRouter, Header, HTTPException, Query, Request

from app.core.config import settings
from app.core.deps import CurrentUser
from app.core.loki import push_async

router = APIRouter(prefix="/logs", tags=["logs"])


@router.post("/device", summary="Forward device logs to Loki")
async def device_logs(
    request: Request,
    current_user: CurrentUser,
    app_name: str = Query(default="poketeamdex"),
    x_device_id: str = Header(...),
    x_level: str = Header(default="UNKNOWN"),
) -> dict:
    """Accept a JSON array of log lines from a Flutter device and push to Loki."""
    if len(x_device_id) > 64:
        raise HTTPException(status_code=400, detail="x-device-id must be 64 characters or fewer")

    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Body must be a JSON array of strings")

    if not isinstance(body, list) or any(not isinstance(s, str) for s in body):
        raise HTTPException(status_code=400, detail="Body must be a JSON array of strings")

    if body:
        await push_async(
            loki_url=settings.loki_url,
            labels={
                "job": "device",
                "device_id": x_device_id,
                "level": x_level.upper(),
                "app": app_name,
            },
            lines=body,
        )

    return {"message": "ok"}
