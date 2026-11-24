"""Prueba de humo contra una API ya desplegada (solo biblioteca estándar).

Uso:
    python backend/scripts/smoke_test.py https://study-with-me-api.onrender.com
    python backend/scripts/smoke_test.py http://127.0.0.1:8000 --admin-email a@x.co --admin-password '...'

Comprueba: /health, /subjects, /panel (HTML del panel), rutas protegidas sin token
y, si se dan credenciales de administrador, el login y /admin/stats.
No crea datos. El primer request a Render gratis puede tardar ~60 s (el servicio duerme).
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request

ok_count = 0
fail_count = 0


def call(base, path, method="GET", body=None, token=None, timeout=90):
    headers = {"User-Agent": "swm-smoke/1.0", "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, dict(r.headers), r.read()
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read()


def check(name, cond, detail=""):
    global ok_count, fail_count
    if cond:
        ok_count += 1
        print(f"  OK     {name}")
    else:
        fail_count += 1
        print(f"  FALLÓ  {name} {detail}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("base_url")
    ap.add_argument("--admin-email")
    ap.add_argument("--admin-password")
    a = ap.parse_args()
    base = a.base_url.rstrip("/")
    print(f"Probando {base} ...")

    s, _, b = call(base, "/health")
    check("GET /health responde 200", s == 200, f"(status {s})")

    s, _, b = call(base, "/subjects")
    names = json.loads(b) if s == 200 else []
    check("GET /subjects devuelve las 6 materias", len(names) >= 6, f"(status {s}, {names})")

    s, h, b = call(base, "/panel")
    hl = {k.lower(): v for k, v in h.items()}
    check("GET /panel sirve el panel HTML", s == 200 and b"Study With Me" in b, f"(status {s})")
    check("/panel con X-Frame-Options DENY", hl.get("x-frame-options") == "DENY")

    s, _, _ = call(base, "/users/me")
    check("/users/me sin token es 401/403", s in (401, 403), f"(status {s})")
    s, _, _ = call(base, "/admin/stats")
    check("/admin/stats sin token es 401/403", s in (401, 403), f"(status {s})")

    s, _, b = call(base, "/auth/login", "POST", {"email": "no.existe@example.com", "password": "x"})
    check("login con datos falsos es 401 (no 500)", s == 401, f"(status {s})")

    if a.admin_email and a.admin_password:
        s, _, b = call(base, "/auth/login", "POST", {"email": a.admin_email, "password": a.admin_password})
        data = json.loads(b) if s == 200 else {}
        check("login del administrador", s == 200 and data.get("user", {}).get("role") == "admin", f"(status {s})")
        if s == 200:
            s, _, b = call(base, "/admin/stats", token=data["access_token"])
            check("/admin/stats con token admin", s == 200 and "users_total" in json.loads(b), f"(status {s})")

    print(f"\n{ok_count} correctas, {fail_count} con fallo")
    return 1 if fail_count else 0


if __name__ == "__main__":
    sys.exit(main())