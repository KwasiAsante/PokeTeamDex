from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, Field


# ── Folder ────────────────────────────────────────────────────────────────────

class FolderCreate(BaseModel):
    name: str = Field(..., description="Display name of the folder.")


class FolderUpdate(BaseModel):
    name: str = Field(..., description="New display name for the folder.")


class FolderResponse(BaseModel):
    id: int = Field(..., description="Database ID of the folder.")
    name: str = Field(..., description="Display name.")
    sort_order: int = Field(..., description="Position among sibling folders (ascending).")
    is_deleted: bool = Field(..., description="True if soft-deleted. Pull responses include deleted records so clients can purge them locally.")
    created_at: datetime = Field(..., description="UTC timestamp of creation.")
    updated_at: datetime = Field(..., description="UTC timestamp of last modification — used as the sync delta cursor.")

    model_config = {"from_attributes": True}


# ── Team ──────────────────────────────────────────────────────────────────────

class TeamCreate(BaseModel):
    name: str = Field(..., description="Display name of the team.")
    folder_id: int | None = Field(None, description="ID of the folder to place the team in. Null means ungrouped.")


class TeamUpdate(BaseModel):
    name: str = Field(..., description="New display name for the team.")


class TeamResponse(BaseModel):
    id: int = Field(..., description="Database ID of the team.")
    user_id: int = Field(..., description="ID of the owning user.")
    folder_id: int | None = Field(..., description="Folder this team belongs to, or null if ungrouped.")
    name: str = Field(..., description="Display name.")
    format_label: str | None = Field(..., description="Competitive format label (e.g. 'OU', 'VGC 2024'). Set via sync push.")
    sort_order: int = Field(..., description="Position among teams (ascending).")
    is_box: bool = Field(..., description="True when this entry is used as a storage box rather than a competitive team.")
    is_deleted: bool = Field(..., description="True if soft-deleted.")
    created_at: datetime = Field(..., description="UTC timestamp of creation.")
    updated_at: datetime = Field(..., description="UTC timestamp of last modification.")

    model_config = {"from_attributes": True}


# ── Instance ──────────────────────────────────────────────────────────────────

class InstanceResponse(BaseModel):
    id: int = Field(..., description="Database ID of this Pokémon instance.")
    user_id: int = Field(..., description="ID of the owning user.")
    pokemon_id: int = Field(..., description="PokéAPI variety ID of the Pokémon.")
    parent_instance_id: int | None = Field(..., description="ID of the parent instance (e.g. the pre-evolution this Pokémon was evolved from). Null if no tracked lineage.")
    nickname_aliases: str | None = Field(..., description="JSON-encoded list of nicknames this Pokémon has had across games.")
    inherited_ribbons: str | None = Field(..., description="JSON-encoded list of ribbon IDs inherited from the lineage chain.")
    is_deleted: bool = Field(..., description="True if soft-deleted.")
    created_at: datetime = Field(..., description="UTC timestamp of creation.")
    updated_at: datetime = Field(..., description="UTC timestamp of last modification.")

    model_config = {"from_attributes": True}


# ── Slot ──────────────────────────────────────────────────────────────────────

class SlotUpsert(BaseModel):
    slot: int = Field(..., description="Slot position within the team (1-indexed, typically 1–6).")
    pokemon_id: int = Field(..., description="PokéAPI variety ID of the Pokémon.")
    nickname: str | None = Field(None, description="Custom nickname for this slot entry.")
    instance_id: int | None = Field(None, description="ID of the linked PokémonInstance for lineage tracking. Null for unlinked slots.")
    form_name: str | None = Field(None, description="PokéAPI form name override (e.g. 'mega', 'gmax'). Null uses the variety's default form.")
    level: int | None = Field(None, description="Level (1–100).")
    gender: str | None = Field(None, description="Gender: 'male', 'female', or null for genderless.")
    is_shiny: bool = Field(False, description="True if the Pokémon is shiny.")
    friendship: int | None = Field(None, description="Friendship / happiness value (0–255).")
    ability_name: str | None = Field(None, description="PokéAPI ability slug (e.g. 'blaze', 'solar-power').")
    nature_name: str | None = Field(None, description="PokéAPI nature slug (e.g. 'timid', 'modest').")
    held_item_name: str | None = Field(None, description="PokéAPI item slug for the held item (e.g. 'choice-scarf').")
    move1: str | None = Field(None, description="Move slot 1 — PokéAPI move slug (e.g. 'flamethrower').")
    move2: str | None = Field(None, description="Move slot 2 — PokéAPI move slug.")
    move3: str | None = Field(None, description="Move slot 3 — PokéAPI move slug.")
    move4: str | None = Field(None, description="Move slot 4 — PokéAPI move slug.")
    ev_hp: int | None = Field(None, description="HP effort value (0–252).")
    ev_atk: int | None = Field(None, description="Attack EV (0–252).")
    ev_def: int | None = Field(None, description="Defense EV (0–252).")
    ev_spa: int | None = Field(None, description="Special Attack EV (0–252).")
    ev_spd: int | None = Field(None, description="Special Defense EV (0–252).")
    ev_spe: int | None = Field(None, description="Speed EV (0–252).")
    iv_hp: int | None = Field(None, description="HP individual value (0–31).")
    iv_atk: int | None = Field(None, description="Attack IV (0–31).")
    iv_def: int | None = Field(None, description="Defense IV (0–31).")
    iv_spa: int | None = Field(None, description="Special Attack IV (0–31).")
    iv_spd: int | None = Field(None, description="Special Defense IV (0–31).")
    iv_spe: int | None = Field(None, description="Speed IV (0–31).")
    ribbons: str | None = Field(None, description="JSON-encoded list of ribbon IDs this Pokémon holds.")
    is_mega_evolved: bool = Field(False, description="True if the Pokémon is currently Mega Evolved in this slot.")
    has_gigantamax: bool = Field(False, description="True if this Pokémon has the Gigantamax factor.")
    gigantamax_enabled: bool = Field(False, description="True if Gigantamax is selected for battle.")
    is_alpha: bool = Field(False, description="True if this is an Alpha Pokémon (Legends: Arceus).")
    tera_type: str | None = Field(None, description="Tera type override (e.g. 'fire', 'water'). Null means no Tera type selected.")
    contest_cool: int | None = Field(None, description="Contest Cool stat (0–255).")
    contest_beautiful: int | None = Field(None, description="Contest Beautiful stat (0–255).")
    contest_cute: int | None = Field(None, description="Contest Cute stat (0–255).")
    contest_clever: int | None = Field(None, description="Contest Clever stat (0–255).")
    contest_tough: int | None = Field(None, description="Contest Tough stat (0–255).")
    contest_sheen: int | None = Field(None, description="Contest Sheen stat (0–255).")


class SlotResponse(BaseModel):
    id: int = Field(..., description="Database ID of this slot record.")
    team_id: int = Field(..., description="ID of the team this slot belongs to.")
    slot: int = Field(..., description="Position within the team (1-indexed).")
    pokemon_id: int = Field(..., description="PokéAPI variety ID of the Pokémon.")
    nickname: str | None = Field(..., description="Custom nickname, or null.")
    instance_id: int | None = Field(..., description="Linked PokémonInstance ID, or null.")
    form_name: str | None = Field(..., description="Form name override, or null for the variety default.")
    level: int | None = Field(..., description="Level (1–100), or null if unset.")
    gender: str | None = Field(..., description="'male', 'female', or null for genderless.")
    is_shiny: bool = Field(..., description="True if shiny.")
    friendship: int | None = Field(..., description="Friendship value (0–255), or null.")
    ability_name: str | None = Field(..., description="PokéAPI ability slug, or null.")
    nature_name: str | None = Field(..., description="PokéAPI nature slug, or null.")
    held_item_name: str | None = Field(..., description="PokéAPI held item slug, or null.")
    move1: str | None = Field(..., description="Move slot 1 slug, or null.")
    move2: str | None = Field(..., description="Move slot 2 slug, or null.")
    move3: str | None = Field(..., description="Move slot 3 slug, or null.")
    move4: str | None = Field(..., description="Move slot 4 slug, or null.")
    ev_hp: int | None = Field(..., description="HP EV (0–252), or null.")
    ev_atk: int | None = Field(..., description="Attack EV (0–252), or null.")
    ev_def: int | None = Field(..., description="Defense EV (0–252), or null.")
    ev_spa: int | None = Field(..., description="Special Attack EV (0–252), or null.")
    ev_spd: int | None = Field(..., description="Special Defense EV (0–252), or null.")
    ev_spe: int | None = Field(..., description="Speed EV (0–252), or null.")
    iv_hp: int | None = Field(..., description="HP IV (0–31), or null.")
    iv_atk: int | None = Field(..., description="Attack IV (0–31), or null.")
    iv_def: int | None = Field(..., description="Defense IV (0–31), or null.")
    iv_spa: int | None = Field(..., description="Special Attack IV (0–31), or null.")
    iv_spd: int | None = Field(..., description="Special Defense IV (0–31), or null.")
    iv_spe: int | None = Field(..., description="Speed IV (0–31), or null.")
    ribbons: str | None = Field(..., description="JSON-encoded ribbon ID list, or null.")
    is_mega_evolved: bool = Field(..., description="True if Mega Evolved.")
    has_gigantamax: bool = Field(..., description="True if has Gigantamax factor.")
    gigantamax_enabled: bool = Field(..., description="True if Gigantamax is selected for battle.")
    is_alpha: bool = Field(..., description="True if Alpha (Legends: Arceus).")
    tera_type: str | None = Field(..., description="Tera type override, or null.")
    contest_cool: int | None = Field(..., description="Contest Cool (0–255), or null.")
    contest_beautiful: int | None = Field(..., description="Contest Beautiful (0–255), or null.")
    contest_cute: int | None = Field(..., description="Contest Cute (0–255), or null.")
    contest_clever: int | None = Field(..., description="Contest Clever (0–255), or null.")
    contest_tough: int | None = Field(..., description="Contest Tough (0–255), or null.")
    contest_sheen: int | None = Field(..., description="Contest Sheen (0–255), or null.")
    is_deleted: bool = Field(..., description="True if soft-deleted.")
    created_at: datetime = Field(..., description="UTC timestamp of creation.")
    updated_at: datetime = Field(..., description="UTC timestamp of last modification.")

    model_config = {"from_attributes": True}


# ── Sync pull ─────────────────────────────────────────────────────────────────

class SyncPullResponse(BaseModel):
    folders: list[FolderResponse] = Field(..., description="All (or delta-updated) folders for the user.")
    teams: list[TeamResponse] = Field(..., description="All (or delta-updated) teams for the user.")
    instances: list[InstanceResponse] = Field(..., description="All (or delta-updated) Pokémon instances, ordered by ID so parents always precede children.")
    slots: list[SlotResponse] = Field(..., description="All (or delta-updated) team slots for the user.")


# ── Sync push — discriminated op union ────────────────────────────────────────

class FolderCreateOp(BaseModel):
    type: Literal["folder_create"]
    client_local_id: int = Field(..., description="Client-assigned temporary ID for this folder. Returned in SyncPushCreated so the client can map it to the server-assigned remote_id.")
    name: str = Field(..., description="Display name of the folder.")
    sort_order: int = Field(0, description="Sort position among folders (ascending).")


class FolderUpdateOp(BaseModel):
    type: Literal["folder_update"]
    remote_id: int = Field(..., description="Server-assigned ID of the folder to update.")
    name: str = Field(..., description="New display name.")
    sort_order: int | None = Field(None, description="New sort position. Only applied when update_sort_order is true.")
    update_sort_order: bool = Field(False, description="Set to true to apply the sort_order value. When false, sort_order is ignored (allowing a plain rename without touching position).")


class FolderDeleteOp(BaseModel):
    type: Literal["folder_delete"]
    remote_id: int = Field(..., description="Server-assigned ID of the folder to soft-delete. Cascades to all its teams and their slots.")


class TeamCreateOp(BaseModel):
    type: Literal["team_create"]
    client_local_id: int = Field(..., description="Client-assigned temporary ID. Returned in SyncPushCreated for client-side mapping.")
    name: str = Field(..., description="Display name of the team.")
    format_label: str | None = Field(None, description="Competitive format label (e.g. 'OU', 'VGC 2024').")
    sort_order: int = Field(0, description="Sort position among teams (ascending).")
    is_box: bool = Field(False, description="True when this entry should behave as a storage box rather than a competitive team.")
    # Exactly one of these two should be set when a folder is involved.
    folder_remote_id: int | None = Field(None, description="Server-assigned folder ID. Use when the folder is already synced.")
    folder_client_local_id: int | None = Field(None, description="Temporary folder ID from a folder_create op in the same batch. Set this instead of folder_remote_id when the folder is also being created in this push.")


class TeamUpdateOp(BaseModel):
    type: Literal["team_update"]
    remote_id: int = Field(..., description="Server-assigned ID of the team to update.")
    name: str = Field(..., description="New display name.")
    format_label: str | None = Field(None, description="New format label. Only applied when update_format_label is true.")
    update_format_label: bool = Field(False, description="Set to true to apply the format_label value.")
    sort_order: int | None = Field(None, description="New sort position. Only applied when update_sort_order is true.")
    update_sort_order: bool = Field(False, description="Set to true to apply the sort_order value.")
    is_box: bool | None = Field(None, description="New box flag. Only applied when update_is_box is true.")
    update_is_box: bool = Field(False, description="Set to true to apply the is_box value.")
    # Folder change — only applied when update_folder is True so that a
    # plain rename (which has no folder info) doesn't accidentally clear it.
    update_folder: bool = Field(False, description="Set to true to change the folder assignment. When false, folder fields are ignored (prevents accidental folder clear on plain renames).")
    folder_remote_id: int | None = Field(None, description="Server-assigned folder ID. Use when moving to an already-synced folder.")
    folder_client_local_id: int | None = Field(None, description="Temporary folder ID from a folder_create op in the same batch.")


class TeamDeleteOp(BaseModel):
    type: Literal["team_delete"]
    remote_id: int = Field(..., description="Server-assigned ID of the team to soft-delete. Cascades to all its slots.")


class InstanceCreateOp(BaseModel):
    type: Literal["instance_create"]
    client_local_id: int = Field(..., description="Client-assigned temporary ID. Returned in SyncPushCreated for client-side mapping.")
    pokemon_id: int = Field(..., description="PokéAPI variety ID of the Pokémon.")
    # Exactly one of these when a parent exists.
    parent_instance_remote_id: int | None = Field(None, description="Server-assigned ID of the parent instance (pre-evolution). Use when the parent is already synced.")
    parent_instance_client_local_id: int | None = Field(None, description="Temporary ID of a parent instance_create op in the same batch.")
    nickname_aliases: str | None = Field(None, description="JSON-encoded list of nicknames this Pokémon has had.")
    inherited_ribbons: str | None = Field(None, description="JSON-encoded list of ribbon IDs inherited from ancestors.")


class InstanceUpdate(BaseModel):
    nickname_aliases: str | None = Field(None, description="Updated nickname list (JSON-encoded). Null means no change.")
    inherited_ribbons: str | None = Field(None, description="Updated inherited ribbon list (JSON-encoded). Null means no change.")


class InstanceUpdateOp(BaseModel):
    type: Literal["instance_update"]
    remote_id: int = Field(..., description="Server-assigned ID of the instance to update.")
    nickname_aliases: str | None = Field(None, description="Updated nickname list (JSON-encoded). Null means no change.")
    inherited_ribbons: str | None = Field(None, description="Updated inherited ribbon list (JSON-encoded). Null means no change.")
    update_parent_instance: bool = Field(False, description="Set to true to change the parent instance link. When false, parent_instance_remote_id is ignored.")
    parent_instance_remote_id: int | None = Field(None, description="Server-assigned ID of the new parent instance. Null clears the parent link.")


class SlotUpsertOp(BaseModel):
    type: Literal["slot_upsert"]
    # Exactly one of these two should be set.
    team_remote_id: int | None = Field(None, description="Server-assigned team ID. Use when the team is already synced.")
    team_client_local_id: int | None = Field(None, description="Temporary team ID from a team_create op in the same batch. Set instead of team_remote_id when the team is also being created in this push.")
    slot: int = Field(..., description="Slot position within the team (1-indexed, typically 1–6).")
    pokemon_id: int = Field(..., description="PokéAPI variety ID of the Pokémon.")
    nickname: str | None = Field(None, description="Custom nickname for this slot entry.")
    # Optional instance link.
    instance_remote_id: int | None = Field(None, description="Server-assigned ID of the linked PokémonInstance. Use when the instance is already synced.")
    instance_client_local_id: int | None = Field(None, description="Temporary instance ID from an instance_create op in the same batch.")
    # Full slot config
    form_name: str | None = Field(None, description="PokéAPI form name override. Null uses the variety's default.")
    level: int | None = Field(None, description="Level (1–100).")
    gender: str | None = Field(None, description="'male', 'female', or null for genderless.")
    is_shiny: bool = Field(False, description="True if shiny.")
    friendship: int | None = Field(None, description="Friendship value (0–255).")
    ability_name: str | None = Field(None, description="PokéAPI ability slug (e.g. 'blaze').")
    nature_name: str | None = Field(None, description="PokéAPI nature slug (e.g. 'timid').")
    held_item_name: str | None = Field(None, description="PokéAPI held item slug (e.g. 'choice-scarf').")
    move1: str | None = Field(None, description="Move slot 1 — PokéAPI move slug.")
    move2: str | None = Field(None, description="Move slot 2 — PokéAPI move slug.")
    move3: str | None = Field(None, description="Move slot 3 — PokéAPI move slug.")
    move4: str | None = Field(None, description="Move slot 4 — PokéAPI move slug.")
    ev_hp: int | None = Field(None, description="HP EV (0–252).")
    ev_atk: int | None = Field(None, description="Attack EV (0–252).")
    ev_def: int | None = Field(None, description="Defense EV (0–252).")
    ev_spa: int | None = Field(None, description="Special Attack EV (0–252).")
    ev_spd: int | None = Field(None, description="Special Defense EV (0–252).")
    ev_spe: int | None = Field(None, description="Speed EV (0–252).")
    iv_hp: int | None = Field(None, description="HP IV (0–31).")
    iv_atk: int | None = Field(None, description="Attack IV (0–31).")
    iv_def: int | None = Field(None, description="Defense IV (0–31).")
    iv_spa: int | None = Field(None, description="Special Attack IV (0–31).")
    iv_spd: int | None = Field(None, description="Special Defense IV (0–31).")
    iv_spe: int | None = Field(None, description="Speed IV (0–31).")
    ribbons: str | None = Field(None, description="JSON-encoded list of ribbon IDs.")
    is_mega_evolved: bool = Field(False, description="True if Mega Evolved.")
    has_gigantamax: bool = Field(False, description="True if this Pokémon has the Gigantamax factor.")
    gigantamax_enabled: bool = Field(False, description="True if Gigantamax is selected for battle.")
    is_alpha: bool = Field(False, description="True if Alpha (Legends: Arceus).")
    tera_type: str | None = Field(None, description="Tera type (e.g. 'fire'). Null means none selected.")
    contest_cool: int | None = Field(None, description="Contest Cool stat (0–255).")
    contest_beautiful: int | None = Field(None, description="Contest Beautiful stat (0–255).")
    contest_cute: int | None = Field(None, description="Contest Cute stat (0–255).")
    contest_clever: int | None = Field(None, description="Contest Clever stat (0–255).")
    contest_tough: int | None = Field(None, description="Contest Tough stat (0–255).")
    contest_sheen: int | None = Field(None, description="Contest Sheen stat (0–255).")


class SlotDeleteOp(BaseModel):
    type: Literal["slot_delete"]
    team_remote_id: int | None = Field(None, description="Server-assigned team ID. Use when the team is already synced.")
    team_client_local_id: int | None = Field(None, description="Temporary team ID from a team_create op in the same batch.")
    slot: int = Field(..., description="Slot position to delete (1-indexed).")


SyncOp = Annotated[
    FolderCreateOp | FolderUpdateOp | FolderDeleteOp
    | TeamCreateOp | TeamUpdateOp | TeamDeleteOp
    | InstanceCreateOp | InstanceUpdateOp
    | SlotUpsertOp | SlotDeleteOp,
    Field(discriminator="type"),
]


class SyncPushRequest(BaseModel):
    ops: list[SyncOp] = Field(..., description="Ordered list of operations to apply. Applied sequentially; cross-references within the batch (client_local_id → remote_id) are resolved as each op is processed.")


class SyncPushCreated(BaseModel):
    entity_type: str = Field(..., description="Type of entity created: 'folder', 'team', or 'instance'.")
    client_local_id: int = Field(..., description="The client_local_id from the originating create op.")
    remote_id: int = Field(..., description="Server-assigned ID for the newly created entity.")


class SyncPushResponse(BaseModel):
    created: list[SyncPushCreated] = Field(..., description="ID mappings for all entities created in this push (client_local_id → remote_id). Use these to update local records with their server IDs.")
