from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Query
from sqlalchemy import select

from app.core.deps import CurrentUser, DB
from app.models.team import PokemonInstance, Team, TeamFolder, TeamSlot
from app.schemas.team import (
    FolderCreateOp, FolderDeleteOp, FolderResponse, FolderUpdateOp,
    InstanceCreateOp, InstanceResponse, InstanceUpdateOp,
    SlotDeleteOp, SlotResponse, SlotUpsertOp,
    SyncPullResponse, SyncPushCreated, SyncPushRequest, SyncPushResponse,
    TeamCreateOp, TeamDeleteOp, TeamResponse, TeamUpdateOp,
)

router = APIRouter(prefix="/sync", tags=["sync"])


@router.get("/pull", response_model=SyncPullResponse)
async def pull(
    current_user: CurrentUser,
    db: DB,
    since: Optional[datetime] = Query(None, description="ISO 8601 timestamp; return records updated after this time"),
) -> SyncPullResponse:
    folder_q = select(TeamFolder).where(TeamFolder.user_id == current_user.id)
    team_q = select(Team).where(Team.user_id == current_user.id)
    instance_q = select(PokemonInstance).where(PokemonInstance.user_id == current_user.id)
    slot_q = (
        select(TeamSlot)
        .join(Team, TeamSlot.team_id == Team.id)
        .where(Team.user_id == current_user.id)
    )

    if since is not None:
        folder_q = folder_q.where(TeamFolder.updated_at > since)
        team_q = team_q.where(Team.updated_at > since)
        instance_q = instance_q.where(PokemonInstance.updated_at > since)
        slot_q = slot_q.where(TeamSlot.updated_at > since)

    folders = (await db.execute(folder_q)).scalars().all()
    teams = (await db.execute(team_q)).scalars().all()
    instances = (await db.execute(instance_q)).scalars().all()
    slots = (await db.execute(slot_q)).scalars().all()

    return SyncPullResponse(
        folders=[FolderResponse.model_validate(f) for f in folders],
        teams=[TeamResponse.model_validate(t) for t in teams],
        instances=[InstanceResponse.model_validate(i) for i in instances],
        slots=[SlotResponse.model_validate(s) for s in slots],
    )


@router.post("/push", response_model=SyncPushResponse)
async def push(body: SyncPushRequest, current_user: CurrentUser, db: DB) -> SyncPushResponse:
    """Process all queued client operations in a single atomic batch.

    Ops are applied in the order they arrive.  Within-batch cross-references
    (e.g. a team_create that references a folder_create in the same batch) are
    resolved via an in-memory map built as the batch is processed.
    Entity-not-found conditions are silently skipped rather than aborting the
    whole batch.
    """
    folder_map: dict[int, int] = {}  # client_local_id → server id (this batch)
    team_map: dict[int, int] = {}
    instance_map: dict[int, int] = {}
    created: list[SyncPushCreated] = []

    for op in body.ops:
        if isinstance(op, FolderCreateOp):
            folder = TeamFolder(user_id=current_user.id, name=op.name, sort_order=op.sort_order)
            db.add(folder)
            await db.flush()
            folder_map[op.client_local_id] = folder.id
            created.append(SyncPushCreated(
                entity_type="folder",
                client_local_id=op.client_local_id,
                remote_id=folder.id,
            ))

        elif isinstance(op, FolderUpdateOp):
            r = await db.execute(
                select(TeamFolder).where(
                    TeamFolder.id == op.remote_id,
                    TeamFolder.user_id == current_user.id,
                )
            )
            folder = r.scalar_one_or_none()
            if folder:
                folder.name = op.name
                if op.update_sort_order and op.sort_order is not None:
                    folder.sort_order = op.sort_order
                folder.updated_at = datetime.now(timezone.utc)

        elif isinstance(op, FolderDeleteOp):
            r = await db.execute(
                select(TeamFolder).where(
                    TeamFolder.id == op.remote_id,
                    TeamFolder.user_id == current_user.id,
                )
            )
            folder = r.scalar_one_or_none()
            if folder:
                now = datetime.now(timezone.utc)
                folder.is_deleted = True
                folder.updated_at = now
                tr = await db.execute(
                    select(Team).where(Team.folder_id == folder.id, Team.is_deleted == False)  # noqa: E712
                )
                for team in tr.scalars():
                    team.is_deleted = True
                    team.updated_at = now
                    sr = await db.execute(
                        select(TeamSlot).where(TeamSlot.team_id == team.id, TeamSlot.is_deleted == False)  # noqa: E712
                    )
                    for slot in sr.scalars():
                        slot.is_deleted = True
                        slot.updated_at = now

        elif isinstance(op, TeamCreateOp):
            folder_id = op.folder_remote_id
            if folder_id is None and op.folder_client_local_id is not None:
                folder_id = folder_map.get(op.folder_client_local_id)
            team = Team(
                user_id=current_user.id,
                name=op.name,
                format_label=op.format_label,
                sort_order=op.sort_order,
                is_box=op.is_box,
                folder_id=folder_id,
            )
            db.add(team)
            await db.flush()
            team_map[op.client_local_id] = team.id
            created.append(SyncPushCreated(
                entity_type="team",
                client_local_id=op.client_local_id,
                remote_id=team.id,
            ))

        elif isinstance(op, TeamUpdateOp):
            r = await db.execute(
                select(Team).where(Team.id == op.remote_id, Team.user_id == current_user.id)
            )
            team = r.scalar_one_or_none()
            if team:
                team.name = op.name
                team.updated_at = datetime.now(timezone.utc)
                if op.update_sort_order and op.sort_order is not None:
                    team.sort_order = op.sort_order
                if op.update_is_box and op.is_box is not None:
                    team.is_box = op.is_box
                if op.update_format_label:
                    team.format_label = op.format_label
                if op.update_folder:
                    folder_id = op.folder_remote_id
                    if folder_id is None and op.folder_client_local_id is not None:
                        folder_id = folder_map.get(op.folder_client_local_id)
                    if folder_id is not None:
                        # Verify the folder belongs to this user before assigning
                        fr = await db.execute(
                            select(TeamFolder).where(
                                TeamFolder.id == folder_id,
                                TeamFolder.user_id == current_user.id,
                            )
                        )
                        team.folder_id = folder_id if fr.scalar_one_or_none() else None
                    else:
                        team.folder_id = None  # move to ungrouped

        elif isinstance(op, TeamDeleteOp):
            r = await db.execute(
                select(Team).where(Team.id == op.remote_id, Team.user_id == current_user.id)
            )
            team = r.scalar_one_or_none()
            if team:
                now = datetime.now(timezone.utc)
                team.is_deleted = True
                team.updated_at = now
                sr = await db.execute(
                    select(TeamSlot).where(TeamSlot.team_id == team.id, TeamSlot.is_deleted == False)  # noqa: E712
                )
                for slot in sr.scalars():
                    slot.is_deleted = True
                    slot.updated_at = now

        elif isinstance(op, InstanceCreateOp):
            parent_id = op.parent_instance_remote_id
            if parent_id is None and op.parent_instance_client_local_id is not None:
                parent_id = instance_map.get(op.parent_instance_client_local_id)
            instance = PokemonInstance(
                user_id=current_user.id,
                pokemon_id=op.pokemon_id,
                parent_instance_id=parent_id,
                nickname_aliases=op.nickname_aliases,
                inherited_ribbons=op.inherited_ribbons,
            )
            db.add(instance)
            await db.flush()
            instance_map[op.client_local_id] = instance.id
            created.append(SyncPushCreated(
                entity_type="instance",
                client_local_id=op.client_local_id,
                remote_id=instance.id,
            ))

        elif isinstance(op, InstanceUpdateOp):
            r = await db.execute(
                select(PokemonInstance).where(
                    PokemonInstance.id == op.remote_id,
                    PokemonInstance.user_id == current_user.id,
                )
            )
            instance = r.scalar_one_or_none()
            if instance:
                if op.nickname_aliases is not None:
                    instance.nickname_aliases = op.nickname_aliases
                if op.inherited_ribbons is not None:
                    instance.inherited_ribbons = op.inherited_ribbons
                instance.updated_at = datetime.now(timezone.utc)

        elif isinstance(op, SlotUpsertOp):
            team_id = op.team_remote_id
            if team_id is None and op.team_client_local_id is not None:
                team_id = team_map.get(op.team_client_local_id)
            if team_id is None:
                continue
            # Resolve instance reference.
            instance_id = op.instance_remote_id
            if instance_id is None and op.instance_client_local_id is not None:
                instance_id = instance_map.get(op.instance_client_local_id)
            r = await db.execute(
                select(TeamSlot).where(TeamSlot.team_id == team_id, TeamSlot.slot == op.slot)
            )
            slot = r.scalar_one_or_none()
            if slot is None:
                slot = TeamSlot(
                    team_id=team_id, slot=op.slot,
                    pokemon_id=op.pokemon_id, nickname=op.nickname,
                    instance_id=instance_id,
                    form_name=op.form_name, level=op.level, gender=op.gender,
                    is_shiny=op.is_shiny, friendship=op.friendship,
                    ability_name=op.ability_name, nature_name=op.nature_name,
                    held_item_name=op.held_item_name,
                    move1=op.move1, move2=op.move2, move3=op.move3, move4=op.move4,
                    ev_hp=op.ev_hp, ev_atk=op.ev_atk, ev_def=op.ev_def,
                    ev_spa=op.ev_spa, ev_spd=op.ev_spd, ev_spe=op.ev_spe,
                    iv_hp=op.iv_hp, iv_atk=op.iv_atk, iv_def=op.iv_def,
                    iv_spa=op.iv_spa, iv_spd=op.iv_spd, iv_spe=op.iv_spe,
                    ribbons=op.ribbons,
                    is_mega_evolved=op.is_mega_evolved, has_gigantamax=op.has_gigantamax,
                    gigantamax_enabled=op.gigantamax_enabled, is_alpha=op.is_alpha,
                    tera_type=op.tera_type,
                    contest_cool=op.contest_cool, contest_beautiful=op.contest_beautiful,
                    contest_cute=op.contest_cute, contest_clever=op.contest_clever,
                    contest_tough=op.contest_tough, contest_sheen=op.contest_sheen,
                )
                db.add(slot)
            else:
                slot.pokemon_id = op.pokemon_id
                slot.nickname = op.nickname
                slot.instance_id = instance_id
                slot.form_name = op.form_name
                slot.level = op.level
                slot.gender = op.gender
                slot.is_shiny = op.is_shiny
                slot.friendship = op.friendship
                slot.ability_name = op.ability_name
                slot.nature_name = op.nature_name
                slot.held_item_name = op.held_item_name
                slot.move1 = op.move1
                slot.move2 = op.move2
                slot.move3 = op.move3
                slot.move4 = op.move4
                slot.ev_hp = op.ev_hp
                slot.ev_atk = op.ev_atk
                slot.ev_def = op.ev_def
                slot.ev_spa = op.ev_spa
                slot.ev_spd = op.ev_spd
                slot.ev_spe = op.ev_spe
                slot.iv_hp = op.iv_hp
                slot.iv_atk = op.iv_atk
                slot.iv_def = op.iv_def
                slot.iv_spa = op.iv_spa
                slot.iv_spd = op.iv_spd
                slot.iv_spe = op.iv_spe
                slot.ribbons = op.ribbons
                slot.is_mega_evolved = op.is_mega_evolved
                slot.has_gigantamax = op.has_gigantamax
                slot.gigantamax_enabled = op.gigantamax_enabled
                slot.is_alpha = op.is_alpha
                slot.tera_type = op.tera_type
                slot.contest_cool = op.contest_cool
                slot.contest_beautiful = op.contest_beautiful
                slot.contest_cute = op.contest_cute
                slot.contest_clever = op.contest_clever
                slot.contest_tough = op.contest_tough
                slot.contest_sheen = op.contest_sheen
                slot.is_deleted = False
                slot.updated_at = datetime.now(timezone.utc)

        elif isinstance(op, SlotDeleteOp):
            team_id = op.team_remote_id
            if team_id is None and op.team_client_local_id is not None:
                team_id = team_map.get(op.team_client_local_id)
            if team_id is None:
                continue
            r = await db.execute(
                select(TeamSlot).where(TeamSlot.team_id == team_id, TeamSlot.slot == op.slot)
            )
            slot = r.scalar_one_or_none()
            if slot:
                slot.is_deleted = True
                slot.updated_at = datetime.now(timezone.utc)

    await db.commit()
    return SyncPushResponse(created=created)
