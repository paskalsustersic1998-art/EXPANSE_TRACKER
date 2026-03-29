from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from app.core.security import get_password_hash
from app.models.trip import trip_participants
from app.models.user import User

EXPENSES_URL = "/trips/{trip_id}/expenses"
BALANCES_URL = "/trips/{trip_id}/balances"
SETTLE_EXPENSE_URL = "/trips/{trip_id}/expenses/{expense_id}/settle"

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
    paid_by: int | None = None,
):
    body: dict = {"amount": amount, "description": description}
    if paid_by is not None:
        body["paid_by"] = paid_by
    return client.post(
        EXPENSES_URL.format(trip_id=trip_id),
        json=body,
        headers=_auth_header(token),
    )


@pytest.fixture
def user_and_token(client, db):
    user = User(email=USER_EMAIL, hashed_password=get_password_hash(PASSWORD))
    db.add(user)
    db.commit()
    db.refresh(user)
    token = client.post("/auth/login", json={"email": USER_EMAIL, "password": PASSWORD}).json()[
        "access_token"
    ]
    return user, token


@pytest.fixture
def other_and_token(client, db):
    user = User(email=OTHER_EMAIL, hashed_password=get_password_hash(PASSWORD))
    db.add(user)
    db.commit()
    db.refresh(user)
    token = client.post("/auth/login", json={"email": OTHER_EMAIL, "password": PASSWORD}).json()[
        "access_token"
    ]
    return user, token


@pytest.fixture
def two_user_trip(client, db, user_and_token, other_and_token):
    """Trip owned by user, with other as second participant."""
    user, user_token = user_and_token
    other, other_token = other_and_token

    resp = client.post("/trips", json={"name": "Group Trip"}, headers=_auth_header(user_token))
    trip_id = resp.json()["id"]

    # Add second participant directly (mirrors what trip service does)
    db.execute(trip_participants.insert().values(trip_id=trip_id, user_id=other.id))
    db.commit()

    return trip_id, user, user_token, other, other_token


# ---------------------------------------------------------------------------
# POST /trips/{id}/expenses
# ---------------------------------------------------------------------------

def test_create_expense_success(client, two_user_trip):
    trip_id, user, user_token, other, _ = two_user_trip
    response = _create_expense(client, user_token, trip_id)
    assert response.status_code == 201
    data = response.json()
    assert data["trip_id"] == trip_id
    assert data["paid_by"] == user.id
    assert Decimal(data["amount"]) == Decimal("30.00")
    assert data["description"] == "Dinner"
    assert "created_at" in data
    assert len(data["splits"]) == 2


def test_create_expense_splits_equal(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    response = _create_expense(client, user_token, trip_id, amount="10.00")
    assert response.status_code == 201
    shares = {s["share"] for s in response.json()["splits"]}
    assert shares == {"5.00"}


def test_create_expense_paid_by_defaults_to_current_user(client, two_user_trip):
    trip_id, user, user_token, _, _ = two_user_trip
    response = _create_expense(client, user_token, trip_id)
    assert response.json()["paid_by"] == user.id


def test_create_expense_paid_by_override(client, two_user_trip):
    trip_id, _, user_token, other, _ = two_user_trip
    response = _create_expense(client, user_token, trip_id, paid_by=other.id)
    assert response.status_code == 201
    assert response.json()["paid_by"] == other.id


def test_create_expense_paid_by_non_participant(client, db, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    outsider = User(email="outsider@example.com", hashed_password=get_password_hash(PASSWORD))
    db.add(outsider)
    db.commit()
    response = _create_expense(client, user_token, trip_id, paid_by=outsider.id)
    assert response.status_code == 400
    assert "not a trip participant" in response.json()["detail"]


def test_create_expense_zero_amount(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    response = _create_expense(client, user_token, trip_id, amount="0")
    assert response.status_code == 422


def test_create_expense_negative_amount(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    response = _create_expense(client, user_token, trip_id, amount="-10")
    assert response.status_code == 422


def test_create_expense_missing_description(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    response = client.post(
        EXPENSES_URL.format(trip_id=trip_id),
        json={"amount": "10.00"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 422


def test_create_expense_missing_amount(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    response = client.post(
        EXPENSES_URL.format(trip_id=trip_id),
        json={"description": "Dinner"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 422


def test_create_expense_not_participant(client, two_user_trip, db):
    trip_id, _, _, _, _ = two_user_trip
    outsider = User(email="stranger@example.com", hashed_password=get_password_hash(PASSWORD))
    db.add(outsider)
    db.commit()
    token = client.post(
        "/auth/login", json={"email": "stranger@example.com", "password": PASSWORD}
    ).json()["access_token"]
    response = _create_expense(client, token, trip_id)
    assert response.status_code == 404


def test_create_expense_nonexistent_trip(client, user_and_token):
    _, token = user_and_token
    response = _create_expense(client, token, trip_id=99999)
    assert response.status_code == 404


def test_create_expense_no_auth(client, two_user_trip):
    trip_id, _, _, _, _ = two_user_trip
    response = client.post(EXPENSES_URL.format(trip_id=trip_id), json={"amount": "10.00", "description": "x"})
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# GET /trips/{id}/balances
# ---------------------------------------------------------------------------

def test_get_balances_no_expenses(client, two_user_trip):
    trip_id, user, user_token, other, _ = two_user_trip
    response = client.get(BALANCES_URL.format(trip_id=trip_id), headers=_auth_header(user_token))
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    nets = {entry["net"] for entry in data}
    assert nets == {"0.00"}


def test_get_balances_single_expense(client, two_user_trip):
    trip_id, user, user_token, other, _ = two_user_trip
    _create_expense(client, user_token, trip_id, amount="10.00")

    response = client.get(BALANCES_URL.format(trip_id=trip_id), headers=_auth_header(user_token))
    data = {e["user_id"]: Decimal(e["net"]) for e in response.json()}

    assert data[user.id] == Decimal("5.00")
    assert data[other.id] == Decimal("-5.00")


def test_get_balances_both_paid_equally(client, two_user_trip):
    trip_id, user, user_token, other, other_token = two_user_trip
    _create_expense(client, user_token, trip_id, amount="10.00")
    _create_expense(client, other_token, trip_id, amount="10.00")

    response = client.get(BALANCES_URL.format(trip_id=trip_id), headers=_auth_header(user_token))
    nets = {Decimal(e["net"]) for e in response.json()}
    assert nets == {Decimal("0.00")}


def test_get_balances_asymmetric(client, two_user_trip):
    trip_id, user, user_token, other, other_token = two_user_trip
    _create_expense(client, user_token, trip_id, amount="20.00")
    _create_expense(client, other_token, trip_id, amount="10.00")

    response = client.get(BALANCES_URL.format(trip_id=trip_id), headers=_auth_header(user_token))
    data = {e["user_id"]: Decimal(e["net"]) for e in response.json()}

    assert data[user.id] == Decimal("5.00")
    assert data[other.id] == Decimal("-5.00")


def test_get_balances_all_participants_present(client, two_user_trip):
    trip_id, user, user_token, other, _ = two_user_trip
    # No expenses — both users still appear
    response = client.get(BALANCES_URL.format(trip_id=trip_id), headers=_auth_header(user_token))
    user_ids = {e["user_id"] for e in response.json()}
    assert user.id in user_ids
    assert other.id in user_ids


def test_get_balances_not_participant(client, two_user_trip, db):
    trip_id, _, _, _, _ = two_user_trip
    stranger = User(email="x@example.com", hashed_password=get_password_hash(PASSWORD))
    db.add(stranger)
    db.commit()
    token = client.post("/auth/login", json={"email": "x@example.com", "password": PASSWORD}).json()[
        "access_token"
    ]
    response = client.get(BALANCES_URL.format(trip_id=trip_id), headers=_auth_header(token))
    assert response.status_code == 404


def test_get_balances_nonexistent_trip(client, user_and_token):
    _, token = user_and_token
    response = client.get(BALANCES_URL.format(trip_id=99999), headers=_auth_header(token))
    assert response.status_code == 404


def test_get_balances_no_auth(client, two_user_trip):
    trip_id, _, _, _, _ = two_user_trip
    response = client.get(BALANCES_URL.format(trip_id=trip_id))
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# POST /trips/{id}/expenses — split_among field
# ---------------------------------------------------------------------------

def test_create_expense_split_among_subset(client, two_user_trip):
    """Expense split among only 1 of 2 participants creates a single split."""
    trip_id, user, user_token, _, _ = two_user_trip
    response = client.post(
        EXPENSES_URL.format(trip_id=trip_id),
        json={"amount": "30.00", "description": "Solo dinner", "split_among": [user.id]},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 201
    data = response.json()
    assert len(data["splits"]) == 1
    assert data["splits"][0]["user_id"] == user.id
    assert Decimal(data["splits"][0]["share"]) == Decimal("30.00")


def test_create_expense_split_among_subset_balances(client, two_user_trip):
    """Partial split affects only the included participant's balance."""
    trip_id, user, user_token, other, _ = two_user_trip
    # user pays $30 split only among user → user net = +30 - 30 = 0, other net = 0
    client.post(
        EXPENSES_URL.format(trip_id=trip_id),
        json={"amount": "30.00", "description": "Solo", "split_among": [user.id]},
        headers=_auth_header(user_token),
    )
    response = client.get(BALANCES_URL.format(trip_id=trip_id), headers=_auth_header(user_token))
    data = {e["user_id"]: Decimal(e["net"]) for e in response.json()}
    assert data[user.id] == Decimal("0.00")
    assert data[other.id] == Decimal("0.00")


def test_create_expense_split_among_non_participant(client, db, two_user_trip):
    """400 when split_among contains a non-participant user id."""
    trip_id, _, user_token, _, _ = two_user_trip
    outsider = User(email="outsider@example.com", hashed_password=get_password_hash(PASSWORD))
    db.add(outsider)
    db.commit()
    response = client.post(
        EXPENSES_URL.format(trip_id=trip_id),
        json={"amount": "10.00", "description": "x", "split_among": [outsider.id]},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 400
    assert "non-participants" in response.json()["detail"]


# ---------------------------------------------------------------------------
# PATCH /trips/{id}/expenses/{eid}/settle
# ---------------------------------------------------------------------------

def test_settle_expense_success(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    response = client.patch(
        SETTLE_EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        headers=_auth_header(user_token),
    )
    assert response.status_code == 200
    assert response.json()["is_settled"] is True


def test_settle_expense_already_settled(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    client.patch(
        SETTLE_EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        headers=_auth_header(user_token),
    )
    response = client.patch(
        SETTLE_EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        headers=_auth_header(user_token),
    )
    assert response.status_code == 400
    assert "already settled" in response.json()["detail"]


def test_settle_expense_removes_from_balances(client, two_user_trip):
    """Settling an expense zeros out its contribution to balances."""
    trip_id, user, user_token, other, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id, amount="20.00").json()["id"]
    balances_before = {
        e["user_id"]: Decimal(e["net"])
        for e in client.get(BALANCES_URL.format(trip_id=trip_id), headers=_auth_header(user_token)).json()
    }
    assert balances_before[user.id] == Decimal("10.00")
    assert balances_before[other.id] == Decimal("-10.00")

    client.patch(
        SETTLE_EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        headers=_auth_header(user_token),
    )
    nets = {
        Decimal(e["net"])
        for e in client.get(BALANCES_URL.format(trip_id=trip_id), headers=_auth_header(user_token)).json()
    }
    assert nets == {Decimal("0.00")}


def test_settle_expense_still_visible_in_list(client, two_user_trip):
    """Settled expense remains in the list with is_settled=True."""
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    client.patch(
        SETTLE_EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id),
        headers=_auth_header(user_token),
    )
    response = client.get(EXPENSES_URL.format(trip_id=trip_id), headers=_auth_header(user_token))
    assert response.status_code == 200
    expenses = response.json()
    assert len(expenses) == 1
    assert expenses[0]["id"] == expense_id
    assert expenses[0]["is_settled"] is True


def test_settle_expense_not_found(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    response = client.patch(
        SETTLE_EXPENSE_URL.format(trip_id=trip_id, expense_id=99999),
        headers=_auth_header(user_token),
    )
    assert response.status_code == 404


def test_settle_expense_wrong_trip(client, two_user_trip):
    """Expense belonging to trip A cannot be settled via trip B's URL."""
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    other_trip_id = client.post(
        "/trips", json={"name": "Other"}, headers=_auth_header(user_token)
    ).json()["id"]
    response = client.patch(
        SETTLE_EXPENSE_URL.format(trip_id=other_trip_id, expense_id=expense_id),
        headers=_auth_header(user_token),
    )
    assert response.status_code == 404


def test_settle_expense_no_auth(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    response = client.patch(
        SETTLE_EXPENSE_URL.format(trip_id=trip_id, expense_id=expense_id)
    )
    assert response.status_code == 401
