from app.core.security import get_password_hash
from app.models.user import User

USERS_URL = "/admin/users"

VALID_EMAIL = "user@example.com"
VALID_PASSWORD = "secret123"


def _register_and_login(client, email: str = VALID_EMAIL, password: str = VALID_PASSWORD) -> str:
    client.post("/auth/register", json={"email": email, "password": password})
    return client.post("/auth/login", json={"email": email, "password": password}).json()["access_token"]


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# GET /admin/users
# ---------------------------------------------------------------------------

def test_list_users_as_admin(client, admin_token):
    response = client.get(USERS_URL, headers=_auth_header(admin_token))
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_list_users_as_regular_user(client):
    token = _register_and_login(client)
    response = client.get(USERS_URL, headers=_auth_header(token))
    assert response.status_code == 403


def test_list_users_unauthenticated(client):
    response = client.get(USERS_URL)
    assert response.status_code == 401


# ---------------------------------------------------------------------------
# PATCH /admin/users/{id}/role
# ---------------------------------------------------------------------------

def test_update_role_success(client, admin_token, db):
    user = User(email=VALID_EMAIL, hashed_password=get_password_hash(VALID_PASSWORD))
    db.add(user)
    db.commit()
    db.refresh(user)

    response = client.patch(
        f"{USERS_URL}/{user.id}/role",
        json={"role": "admin"},
        headers=_auth_header(admin_token),
    )
    assert response.status_code == 200
    assert response.json()["role"] == "admin"


def test_update_role_user_not_found(client, admin_token):
    response = client.patch(
        f"{USERS_URL}/99999/role",
        json={"role": "admin"},
        headers=_auth_header(admin_token),
    )
    assert response.status_code == 404


def test_update_role_as_regular_user(client, db):
    token = _register_and_login(client)

    user = User(email="target@example.com", hashed_password=get_password_hash("pass"))
    db.add(user)
    db.commit()
    db.refresh(user)

    response = client.patch(
        f"{USERS_URL}/{user.id}/role",
        json={"role": "admin"},
        headers=_auth_header(token),
    )
    assert response.status_code == 403


def test_update_role_invalid_role(client, admin_token, db):
    user = User(email=VALID_EMAIL, hashed_password=get_password_hash(VALID_PASSWORD))
    db.add(user)
    db.commit()
    db.refresh(user)

    response = client.patch(
        f"{USERS_URL}/{user.id}/role",
        json={"role": "superuser"},
        headers=_auth_header(admin_token),
    )
    assert response.status_code == 422
