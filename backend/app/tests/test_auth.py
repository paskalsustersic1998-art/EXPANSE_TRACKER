import pytest
from fastapi.testclient import TestClient

from app.models.user import User

REGISTER_URL = "/auth/register"
LOGIN_URL = "/auth/login"
REFRESH_URL = "/auth/refresh"
ME_URL = "/auth/me"

VALID_EMAIL = "test@example.com"
VALID_PASSWORD = "secret123"


def _register(client: TestClient, email: str = VALID_EMAIL, password: str = VALID_PASSWORD):
    return client.post(REGISTER_URL, json={"email": email, "password": password})


def _login(client: TestClient, email: str = VALID_EMAIL, password: str = VALID_PASSWORD):
    return client.post(LOGIN_URL, json={"email": email, "password": password})


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# POST /auth/register
# ---------------------------------------------------------------------------

def test_register_success(client):
    response = _register(client)
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == VALID_EMAIL
    assert data["role"] == "user"
    assert data["is_active"] is True
    assert "id" in data
    assert "created_at" in data
    assert "hashed_password" not in data


def test_register_duplicate_email(client):
    _register(client)
    response = _register(client)
    assert response.status_code == 400
    assert "already registered" in response.json()["detail"]


def test_register_invalid_email(client):
    response = client.post(REGISTER_URL, json={"email": "notanemail", "password": VALID_PASSWORD})
    assert response.status_code == 422


def test_register_missing_fields(client):
    response = client.post(REGISTER_URL, json={"email": VALID_EMAIL})
    assert response.status_code == 422


# ---------------------------------------------------------------------------
# POST /auth/login
# ---------------------------------------------------------------------------

def test_login_success(client):
    _register(client)
    response = _login(client)
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


def test_login_wrong_password(client):
    _register(client)
    response = _login(client, password="wrongpassword")
    assert response.status_code == 401


def test_login_nonexistent_user(client):
    response = _login(client, email="nobody@example.com")
    assert response.status_code == 401


def test_login_inactive_user(client, db):
    _register(client)
    user = db.query(User).filter(User.email == VALID_EMAIL).first()
    user.is_active = False
    db.commit()

    response = _login(client)
    assert response.status_code == 403


# ---------------------------------------------------------------------------
# GET /auth/me
# ---------------------------------------------------------------------------

def test_me_success(client):
    _register(client)
    token = _login(client).json()["access_token"]
    response = client.get(ME_URL, headers=_auth_header(token))
    assert response.status_code == 200
    assert response.json()["email"] == VALID_EMAIL


def test_me_no_token(client):
    response = client.get(ME_URL)
    assert response.status_code == 401


def test_me_invalid_token(client):
    response = client.get(ME_URL, headers=_auth_header("this.is.invalid"))
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# POST /auth/refresh
# ---------------------------------------------------------------------------

def test_refresh_success(client):
    _register(client)
    login_data = _login(client).json()
    response = client.post(REFRESH_URL, json={"refresh_token": login_data["refresh_token"]})
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data


def test_refresh_with_access_token(client):
    _register(client)
    access_token = _login(client).json()["access_token"]
    response = client.post(REFRESH_URL, json={"refresh_token": access_token})
    assert response.status_code == 401


def test_refresh_invalid_token(client):
    response = client.post(REFRESH_URL, json={"refresh_token": "this.is.invalid"})
    assert response.status_code == 401


def test_refresh_inactive_user(client, db):
    _register(client)
    refresh_token = _login(client).json()["refresh_token"]

    user = db.query(User).filter(User.email == VALID_EMAIL).first()
    user.is_active = False
    db.commit()

    response = client.post(REFRESH_URL, json={"refresh_token": refresh_token})
    assert response.status_code == 401
