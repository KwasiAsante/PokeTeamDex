from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.deps import CurrentUser, DB
from app.models.team import Team, TeamFolder, TeamSlot
from app.schemas.team import SlotResponse, SlotUpsert, TeamCreate, TeamResponse, TeamUpdate

router = APIRouter(prefix="/teams", tags=["teams"])


# ── Teams ─────────────────────────────────────────────────────────────────────

@router.get("", response_model=list[TeamResponse])
async def list_teams(current_user: CurrentUser, db: DB) -> list[TeamResponse]:
    result = await db.execute(
        select(Team)
        .join(TeamFolder, Team.folder_id == TeamFolder.id)
        .where(TeamFolder.user_id == current_user.id)
    )
    return [TeamResponse.model_validate(t) for t in result.scalars()]


@router.post("", response_model=TeamResponse, status_code=status.HTTP_201_CREATED)
async def create_team(body: TeamCreate, current_user: CurrentUser, db: DB) -> TeamResponse:
    await _get_owned_folder(body.folder_id, current_user.id, db)
    team = Team(folder_id=body.folder_id, name=body.name)
    db.add(team)
    await db.commit()
    await db.refresh(team)
    return TeamResponse.model_validate(team)


@router.patch("/{team_id}", response_model=TeamResponse)
async def rename_team(
    team_id: int, body: TeamUpdate, current_user: CurrentUser, db: DB
) -> TeamResponse:
    team = await _get_owned_team(team_id, current_user.id, db)
    team.name = body.name
    await db.commit()
    await db.refresh(team)
    return TeamResponse.model_validate(team)


@router.delete("/{team_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_team(team_id: int, current_user: CurrentUser, db: DB) -> None:
    team = await _get_owned_team(team_id, current_user.id, db)
    await db.delete(team)
    await db.commit()


# ── Slots ─────────────────────────────────────────────────────────────────────

@router.get("/{team_id}/slots", response_model=list[SlotResponse])
async def list_slots(team_id: int, current_user: CurrentUser, db: DB) -> list[SlotResponse]:
    await _get_owned_team(team_id, current_user.id, db)
    result = await db.execute(
        select(TeamSlot).where(TeamSlot.team_id == team_id)
    )
    return [SlotResponse.model_validate(s) for s in result.scalars()]


@router.put("/{team_id}/slots/{slot_number}", response_model=SlotResponse)
async def upsert_slot(
    team_id: int, slot_number: int, body: SlotUpsert, current_user: CurrentUser, db: DB
) -> SlotResponse:
    await _get_owned_team(team_id, current_user.id, db)

    result = await db.execute(
        select(TeamSlot).where(TeamSlot.team_id == team_id, TeamSlot.slot == slot_number)
    )
    slot = result.scalar_one_or_none()

    if slot is None:
        slot = TeamSlot(team_id=team_id, slot=slot_number, pokemon_id=body.pokemon_id, nickname=body.nickname)
        db.add(slot)
    else:
        slot.pokemon_id = body.pokemon_id
        slot.nickname = body.nickname

    await db.commit()
    await db.refresh(slot)
    return SlotResponse.model_validate(slot)


@router.delete("/{team_id}/slots/{slot_number}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_slot(team_id: int, slot_number: int, current_user: CurrentUser, db: DB) -> None:
    await _get_owned_team(team_id, current_user.id, db)
    result = await db.execute(
        select(TeamSlot).where(TeamSlot.team_id == team_id, TeamSlot.slot == slot_number)
    )
    slot = result.scalar_one_or_none()
    if slot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Slot not found")
    await db.delete(slot)
    await db.commit()


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_owned_folder(folder_id: int, user_id: int, db: DB) -> TeamFolder:
    result = await db.execute(
        select(TeamFolder).where(TeamFolder.id == folder_id, TeamFolder.user_id == user_id)
    )
    folder = result.scalar_one_or_none()
    if folder is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found")
    return folder


async def _get_owned_team(team_id: int, user_id: int, db: DB) -> Team:
    result = await db.execute(
        select(Team)
        .join(TeamFolder, Team.folder_id == TeamFolder.id)
        .where(Team.id == team_id, TeamFolder.user_id == user_id)
    )
    team = result.scalar_one_or_none()
    if team is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Team not found")
    return team
