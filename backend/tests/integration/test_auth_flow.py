import pytest

from tests.integration.conftest import Session


def reg(client, **over):
    body = dict(full_name="Laura Sánchez", username="laura", email="laura@uni.edu", password="clave-segura-1",
                role="student", subjects=[])
    body.update(over)
    return client.post("/auth/register", json=body)


def test_health_and_subjects_catalog(client):
    assert client.get("/health").json() == {"status": "ok"}
    assert sorted(client.get("/subjects").json()) == sorted(["Cálculo", "Programación", "Física", "Inglés", "Bases de datos", "Matemáticas"])


def test_register_verify_login(client, codes):
    assert reg(client).status_code == 201
    # sin verificar no puede entrar
    r = client.post("/auth/login", json={"email": "laura@uni.edu", "password": "clave-segura-1"})
    assert r.status_code == 403 and r.json()["code"] == "email_not_verified"
    # código incorrecto
    r = client.post("/auth/verify-email", json={"email": "laura@uni.edu", "code": "000000" if codes["laura@uni.edu"] != "000000" else "111111"})
    assert r.status_code == 400 and r.json()["code"] == "invalid_code"
    # código correcto -> token
    r = client.post("/auth/verify-email", json={"email": "laura@uni.edu", "code": codes["laura@uni.edu"]})
    assert r.status_code == 200 and r.json()["user"]["username"] == "laura"
    # login
    r = client.post("/auth/login", json={"email": "LAURA@uni.edu", "password": "clave-segura-1"})
    assert r.status_code == 200
    token = r.json()["access_token"]
    assert client.get("/users/me", headers={"Authorization": f"Bearer {token}"}).json()["email"] == "laura@uni.edu"
    assert client.post("/auth/login", json={"email": "laura@uni.edu", "password": "mala"}).status_code == 401


def test_password_is_stored_hashed(client, codes):
    from sqlalchemy import text
    from app.db.session import get_engine
    reg(client)
    with get_engine().connect() as conn:
        h = conn.execute(text("select password_hash from users")).scalar_one()
    assert h.startswith("scrypt$") and "clave-segura-1" not in h


def test_duplicates_and_validation(client, codes):
    assert reg(client).status_code == 201
    assert reg(client, username="otro").status_code == 409
    assert reg(client, email="otro@uni.edu").status_code == 409
    assert reg(client, email="x@uni.edu", username="x1", password="corta").status_code == 422
    assert reg(client, email="m@uni.edu", username="m1", role="monitor", subjects=[]).status_code == 422
    assert reg(client, email="m@uni.edu", username="m1", role="monitor", subjects=["Cálculo", "Física", "Inglés", "Programación"]).status_code == 422
    assert reg(client, email="m@uni.edu", username="m1", role="monitor", subjects=["Alquimia"]).status_code == 400


def test_code_attempts_limit_and_resend_cooldown(client, codes):
    reg(client)
    for _ in range(5):
        client.post("/auth/verify-email", json={"email": "laura@uni.edu", "code": "999999"})
    r = client.post("/auth/verify-email", json={"email": "laura@uni.edu", "code": codes["laura@uni.edu"]})
    assert r.status_code == 429  # agotó los 5 intentos aunque ahora acierte
    assert client.post("/auth/resend-code", json={"email": "laura@uni.edu"}).status_code == 429  # < 48 s
    assert client.post("/auth/resend-code", json={"email": "nadie@uni.edu"}).status_code == 200  # no revela cuentas


def test_protected_routes_need_token(client):
    for method, url in [("get", "/meetings"), ("get", "/users/me"), ("get", "/users/me/summary"),
                        ("get", "/history/meetings?year=2026&month=11"), ("get", "/calendar?from=2026-11-01&to=2026-11-30")]:
        assert getattr(client, method)(url).status_code == 401
    assert client.get("/meetings", headers={"Authorization": "Bearer basura"}).status_code == 401


def test_monitor_subjects_saved(client, codes):
    s = Session(client, codes, "m@uni.edu", "monica", role="monitor", subjects=["Cálculo", "Física"])
    assert s.user["subjects"] == ["Cálculo", "Física"]
    r = s.put("/users/me/subjects", {"subjects": ["Inglés"]})
    assert r.json()["subjects"] == ["Inglés"]
    assert s.put("/users/me/subjects", {"subjects": []}).status_code == 400
    st = Session(client, codes, "e@uni.edu", "estu")
    assert st.put("/users/me/subjects", {"subjects": ["Inglés"]}).status_code == 400


def test_pending_account_is_replaced_by_a_new_registration(client, codes):
    assert reg(client).status_code == 201  # queda SIN verificar
    # volver atrás y registrarse otra vez con el mismo correo: reemplaza a la cuenta pendiente
    assert reg(client, full_name="Laura Nueva", password="otra-clave-9").status_code == 201
    from sqlalchemy import text
    from app.db.session import get_engine
    with get_engine().connect() as conn:
        assert conn.execute(text("select count(*) from users")).scalar_one() == 1
        assert conn.execute(text("select full_name from users")).scalar_one() == "Laura Nueva"
    r = client.post("/auth/verify-email", json={"email": "laura@uni.edu", "code": codes["laura@uni.edu"]})
    assert r.status_code == 200
    assert client.post("/auth/login", json={"email": "laura@uni.edu", "password": "otra-clave-9"}).status_code == 200
    assert client.post("/auth/login", json={"email": "laura@uni.edu", "password": "clave-segura-1"}).status_code == 401
    # ya verificada: nadie puede reemplazarla
    assert reg(client, password="intruso-123").status_code == 409


def test_pending_username_is_released_for_another_email(client, codes):
    assert reg(client).status_code == 201  # laura@uni.edu, pendiente
    assert reg(client, email="otra@uni.edu").status_code == 201  # mismo username "laura": reemplaza a la pendiente
    r = client.post("/auth/verify-email", json={"email": "otra@uni.edu", "code": codes["otra@uni.edu"]})
    assert r.status_code == 200