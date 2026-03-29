from decimal import Decimal, ROUND_HALF_UP

from sqlalchemy.orm import Session

from app.models.settlement import Settlement, SettlementTransaction
from app.models.user import User
from app.schemas.settlement import SettlementRead, SettlementTransactionRead
from app.services import expense as expense_service
from app.services import trip as trip_service


def create_settlement(db: Session, trip_id: int, current_user_id: int) -> SettlementRead:
    trip = trip_service.get_trip(db, trip_id, current_user_id)
    balance_entries = expense_service.get_balances(db, trip_id, current_user_id)

    participant_map = {e.user_id: e.email for e in balance_entries}

    # Mutable lists: [user_id, amount] — debtors owe, creditors are owed
    debtors = [[e.user_id, abs(e.net)] for e in balance_entries if e.net < 0]
    creditors = [[e.user_id, e.net] for e in balance_entries if e.net > 0]

    raw_transactions: list[tuple[int, int, Decimal]] = []
    while debtors and creditors:
        debtor_id, debt = debtors[0]
        creditor_id, credit = creditors[0]
        settle = min(debt, credit).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        raw_transactions.append((debtor_id, creditor_id, settle))
        debtors[0][1] -= settle
        creditors[0][1] -= settle
        if debtors[0][1] == 0:
            debtors.pop(0)
        if creditors[0][1] == 0:
            creditors.pop(0)

    settlement = Settlement(trip_id=trip.id, created_by=current_user_id)
    db.add(settlement)
    db.flush()

    txn_objects: list[SettlementTransaction] = []
    for from_id, to_id, amount in raw_transactions:
        st = SettlementTransaction(
            settlement_id=settlement.id,
            from_user_id=from_id,
            to_user_id=to_id,
            amount=amount,
        )
        db.add(st)
        txn_objects.append(st)

    db.commit()
    db.refresh(settlement)

    return SettlementRead(
        id=settlement.id,
        trip_id=settlement.trip_id,
        created_by=settlement.created_by,
        created_at=settlement.created_at,
        transactions=[
            SettlementTransactionRead(
                id=st.id,
                from_user_id=st.from_user_id,
                from_email=participant_map[st.from_user_id],
                to_user_id=st.to_user_id,
                to_email=participant_map[st.to_user_id],
                amount=st.amount,
            )
            for st in txn_objects
        ],
    )


def list_settlements(db: Session, trip_id: int, current_user_id: int) -> list[SettlementRead]:
    trip_service.get_trip(db, trip_id, current_user_id)
    settlements = (
        db.query(Settlement)
        .filter(Settlement.trip_id == trip_id)
        .order_by(Settlement.created_at.desc())
        .all()
    )
    if not settlements:
        return []
    user_ids = (
        {t.from_user_id for s in settlements for t in s.transactions}
        | {t.to_user_id for s in settlements for t in s.transactions}
    )
    user_map = {u.id: u.email for u in db.query(User).filter(User.id.in_(user_ids)).all()}
    return [
        SettlementRead(
            id=s.id,
            trip_id=s.trip_id,
            created_by=s.created_by,
            created_at=s.created_at,
            transactions=[
                SettlementTransactionRead(
                    id=t.id,
                    from_user_id=t.from_user_id,
                    from_email=user_map.get(t.from_user_id, "Unknown"),
                    to_user_id=t.to_user_id,
                    to_email=user_map.get(t.to_user_id, "Unknown"),
                    amount=t.amount,
                )
                for t in s.transactions
            ],
        )
        for s in settlements
    ]
