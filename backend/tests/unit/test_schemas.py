import pytest
from pydantic import ValidationError

from app.schemas.meeting import MeetingCreateIn, MeetingOut
from app.schemas.user import AvailabilityIn, RegisterIn, VerifyEmailIn

OK = dict(full_name="Laura Sánchez", username="@LauraEstudia", email=" Laura@Uni.EDU ", password="12345678")


def test_register_normalizes():
    r = RegisterIn(**OK, role="student")
    assert r.username == "lauraestudia" and r.email == "laura@uni.edu"


def test_register_monitor_subject_rules():
    assert RegisterIn(**OK, role="monitor", subjects=["Cálculo", "Física", "Inglés"]).subjects == ["Cálculo", "Física", "Inglés"]
    with pytest.raises(ValidationError):
        RegisterIn(**OK, role="monitor", subjects=[])
    with pytest.raises(ValidationError):
        RegisterIn(**OK, role="monitor", subjects=["Cálculo", "Física", "Inglés", "Programación"])
    with pytest.raises(ValidationError):
        RegisterIn(**OK, role="student", subjects=["Cálculo"])


@pytest.mark.parametrize("field,value", [("password", "corta"), ("email", "sin-arroba"), ("username", "a b"), ("role", "admin")])
def test_register_rejects(field, value):
    with pytest.raises(ValidationError):
        RegisterIn(**{**OK, "role": "student", field: value})


def test_verify_code_must_be_6_digits():
    VerifyEmailIn(email="a@b.co", code="012345")
    for bad in ("12345", "1234567", "abcdef"):
        with pytest.raises(ValidationError):
            VerifyEmailIn(email="a@b.co", code=bad)


def test_meeting_create_time_order_and_json_time_format():
    base = dict(title="t", subject="Cálculo", date="2026-12-01", start_time="09:00", end_time="10:30", location="Sala", capacity=5)
    m = MeetingCreateIn(**base)
    assert m.price == 0
    with pytest.raises(ValidationError):
        MeetingCreateIn(**{**base, "end_time": "09:00"})
    with pytest.raises(ValidationError):
        MeetingCreateIn(**{**base, "capacity": 0})
    out = MeetingOut(id="1", title="t", subject="s", host="h", host_id="2", description="", date=m.date, start_time=m.start_time,
                     end_time=m.end_time, is_virtual=False, location="l", capacity=5, price=0, spots=5, saved=False,
                     joined=False, created_by_me=False, status="scheduled")
    js = out.model_dump(mode="json")
    assert js["start_time"] == "09:00" and js["end_time"] == "10:30" and js["date"] == "2026-12-01"


def test_availability_rejects_inverted_range():
    AvailabilityIn(slots=[{"weekday": 0, "start_time": "14:00", "end_time": "18:00"}])
    with pytest.raises(ValidationError):
        AvailabilityIn(slots=[{"weekday": 0, "start_time": "18:00", "end_time": "14:00"}])
    with pytest.raises(ValidationError):
        AvailabilityIn(slots=[{"weekday": 7, "start_time": "08:00", "end_time": "09:00"}])


def test_profile_and_password_schemas():
    from app.schemas.user import PasswordChangeIn, ProfileUpdateIn, ResetPasswordIn
    p = ProfileUpdateIn(full_name=" Ana Gil ", username="@Ana.Gil")
    assert (p.full_name, p.username) == ("Ana Gil", "ana.gil")
    with pytest.raises(ValidationError):
        ProfileUpdateIn(full_name="Ana", username="a b")
    with pytest.raises(ValidationError):
        PasswordChangeIn(current_password="x", new_password="corta")
    with pytest.raises(ValidationError):
        ResetPasswordIn(email="a@b.co", code="12345", new_password="12345678")
    assert ResetPasswordIn(email=" A@B.co", code="123456", new_password="12345678").email == "a@b.co"