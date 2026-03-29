"""Tests for safe delete endpoints: DELETE /trips/{id}, DELETE /trips/{id}/participants/{pid},
GET /trips/{id}/expenses, DELETE /trips/{id}/expenses/{eid}."""
import pytest
from fastapi.testclient import TestClient

from app.core.security import get_password_hash
from app.models.trip import trip_participants
from app.models.user import User

TRIPS_URL = "/trips"
USER_EMAIL = "user@example.com"
OTHER_EMAIL = "other@example.com"
PASSWORD = "secret123"


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create_expense(client, token, trip_id, amount="30.00", paid_by=None):
    body: dict = {"amount": amount, "description": "Test"}
    if paid_by:
        body["paid_by"] = paid_by
    return client.post(f"/trips/{trip_id}/expenses", json=body, headers=_auth_header(token))


def _settle(client, token, trip_id):
    return client.post(f"/trips/{trip_id}/settlements", headers=_auth_header(token))


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
def two_user_trip(client, db, user_and_token, other_and_token):
    user, user_token = user_and_token
    other, other_token = other_and_token
    resp = client.post(TRIPS_URL, json={"name": "Group Trip"}, headers=_auth_header(user_token))
    trip_id = resp.json()["id"]
    db.execute(trip_participants.insert().values(trip_id=trip_id, user_id=other.id))
    db.commit()
    return trip_id, user, user_token, other, other_token


# ---------------------------------------------------------------------------
# DELETE /trips/{id}
# ---------------------------------------------------------------------------

def test_delete_trip_no_expenses(client, user_and_token):
    _, user_token = user_and_token
    trip_id = client.post(TRIPS_URL, json={"name": "Empty"}, headers=_auth_header(user_token)).json()["id"]
    response = client.delete(f"{TRIPS_URL}/{trip_id}", headers=_auth_header(user_token))
    assert response.status_code == 204
    assert client.get(f"{TRIPS_URL}/{trip_id}", headers=_auth_header(user_token)).status_code == 404


def test_delete_trip_with_settlement(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    _create_expense(client, user_token, trip_id)
    _settle(client, user_token, trip_id)
    response = client.delete(f"{TRIPS_URL}/{trip_id}", headers=_auth_header(user_token))
    assert response.status_code == 204


def test_delete_trip_unsettled_expenses_blocked(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    _create_expense(client, user_token, trip_id)
    response = client.delete(f"{TRIPS_URL}/{trip_id}", headers=_auth_header(user_token))
    assert response.status_code == 400
    assert "unsettled" in response.json()["detail"].lower()


def test_delete_trip_not_participant(client, user_and_token, other_and_token):
    _, user_token = user_and_token
    _, other_token = other_and_token
    trip_id = client.post(TRIPS_URL, json={"name": "Private"}, headers=_auth_header(user_token)).json()["id"]
    response = client.delete(f"{TRIPS_URL}/{trip_id}", headers=_auth_header(other_token))
    assert response.status_code == 404


def test_delete_trip_no_auth(client, user_and_token):
    _, user_token = user_and_token
    trip_id = client.post(TRIPS_URL, json={"name": "Trip"}, headers=_auth_header(user_token)).json()["id"]
    assert client.delete(f"{TRIPS_URL}/{trip_id}").status_code == 401


# ---------------------------------------------------------------------------
# DELETE /trips/{id}/participants/{participant_id}
# ---------------------------------------------------------------------------

def test_remove_participant_no_expenses(client, two_user_trip):
    trip_id, _, user_token, other, _ = two_user_trip
    response = client.delete(
        f"{TRIPS_URL}/{trip_id}/participants/{other.id}",
        headers=_auth_header(user_token),
    )
    assert response.status_code == 200
    emails = {p["email"] for p in response.json()["participants"]}
    assert OTHER_EMAIL not in emails


def test_remove_participant_has_paid_blocked(client, two_user_trip):
    trip_id, _, user_token, other, other_token = two_user_trip
    _create_expense(client, other_token, trip_id, paid_by=other.id)
    response = client.delete(
        f"{TRIPS_URL}/{trip_id}/participants/{other.id}",
        headers=_auth_header(user_token),
    )
    assert response.status_code == 400
    assert "paid" in response.json()["detail"].lower()


def test_remove_participant_in_split_blocked(client, two_user_trip):
    trip_id, user, user_token, other, _ = two_user_trip
    _create_expense(client, user_token, trip_id, paid_by=user.id)
    response = client.delete(
        f"{TRIPS_URL}/{trip_id}/participants/{other.id}",
        headers=_auth_header(user_token),
    )
    assert response.status_code == 400
    assert "split" in response.json()["detail"].lower()


def test_remove_participant_not_found(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    response = client.delete(
        f"{TRIPS_URL}/{trip_id}/participants/99999",
        headers=_auth_header(user_token),
    )
    assert response.status_code == 404


def test_remove_participant_no_auth(client, two_user_trip):
    trip_id, _, _, other, _ = two_user_trip
    assert client.delete(f"{TRIPS_URL}/{trip_id}/participants/{other.id}").status_code == 401


# ---------------------------------------------------------------------------
# GET /trips/{id}/expenses
# ---------------------------------------------------------------------------

def test_list_expenses_empty(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    response = client.get(f"/trips/{trip_id}/expenses", headers=_auth_header(user_token))
    assert response.status_code == 200
    assert response.json() == []


def test_list_expenses_returns_all(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    _create_expense(client, user_token, trip_id, "10.00")
    _create_expense(client, user_token, trip_id, "20.00")
    response = client.get(f"/trips/{trip_id}/expenses", headers=_auth_header(user_token))
    assert response.status_code == 200
    assert len(response.json()) == 2


def test_list_expenses_no_auth(client, two_user_trip):
    trip_id, _, _, _, _ = two_user_trip
    assert client.get(f"/trips/{trip_id}/expenses").status_code == 401


# ---------------------------------------------------------------------------
# DELETE /trips/{id}/expenses/{expense_id}
# ---------------------------------------------------------------------------

def test_delete_expense_success(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    response = client.delete(f"/trips/{trip_id}/expenses/{expense_id}", headers=_auth_header(user_token))
    assert response.status_code == 204
    assert client.get(f"/trips/{trip_id}/expenses", headers=_auth_header(user_token)).json() == []


def test_delete_expense_recalculates_balances(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id, "30.00").json()["id"]
    balances_before = client.get(f"/trips/{trip_id}/balances", headers=_auth_header(user_token)).json()
    assert any(b["net"] != "0.00" for b in balances_before)
    client.delete(f"/trips/{trip_id}/expenses/{expense_id}", headers=_auth_header(user_token))
    balances_after = client.get(f"/trips/{trip_id}/balances", headers=_auth_header(user_token)).json()
    assert all(b["net"] == "0.00" for b in balances_after)


def test_delete_expense_not_found(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    assert client.delete(f"/trips/{trip_id}/expenses/99999", headers=_auth_header(user_token)).status_code == 404


def test_delete_expense_wrong_trip(client, user_and_token, client_fixture=None):
    _, user_token = user_and_token
    trip1_id = client.post(TRIPS_URL, json={"name": "T1"}, headers=_auth_header(user_token)).json()["id"]
    trip2_id = client.post(TRIPS_URL, json={"name": "T2"}, headers=_auth_header(user_token)).json()["id"]
    expense_id = _create_expense(client, user_token, trip1_id).json()["id"]
    assert client.delete(f"/trips/{trip2_id}/expenses/{expense_id}", headers=_auth_header(user_token)).status_code == 404


def test_delete_expense_no_auth(client, two_user_trip):
    trip_id, _, user_token, _, _ = two_user_trip
    expense_id = _create_expense(client, user_token, trip_id).json()["id"]
    assert client.delete(f"/trips/{trip_id}/expenses/{expense_id}").status_code == 401
