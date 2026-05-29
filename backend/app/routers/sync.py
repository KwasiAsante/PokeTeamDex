from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Query
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.deps import CurrentUser, DB
from app.models.team import Team, TeamFolder, TeamSlot
from app.schemas.team import FolderResponse, SlotResponse, SyncPullResponse, TeamResponse

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
