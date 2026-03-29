from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class SettlementTransactionRead(BaseModel):
    id: int
    from_user_id: int
    from_email: str
    to_user_id: int
    to_email: str
    amount: Decimal


class SettlementRead(BaseModel):
    id: int
    trip_id: int
    created_by: int
    created_at: datetime
    transactions: list[SettlementTransactionRead]
