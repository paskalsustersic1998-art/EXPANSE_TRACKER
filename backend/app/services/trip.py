from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.expense import Expense, ExpenseSplit
from app.models.settlement import Settlement
from app.models.trip import Trip, trip_participants
from app.models.user import User
from app.schemas.trip import AddParticipantRequest, TripCreate, TripUpdate


def create_trip(db: Session, data: TripCreate, creator_id: int) -> Trip:
    trip = Trip(name=data.name, description=data.description, created_by=creator_id)
    db.add(trip)
    db.flush()  # get trip.id before inserting participant
    db.execute(trip_participants.insert().values(trip_id=trip.id, user_id=creator_id))
    db.commit()
    db.refresh(trip)
    return trip


def get_trip(db: Session, trip_id: int, user_id: int) -> Trip:
    trip = db.get(Trip, trip_id)
    if trip is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
    is_participant = any(p.id == user_id for p in trip.participants)
    if not is_participant:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trip not found")
    return trip


def add_participant(db: Session, trip_id: int, data: AddParticipantRequest, caller_id: int) -> Trip:
    trip = get_trip(db, trip_id, caller_id)

    target = db.query(User).filter(User.email == data.email).first()
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if any(p.id == target.id for p in trip.participants):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is already a participant",
        )

    db.execute(trip_participants.insert().values(trip_id=trip.id, user_id=target.id))
    db.commit()
    db.refresh(trip)
    return trip


def delete_trip(db: Session, trip_id: int, current_user_id: int) -> None:
    trip = get_trip(db, trip_id, current_user_id)

    last_settlement = (
        db.query(Settlement)
        .filter(Settlement.trip_id == trip_id)
        .order_by(Settlement.created_at.desc())
        .first()
    )

    # Active = not individually settled AND after the last trip-level settlement (if any)
    active_query = db.query(Expense).filter(
        Expense.trip_id == trip_id,
        Expense.is_settled == False,  # noqa: E712
    )
    if last_settlement:
        active_query = active_query.filter(Expense.created_at > last_settlement.created_at)

    if active_query.count() > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Trip has unsettled expenses. Settle all expenses first.",
        )
    db.delete(trip)
    db.commit()


def remove_participant(db: Session, trip_id: int, participant_id: int, caller_id: int) -> Trip:
    trip = get_trip(db, trip_id, caller_id)

    target = next((p for p in trip.participants if p.id == participant_id), None)
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Participant not found")

    paid_count = db.query(Expense).filter(
        Expense.trip_id == trip_id, Expense.paid_by == participant_id
    ).count()
    if paid_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot remove participant who has paid expenses.",
        )

    split_count = (
        db.query(ExpenseSplit)
        .join(Expense, ExpenseSplit.expense_id == Expense.id)
        .filter(Expense.trip_id == trip_id, ExpenseSplit.user_id == participant_id)
        .count()
    )
    if split_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot remove participant who is part of expense splits.",
        )

    db.execute(
        trip_participants.delete().where(
            trip_participants.c.trip_id == trip_id,
            trip_participants.c.user_id == participant_id,
        )
    )
    db.commit()
    db.refresh(trip)
    return trip


def update_trip(db: Session, trip_id: int, data: TripUpdate, current_user_id: int) -> Trip:
    trip = get_trip(db, trip_id, current_user_id)
    if data.name is not None:
        trip.name = data.name
    if data.description is not None:
        trip.description = data.description
    db.commit()
    db.refresh(trip)
    return trip


def list_user_trips(db: Session, user_id: int) -> list[Trip]:
    return (
        db.query(Trip)
        .join(trip_participants, Trip.id == trip_participants.c.trip_id)
        .filter(trip_participants.c.user_id == user_id)
        .all()
    )
