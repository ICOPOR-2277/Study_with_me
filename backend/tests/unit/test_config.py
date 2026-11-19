import pytest

from app.core.config import load_settings, normalize_database_url

BASE = {"SECRET_KEY": "k" * 40, "DATABASE_URL": "postgres://u:p@h:5432/d"}


def test_normalize_database_url():
    assert normalize_database_url("postgres://u:p@h/d") == "postgresql+psycopg://u:p@h/d"
    assert normalize_database_url("postgresql://u:p@h/d") == "postgresql+psycopg://u:p@h/d"
    assert normalize_database_url("postgresql+psycopg://u:p@h/d") == "postgresql+psycopg://u:p@h/d"


def test_load_settings_ok():
    s = load_settings({**BASE, "CORS_ORIGINS": "https://a.com/, https://b.com", "APP_ENV": "Production"})
    assert s.database_url.startswith("postgresql+psycopg://")
    assert s.cors_origins == ["https://a.com", "https://b.com"]
    assert s.is_production and not s.smtp_enabled


@pytest.mark.parametrize("env", [
    {"DATABASE_URL": "x"},
    {**BASE, "SECRET_KEY": "change-me"},
    {**BASE, "SECRET_KEY": "corta"},
    {"SECRET_KEY": "k" * 40},
])
def test_load_settings_rejects_bad_config(env):
    with pytest.raises(RuntimeError):
        load_settings(env)
