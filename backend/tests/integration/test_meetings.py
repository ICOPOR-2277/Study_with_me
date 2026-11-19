from tests.integration.conftest import meeting_body


def test_create_search_filters(make_user):
    mon = make_user("m@uni.edu", "monica", role="monitor", subjects=["Cálculo", "Programación"])
    est = make_user("e@uni.edu", "estu")
    assert mon.post("/meetings", meeting_body(price=15000)).status_code == 201
    assert est.post("/meetings", meeting_body(title="Python", subject="Programación", date="2026-11-19", start_time="19:00",
                                              end_time="20:00", is_virtual=True, location="Meet")).status_code == 201
    allm = est.get("/meetings").json()
    assert [m["title"] for m in allm] == ["Derivadas", "Python"]
    assert allm[0]["spots"] == 2 and allm[0]["host"] == "Monica" and allm[0]["start_time"] == "15:00"
    assert [m["title"] for m in est.get("/meetings", params={"q": "pyth"}).json()] == ["Python"]
    assert [m["title"] for m in est.get("/meetings", params={"q": "monica"}).json()] == ["Derivadas"]
    assert [m["title"] for m in est.get("/meetings", params={"subject": "Cálculo"}).json()] == ["Derivadas"]
    assert [m["title"] for m in est.get("/meetings", params={"time_of_day": "Noche"}).json()] == ["Python"]
    assert [m["title"] for m in est.get("/meetings", params={"modality": "Virtual"}).json()] == ["Python"]
    assert [m["title"] for m in est.get("/meetings", params={"price_max": 0}).json()] == ["Python"]
    assert [m["title"] for m in est.get("/meetings", params={"price_min": 15001}).json()] == []
    assert [m["title"] for m in est.get("/meetings", params={"day": "2026-11-18"}).json()] == ["Derivadas"]
    assert [m["title"] for m in est.get("/meetings", params={"sort": "price"}).json()] == ["Python", "Derivadas"]
    assert est.get("/meetings", params={"q": "%"}).json() == []  # los comodines se escapan


def test_creation_rules(make_user):
    est = make_user("e@uni.edu", "estu")
    assert est.post("/meetings", meeting_body(price=5000)).status_code == 403  # estudiantes: gratis
    assert est.post("/meetings", meeting_body(date="2026-11-10")).status_code == 400  # en el pasado
    assert est.post("/meetings", meeting_body(end_time="14:00")).status_code == 422
    assert est.post("/meetings", meeting_body(subject="Alquimia")).status_code == 400


def test_join_capacity_payment_and_permissions(make_user):
    mon = make_user("m@uni.edu", "monica", role="monitor", subjects=["Cálculo"])
    a, b, c = (make_user(f"{n}@uni.edu", n) for n in ("ana", "beto", "cami"))
    mid = mon.post("/meetings", meeting_body(price=15000, capacity=2)).json()["id"]
    assert mon.post(f"/meetings/{mid}/join").status_code == 409  # propia
    r = a.post(f"/meetings/{mid}/join")
    assert r.status_code == 200 and r.json()["joined"] and r.json()["spots"] == 1
    assert a.post(f"/meetings/{mid}/join").status_code == 409  # ya inscrito
    assert b.post(f"/meetings/{mid}/join").json()["spots"] == 0
    r = c.post(f"/meetings/{mid}/join")
    assert r.status_code == 409 and r.json()["code"] == "no_spots"
    # pagos simulados: gasto para quien paga, ingreso para el monitor
    pays_a = a.get("/history/payments", params={"year": 2026, "month": 11}).json()
    assert [(p["amount"], p["detail"]) for p in pays_a] == [(-15000, "Pago a Monica")]
    pays_m = mon.get("/history/payments", params={"year": 2026, "month": 11}).json()
    assert sorted(p["amount"] for p in pays_m) == [15000, 15000]
    assert {p["detail"] for p in pays_m} == {"Pago de Ana", "Pago de Beto"}
    assert [p["amount"] for p in mon.get("/history/payments", params={"year": 2026, "month": 11, "movement": "expense"}).json()] == []
    # c no ve pagos ajenos
    assert c.get("/history/payments", params={"year": 2026, "month": 11}).json() == []


def test_free_meeting_creates_no_payment(make_user):
    a, b = make_user("a@uni.edu", "ana"), make_user("b@uni.edu", "beto")
    mid = a.post("/meetings", meeting_body()).json()["id"]
    assert b.post(f"/meetings/{mid}/join").status_code == 200
    assert b.get("/history/payments", params={"year": 2026, "month": 11}).json() == []


def test_save_toggle_and_cancel_permissions(make_user):
    a, b = make_user("a@uni.edu", "ana"), make_user("b@uni.edu", "beto")
    mid = a.post("/meetings", meeting_body()).json()["id"]
    assert b.put(f"/meetings/{mid}/save").json()["saved"] is True
    assert a.get(f"/meetings/{mid}").json()["saved"] is False  # el guardado es por persona
    assert b.delete(f"/meetings/{mid}/save").json()["saved"] is False
    assert b.post(f"/meetings/{mid}/cancel").status_code == 403
    assert a.post(f"/meetings/{mid}/cancel").json()["status"] == "cancelled"
    assert a.post(f"/meetings/{mid}/cancel").status_code == 409
    assert b.post(f"/meetings/{mid}/join").status_code == 409  # cancelada
    assert b.get("/meetings").json() == []  # ya no aparece en la búsqueda
    assert b.get("/meetings/no-es-uuid").status_code == 404


def test_calendar_history_and_summary(make_user):
    a, b = make_user("a@uni.edu", "ana"), make_user("b@uni.edu", "beto")
    future = a.post("/meetings", meeting_body(date="2026-11-18")).json()["id"]
    b.post(f"/meetings/{future}/join")
    cal_b = b.get("/calendar", params={"from": "2026-11-01", "to": "2026-11-30"}).json()
    assert [e["title"] for e in cal_b] == ["Derivadas"] and cal_b[0]["start_time"] == "15:00"
    assert a.get("/calendar", params={"from": "2026-11-01", "to": "2026-11-30"}).json()[0]["meeting_id"] == future
    assert make_user("c@uni.edu", "cami").get("/calendar", params={"from": "2026-11-01", "to": "2026-11-30"}).json() == []
    # cancelada por el creador -> aparece en historial como cancelada
    cancelled = a.post("/meetings", meeting_body(title="Cancelada", date="2026-11-20")).json()["id"]
    a.post(f"/meetings/{cancelled}/cancel")
    hist = a.get("/history/meetings", params={"year": 2026, "month": 11}).json()
    assert [(h["title"], h["created_by_me"], h["cancelled"]) for h in hist] == [("Cancelada", True, True)]
    s = b.get("/users/me/summary").json()
    assert s["next_meeting"]["id"] == future and s["week"]["scheduled"] == 1 and s["sessions_completed"] == 0
    assert any(x["name"] == "Cálculo" and x["upcoming"] >= 1 for x in s["subjects"])


def test_recommended_sort_uses_interests_and_availability(make_user):
    host = make_user("h@uni.edu", "host")
    host.post("/meetings", meeting_body(title="Ingles", subject="Inglés", date="2026-11-17", start_time="10:00", end_time="11:00"))
    host.post("/meetings", meeting_body(title="Fisica", subject="Física", date="2026-11-24", start_time="15:00", end_time="16:00"))
    me = make_user("me@uni.edu", "yo")
    assert [m["title"] for m in me.get("/meetings", params={"sort": "recommended"}).json()] == ["Ingles", "Fisica"]  # sin señales: más próxima
    assert me.put("/users/me/interests", {"subjects": ["Física"]}).json()["interests"] == ["Física"]
    assert [m["title"] for m in me.get("/meetings", params={"sort": "recommended"}).json()] == ["Fisica", "Ingles"]
    r = me.put("/users/me/availability", {"slots": [{"weekday": 1, "start_time": "09:00", "end_time": "12:00"}]})
    assert r.json()["availability"][0]["start_time"] == "09:00"
    # Inglés (martes 10:00, cabe en la franja): 2.0 + cercanía ~0.9 = ~2.9
    # Física (interés): 3.0 + cercanía ~0.47 = ~3.47  -> Física sigue primero
    assert [m["title"] for m in me.get("/meetings", params={"sort": "recommended"}).json()] == ["Fisica", "Ingles"]


def test_update_meeting_rules(make_user):
    mon = make_user("m@uni.edu", "monica", role="monitor", subjects=["Cálculo", "Programación"])
    a, b = make_user("ana@uni.edu", "ana"), make_user("beto@uni.edu", "beto")
    mid = mon.post("/meetings", meeting_body(price=15000, capacity=3)).json()["id"]
    # solo el creador
    assert a.put(f"/meetings/{mid}", meeting_body(title="Hack")).status_code == 403
    # sin inscritos se puede cambiar todo
    r = mon.put(f"/meetings/{mid}", meeting_body(title="Integrales", subject="Programación", price=20000, capacity=2,
                                                  date="2026-11-19", start_time="16:00", end_time="18:00"))
    assert r.status_code == 200
    body = r.json()
    assert (body["title"], body["subject"], body["price"], body["capacity"], body["date"], body["start_time"]) == \
           ("Integrales", "Programación", 20000, 2, "2026-11-19", "16:00")
    # con inscritos: materia y precio bloqueados; aforo no menor a los inscritos
    assert a.post(f"/meetings/{mid}/join").status_code == 200
    assert b.post(f"/meetings/{mid}/join").status_code == 200
    base = dict(title="Integrales", subject="Programación", price=20000, capacity=2, date="2026-11-19",
                start_time="16:00", end_time="18:00")
    r = mon.put(f"/meetings/{mid}", meeting_body(**{**base, "price": 1000}))
    assert r.status_code == 409 and r.json()["code"] == "locked_has_registrations"
    r = mon.put(f"/meetings/{mid}", meeting_body(**{**base, "subject": "Cálculo"}))
    assert r.status_code == 409 and r.json()["code"] == "locked_has_registrations"
    r = mon.put(f"/meetings/{mid}", meeting_body(**{**base, "capacity": 1}))
    assert r.status_code == 409 and r.json()["code"] == "capacity_below_registered"
    # título, descripción, lugar y aforo mayor sí se pueden cambiar
    r = mon.put(f"/meetings/{mid}", meeting_body(**{**base, "title": "Nuevo título", "capacity": 5, "location": "Aula 3"}))
    assert r.status_code == 200 and r.json()["spots"] == 3 and r.json()["location"] == "Aula 3"
    # el nuevo inicio debe ser futuro y no se edita una cancelada
    assert mon.put(f"/meetings/{mid}", meeting_body(**{**base, "date": "2026-11-10"})).status_code == 400
    assert mon.post(f"/meetings/{mid}/cancel").status_code == 200
    r = mon.put(f"/meetings/{mid}", meeting_body(**base))
    assert r.status_code == 409 and r.json()["code"] == "meeting_cancelled"


def test_student_cannot_set_price_when_editing(make_user):
    est = make_user("e@uni.edu", "estu")
    mid = est.post("/meetings", meeting_body()).json()["id"]
    assert est.put(f"/meetings/{mid}", meeting_body(price=5000)).status_code == 403
    assert est.put(f"/meetings/{mid}", meeting_body(title="Otro")).status_code == 200
