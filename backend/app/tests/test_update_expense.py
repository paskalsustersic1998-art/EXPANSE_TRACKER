from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from app.core.security import get_password_hash
from app.models.trip import trip_participants
from app.models.user import User

EXPENSES_URL = "/trips/{trip_id}/expenses"
EXPENSE_URL = "/trips/{trip_id}/expenses/{expense_id}"
SETTLE_URL = "/trips/{trip_id}/expenses/{expense_id}/settle"
BALANCES_URL = "/trips/{trip_id}/balances"

USER_EMAIL = "user@example.com"
OTHER_EMAIL = "other@example.com"
PASSWORD = "secret123"


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create_expense(
    client: TestClient,
    token: str,
    trip_id: int,
    amount: str = "30.00",
    description: str = "Dinner",
):
    return client.post(
        EXPENSES_URL.format(trip_id=trip_id),
        json={"amount": amount, "description": description},
        headers=_auth_header(token),
    )


@pytest.fixture
def user_and_token(client, db):
    user = User(email=USER_EMAIL, hashed_password=get_password_hash(PASSWORD))
    db.add(user)
    db.commit()
    db.refresh(user)
    token = client.post(
        "/auth/login", json={"email": USER_EMAIL, "password": PASSWORD}
    ).json()["access_token"]
    return user, token


@pytest.fixture
def other_and_token(client, db):
    user = User(email=OTHER_EMAIL, hashed_password=get_password_hash(PASSWORD))
    db.add(user)
    db.commit()
    db.refresh(user)
    token = client.post(
        "/auth/login", json={"email": OTHER_EMAIL, "password": PASSWORD}
    ).json()["access_token"]
    return user, token


@pytest.fixture
def two_user_trip(client, db, user_and_token, other_and_token):
    user, user_token = user_and_token
    other, other_token = other_and_token
    resp = client.post("/trips", json={"name": "Group Trip"}, headers=_auth_header(user_token))
    trip_id = resp.json()["id"]
    db.execute(trip_participants.insert().values(trip_id=trip_id, user_id=other.id))
    db.commit()
    return trip_id, user, user_token, other, other_token


# ---------------------------------------------------------------------------
# PATCH /trips/{id}/expenses/{eid}
# ---------------------------------------------------------------------------

def test_update_expense_description(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    response = client.patch(
        EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        json={"description": "Lunch"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 200
    assert response.json()["description"] == "Lunch"


def test_update_expense_amount(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id, amount="20.00").json()["id"]
    response = client.patch(
        EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        json={"amount": "40.00"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 200
    assert Decimal(response.json()["amount"]) == Decimal("40.00")
    shares = {Decimal(s["share"]) for s in response.json()["splits"]}
    assert shares == {Decimal("20.00")}


def test_update_expense_recalculates_balances(client, two_user_trip):
    """After updating amount, balances reflect the new figure."""
    trip_id, user, user_token, other, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id, amount="20.00").json()["id"]
    client.patch(
        EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        json={"amount": "40.00"},
        headers=_auth_header(user_token),
    )
    data = {
        e["user_id"]: Decimal(e["net"])
        for e in client.get(
            BALANCES_URL.format(trip_id=trip_id), headers=_auth_header(user_token)
        ).json()
    }
    assert data[user.id] == Decimal("20.00")
    assert data[other.id] == Decimal("-20.00")


def test_update_expense_paid_by(client, two_user_trip):
    trip_id, _, user_token, other, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    response = client.patch(
        EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        json={"paid_by": other.id},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 200
    assert response.json()["paid_by"] == other.id


def test_update_expense_split_among(client, two_user_trip):
    """Updating split_among to a subset recalculates splits correctly."""
    trip_id, user, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id, amount="30.00").json()["id"]
    response = client.patch(
        EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        json={"split_among": [user.id]},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 200
    splits = response.json()["splits"]
    assert len(splits) == 1
    assert splits[0]["user_id"] == user.id
    assert Decimal(splits[0]["share"]) == Decimal("30.00")


def test_update_expense_preserves_unset_fields(client, two_user_trip):
    """Patching only description leaves amount and splits unchanged."""
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id, amount="20.00").json()["id"]
    response = client.patch(
        EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        json={"description": "Updated"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 200
    data = response.json()
    assert data["description"] == "Updated"
    assert Decimal(data["amount"]) == Decimal("20.00")
    assert len(data["splits"]) == 2


def test_update_expense_settled_blocked(client, two_user_trip):
    """Cannot edit an expense that has already been individually settled."""
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    client.patch(
        SETTLE_URL.format(trip_id=trip_id, expense_id=expense_id),
        headers=_auth_header(user_token),
    )
    response = client.patch(
        EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        json={"description": "Changed"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 400
    assert "settled" in response.json()["detail"]


def test_update_expense_invalid_paid_by(client, db, two_user_trip):
    """400 when paid_by is not a trip participant."""
    trip_id, _, user_token, _, _ = two_user_trip
    outsider = User(email="out@example.com", hashed_password=get_password_hash(PASSWORD))
    db.add(outsider)
    db.commit()
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    response = client.patch(
        EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        json={"paid_by": outsider.id},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 400
    assert "participant" in response.json()["detail"]


def test_update_expense_invalid_split_among(client, db, two_user_trip):
    """400 when split_among contains a non-participant."""
    trip_id, _, user_token, _, _ = two_user_trip
    outsider = User(email="out@example.com", hashed_password=get_password_hash(PASSWORD))
    db.add(outsider)
    db.commit()
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    response = client.patch(
        EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        json={"split_among": [outsider.id]},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 400
    assert "non-participants" in response.json()["detail"]


def test_update_expense_not_found(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    response = client.patch(
        EXPENSE_URL.format(trip_id=trip_id, expense_id=99999),
        json={"description": "x"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 404


def test_update_expense_no_auth(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    response = client.patch(
        EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        json={"description": "x"},
    )
    assert response.status_code == 401
