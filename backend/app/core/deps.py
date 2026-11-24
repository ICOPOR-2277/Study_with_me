"""Dependencias de FastAPI: configuración, sesión, usuario autenticado y 'ahora'."""
from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core import security
from app.core.config import Settings, get_settings
from app.core.errors import Forbidden, Unauthorized
from app.core.timeutil import local_now
from app.db.session import get_db
from app.models import User

bearer = HTTPBearer(auto_error=False)


def settings_dep() -> Settings:
    return get_settings()


def now_dep(settings: Settings = Depends(settings_dep)) -> datetime:
    """Hora de pared de la universidad. Se puede reemplazar en pruebas."""
    return local_now(settings.app_timezone)


def current_user(creds: HTTPAuthorizationCredentials | None = Depends(bearer),
                 db: Session = Depends(get_db), settings: Settings = Depends(settings_dep)) -> User:
    if creds is None:
        raise Unauthorized("Falta iniciar sesión", code="not_authenticated")
    sub = security.decode_access_token(creds.credentials, settings.secret_key)
    if sub is None:
        raise Unauthorized("Sesión inválida o vencida", code="invalid_token")
    try:
        user = db.get(User, uuid.UUID(sub))
    except ValueError:
        user = None
    if user is None or user.email_verified_at is None:
        raise Unauthorized("Sesión inválida o vencida", code="invalid_token")
    if not user.is_active:
        raise Forbidden("Tu cuenta está suspendida", code="account_disabled")
    return user


def require_admin(user: User = Depends(current_user)) -> User:
    """Solo cuentas con rol admin."""
    if not user.is_admin:
        raise Forbidden("Solo el administrador puede hacer esto", code="admin_only")
    return user