import json
import os

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

router = APIRouter(prefix="/ps-data", tags=["ps-data"])

_STATIC_DIR = os.path.join(os.path.dirname(__file__), "..", "static")
_VERSION_FILE = os.path.join(_STATIC_DIR, "ps_data_version.json")

# Filenames the Flutter app may request via GET /ps-data/file/:name — must match
# the `served_files` list in scripts/sync_ps_data.py (which publishes them here)
# and the `fileMap` in FormatService._checkForUpdates.
_ALLOWED_FILES = {
    "learnsets.json",
    "moves.json",
    "items.json",
    "abilities.json",
    "event_learnsets.json",
}


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


@router.get("/file/{filename}")
async def get_ps_data_file(filename: str) -> FileResponse:
    """
    Serves a single PS data JSON file so the Flutter app can refresh its cache
    when /ps-data/version reports a changed sha. Restricted to the known set of
    files scripts/sync_ps_data.py publishes — `filename` is matched against an
    explicit allow-list, so it can never escape the static directory.
    """
    if filename not in _ALLOWED_FILES:
        raise HTTPException(status_code=404, detail="Unknown PS data file.")
    path = os.path.join(_STATIC_DIR, filename)
    if not os.path.exists(path):
        raise HTTPException(
            status_code=404,
            detail=f"{filename} not found. Run scripts/sync_ps_data.py.",
        )
    return FileResponse(path, media_type="application/json")
