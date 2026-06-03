from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, Field


# ── Folder ────────────────────────────────────────────────────────────────────

class FolderCreate(BaseModel):
    name: str


class FolderUpdate(BaseModel):
    name: str


class FolderResponse(BaseModel):
    id: int
    name: str
    is_deleted: bool
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
    is_deleted: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── Instance ──────────────────────────────────────────────────────────────────

class InstanceResponse(BaseModel):
    id: int
    pokemon_id: int
    parent_instance_id: int | None
    nickname_aliases: str | None
    inherited_ribbons: str | None
    is_deleted: bool
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
    instance_id: int | None
    is_deleted: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── Sync pull ─────────────────────────────────────────────────────────────────

class SyncPullResponse(BaseModel):
    folders: list[FolderResponse]
    teams: list[TeamResponse]
    instances: list[InstanceResponse]
    slots: list[SlotResponse]


# ── Sync push — discriminated op union ────────────────────────────────────────

class FolderCreateOp(BaseModel):
    type: Literal["folder_create"]
    client_local_id: int
    name: str


class FolderUpdateOp(BaseModel):
    type: Literal["folder_update"]
    remote_id: int
    name: str


class FolderDeleteOp(BaseModel):
    type: Literal["folder_delete"]
    remote_id: int


class TeamCreateOp(BaseModel):
    type: Literal["team_create"]
    client_local_id: int
    name: str
    # Exactly one of these two should be set when a folder is involved.
    # folder_remote_id: folder already synced — server ID known.
    # folder_client_local_id: folder being created in the same batch.
    folder_remote_id: int | None = None
    folder_client_local_id: int | None = None


class TeamUpdateOp(BaseModel):
    type: Literal["team_update"]
    remote_id: int
    name: str
    # Folder change — only applied when update_folder is True so that a
    # plain rename (which has no folder info) doesn't accidentally clear it.
    update_folder: bool = False
    folder_remote_id: int | None = None
    folder_client_local_id: int | None = None


class TeamDeleteOp(BaseModel):
    type: Literal["team_delete"]
    remote_id: int


class InstanceCreateOp(BaseModel):
    type: Literal["instance_create"]
    client_local_id: int
    pokemon_id: int
    # Exactly one of these when a parent exists.
    parent_instance_remote_id: int | None = None
    parent_instance_client_local_id: int | None = None
    nickname_aliases: str | None = None
    inherited_ribbons: str | None = None


class InstanceUpdateOp(BaseModel):
    type: Literal["instance_update"]
    remote_id: int
    nickname_aliases: str | None = None
    inherited_ribbons: str | None = None


class SlotUpsertOp(BaseModel):
    type: Literal["slot_upsert"]
    # Exactly one of these two should be set.
    team_remote_id: int | None = None
    team_client_local_id: int | None = None
    slot: int
    pokemon_id: int
    nickname: str | None = None
    # Optional instance link.
    instance_remote_id: int | None = None
    instance_client_local_id: int | None = None


class SlotDeleteOp(BaseModel):
    type: Literal["slot_delete"]
    team_remote_id: int | None = None
    team_client_local_id: int | None = None
    slot: int


SyncOp = Annotated[
    FolderCreateOp | FolderUpdateOp | FolderDeleteOp
    | TeamCreateOp | TeamUpdateOp | TeamDeleteOp
    | InstanceCreateOp | InstanceUpdateOp
    | SlotUpsertOp | SlotDeleteOp,
    Field(discriminator="type"),
]


class SyncPushRequest(BaseModel):
    ops: list[SyncOp]


class SyncPushCreated(BaseModel):
    entity_type: str
    client_local_id: int
    remote_id: int


class SyncPushResponse(BaseModel):
    created: list[SyncPushCreated]
