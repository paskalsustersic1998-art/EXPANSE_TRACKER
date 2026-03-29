import pytest
from fastapi.testclient import TestClient

from app.core.security import get_password_hash
from app.models.trip import trip_participants
from app.models.user import User

SETTLEMENTS_URL = "/trips/{trip_id}/settlements"
EXPENSES_URL = "/trips/{trip_id}/expenses"

USER_EMAIL = "user@example.com"
OTHER_EMAIL = "other@example.com"
THIRD_EMAIL = "third@example.com"
PASSWORD = "secret123"


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _settle(client: TestClient, token: str, trip_id: int):
    return client.post(
        SETTLEMENTS_URL.format(trip_id=trip_id),
        headers=_auth_header(token),
    )


def _create_expense(client: TestClient, token: str, trip_id: int, amount: str, paid_by: int | None = None):
    body: dict = {"amount": amount, "description": "Test expense"}
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
    token = client.post("/auth/login", json={"email": USER_EMAIL, "password": PASSWORD}).json()["access_token"]
    return user, token


@pytest.fixture
def other_and_token(client, db):
    user = User(email=OTHER_EMAIL, hashed_password=get_password_hash(PASSWORD))
    db.add(user)
    db.commit()
    db.refresh(user)
    token = client.post("/auth/login", json={"email": OTHER_EMAIL, "password": PASSWORD}).json()["access_token"]
    return user, token


@pytest.fixture
def third_and_token(client, db):
    user = User(email=THIRD_EMAIL, hashed_password=get_password_hash(PASSWORD))
    db.add(user)
    db.commit()
    db.refresh(user)
    token = client.post("/auth/login", json={"email": THIRD_EMAIL, "password": PASSWORD}).json()["access_token"]
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


@pytest.fixture
def three_user_trip(client, db, user_and_token, other_and_token, third_and_token):
    user, user_token = user_and_token
    other, _ = other_and_token
    third, _ = third_and_token
    resp = client.post("/trips", json={"name": "Group Trip"}, headers=_auth_header(user_token))
    trip_id = resp.json()["id"]
    db.execute(trip_participants.insert().values(trip_id=trip_id, user_id=other.id))
    db.execute(trip_participants.insert().values(trip_id=trip_id, user_id=third.id))
    db.commit()
    return trip_id, user, user_token, other, third


# ---------------------------------------------------------------------------
# POST /trips/{id}/settlements
# ---------------------------------------------------------------------------

def test_settle_empty_trip(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    response = _settle(client, user_token, trip_id)
    assert response.status_code == 201
    data = response.json()
    assert data["trip_id"] == trip_id
    assert data["transactions"] == []


def test_settle_already_balanced(client, two_user_trip):
    """Each user pays $10 for a $20 equal-split expense — net is zero for both."""
    trip_id, user, user_token, other, other_token = two_user_trip
    # user pays $20, each owes $10 → user net = +10, other net = -10
    # other pays $20, each owes $10 → other net = +10, user net = -10
    # Combined: both net = 0
    _create_expense(client, user_token, trip_id, "20.00", paid_by=user.id)
    _create_expense(client, user_token, trip_id, "20.00", paid_by=other.id)
    response = _settle(client, user_token, trip_id)
    assert response.status_code == 201
    assert response.json()["transactions"] == []


def test_settle_single_expense_two_users(client, two_user_trip):
    """user pays $30 for 2 people → other owes user $15."""
    trip_id, user, user_token, other, _ = two_user_trip
    _create_expense(client, user_token, trip_id, "30.00", paid_by=user.id)
    response = _settle(client, user_token, trip_id)
    assert response.status_code == 201
    txns = response.json()["transactions"]
    assert len(txns) == 1
    assert txns[0]["from_user_id"] == other.id
    assert txns[0]["to_user_id"] == user.id
    assert txns[0]["from_email"] == OTHER_EMAIL
    assert txns[0]["to_email"] == USER_EMAIL
    assert txns[0]["amount"] == "15.00"


def test_settle_multiple_expenses_two_users(client, two_user_trip):
    """user pays $30, other pays $10 → net: user +10, other -10 → 1 transaction of $10."""
    trip_id, user, user_token, other, _ = two_user_trip
    _create_expense(client, user_token, trip_id, "30.00", paid_by=user.id)
    _create_expense(client, user_token, trip_id, "10.00", paid_by=other.id)
    response = _settle(client, user_token, trip_id)
    assert response.status_code == 201
    txns = response.json()["transactions"]
    assert len(txns) == 1
    assert txns[0]["from_user_id"] == other.id
    assert txns[0]["to_user_id"] == user.id
    assert txns[0]["amount"] == "10.00"


def test_settle_three_users_complex(client, three_user_trip):
    """
    3 users, user pays $60 for all three → each owes $20.
    user net = +40, other net = -20, third net = -20.
    Expect 2 transactions: other → user $20, third → user $20.
    """
    trip_id, user, user_token, other, third = three_user_trip
    _create_expense(client, user_token, trip_id, "60.00", paid_by=user.id)
    response = _settle(client, user_token, trip_id)
    assert response.status_code == 201
    txns = response.json()["transactions"]
    assert len(txns) == 2
    to_ids = {t["to_user_id"] for t in txns}
    from_ids = {t["from_user_id"] for t in txns}
    assert user.id in to_ids
    assert other.id in from_ids
    assert third.id in from_ids
    for t in txns:
        assert t["amount"] == "20.00"


def test_settle_not_participant(client, two_user_trip, db):
    """A user not on the trip gets 404."""
    trip_id, _, _, _, _ = two_user_trip
    outsider = User(email="outsider@example.com", hashed_password=get_password_hash(PASSWORD))
    db.add(outsider)
    db.commit()
    token = client.post("/auth/login", json={"email": "outsider@example.com", "password": PASSWORD}).json()["access_token"]
    response = _settle(client, token, trip_id)
    assert response.status_code == 404


def test_settle_trip_not_found(client, user_and_token):
    _, user_token = user_and_token
    response = _settle(client, user_token, 99999)
    assert response.status_code == 404


def test_settle_no_auth(client, two_user_trip):
    trip_id, _, _, _, _ = two_user_trip
    response = client.post(SETTLEMENTS_URL.format(trip_id=trip_id))
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# GET /trips/{id}/settlements
# ---------------------------------------------------------------------------

def test_list_settlements_empty(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    response = client.get(SETTLEMENTS_URL.format(trip_id=trip_id), headers=_auth_header(user_token))
    assert response.status_code == 200
    assert response.json() == []


def test_list_settlements_after_settle_up(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    _create_expense(client, user_token, trip_id, "30.00")
    _settle(client, user_token, trip_id)
    response = client.get(SETTLEMENTS_URL.format(trip_id=trip_id), headers=_auth_header(user_token))
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["trip_id"] == trip_id
    assert "transactions" in data[0]
    assert "created_at" in data[0]


def test_list_settlements_includes_transactions(client, two_user_trip):
    """Settlement record includes the from/to email transaction detail."""
    trip_id, user, user_token, other, _ = two_user_trip
    _create_expense(client, user_token, trip_id, "30.00", paid_by=user.id)
    _settle(client, user_token, trip_id)
    response = client.get(SETTLEMENTS_URL.format(trip_id=trip_id), headers=_auth_header(user_token))
    txns = response.json()[0]["transactions"]
    assert len(txns) == 1
    assert txns[0]["from_email"] == OTHER_EMAIL
    assert txns[0]["to_email"] == USER_EMAIL
    assert txns[0]["amount"] == "15.00"


def test_list_settlements_multiple(client, two_user_trip):
    """Each settle-up creates a separate settlement record."""
    trip_id, _, user_token, _, _ = two_user_trip
    _create_expense(client, user_token, trip_id, "10.00")
    _settle(client, user_token, trip_id)
    _create_expense(client, user_token, trip_id, "20.00")
    _settle(client, user_token, trip_id)
    response = client.get(SETTLEMENTS_URL.format(trip_id=trip_id), headers=_auth_header(user_token))
    assert response.status_code == 200
    assert len(response.json()) == 2


def test_list_settlements_not_participant(client, two_user_trip, db):
    trip_id, _, _, _, _ = two_user_trip
    outsider = User(email="outsider@example.com", hashed_password=get_password_hash(PASSWORD))
    db.add(outsider)
    db.commit()
    token = client.post(
        "/auth/login", json={"email": "outsider@example.com", "password": PASSWORD}
    ).json()["access_token"]
    response = client.get(SETTLEMENTS_URL.format(trip_id=trip_id), headers=_auth_header(token))
    assert response.status_code == 404


def test_list_settlements_no_auth(client, two_user_trip):
    trip_id, _, _, _, _ = two_user_trip
    response = client.get(SETTLEMENTS_URL.format(trip_id=trip_id))
    assert response.status_code == 401
