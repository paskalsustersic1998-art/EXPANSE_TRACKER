from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_user
from app.models.user import User
from app.schemas.expense import BalanceEntry, ExpenseCreate, ExpenseRead, ExpenseUpdate
from app.schemas.settlement import SettlementRead
from app.services import expense as expense_service
from app.services import settlement as settlement_service

router = APIRouter()


@router.get("/{trip_id}/expenses", response_model=list[ExpenseRead])
def list_expenses(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return expense_service.list_expenses(db, trip_id, current_user.id)


@router.post("/{trip_id}/expenses", response_model=ExpenseRead, status_code=201)
def create_expense(
    trip_id: int,
    data: ExpenseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return expense_service.create_expense(db, trip_id, data, current_user.id)


@router.get("/{trip_id}/balances", response_model=list[BalanceEntry])
def get_balances(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return expense_service.get_balances(db, trip_id, current_user.id)


@router.delete("/{trip_id}/expenses/{expense_id}", status_code=204)
def delete_expense(
    trip_id: int,
    expense_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    expense_service.delete_expense(db, trip_id, expense_id, current_user.id)
    return Response(status_code=204)


@router.patch("/{trip_id}/expenses/{expense_id}/settle", response_model=ExpenseRead)
def settle_expense(
    trip_id: int,
    expense_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return expense_service.settle_expense(db, trip_id, expense_id, current_user.id)


@router.patch("/{trip_id}/expenses/{expense_id}", response_model=ExpenseRead)
def update_expense(
    trip_id: int,
    expense_id: int,
    data: ExpenseUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return expense_service.update_expense(db, trip_id, expense_id, data, current_user.id)


@router.get("/{trip_id}/settlements", response_model=list[SettlementRead])
def list_settlements(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return settlement_service.list_settlements(db, trip_id, current_user.id)


@router.post("/{trip_id}/settlements", response_model=SettlementRead, status_code=201)
def create_settlement(
    trip_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return settlement_service.create_settlement(db, trip_id, current_user.id)
