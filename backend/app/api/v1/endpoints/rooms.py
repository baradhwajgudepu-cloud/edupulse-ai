import uuid
from typing import List, Optional
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Query, status, HTTPException
from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.auth import require_permission
from app.models.room import Room
from app.models.user import User
from app.schemas.room import RoomCreate, RoomUpdate, RoomResponse
from app.schemas.response import APIResponse

router = APIRouter()

@router.post(
    "",
    response_model=APIResponse[RoomResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Create a new room"
)
async def create_room(
    obj_in: RoomCreate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.update", "school.write")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[RoomResponse]:
    # Check duplicate room_number in this school
    stmt_check = select(Room).where(
        Room.tenant_id == tenant_id,
        Room.school_id == obj_in.school_id,
        Room.room_number == obj_in.room_number.strip(),
        Room.deleted_at.is_(None)
    )
    existing = (await db.execute(stmt_check)).scalar_one_or_none()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"A room with number '{obj_in.room_number}' already exists in this school."
        )

    room = Room(
        tenant_id=tenant_id,
        school_id=obj_in.school_id,
        room_number=obj_in.room_number.strip(),
        name=obj_in.name.strip(),
        room_type=obj_in.room_type.strip(),
        capacity=obj_in.capacity,
        floor=obj_in.floor.strip() if obj_in.floor else None,
        building=obj_in.building.strip() if obj_in.building else None,
        is_active=obj_in.is_active,
        settings=obj_in.settings,
        created_by=current_user.id,
        updated_by=current_user.id
    )
    db.add(room)
    await db.commit()
    await db.refresh(room)

    return APIResponse[RoomResponse](
        success=True,
        message="Room created successfully.",
        data=RoomResponse.model_validate(room)
    )

@router.get(
    "",
    response_model=APIResponse[List[RoomResponse]],
    status_code=status.HTTP_200_OK,
    summary="List rooms under school"
)
async def list_rooms(
    school_id: uuid.UUID = Query(..., description="Target school ID"),
    room_type: Optional[str] = Query(None, description="Filter by room type"),
    is_active: Optional[bool] = Query(None, description="Filter by active status"),
    search: Optional[str] = Query(None, description="Search room number or name"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=100),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[RoomResponse]]:
    query = select(Room).where(
        Room.tenant_id == tenant_id,
        Room.school_id == school_id,
        Room.deleted_at.is_(None)
    )
    if room_type:
        query = query.where(Room.room_type == room_type)
    if is_active is not None:
        query = query.where(Room.is_active == is_active)
    if search:
        search_fmt = f"%{search.strip()}%"
        query = query.where(
            (Room.room_number.ilike(search_fmt)) | (Room.name.ilike(search_fmt))
        )

    query = query.order_by(Room.room_number.asc()).offset(skip).limit(limit)
    res = await db.execute(query)
    rooms = res.scalars().all()

    return APIResponse[List[RoomResponse]](
        success=True,
        message="Rooms retrieved successfully.",
        data=[RoomResponse.model_validate(r) for r in rooms]
    )

@router.get(
    "/{room_id}",
    response_model=APIResponse[RoomResponse],
    status_code=status.HTTP_200_OK,
    summary="Get single room"
)
async def get_room(
    room_id: uuid.UUID,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.read")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[RoomResponse]:
    stmt = select(Room).where(
        Room.id == room_id,
        Room.tenant_id == tenant_id,
        Room.deleted_at.is_(None)
    )
    room = (await db.execute(stmt)).scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found.")

    return APIResponse[RoomResponse](
        success=True,
        message="Room details retrieved.",
        data=RoomResponse.model_validate(room)
    )

@router.put(
    "/{room_id}",
    response_model=APIResponse[RoomResponse],
    status_code=status.HTTP_200_OK,
    summary="Update room"
)
async def update_room(
    room_id: uuid.UUID,
    obj_in: RoomUpdate,
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.update", "school.write")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[RoomResponse]:
    stmt = select(Room).where(
        Room.id == room_id,
        Room.tenant_id == tenant_id,
        Room.deleted_at.is_(None)
    )
    room = (await db.execute(stmt)).scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found.")

    if obj_in.room_number is not None and obj_in.room_number.strip() != room.room_number:
        # Check uniqueness
        stmt_dup = select(Room).where(
            Room.tenant_id == tenant_id,
            Room.school_id == room.school_id,
            Room.room_number == obj_in.room_number.strip(),
            Room.id != room.id,
            Room.deleted_at.is_(None)
        )
        if (await db.execute(stmt_dup)).scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"A room with number '{obj_in.room_number}' already exists in this school."
            )
        room.room_number = obj_in.room_number.strip()

    if obj_in.name is not None:
        room.name = obj_in.name.strip()
    if obj_in.room_type is not None:
        room.room_type = obj_in.room_type.strip()
    if obj_in.capacity is not None:
        room.capacity = obj_in.capacity
    if obj_in.floor is not None:
        room.floor = obj_in.floor.strip() if obj_in.floor else None
    if obj_in.building is not None:
        room.building = obj_in.building.strip() if obj_in.building else None
    if obj_in.is_active is not None:
        room.is_active = obj_in.is_active
    if obj_in.settings is not None:
        room.settings = obj_in.settings

    room.updated_by = current_user.id
    await db.commit()
    await db.refresh(room)

    return APIResponse[RoomResponse](
        success=True,
        message="Room updated successfully.",
        data=RoomResponse.model_validate(room)
    )

@router.delete(
    "/{room_id}",
    response_model=APIResponse[bool],
    status_code=status.HTTP_200_OK,
    summary="Delete or deactivate room"
)
async def delete_room(
    room_id: uuid.UUID,
    permanent: bool = Query(False, description="Whether to soft-delete"),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    current_user: User = Depends(require_permission("school.update", "school.write")),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[bool]:
    stmt = select(Room).where(
        Room.id == room_id,
        Room.tenant_id == tenant_id,
        Room.deleted_at.is_(None)
    )
    room = (await db.execute(stmt)).scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found.")

    room.deleted_at = datetime.now(timezone.utc)
    room.is_active = False
    room.updated_by = current_user.id
    await db.commit()

    return APIResponse[bool](
        success=True,
        message="Room deleted successfully.",
        data=True
    )
