from datetime import datetime

from pydantic import BaseModel


# ── Folder ────────────────────────────────────────────────────────────────────

class FolderCreate(BaseModel):
    name: str


class FolderUpdate(BaseModel):
    name: str


class FolderResponse(BaseModel):
    id: int
    name: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── Team ──────────────────────────────────────────────────────────────────────

class TeamCreate(BaseModel):
    name: str
    folder_id: int | None = None


class TeamUpdate(BaseModel):
    name: str


class TeamResponse(BaseModel):
    id: int
    user_id: int
    folder_id: int | None
    name: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── Slot ──────────────────────────────────────────────────────────────────────

class SlotUpsert(BaseModel):
    slot: int
    pokemon_id: int
    nickname: str | None = None


class SlotResponse(BaseModel):
    id: int
    team_id: int
    slot: int
    pokemon_id: int
    nickname: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── Sync ──────────────────────────────────────────────────────────────────────

class SyncPullResponse(BaseModel):
    folders: list[FolderResponse]
    teams: list[TeamResponse]
    slots: list[SlotResponse]
