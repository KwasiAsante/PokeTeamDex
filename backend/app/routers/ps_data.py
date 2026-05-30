import json
import os

from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/ps-data", tags=["ps-data"])

_VERSION_FILE = os.path.join(
    os.path.dirname(__file__), "..", "static", "ps_data_version.json"
)


@router.get("/version")
async def get_ps_data_version() -> dict:
    """
    Returns the version manifest for the bundled PS data assets.
    The Flutter app polls this to decide whether to refresh its local cache.
    Updated automatically by scripts/sync_ps_data.py.
    """
    if not os.path.exists(_VERSION_FILE):
        raise HTTPException(
            status_code=404,
            detail="PS data version file not found. Run scripts/sync_ps_data.py.",
        )
    with open(_VERSION_FILE, encoding="utf-8") as f:
        return json.load(f)
