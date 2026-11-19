"""Utilidades de fecha/hora (puras, sin base de datos)."""
from __future__ import annotations

from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo


def local_now(tz_name: str) -> datetime:
    """Ahora, como hora de pared (sin tzinfo) en la zona de la universidad."""
    return datetime.now(ZoneInfo(tz_name)).replace(tzinfo=None)


def time_of_day(start: time) -> str:
    """Mismos cortes que Meeting.timeOfDay de Flutter: Mañana <12, Tarde <18, Noche."""
    if start.hour < 12:
        return "Mañana"
    if start.hour < 18:
        return "Tarde"
    return "Noche"


def week_range(today: date) -> tuple[date, date]:
    """Semana domingo-sábado que contiene 'today' (igual que el Calendario de Flutter)."""
    start = today - timedelta(days=(today.weekday() + 1) % 7)
    return start, start + timedelta(days=6)


def duration_hours(start: time, end: time) -> float:
    s = start.hour * 60 + start.minute
    e = end.hour * 60 + end.minute
    return max(e - s, 0) / 60
