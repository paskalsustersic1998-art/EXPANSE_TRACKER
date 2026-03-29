from decimal import Decimal, ROUND_HALF_UP

from fastapi import HTTPException, status
from sqlalchemy import desc
from sqlalchemy.orm import Session

from app.models.expense import Expense, ExpenseSplit
from app.models.settlement import Settlement
from app.schemas.expense import BalanceEntry, ExpenseCreate, ExpenseUpdate
from app.services import trip as trip_service


def create_expense(
    db: Session,
    trip_id: int,
    data: ExpenseCreate,
    current_user_id: int,
) -> Expense:
    trip = trip_service.get_trip(db, trip_id, current_user_id)

    # Resolve paid_by — default to caller, else validate override is a participant
    if data.paid_by is None:
        payer_id = current_user_id
    else:
        if not any(p.id == data.paid_by for p in trip.participants):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="paid_by user is not a trip participant",
            )
        payer_id = data.paid_by

    # Resolve which participants share this expense
    if data.split_among:
        participant_ids = {p.id for p in trip.participants}
        if any(uid not in participant_ids for uid in data.split_among):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="split_among contains non-participants",
            )
        split_participants = [p for p in trip.participants if p.id in set(data.split_among)]
    else:
        split_participants = list(trip.participants)

    # Equal split rounded to 2 decimal places
    participant_count = len(split_participants)
    share = (data.amount / Decimal(participant_count)).quantize(
        Decimal("0.01"), rounding=ROUND_HALF_UP
    )

    expense = Expense(
        trip_id=trip_id,
        paid_by=payer_id,
        amount=data.amount,
        description=data.description,
    )
    db.add(expense)
    db.flush()

    for participant in split_participants:
        db.add(ExpenseSplit(expense_id=expense.id, user_id=participant.id, share=share))

    db.commit()
    db.refresh(expense)
    return expense


def list_expenses(
    db: Session,
    trip_id: int,
    current_user_id: int,
) -> list[Expense]:
    trip_service.get_trip(db, trip_id, current_user_id)
    last_settlement = (
        db.query(Settlement)
        .filter(Settlement.trip_id == trip_id)
        .order_by(desc(Settlement.created_at))
        .first()
    )
    query = db.query(Expense).filter(Expense.trip_id == trip_id)
    if last_settlement:
        query = query.filter(Expense.created_at > last_settlement.created_at)
    return query.order_by(Expense.created_at.desc()).all()


def settle_expense(
    db: Session,
    trip_id: int,
    expense_id: int,
    current_user_id: int,
) -> Expense:
    trip_service.get_trip(db, trip_id, current_user_id)
    expense = db.get(Expense, expense_id)
    if expense is None or expense.trip_id != trip_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Expense not found")
    if expense.is_settled:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Expense is already settled")
    expense.is_settled = True
    db.commit()
    db.refresh(expense)
    return expense


def delete_expense(
    db: Session,
    trip_id: int,
    expense_id: int,
    current_user_id: int,
) -> None:
    trip_service.get_trip(db, trip_id, current_user_id)
    expense = db.get(Expense, expense_id)
    if expense is None or expense.trip_id != trip_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Expense not found")
    db.delete(expense)
    db.commit()


def update_expense(
    db: Session,
    trip_id: int,
    expense_id: int,
    data: ExpenseUpdate,
    current_user_id: int,
) -> Expense:
    trip = trip_service.get_trip(db, trip_id, current_user_id)
    expense = db.get(Expense, expense_id)
    if expense is None or expense.trip_id != trip_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Expense not found")
    if expense.is_settled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot edit a settled expense"
        )

    if data.description is not None:
        expense.description = data.description

    if data.paid_by is not None:
        if data.paid_by not in {p.id for p in trip.participants}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="paid_by must be a trip participant",
            )
        expense.paid_by = data.paid_by

    if data.amount is not None or data.split_among is not None:
        # Capture current split user IDs BEFORE deleting them
        existing_split_ids = {s.user_id for s in expense.splits}
        new_split_ids = set(data.split_among) if data.split_among is not None else existing_split_ids
        if not new_split_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="split_among cannot be empty"
            )
        participant_ids = {p.id for p in trip.participants}
        if any(uid not in participant_ids for uid in new_split_ids):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="split_among contains non-participants",
            )

        if data.amount is not None:
            expense.amount = data.amount

        split_participants = [p for p in trip.participants if p.id in new_split_ids]
        share = (expense.amount / Decimal(len(split_participants))).quantize(
            Decimal("0.01"), rounding=ROUND_HALF_UP
        )
        for s in expense.splits:
            db.delete(s)
        db.flush()
        for p in split_participants:
            db.add(ExpenseSplit(expense_id=expense.id, user_id=p.id, share=share))

    db.commit()
    db.refresh(expense)
    return expense


def get_balances(
    db: Session,
    trip_id: int,
    current_user_id: int,
) -> list[BalanceEntry]:
    trip = trip_service.get_trip(db, trip_id, current_user_id)

    participant_map = {p.id: p for p in trip.participants}

    last_settlement = (
        db.query(Settlement)
        .filter(Settlement.trip_id == trip_id)
        .order_by(desc(Settlement.created_at))
        .first()
    )

    # Only count active expenses: not individually settled, and after last trip settlement
    expense_query = db.query(Expense).filter(
        Expense.trip_id == trip_id,
        Expense.is_settled == False,  # noqa: E712
    )
    if last_settlement:
        expense_query = expense_query.filter(
            Expense.created_at > last_settlement.created_at
        )
    expenses = expense_query.all()

    balances: dict[int, Decimal] = {p.id: Decimal("0.00") for p in trip.participants}

    for expense in expenses:
        balances[expense.paid_by] += expense.amount
        for split in expense.splits:
            balances[split.user_id] -= split.share

    return [
        BalanceEntry(user_id=uid, email=participant_map[uid].email, net=net)
        for uid, net in sorted(balances.items())
    ]
