"""Configuración leída de variables de entorno (ver .env.example).

No hay valores secretos en el código: SECRET_KEY y DATABASE_URL son obligatorios.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from functools import lru_cache

from dotenv import load_dotenv

PLACEHOLDER_SECRETS = {"", "change-me", "changeme", "cambia-esto"}


def normalize_database_url(url: str) -> str:
    """Render entrega 'postgres://' o 'postgresql://'; SQLAlchemy+psycopg3 necesita el driver explícito."""
    for prefix in ("postgres://", "postgresql://"):
        if url.startswith(prefix):
            return "postgresql+psycopg://" + url[len(prefix):]
    return url


def _split_csv(value: str) -> list[str]:
    return [item.strip().rstrip("/") for item in value.split(",") if item.strip()]


@dataclass(frozen=True)
class Settings:
    app_env: str
    database_url: str
    secret_key: str
    access_token_expire_minutes: int = 720
    cors_origins: list[str] = field(default_factory=list)
    app_timezone: str = "America/Bogota"
    verification_code_ttl_minutes: int = 10
    verification_max_attempts: int = 5
    verification_resend_seconds: int = 48
    # Resend (https://resend.com): si resend_api_key está definida, el código se envía por su API HTTP.
    resend_api_key: str = ""
    resend_from: str = ""
    # SMTP (opcional, solo si no hay Resend). Sin Resend ni SMTP, el código solo se escribe en el log.
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def resend_enabled(self) -> bool:
        return bool(self.resend_api_key.strip())

    @property
    def smtp_enabled(self) -> bool:
        return bool(self.smtp_host)


def load_settings(env: dict[str, str] | None = None) -> Settings:
    e = os.environ if env is None else env
    secret = e.get("SECRET_KEY", "")
    app_env = e.get("APP_ENV", "development").lower()
    if secret.strip().lower() in PLACEHOLDER_SECRETS:
        raise RuntimeError("SECRET_KEY no está configurada. Genera una con: python -c \"import secrets; print(secrets.token_urlsafe(48))\"")
    if len(secret) < 32:
        raise RuntimeError("SECRET_KEY debe tener al menos 32 caracteres.")
    db = e.get("DATABASE_URL", "").strip()
    if not db:
        raise RuntimeError("DATABASE_URL no está configurada (ver .env.example).")
    return Settings(
        app_env=app_env,
        database_url=normalize_database_url(db),
        secret_key=secret,
        access_token_expire_minutes=int(e.get("ACCESS_TOKEN_EXPIRE_MINUTES", "720")),
        cors_origins=_split_csv(e.get("CORS_ORIGINS", "")),
        app_timezone=e.get("APP_TIMEZONE", "America/Bogota"),
        verification_code_ttl_minutes=int(e.get("VERIFICATION_CODE_TTL_MINUTES", "10")),
        verification_max_attempts=int(e.get("VERIFICATION_MAX_ATTEMPTS", "5")),
        verification_resend_seconds=int(e.get("VERIFICATION_RESEND_SECONDS", "48")),
        resend_api_key=e.get("RESEND_API_KEY", "").strip(),
        resend_from=e.get("RESEND_FROM", "").strip(),
        smtp_host=e.get("SMTP_HOST", ""),
        smtp_port=int(e.get("SMTP_PORT", "587")),
        smtp_user=e.get("SMTP_USER", ""),
        smtp_password=e.get("SMTP_PASSWORD", ""),
        smtp_from=e.get("SMTP_FROM", ""),
    )


@lru_cache
def get_settings() -> Settings:
    load_dotenv()
    return load_settings()