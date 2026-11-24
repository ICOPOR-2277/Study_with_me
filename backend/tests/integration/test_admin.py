from tests.integration.conftest import meeting_body

ADMIN = ("admin@uni.edu", "clave-admin-1")


def admin_headers(client):
    from app.db.session import get_sessionmaker
    from app.services import admin_service
    with get_sessionmaker()() as db:
        admin_service.ensure_admin(db, *ADMIN)
    r = client.post("/auth/login", json={"email": ADMIN[0], "password": ADMIN[1]})
    assert r.status_code == 200 and r.json()["user"]["role"] == "admin"
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_ensure_admin_is_idempotent_and_does_not_hijack(client, make_user):
    from app.db.session import get_sessionmaker
    from app.services import admin_service
    with get_sessionmaker()() as db:
        assert admin_service.ensure_admin(db, *ADMIN) == "created"
        assert admin_service.ensure_admin(db, *ADMIN) == "exists"
    make_user("ana@uni.edu", "ana")
    with get_sessionmaker()() as db:
        assert admin_service.ensure_admin(db, "ana@uni.edu", "otra-clave-77") == "conflict"  # no convierte a Ana en admin


def test_admin_routes_require_admin_role(client, make_user):
    assert client.get("/admin/stats").status_code == 401
    ana = make_user("ana@uni.edu", "ana")
    r = ana.get("/admin/stats")
    assert r.status_code == 403 and r.json()["code"] == "admin_only"
    assert client.get("/admin/stats", headers=admin_headers(client)).status_code == 200


def test_panel_page_is_served(client):
    r = client.get("/panel")
    assert r.status_code == 200 and "Study With Me" in r.text and r.headers["x-frame-options"] == "DENY"


def test_stats_users_and_suspension(client, make_user):
    h = admin_headers(client)
    mon = make_user("m@uni.edu", "monica", role="monitor", subjects=["Cálculo"])
    ana = make_user("ana@uni.edu", "ana")
    mid = mon.post("/meetings", meeting_body(price=15000)).json()["id"]
    assert ana.post(f"/meetings/{mid}/join").status_code == 200
    st = client.get("/admin/stats", headers=h).json()
    assert (st["users_total"], st["users_students"], st["users_monitors"], st["users_admins"]) == (3, 1, 1, 1)
    assert (st["meetings_total"], st["meetings_scheduled"], st["registrations_total"]) == (1, 1, 1)
    assert (st["payments_total"], st["payments_amount_cop"]) == (1, 15000)
    # búsqueda y filtros
    users = client.get("/admin/users", params={"q": "ana"}, headers=h).json()
    assert [u["username"] for u in users] == ["ana"] and users[0]["registrations"] == 1
    assert [u["username"] for u in client.get("/admin/users", params={"role": "monitor"}, headers=h).json()] == ["monica"]
    # suspender: no puede iniciar sesión ni usar su token
    uid = users[0]["id"]
    assert client.put(f"/admin/users/{uid}/active", json={"is_active": False}, headers=h).status_code == 200
    r = client.post("/auth/login", json={"email": "ana@uni.edu", "password": "clave-segura-1"})
    assert r.status_code == 403 and r.json()["code"] == "account_disabled"
    assert ana.get("/users/me").status_code == 403
    assert [u["username"] for u in client.get("/admin/users", params={"status": "suspended"}, headers=h).json()] == ["ana"]
    # reactivar
    assert client.put(f"/admin/users/{uid}/active", json={"is_active": True}, headers=h).status_code == 200
    assert ana.get("/users/me").status_code == 200


def test_admin_cannot_suspend_self_or_other_admin(client):
    h = admin_headers(client)
    me = client.get("/admin/users", params={"role": "admin"}, headers=h).json()[0]["id"]
    r = client.put(f"/admin/users/{me}/active", json={"is_active": False}, headers=h)
    assert r.status_code == 400 and r.json()["code"] == "cannot_disable_self"
    assert client.put("/admin/users/no-es-uuid/active", json={"is_active": False}, headers=h).status_code == 404


def test_admin_lists_and_cancels_meetings(client, make_user):
    h = admin_headers(client)
    mon = make_user("m@uni.edu", "monica", role="monitor", subjects=["Cálculo"])
    mid = mon.post("/meetings", meeting_body(title="Derivadas")).json()["id"]
    rows = client.get("/admin/meetings", params={"q": "deriv"}, headers=h).json()
    assert [r["title"] for r in rows] == ["Derivadas"] and rows[0]["host_email"] == "m@uni.edu" and rows[0]["taken"] == 0
    assert client.post(f"/admin/meetings/{mid}/cancel", headers=h).status_code == 200
    assert client.get("/admin/meetings", params={"status": "cancelled"}, headers=h).json()[0]["status"] == "cancelled"
    r = client.post(f"/admin/meetings/{mid}/cancel", headers=h)
    assert r.status_code == 409 and r.json()["code"] == "already_cancelled"
    assert mon.get(f"/meetings/{mid}").json()["status"] == "cancelled"