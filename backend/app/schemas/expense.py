from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, field_validator


class ExpenseCreate(BaseModel):
    amount: Decimal
    description: str
    paid_by: int | None = None  # defaults to current user in service layer
    split_among: list[int] | None = None  # subset of participant IDs; None = all

    @field_validator("amount")
    @classmethod
    def amount_must_be_positive(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("amount must be greater than zero")
        return v


class SplitRead(BaseModel):
    user_id: int
    share: Decimal

    model_config = {"from_attributes": True}


class ExpenseRead(BaseModel):
    id: int
    trip_id: int
    paid_by: int
    amount: Decimal
    description: str
    is_settled: bool
    created_at: datetime
    splits: list[SplitRead]

    model_config = {"from_attributes": True}


class ExpenseUpdate(BaseModel):
    description: str | None = None
    amount: Decimal | None = None
    paid_by: int | None = None
    split_among: list[int] | None = None

    @field_validator("amount")
    @classmethod
    def amount_must_be_positive(cls, v: Decimal | None) -> Decimal | None:
        if v is not None and v <= 0:
            raise ValueError("amount must be greater than zero")
        return v


class BalanceEntry(BaseModel):
    user_id: int
    email: str
    net: Decimal  # positive = is owed money; negative = owes money
