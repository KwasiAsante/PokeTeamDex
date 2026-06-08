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
    format_label: str | None
    is_deleted: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── Instance ──────────────────────────────────────────────────────────────────

class InstanceResponse(BaseModel):
    id: int
    user_id: int
    pokemon_id: int
    parent_instance_id: int | None
    nickname_aliases: str | None
    inherited_ribbons: str | None
    is_deleted: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ── Slot ──────────────────────────────────────────────────────────────────────

class SlotUpsert(BaseModel):
    slot: int
    pokemon_id: int
    nickname: str | None = None
    instance_id: int | None = None
    form_name: str | None = None
    level: int | None = None
    gender: str | None = None
    is_shiny: bool = False
    friendship: int | None = None
    ability_name: str | None = None
    nature_name: str | None = None
    held_item_name: str | None = None
    move1: str | None = None
    move2: str | None = None
    move3: str | None = None
    move4: str | None = None
    ev_hp: int | None = None
    ev_atk: int | None = None
    ev_def: int | None = None
    ev_spa: int | None = None
    ev_spd: int | None = None
    ev_spe: int | None = None
    iv_hp: int | None = None
    iv_atk: int | None = None
    iv_def: int | None = None
    iv_spa: int | None = None
    iv_spd: int | None = None
    iv_spe: int | None = None
    ribbons: str | None = None
    is_mega_evolved: bool = False
    has_gigantamax: bool = False
    gigantamax_enabled: bool = False
    is_alpha: bool = False
    tera_type: str | None = None
    contest_cool: int | None = None
    contest_beautiful: int | None = None
    contest_cute: int | None = None
    contest_clever: int | None = None
    contest_tough: int | None = None
    contest_sheen: int | None = None


class SlotResponse(BaseModel):
    id: int
    team_id: int
    slot: int
    pokemon_id: int
    nickname: str | None
    instance_id: int | None
    form_name: str | None
    level: int | None
    gender: str | None
    is_shiny: bool
    friendship: int | None
    ability_name: str | None
    nature_name: str | None
    held_item_name: str | None
    move1: str | None
    move2: str | None
    move3: str | None
    move4: str | None
    ev_hp: int | None
    ev_atk: int | None
    ev_def: int | None
    ev_spa: int | None
    ev_spd: int | None
    ev_spe: int | None
    iv_hp: int | None
    iv_atk: int | None
    iv_def: int | None
    iv_spa: int | None
    iv_spd: int | None
    iv_spe: int | None
    ribbons: str | None
    is_mega_evolved: bool
    has_gigantamax: bool
    gigantamax_enabled: bool
    is_alpha: bool
    tera_type: str | None
    contest_cool: int | None
    contest_beautiful: int | None
    contest_cute: int | None
    contest_clever: int | None
    contest_tough: int | None
    contest_sheen: int | None
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
    format_label: str | None = None
    # Exactly one of these two should be set when a folder is involved.
    # folder_remote_id: folder already synced — server ID known.
    # folder_client_local_id: folder being created in the same batch.
    folder_remote_id: int | None = None
    folder_client_local_id: int | None = None


class TeamUpdateOp(BaseModel):
    type: Literal["team_update"]
    remote_id: int
    name: str
    format_label: str | None = None
    update_format_label: bool = False
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


class InstanceUpdate(BaseModel):
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
    # Full slot config
    form_name: str | None = None
    level: int | None = None
    gender: str | None = None
    is_shiny: bool = False
    friendship: int | None = None
    ability_name: str | None = None
    nature_name: str | None = None
    held_item_name: str | None = None
    move1: str | None = None
    move2: str | None = None
    move3: str | None = None
    move4: str | None = None
    ev_hp: int | None = None
    ev_atk: int | None = None
    ev_def: int | None = None
    ev_spa: int | None = None
    ev_spd: int | None = None
    ev_spe: int | None = None
    iv_hp: int | None = None
    iv_atk: int | None = None
    iv_def: int | None = None
    iv_spa: int | None = None
    iv_spd: int | None = None
    iv_spe: int | None = None
    ribbons: str | None = None
    is_mega_evolved: bool = False
    has_gigantamax: bool = False
    gigantamax_enabled: bool = False
    is_alpha: bool = False
    tera_type: str | None = None
    contest_cool: int | None = None
    contest_beautiful: int | None = None
    contest_cute: int | None = None
    contest_clever: int | None = None
    contest_tough: int | None = None
    contest_sheen: int | None = None


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
