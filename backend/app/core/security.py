"""Contraseñas (scrypt), tokens JWT y códigos de verificación. Sin dependencias de FastAPI/SQLAlchemy."""
from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

import jwt

# scrypt (hashlib, librería estándar). Los parámetros quedan dentro del hash guardado,
# así se pueden endurecer después y detectar hashes viejos con needs_rehash().
SCRYPT_N = 2 ** 15
SCRYPT_R = 8
SCRYPT_P = 1
SCRYPT_MAXMEM = 128 * 1024 * 1024
JWT_ALGORITHM = "HS256"


def _b64(raw: bytes) -> str:
    return base64.b64encode(raw).decode("ascii")


def hash_password(password: str, *, n: int = SCRYPT_N, r: int = SCRYPT_R, p: int = SCRYPT_P) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode("utf-8"), salt=salt, n=n, r=r, p=p, maxmem=SCRYPT_MAXMEM, dklen=32)
    return f"scrypt${n}${r}${p}${_b64(salt)}${_b64(digest)}"


def verify_password(password: str, stored: str) -> bool:
    try:
        scheme, n, r, p, salt_b64, digest_b64 = stored.split("$")
        if scheme != "scrypt":
            return False
        salt = base64.b64decode(salt_b64)
        expected = base64.b64decode(digest_b64)
        actual = hashlib.scrypt(password.encode("utf-8"), salt=salt, n=int(n), r=int(r), p=int(p),
                                maxmem=SCRYPT_MAXMEM, dklen=len(expected))
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(actual, expected)


def needs_rehash(stored: str) -> bool:
    parts = stored.split("$")
    return len(parts) != 6 or (parts[1], parts[2], parts[3]) != (str(SCRYPT_N), str(SCRYPT_R), str(SCRYPT_P))


# Contraseña ficticia para igualar el tiempo de respuesta cuando el correo no existe.
DUMMY_HASH = hash_password("dummy-password-for-timing", n=2 ** 10)


def create_access_token(user_id: str, secret: str, expires_minutes: int, now: datetime | None = None) -> str:
    now = now or datetime.now(timezone.utc)
    payload = {"sub": user_id, "iat": now, "exp": now + timedelta(minutes=expires_minutes)}
    return jwt.encode(payload, secret, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str, secret: str) -> str | None:
    """Devuelve el id de usuario o None si el token es inválido o venció."""
    try:
        data = jwt.decode(token, secret, algorithms=[JWT_ALGORITHM], options={"require": ["exp", "sub"]})
    except jwt.PyJWTError:
        return None
    sub = data.get("sub")
    return sub if isinstance(sub, str) else None


def generate_verification_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_verification_code(code: str, secret: str) -> str:
    """HMAC con la clave del servidor: un código de 6 dígitos sin clave se rompería por fuerza bruta."""
    return hmac.new(secret.encode("utf-8"), code.encode("utf-8"), hashlib.sha256).hexdigest()


def verify_verification_code(code: str, stored_hash: str, secret: str) -> bool:
    return hmac.compare_digest(hash_verification_code(code, secret), stored_hash)
