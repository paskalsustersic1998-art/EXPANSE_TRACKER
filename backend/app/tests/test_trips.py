import pytest
from fastapi.testclient import TestClient

from app.core.security import get_password_hash
from app.models.user import User

TRIPS_URL = "/trips"
VALID_EMAIL = "user@example.com"
VALID_PASSWORD = "secret123"
OTHER_EMAIL = "other@example.com"


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def user_token(client, db):
    user = User(
        email=VALID_EMAIL,
        hashed_password=get_password_hash(VALID_PASSWORD),
    )
    db.add(user)
    db.commit()
    resp = client.post("/auth/login", json={"email": VALID_EMAIL, "password": VALID_PASSWORD})
    return resp.json()["access_token"]


@pytest.fixture
def other_token(client, db):
    user = User(
        email=OTHER_EMAIL,
        hashed_password=get_password_hash(VALID_PASSWORD),
    )
    db.add(user)
    db.commit()
    resp = client.post("/auth/login", json={"email": OTHER_EMAIL, "password": VALID_PASSWORD})
    return resp.json()["access_token"]


def _create_trip(client: TestClient, token: str, name: str = "Test Trip", description: str | None = None):
    return client.post(
        TRIPS_URL,
        json={"name": name, "description": description},
        headers=_auth_header(token),
    )


# ---------------------------------------------------------------------------
# POST /trips
# ---------------------------------------------------------------------------

def test_create_trip_success(client, user_token):
    response = _create_trip(client, user_token, name="Summer Road Trip", description="Fun times")
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Summer Road Trip"
    assert data["description"] == "Fun times"
    assert "id" in data
    assert "created_at" in data
    assert len(data["participants"]) == 1
    assert data["participants"][0]["email"] == VALID_EMAIL


def test_create_trip_no_description(client, user_token):
    response = _create_trip(client, user_token, name="Minimal Trip")
    assert response.status_code == 201
    assert response.json()["description"] is None


def test_create_trip_missing_name(client, user_token):
    response = client.post(
        TRIPS_URL,
        json={"description": "No name"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 422


def test_create_trip_no_auth(client):
    response = client.post(TRIPS_URL, json={"name": "Ghost Trip"})
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# GET /trips
# ---------------------------------------------------------------------------

def test_list_trips_empty(client, user_token):
    response = client.get(TRIPS_URL, headers=_auth_header(user_token))
    assert response.status_code == 200
    assert response.json() == []


def test_list_trips_returns_own_only(client, user_token, other_token):
    _create_trip(client, user_token, name="My Trip")
    _create_trip(client, other_token, name="Other Trip")

    response = client.get(TRIPS_URL, headers=_auth_header(user_token))
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["name"] == "My Trip"


def test_list_trips_no_auth(client):
    response = client.get(TRIPS_URL)
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# GET /trips/{id}
# ---------------------------------------------------------------------------

def test_get_trip_success(client, user_token):
    trip_id = _create_trip(client, user_token, name="My Trip").json()["id"]
    response = client.get(f"{TRIPS_URL}/{trip_id}", headers=_auth_header(user_token))
    assert response.status_code == 200
    assert response.json()["name"] == "My Trip"


def test_get_trip_not_participant(client, user_token, other_token):
    trip_id = _create_trip(client, other_token, name="Private Trip").json()["id"]
    response = client.get(f"{TRIPS_URL}/{trip_id}", headers=_auth_header(user_token))
    assert response.status_code == 404


def test_get_trip_nonexistent(client, user_token):
    response = client.get(f"{TRIPS_URL}/99999", headers=_auth_header(user_token))
    assert response.status_code == 404


def test_get_trip_no_auth(client):
    response = client.get(f"{TRIPS_URL}/1")
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# POST /trips/{id}/participants
# ---------------------------------------------------------------------------

def _add_participant(client: TestClient, token: str, trip_id: int, email: str):
    return client.post(
        f"{TRIPS_URL}/{trip_id}/participants",
        json={"email": email},
        headers=_auth_header(token),
    )


def test_add_participant_success(client, user_token, other_token):
    trip_id = _create_trip(client, user_token).json()["id"]
    response = _add_participant(client, user_token, trip_id, OTHER_EMAIL)
    assert response.status_code == 201
    data = response.json()
    assert len(data["participants"]) == 2
    emails = {p["email"] for p in data["participants"]}
    assert VALID_EMAIL in emails
    assert OTHER_EMAIL in emails


def test_add_participant_caller_not_participant(client, user_token, other_token):
    trip_id = _create_trip(client, other_token).json()["id"]
    response = _add_participant(client, user_token, trip_id, OTHER_EMAIL)
    assert response.status_code == 404


def test_add_participant_trip_not_found(client, user_token):
    response = _add_participant(client, user_token, 99999, OTHER_EMAIL)
    assert response.status_code == 404


def test_add_participant_target_not_found(client, user_token):
    trip_id = _create_trip(client, user_token).json()["id"]
    response = _add_participant(client, user_token, trip_id, "ghost@example.com")
    assert response.status_code == 404


def test_add_participant_already_participant(client, user_token):
    trip_id = _create_trip(client, user_token).json()["id"]
    response = _add_participant(client, user_token, trip_id, VALID_EMAIL)
    assert response.status_code == 400
    assert "already a participant" in response.json()["detail"]


def test_add_participant_invalid_email(client, user_token):
    trip_id = _create_trip(client, user_token).json()["id"]
    response = _add_participant(client, user_token, trip_id, "not-an-email")
    assert response.status_code == 422


def test_add_participant_no_auth(client, user_token):
    trip_id = _create_trip(client, user_token).json()["id"]
    response = client.post(
        f"{TRIPS_URL}/{trip_id}/participants",
        json={"email": OTHER_EMAIL},
    )
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# PATCH /trips/{id}
# ---------------------------------------------------------------------------

def test_update_trip_name(client, user_token):
    trip_id = _create_trip(client, user_token, name="Old Name").json()["id"]
    response = client.patch(
        f"{TRIPS_URL}/{trip_id}",
        json={"name": "New Name"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 200
    assert response.json()["name"] == "New Name"


def test_update_trip_description(client, user_token):
    trip_id = _create_trip(client, user_token, name="Trip", description="Old desc").json()["id"]
    response = client.patch(
        f"{TRIPS_URL}/{trip_id}",
        json={"description": "New desc"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 200
    assert response.json()["description"] == "New desc"


def test_update_trip_preserves_unset_fields(client, user_token):
    """Updating only name leaves description unchanged."""
    trip_id = _create_trip(client, user_token, name="Trip", description="Keep me").json()["id"]
    response = client.patch(
        f"{TRIPS_URL}/{trip_id}",
        json={"name": "New Name"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 200
    assert response.json()["description"] == "Keep me"


def test_update_trip_empty_name_rejected(client, user_token):
    trip_id = _create_trip(client, user_token, name="Trip").json()["id"]
    response = client.patch(
        f"{TRIPS_URL}/{trip_id}",
        json={"name": "   "},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 422


def test_update_trip_not_participant(client, user_token, other_token):
    trip_id = _create_trip(client, other_token, name="Private").json()["id"]
    response = client.patch(
        f"{TRIPS_URL}/{trip_id}",
        json={"name": "Hacked"},
        headers=_auth_header(user_token),
    )
    assert response.status_code == 404


def test_update_trip_no_auth(client, user_token):
    trip_id = _create_trip(client, user_token, name="Trip").json()["id"]
    response = client.patch(f"{TRIPS_URL}/{trip_id}", json={"name": "New"})
    assert response.status_code == 401
