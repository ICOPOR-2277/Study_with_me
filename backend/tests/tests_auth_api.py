import os
import pytest
import httpx

BASE_URL = os.getenv(
    "API_BASE_URL",
    "http://127.0.0.1:8000"
)

EMAIL = os.getenv("TEST_EMAIL")
PASSWORD = os.getenv("TEST_PASSWORD")


@pytest.fixture(scope="module")
def client():
    with httpx.Client(
        base_url=BASE_URL,
        timeout=15
    ) as test_client:
        yield test_client


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200


def test_login_and_access_protected_route(client):
    if not EMAIL or not PASSWORD:
        pytest.skip("Configura TEST_EMAIL y TEST_PASSWORD")

    response = client.post(
        "/auth/login",
        json={
            "email": "jpautt@utb.edu.co",
            "password": "JHhp61107"
        }
    )

    assert response.status_code == 200

    data = response.json()

    assert "access_token" in data
    assert data["access_token"]
    assert data.get("token_type", "").lower() == "bearer"

    token = data["access_token"]

    # Consultar perfil con el token
    profile = client.get(
        "/users/me",
        headers={
            "Authorization": f"Bearer {token}"
        }
    )

    assert profile.status_code == 200

    profile_data = profile.json()
    assert profile_data["email"].lower() == EMAIL.lower()


def test_login_with_wrong_password(client):
    if not EMAIL:
        pytest.skip("Configura TEST_EMAIL")

    response = client.post(
        "/auth/login",
        json={
            "email": EMAIL,
            "password": "WrongPassword_For_Test_123!"
        }
    )

    assert response.status_code == 401


def test_protected_route_without_token(client):
    response = client.get("/users/me")

    assert response.status_code == 401


def test_protected_route_with_invalid_token(client):
    response = client.get(
        "/users/me",
        headers={
            "Authorization": "Bearer token_invalido"
        }
    )

    assert response.status_code == 401