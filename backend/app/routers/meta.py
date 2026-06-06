from fastapi import APIRouter, HTTPException

from app.core.deps import CurrentUser
from app.core.logging import get_logs_token

router = APIRouter(prefix="/meta", tags=["meta"])


@router.get("/logs-token")
async def logs_token(current_user: CurrentUser) -> dict:
    """Return the cached UtilityBillsServer session token.

    Flutter calls this after PokeTeamDex login so it can include an
    Authorization header when pushing log lines to /logs/device.
    Returns 503 if the backend has not yet authenticated with UtilityBillsServer
    (e.g. LOGS_API_EMAIL / LOGS_API_PASSWORD not configured).
    """
    token = get_logs_token()
    if token is None:
        raise HTTPException(status_code=503, detail="Logs token not available")
    return {"token": token}
