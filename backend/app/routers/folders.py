from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.core.deps import CurrentUser, DB
from app.models.team import Team, TeamFolder, TeamSlot
from app.schemas.team import FolderCreate, FolderResponse, FolderUpdate

router = APIRouter(prefix="/folders", tags=["folders"])


@router.get("", response_model=list[FolderResponse], summary="List folders")
async def list_folders(current_user: CurrentUser, db: DB) -> list[FolderResponse]:
    """Return all non-deleted folders belonging to the authenticated user."""
    result = await db.execute(
        select(TeamFolder).where(
            TeamFolder.user_id == current_user.id,
            TeamFolder.is_deleted == False,  # noqa: E712
        )
    )
    return [FolderResponse.model_validate(f) for f in result.scalars()]


@router.post("", response_model=FolderResponse, status_code=status.HTTP_201_CREATED, summary="Create folder")
async def create_folder(body: FolderCreate, current_user: CurrentUser, db: DB) -> FolderResponse:
    """Create a new team folder for the authenticated user."""
    folder = TeamFolder(user_id=current_user.id, name=body.name)
    db.add(folder)
    await db.commit()
    await db.refresh(folder)
    return FolderResponse.model_validate(folder)


@router.get("/{folder_id}", response_model=FolderResponse, summary="Get folder")
async def get_folder(folder_id: int, current_user: CurrentUser, db: DB) -> FolderResponse:
    """Return a single folder by ID, verifying ownership."""
    folder = await _get_owned_folder(folder_id, current_user.id, db)
    return FolderResponse.model_validate(folder)


@router.patch("/{folder_id}", response_model=FolderResponse, summary="Rename folder")
async def rename_folder(
    folder_id: int, body: FolderUpdate, current_user: CurrentUser, db: DB
) -> FolderResponse:
    folder = await _get_owned_folder(folder_id, current_user.id, db)
    folder.name = body.name
    await db.commit()
    await db.refresh(folder)
    return FolderResponse.model_validate(folder)


@router.delete("/{folder_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Delete folder")
async def delete_folder(folder_id: int, current_user: CurrentUser, db: DB) -> None:
    """Soft-delete a folder and cascade the deletion to all its teams and their slots."""
    folder = await _get_owned_folder(folder_id, current_user.id, db)
    folder.is_deleted = True

    # Cascade soft-delete to all teams and their slots so Device B can
    # pick up the full deletion tree via the pull endpoint.
    teams_result = await db.execute(
        select(Team).where(Team.folder_id == folder.id, Team.is_deleted == False)  # noqa: E712
    )
    for team in teams_result.scalars():
        team.is_deleted = True
        slots_result = await db.execute(
            select(TeamSlot).where(TeamSlot.team_id == team.id, TeamSlot.is_deleted == False)  # noqa: E712
        )
        for slot in slots_result.scalars():
            slot.is_deleted = True

    await db.commit()


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
