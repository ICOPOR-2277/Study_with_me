from datetime import datetime, timedelta, timezone

from app.core import security

SECRET = "x" * 40


def test_password_hash_roundtrip_and_salt():
    h1 = security.hash_password("clave-segura-1", n=2 ** 10)
    h2 = security.hash_password("clave-segura-1", n=2 ** 10)
    assert h1 != h2 and "clave-segura-1" not in h1
    assert security.verify_password("clave-segura-1", h1)
    assert not security.verify_password("otra-clave", h1)


def test_verify_rejects_garbage():
    assert not security.verify_password("x", "no-es-un-hash")
    assert not security.verify_password("x", "bcrypt$1$2$3$4$5")


def test_needs_rehash():
    assert security.needs_rehash(security.hash_password("abc12345", n=2 ** 10))
    assert not security.needs_rehash(security.hash_password("abc12345"))


def test_jwt_roundtrip_expired_and_tampered():
    token = security.create_access_token("user-1", SECRET, 5)
    assert security.decode_access_token(token, SECRET) == "user-1"
    assert security.decode_access_token(token, "y" * 40) is None
    old = security.create_access_token("user-1", SECRET, 1, now=datetime.now(timezone.utc) - timedelta(hours=1))
    assert security.decode_access_token(old, SECRET) is None
    assert security.decode_access_token(token[:-2] + "xx", SECRET) is None
    assert security.decode_access_token("basura", SECRET) is None


def test_verification_code():
    code = security.generate_verification_code()
    assert len(code) == 6 and code.isdigit()
    h = security.hash_verification_code(code, SECRET)
    assert code not in h
    assert security.verify_verification_code(code, h, SECRET)
    assert not security.verify_verification_code("000000" if code != "000000" else "111111", h, SECRET)
    assert not security.verify_verification_code(code, h, "z" * 40)
