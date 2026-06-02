from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Query
from sqlalchemy import select

from app.core.deps import CurrentUser, DB
from app.models.team import Team, TeamFolder, TeamSlot
from app.schemas.team import (
    FolderCreateOp, FolderDeleteOp, FolderResponse, FolderUpdateOp,
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
    slot_q = (
        select(TeamSlot)
        .join(Team, TeamSlot.team_id == Team.id)
        .where(Team.user_id == current_user.id)
    )

    if since is not None:
        folder_q = folder_q.where(TeamFolder.updated_at > since)
        team_q = team_q.where(Team.updated_at > since)
        slot_q = slot_q.where(TeamSlot.updated_at > since)

    folders = (await db.execute(folder_q)).scalars().all()
    teams = (await db.execute(team_q)).scalars().all()
    slots = (await db.execute(slot_q)).scalars().all()

    return SyncPullResponse(
        folders=[FolderResponse.model_validate(f) for f in folders],
        teams=[TeamResponse.model_validate(t) for t in teams],
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
    created: list[SyncPushCreated] = []

    for op in body.ops:
        if isinstance(op, FolderCreateOp):
            folder = TeamFolder(user_id=current_user.id, name=op.name)
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

        elif isinstance(op, FolderDeleteOp):
            r = await db.execute(
                select(TeamFolder).where(
                    TeamFolder.id == op.remote_id,
                    TeamFolder.user_id == current_user.id,
                )
            )
            folder = r.scalar_one_or_none()
            if folder:
                folder.is_deleted = True
                tr = await db.execute(
                    select(Team).where(Team.folder_id == folder.id, Team.is_deleted == False)  # noqa: E712
                )
                for team in tr.scalars():
                    team.is_deleted = True
                    sr = await db.execute(
                        select(TeamSlot).where(TeamSlot.team_id == team.id, TeamSlot.is_deleted == False)  # noqa: E712
                    )
                    for slot in sr.scalars():
                        slot.is_deleted = True

        elif isinstance(op, TeamCreateOp):
            folder_id = op.folder_remote_id
            if folder_id is None and op.folder_client_local_id is not None:
                folder_id = folder_map.get(op.folder_client_local_id)
            team = Team(user_id=current_user.id, name=op.name, folder_id=folder_id)
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
                team.is_deleted = True
                sr = await db.execute(
                    select(TeamSlot).where(TeamSlot.team_id == team.id, TeamSlot.is_deleted == False)  # noqa: E712
                )
                for slot in sr.scalars():
                    slot.is_deleted = True

        elif isinstance(op, SlotUpsertOp):
            team_id = op.team_remote_id
            if team_id is None and op.team_client_local_id is not None:
                team_id = team_map.get(op.team_client_local_id)
            if team_id is None:
                continue
            r = await db.execute(
                select(TeamSlot).where(TeamSlot.team_id == team_id, TeamSlot.slot == op.slot)
            )
            slot = r.scalar_one_or_none()
            if slot is None:
                slot = TeamSlot(
                    team_id=team_id, slot=op.slot,
                    pokemon_id=op.pokemon_id, nickname=op.nickname,
                )
                db.add(slot)
            else:
                slot.pokemon_id = op.pokemon_id
                slot.nickname = op.nickname
                slot.is_deleted = False

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

    await db.commit()
    return SyncPushResponse(created=created)
