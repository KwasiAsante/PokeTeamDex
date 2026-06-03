from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.core.deps import CurrentUser, DB
from app.models.team import PokemonInstance
from app.schemas.team import InstanceResponse, InstanceUpdate

router = APIRouter(prefix="/instances", tags=["instances"])


@router.get("", response_model=list[InstanceResponse])
async def list_instances(current_user: CurrentUser, db: DB) -> list[InstanceResponse]:
    result = await db.execute(
        select(PokemonInstance).where(
            PokemonInstance.user_id == current_user.id,
            PokemonInstance.is_deleted == False,  # noqa: E712
        )
    )
    return [InstanceResponse.model_validate(i) for i in result.scalars()]


@router.get("/{instance_id}", response_model=InstanceResponse)
async def get_instance(instance_id: int, current_user: CurrentUser, db: DB) -> InstanceResponse:
    instance = await _get_owned_instance(instance_id, current_user.id, db)
    return InstanceResponse.model_validate(instance)


@router.patch("/{instance_id}", response_model=InstanceResponse)
async def update_instance(
    instance_id: int, body: InstanceUpdate, current_user: CurrentUser, db: DB
) -> InstanceResponse:
    instance = await _get_owned_instance(instance_id, current_user.id, db)
    if body.nickname_aliases is not None:
        instance.nickname_aliases = body.nickname_aliases
    if body.inherited_ribbons is not None:
        instance.inherited_ribbons = body.inherited_ribbons
    await db.commit()
    await db.refresh(instance)
    return InstanceResponse.model_validate(instance)


@router.delete("/{instance_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_instance(instance_id: int, current_user: CurrentUser, db: DB) -> None:
    instance = await _get_owned_instance(instance_id, current_user.id, db)
    instance.is_deleted = True
    await db.commit()


async def _get_owned_instance(instance_id: int, user_id: int, db: DB) -> PokemonInstance:
    result = await db.execute(
        select(PokemonInstance).where(
            PokemonInstance.id == instance_id,
            PokemonInstance.user_id == user_id,
            PokemonInstance.is_deleted == False,  # noqa: E712
        )
    )
    instance = result.scalar_one_or_none()
    if instance is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Instance not found")
    return instance
