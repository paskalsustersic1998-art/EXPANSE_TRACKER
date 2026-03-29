from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.trip import AddParticipantRequest, TripCreate, TripRead, TripUpdate
from app.services import trip as trip_service

router = APIRouter()


@router.post("", response_model=TripRead, status_code=201)
def create_trip(
    data: TripCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return trip_service.create_trip(db, data, current_user.id)


@router.get("", response_model=list[TripRead])
def list_trips(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return trip_service.list_user_trips(db, current_user.id)


@router.get("/{trip_id}", response_model=TripRead)
def get_trip(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return trip_service.get_trip(db, trip_id, current_user.id)


@router.patch("/{trip_id}", response_model=TripRead)
def update_trip(
    trip_id: int,
    data: TripUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return trip_service.update_trip(db, trip_id, data, current_user.id)


@router.delete("/{trip_id}", status_code=204)
def delete_trip(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip_service.delete_trip(db, trip_id, current_user.id)
    return Response(status_code=204)


@router.post("/{trip_id}/participants", response_model=TripRead, status_code=201)
def add_participant(
    trip_id: int,
    data: AddParticipantRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return trip_service.add_participant(db, trip_id, data, current_user.id)


@router.delete("/{trip_id}/participants/{participant_id}", response_model=TripRead)
def remove_participant(
    trip_id: int,
    participant_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return trip_service.remove_participant(db, trip_id, participant_id, current_user.id)
