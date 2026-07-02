from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.core.deps import CurrentUser, DB
from app.models.team import Team, TeamFolder, TeamSlot
from app.schemas.team import SlotResponse, SlotUpsert, TeamCreate, TeamResponse, TeamUpdate

router = APIRouter(prefix="/teams", tags=["teams"])
slots_router = APIRouter(prefix="/slots", tags=["slots"])


@slots_router.get("/{slot_id}", response_model=SlotResponse)
async def get_slot_by_id(slot_id: int, current_user: CurrentUser, db: DB) -> SlotResponse:
    """Fetch a single slot by its primary-key id, verifying team ownership."""
    result = await db.execute(
        select(TeamSlot)
        .join(Team, TeamSlot.team_id == Team.id)
        .where(
            TeamSlot.id == slot_id,
            TeamSlot.is_deleted == False,  # noqa: E712
            Team.user_id == current_user.id,
            Team.is_deleted == False,  # noqa: E712
        )
    )
    slot = result.scalar_one_or_none()
    if slot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Slot not found")
    return SlotResponse.model_validate(slot)


# ── Teams ─────────────────────────────────────────────────────────────────────

@router.get("", response_model=list[TeamResponse])
async def list_teams(current_user: CurrentUser, db: DB) -> list[TeamResponse]:
    result = await db.execute(
        select(Team).where(
            Team.user_id == current_user.id,
            Team.is_deleted == False,  # noqa: E712
        )
    )
    return [TeamResponse.model_validate(t) for t in result.scalars()]


@router.post("", response_model=TeamResponse, status_code=status.HTTP_201_CREATED)
async def create_team(body: TeamCreate, current_user: CurrentUser, db: DB) -> TeamResponse:
    if body.folder_id is not None:
        await _get_owned_folder(body.folder_id, current_user.id, db)
    team = Team(user_id=current_user.id, folder_id=body.folder_id, name=body.name)
    db.add(team)
    await db.commit()
    await db.refresh(team)
    return TeamResponse.model_validate(team)


@router.get("/{team_id}", response_model=TeamResponse)
async def get_team(team_id: int, current_user: CurrentUser, db: DB) -> TeamResponse:
    team = await _get_owned_team(team_id, current_user.id, db)
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
    team.is_deleted = True

    # Cascade soft-delete to slots.
    slots_result = await db.execute(
        select(TeamSlot).where(TeamSlot.team_id == team.id, TeamSlot.is_deleted == False)  # noqa: E712
    )
    for slot in slots_result.scalars():
        slot.is_deleted = True

    await db.commit()


# ── Slots ─────────────────────────────────────────────────────────────────────

@router.get("/{team_id}/slots", response_model=list[SlotResponse])
async def list_slots(team_id: int, current_user: CurrentUser, db: DB) -> list[SlotResponse]:
    await _get_owned_team(team_id, current_user.id, db)
    result = await db.execute(
        select(TeamSlot).where(
            TeamSlot.team_id == team_id,
            TeamSlot.is_deleted == False,  # noqa: E712
        )
    )
    return [SlotResponse.model_validate(s) for s in result.scalars()]


@router.get("/{team_id}/slots/{slot_number}", response_model=SlotResponse)
async def get_slot(
    team_id: int, slot_number: int, current_user: CurrentUser, db: DB
) -> SlotResponse:
    await _get_owned_team(team_id, current_user.id, db)
    result = await db.execute(
        select(TeamSlot).where(
            TeamSlot.team_id == team_id,
            TeamSlot.slot == slot_number,
            TeamSlot.is_deleted == False,  # noqa: E712
        )
    )
    slot = result.scalar_one_or_none()
    if slot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Slot not found")
    return SlotResponse.model_validate(slot)


@router.put("/{team_id}/slots/{slot_number}", response_model=SlotResponse)
async def upsert_slot(
    team_id: int, slot_number: int, body: SlotUpsert, current_user: CurrentUser, db: DB
) -> SlotResponse:
    await _get_owned_team(team_id, current_user.id, db)

    result = await db.execute(
        select(TeamSlot).where(TeamSlot.team_id == team_id, TeamSlot.slot == slot_number)
    )
    slot = result.scalar_one_or_none()

    def _apply(s: TeamSlot) -> None:
        s.pokemon_id = body.pokemon_id
        s.nickname = body.nickname
        s.instance_id = body.instance_id
        s.form_name = body.form_name
        s.level = body.level
        s.gender = body.gender
        s.is_shiny = body.is_shiny
        s.friendship = body.friendship
        s.ability_name = body.ability_name
        s.nature_name = body.nature_name
        s.held_item_name = body.held_item_name
        s.move1 = body.move1
        s.move2 = body.move2
        s.move3 = body.move3
        s.move4 = body.move4
        s.ev_hp = body.ev_hp
        s.ev_atk = body.ev_atk
        s.ev_def = body.ev_def
        s.ev_spa = body.ev_spa
        s.ev_spd = body.ev_spd
        s.ev_spe = body.ev_spe
        s.iv_hp = body.iv_hp
        s.iv_atk = body.iv_atk
        s.iv_def = body.iv_def
        s.iv_spa = body.iv_spa
        s.iv_spd = body.iv_spd
        s.iv_spe = body.iv_spe
        s.ribbons = body.ribbons
        s.is_mega_evolved = body.is_mega_evolved
        s.has_gigantamax = body.has_gigantamax
        s.gigantamax_enabled = body.gigantamax_enabled
        s.is_alpha = body.is_alpha
        s.contest_cool = body.contest_cool
        s.contest_beautiful = body.contest_beautiful
        s.contest_cute = body.contest_cute
        s.contest_clever = body.contest_clever
        s.contest_tough = body.contest_tough
        s.contest_sheen = body.contest_sheen

    if slot is None:
        slot = TeamSlot(team_id=team_id, slot=slot_number)
        _apply(slot)
        db.add(slot)
    else:
        _apply(slot)
        slot.is_deleted = False

    await db.commit()
    await db.refresh(slot)
    return SlotResponse.model_validate(slot)


@router.delete("/{team_id}/slots/{slot_number}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_slot(team_id: int, slot_number: int, current_user: CurrentUser, db: DB) -> None:
    await _get_owned_team(team_id, current_user.id, db)
    result = await db.execute(
        select(TeamSlot).where(
            TeamSlot.team_id == team_id,
            TeamSlot.slot == slot_number,
            TeamSlot.is_deleted == False,  # noqa: E712
        )
    )
    slot = result.scalar_one_or_none()
    if slot is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Slot not found")
    slot.is_deleted = True
    await db.commit()


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_owned_folder(folder_id: int, user_id: int, db: DB) -> TeamFolder:
    result = await db.execute(
        select(TeamFolder).where(
            TeamFolder.id == folder_id,
            TeamFolder.user_id == user_id,
            TeamFolder.is_deleted == False,  # noqa: E712
        )
    )
    folder = result.scalar_one_or_none()
    if folder is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found")
    return folder


async def _get_owned_team(team_id: int, user_id: int, db: DB) -> Team:
    result = await db.execute(
        select(Team).where(
            Team.id == team_id,
            Team.user_id == user_id,
            Team.is_deleted == False,  # noqa: E712
        )
    )
    team = result.scalar_one_or_none()
    if team is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Team not found")
    return team
