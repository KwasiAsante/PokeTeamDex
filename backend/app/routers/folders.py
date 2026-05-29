from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.core.deps import CurrentUser, DB
from app.models.team import TeamFolder
from app.schemas.team import FolderCreate, FolderResponse, FolderUpdate

router = APIRouter(prefix="/folders", tags=["folders"])


@router.get("", response_model=list[FolderResponse])
async def list_folders(current_user: CurrentUser, db: DB) -> list[FolderResponse]:
    result = await db.execute(
        select(TeamFolder).where(TeamFolder.user_id == current_user.id)
    )
    return [FolderResponse.model_validate(f) for f in result.scalars()]


@router.post("", response_model=FolderResponse, status_code=status.HTTP_201_CREATED)
async def create_folder(body: FolderCreate, current_user: CurrentUser, db: DB) -> FolderResponse:
    folder = TeamFolder(user_id=current_user.id, name=body.name)
    db.add(folder)
    await db.commit()
    await db.refresh(folder)
    return FolderResponse.model_validate(folder)


@router.patch("/{folder_id}", response_model=FolderResponse)
async def rename_folder(
    folder_id: int, body: FolderUpdate, current_user: CurrentUser, db: DB
) -> FolderResponse:
    folder = await _get_owned_folder(folder_id, current_user.id, db)
    folder.name = body.name
    await db.commit()
    await db.refresh(folder)
    return FolderResponse.model_validate(folder)


@router.delete("/{folder_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_folder(folder_id: int, current_user: CurrentUser, db: DB) -> None:
    folder = await _get_owned_folder(folder_id, current_user.id, db)
    await db.delete(folder)
    await db.commit()


async def _get_owned_folder(folder_id: int, user_id: int, db: DB) -> TeamFolder:
    result = await db.execute(
        select(TeamFolder).where(
            TeamFolder.id == folder_id, TeamFolder.user_id == user_id
        )
    )
    folder = result.scalar_one_or_none()
    if folder is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Folder not found")
    return folder
