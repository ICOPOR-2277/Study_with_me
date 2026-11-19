from collections import Counter
from datetime import date, datetime, time

from app.services import recommendation as rec

NOW = datetime(2026, 11, 16, 8, 0)  # lunes
MON = date(2026, 11, 16)
TUE = date(2026, 11, 17)


def cand(id, subject, d=TUE, s=time(15, 0), e=time(16, 0)):
    return rec.Candidate(id, subject, d, s, e)


def test_interest_beats_closer_meeting():
    profile = rec.Profile(interests={"Física"})
    ranked = rec.rank([cand("cerca", "Inglés", MON, time(9)), cand("interes", "Física", date(2026, 11, 25))], profile, NOW)
    assert [c.id for c, _, _ in ranked] == ["interes", "cerca"]
    assert rec.R_INTEREST in ranked[0][2]


def test_availability_fit_requires_same_weekday_and_full_containment():
    slot = rec.Slot(weekday=1, start=time(14), end=time(18))  # martes 14-18
    assert rec.fits_availability(cand("a", "x", TUE, time(15), time(16)), [slot])
    assert not rec.fits_availability(cand("b", "x", TUE, time(17), time(19)), [slot])  # se sale de la franja
    assert not rec.fits_availability(cand("c", "x", MON, time(15), time(16)), [slot])  # otro día


def test_past_registrations_capped_and_expertise():
    p = rec.Profile(past_subjects=Counter({"Cálculo": 10}), expertise={"Cálculo"})
    s, reasons = rec.score(cand("a", "Cálculo"), p, NOW)
    assert reasons == [rec.R_EXPERTISE, rec.R_PAST]
    assert s > rec.W_EXPERTISE + rec.W_PAST_EACH * rec.W_PAST_MAX_COUNT  # + algo de cercanía
    assert s < rec.W_EXPERTISE + rec.W_PAST_EACH * rec.W_PAST_MAX_COUNT + rec.W_PROXIMITY + 1e-9


def test_no_signals_falls_back_to_soonest():
    ranked = rec.rank([cand("tarde", "A", date(2026, 11, 30)), cand("pronto", "B", MON, time(10))], rec.Profile(), NOW)
    assert [c.id for c, _, _ in ranked] == ["pronto", "tarde"]
    assert ranked[0][2] == []


def test_ties_are_deterministic():
    a, b = cand("b", "X"), cand("a", "X")
    assert [c.id for c, _, _ in rec.rank([a, b], rec.Profile(), NOW)] == ["a", "b"]
