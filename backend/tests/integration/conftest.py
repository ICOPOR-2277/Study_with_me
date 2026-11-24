"""Pruebas de integración: API real + PostgreSQL real.

Requisitos: dependencias instaladas (requirements-dev.txt) y una base VACÍA de pruebas, p. ej.:
    createdb swm_test
    TEST_DATABASE_URL=postgresql://usuario:clave@localhost:5432/swm_test pytest tests/integration

Se aplica el esquema (el mismo SQL de la migración) y se borran los datos entre pruebas.
NUNCA apuntes TEST_DATABASE_URL a una base con datos reales: se vacía.
"""
import os
import sys
from datetime import datetime
from pathlib import Path

import pytest

pytest.importorskip("fastapi")
pytest.importorskip("sqlalchemy")
pytest.importorskip("psycopg")
pytest.importorskip("httpx")

TEST_URL = os.environ.get("TEST_DATABASE_URL")
if not TEST_URL:
    pytest.skip("Define TEST_DATABASE_URL para ejecutar las pruebas de integración", allow_module_level=True)

os.environ["DATABASE_URL"] = TEST_URL  # antes de importar la app

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "alembic"))

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import text  # noqa: E402
from sqlfile import SQL_DIR, split_statements  # noqa: E402

from app.core.deps import now_dep  # noqa: E402
from app.db.session import get_engine  # noqa: E402
from app.main import create_app  # noqa: E402
from app.services import email_service  # noqa: E402

NOW = datetime(2026, 11, 16, 10, 0)  # "ahora" fijo de las pruebas (lunes)


@pytest.fixture(scope="session", autouse=True)
def schema():
    engine = get_engine()
    with engine.begin() as conn:
        conn.exec_driver_sql("DROP SCHEMA public CASCADE")
        conn.exec_driver_sql("CREATE SCHEMA public")
        for stmt in split_statements((SQL_DIR / "0001_initial_up.sql").read_text(encoding="utf-8")):
            conn.exec_driver_sql(stmt)
    yield


@pytest.fixture(autouse=True)
def clean_db():
    yield
    with get_engine().begin() as conn:
        conn.execute(text("TRUNCATE payments, saved_meetings, registrations, meetings, availability_slots, "
                          "user_interests, monitor_subjects, email_verifications, users RESTART IDENTITY CASCADE"))


@pytest.fixture
def codes(monkeypatch):
    """Captura los códigos de verificación que normalmente solo salen en el log."""
    sent = {}
    monkeypatch.setattr(email_service, "send_verification_code", lambda settings, to, code, purpose="verify": sent.__setitem__(to, code))
    return sent


@pytest.fixture
def client():
    app = create_app()
    app.dependency_overrides[now_dep] = lambda: NOW
    with TestClient(app) as c:
        yield c


class Session:
    """Ayudante: registra, verifica e inicia sesión; guarda el encabezado Authorization."""

    def __init__(self, client, codes, email, username, role="student", subjects=None, password="clave-segura-1"):
        self.client, self.email = client, email
        body = dict(full_name=username.title(), username=username, email=email, password=password, role=role,
                    subjects=subjects or [])
        r = client.post("/auth/register", json=body)
        assert r.status_code == 201, r.text
        r = client.post("/auth/verify-email", json={"email": email, "code": codes[email]})
        assert r.status_code == 200, r.text
        self.headers = {"Authorization": f"Bearer {r.json()['access_token']}"}
        self.user = r.json()["user"]

    def get(self, url, **kw):
        return self.client.get(url, headers=self.headers, **kw)

    def post(self, url, json=None):
        return self.client.post(url, headers=self.headers, json=json)

    def put(self, url, json=None):
        return self.client.put(url, headers=self.headers, json=json)

    def delete(self, url):
        return self.client.delete(url, headers=self.headers)


@pytest.fixture
def make_user(client, codes):
    return lambda email, username, **kw: Session(client, codes, email, username, **kw)


def meeting_body(**over):
    body = dict(title="Derivadas", subject="Cálculo", description="Repaso", date="2026-11-18", start_time="15:00",
                end_time="17:00", is_virtual=False, location="Biblioteca", capacity=2, price=0)
    body.update(over)
    return body