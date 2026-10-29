from backend.core.security import hash_password, verify_password
from backend.tests.conftest import auth_header_for_user


def test_password_hashing():
    """Verify password hashing produces salted hashes and validates correctly."""
    raw = "MySecurePass123!"
    hashed = hash_password(raw)
    assert hashed != raw
    assert verify_password(raw, hashed) is True
    assert verify_password("WrongPass123!", hashed) is False


def test_register_citizen_success(client):
    """Citizen registration creates account and returns valid JWT tokens."""
    payload = {
        "email": "newcitizen@example.com",
        "full_name": "New Citizen",
        "password": "Password123!",
        "phone_number": "9123456789",
        "ward": "Ward 10",
    }
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["email"] == "newcitizen@example.com"
    assert data["user"]["role"] == "citizen"


def test_register_duplicate_email(client, seed_data):
    """Registration with existing email must return 400 Bad Request."""
    payload = {
        "email": "citizen@test.civicai",
        "full_name": "Duplicate Tester",
        "password": "Password123!",
    }
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 400
    assert "already exists" in response.json()["detail"]


def test_login_success(client, seed_data):
    """Login with valid credentials returns access and refresh tokens."""
    payload = {
        "email": "citizen@test.civicai",
        "password": "TestSecret123!",
    }
    response = client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["user"]["email"] == "citizen@test.civicai"


def test_login_invalid_password(client, seed_data):
    """Login with wrong password must return 401 Unauthorized."""
    payload = {
        "email": "citizen@test.civicai",
        "password": "IncorrectPassword!",
    }
    response = client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 401
    assert "Invalid email or password" in response.json()["detail"]


def test_login_nonexistent_user(client):
    """Login with unknown email must return 401 Unauthorized."""
    payload = {
        "email": "unknown@nowhere.com",
        "password": "SomePassword123!",
    }
    response = client.post("/api/v1/auth/login", json=payload)
    assert response.status_code == 401


def test_refresh_token_exchange(client, seed_data):
    """Exchanging a valid refresh token generates new token pair."""
    login_resp = client.post(
        "/api/v1/auth/login",
        json={"email": "citizen@test.civicai", "password": "TestSecret123!"},
    )
    refresh_token = login_resp.json()["refresh_token"]

    resp = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_token})
    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data


def test_get_current_user_profile(client, seed_data):
    """Accessing /auth/me with valid Bearer token returns user profile."""
    headers = auth_header_for_user(seed_data["citizen"])
    response = client.get("/api/v1/auth/me", headers=headers)
    assert response.status_code == 200
    assert response.json()["email"] == seed_data["citizen"].email


def test_unauthenticated_request_rejected(client):
    """Accessing protected endpoint without token returns 401."""
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401
