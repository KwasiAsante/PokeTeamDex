import json
import os

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

router = APIRouter(prefix="/ps-data", tags=["ps-data"])

# PS_DATA_DIR env var points to shared/ps_data/ at the project root.
# Default "../shared/ps_data" works when running uvicorn from the backend/ directory.
# In Docker the env var is set explicitly to /app/shared/ps_data via docker-compose.
_PS_DATA_DIR = os.environ.get("PS_DATA_DIR", "../shared/ps_data")
_VERSION_FILE = os.path.join(_PS_DATA_DIR, "version.json")

# Filenames the Flutter app may request via GET /ps-data/file/:name — must match
# the version manifest keys in scripts/sync_ps_data.py and the fileMap in
# FormatService._checkForUpdates.
_ALLOWED_FILES = {
    "learnset_1.json",
    "learnset_2.json",
    "learnset_3.json",
    "learnset_4.json",
    "learnset_5.json",
    "learnset_6.json",
    "learnset_7.json",
    "learnset_8.json",
    "learnset_9.json",
    "moves.json",
    "items.json",
    "abilities.json",
}


@router.get("/version", summary="Get PS data version manifest")
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


@router.get("/file/{filename}", summary="Download a PS data file")
async def get_ps_data_file(filename: str) -> FileResponse:
    """
    Serves a single PS data JSON file so the Flutter app can refresh its cache
    when /ps-data/version reports a changed sha. Restricted to the known set of
    files scripts/sync_ps_data.py publishes — `filename` is matched against an
    explicit allow-list, so it can never escape the data directory.
    """
    if filename not in _ALLOWED_FILES:
        raise HTTPException(status_code=404, detail="Unknown PS data file.")
    path = os.path.join(_PS_DATA_DIR, filename)
    if not os.path.exists(path):
        raise HTTPException(
            status_code=404,
            detail=f"{filename} not found. Run scripts/sync_ps_data.py.",
        )
    return FileResponse(path, media_type="application/json")
