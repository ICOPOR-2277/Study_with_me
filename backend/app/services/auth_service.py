from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core import security
from app.core.config import Settings
from app.core.errors import AppError, Conflict, Forbidden, TooManyRequests, Unauthorized
from app.models import EmailVerification, MonitorSubject, User
from app.schemas.user import LoginIn, RegisterIn, TokenOut
from app.services import email_service
from app.services.subject_service import subjects_by_names
from app.services.user_service import to_user_out

logger = logging.getLogger("study_with_me.auth")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _find_user_by_email(db: Session, email: str) -> User | None:
    return db.scalar(select(User).where(User.email == email))


def _issue_code(db: Session, settings: Settings, user: User) -> None:
    """Invalida los códigos anteriores y crea uno nuevo (el envío ocurre después del commit)."""
    now = _now()
    db.execute(update(EmailVerification)
               .where(EmailVerification.user_id == user.id, EmailVerification.consumed_at.is_(None))
               .values(consumed_at=now))
    code = security.generate_verification_code()
    db.add(EmailVerification(user_id=user.id, code_hash=security.hash_verification_code(code, settings.secret_key),
                             expires_at=now + timedelta(minutes=settings.verification_code_ttl_minutes)))
    db.commit()
    email_service.send_verification_code(settings, user.email, code)


PENDING_ACCOUNT_MAX_AGE = timedelta(hours=24)


def _purge_pending(db: Session, email: str, username: str) -> None:
    """Borra cuentas SIN verificar que estorban: las del mismo correo/username y las de más de 24 h.

    Una cuenta sin verificar nunca pudo iniciar sesión, así que no tiene reuniones ni inscripciones;
    sus materias y códigos se borran solos (ON DELETE CASCADE en la base de datos).
    """
    cutoff = _now() - PENDING_ACCOUNT_MAX_AGE
    db.execute(delete(User).where(User.email_verified_at.is_(None),
                                  or_(User.email == email, User.username == username, User.created_at < cutoff))
               .execution_options(synchronize_session=False))


def register(db: Session, settings: Settings, data: RegisterIn) -> User:
    # Solo las cuentas YA verificadas bloquean un correo o username.
    if db.scalar(select(User.id).where(User.email == data.email, User.email_verified_at.is_not(None))):
        raise Conflict("Ya existe una cuenta con ese correo", code="email_taken")
    if db.scalar(select(User.id).where(User.username == data.username, User.email_verified_at.is_not(None))):
        raise Conflict("Ese username ya está en uso", code="username_taken")
    subjects = subjects_by_names(db, data.subjects)  # valida nombres antes de crear nada
    _purge_pending(db, data.email, data.username)  # un registro nuevo reemplaza al pendiente anterior
    user = User(full_name=data.full_name, username=data.username, email=data.email,
                password_hash=security.hash_password(data.password), role=data.role)
    db.add(user)
    try:
        db.flush()
        db.add_all(MonitorSubject(user_id=user.id, subject_id=s.id) for s in subjects)
        db.flush()
    except IntegrityError:
        db.rollback()
        raise Conflict("El correo o el username ya están registrados", code="duplicate_user")
    _issue_code(db, settings, user)
    return user


def resend_code(db: Session, settings: Settings, email: str) -> None:
    user = _find_user_by_email(db, email)
    # Misma respuesta exista o no la cuenta, para no revelar qué correos están registrados.
    if user is None or user.email_verified_at is not None:
        return
    last = db.scalar(select(EmailVerification.created_at).where(EmailVerification.user_id == user.id)
                     .order_by(EmailVerification.created_at.desc()).limit(1))
    if last and (_now() - last).total_seconds() < settings.verification_resend_seconds:
        raise TooManyRequests("Espera unos segundos antes de pedir otro código", code="resend_too_soon")
    _issue_code(db, settings, user)


def verify_email(db: Session, settings: Settings, email: str, code: str) -> TokenOut:
    user = _find_user_by_email(db, email)
    invalid = AppError("Código incorrecto o vencido", code="invalid_code")
    if user is None:
        raise invalid
    if user.email_verified_at is not None:
        raise Conflict("Este correo ya está verificado. Inicia sesión.", code="already_verified")
    ver = db.scalar(select(EmailVerification)
                    .where(EmailVerification.user_id == user.id, EmailVerification.consumed_at.is_(None))
                    .order_by(EmailVerification.created_at.desc()).limit(1).with_for_update())
    if ver is None or ver.expires_at <= _now():
        raise AppError("El código venció. Solicita uno nuevo.", code="code_expired")
    if ver.attempts >= settings.verification_max_attempts:
        raise TooManyRequests("Demasiados intentos. Solicita un código nuevo.", code="too_many_attempts")
    if not security.verify_verification_code(code, ver.code_hash, settings.secret_key):
        ver.attempts += 1
        db.commit()  # el intento fallido debe quedar registrado
        raise invalid
    now = _now()
    ver.consumed_at = now
    user.email_verified_at = now
    db.commit()
    return _token_for(db, settings, user)


def login(db: Session, settings: Settings, data: LoginIn) -> TokenOut:
    user = _find_user_by_email(db, data.email)
    stored = user.password_hash if user else security.DUMMY_HASH
    ok = security.verify_password(data.password, stored)
    if user is None or not ok:
        raise Unauthorized("Correo o contraseña incorrectos", code="invalid_credentials")
    if user.email_verified_at is None:
        raise Forbidden("Debes verificar tu correo antes de entrar", code="email_not_verified")
    if security.needs_rehash(user.password_hash):
        user.password_hash = security.hash_password(data.password)
        db.commit()
    return _token_for(db, settings, user)


def _token_for(db: Session, settings: Settings, user: User) -> TokenOut:
    token = security.create_access_token(str(user.id), settings.secret_key, settings.access_token_expire_minutes)
    return TokenOut(access_token=token, user=to_user_out(db, user))
