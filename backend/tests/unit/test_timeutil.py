from datetime import date, time

from app.core.timeutil import duration_hours, time_of_day, week_range


def test_time_of_day_matches_flutter_cutoffs():
    assert time_of_day(time(11, 59)) == "Mañana"
    assert time_of_day(time(12, 0)) == "Tarde"
    assert time_of_day(time(17, 59)) == "Tarde"
    assert time_of_day(time(18, 0)) == "Noche"


def test_week_range_sunday_to_saturday():
    # 2026-11-16 es lunes -> semana 15 (dom) a 21 (sáb)
    assert week_range(date(2026, 11, 16)) == (date(2026, 11, 15), date(2026, 11, 21))
    assert week_range(date(2026, 11, 15)) == (date(2026, 11, 15), date(2026, 11, 21))  # domingo
    assert week_range(date(2026, 11, 21)) == (date(2026, 11, 15), date(2026, 11, 21))  # sábado


def test_duration_hours():
    assert duration_hours(time(9, 0), time(10, 30)) == 1.5
