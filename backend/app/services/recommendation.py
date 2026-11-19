"""Recomendaciones automáticas de reuniones. Lógica pura (sin base de datos) para poder probarla.

Puntaje = señales de la persona + cercanía en el tiempo:
  +3.0   la materia está en sus intereses
  +1.0   la materia es una de las que domina (monitor)
  +0.5   por cada inscripción previa en esa materia (máx. 3 -> +1.5)
  +2.0   la reunión cabe completa dentro de una franja de su disponibilidad
  +1.0   cercanía: 1 / (1 + días_hasta_la_reunión / 7)
Sin señales de ningún tipo, el orden queda por cercanía (igual que "Más próximas").
"""
from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from datetime import date, datetime, time


@dataclass(frozen=True)
class Slot:
    weekday: int  # 0 = lunes
    start: time
    end: time


@dataclass
class Profile:
    interests: set[str] = field(default_factory=set)
    expertise: set[str] = field(default_factory=set)
    past_subjects: Counter = field(default_factory=Counter)
    slots: list[Slot] = field(default_factory=list)


@dataclass(frozen=True)
class Candidate:
    id: str
    subject: str
    meeting_date: date
    start: time
    end: time


W_INTEREST = 3.0
W_EXPERTISE = 1.0
W_PAST_EACH = 0.5
W_PAST_MAX_COUNT = 3
W_AVAILABILITY = 2.0
W_PROXIMITY = 1.0

R_INTEREST = "Coincide con tus intereses"
R_EXPERTISE = "Es una materia que dominas"
R_PAST = "Ya asististe a reuniones de esta materia"
R_AVAILABILITY = "Encaja con tu disponibilidad"


def fits_availability(c: Candidate, slots: list[Slot]) -> bool:
    wd = c.meeting_date.weekday()
    return any(s.weekday == wd and s.start <= c.start and c.end <= s.end for s in slots)


def score(c: Candidate, profile: Profile, now: datetime) -> tuple[float, list[str]]:
    total = 0.0
    reasons: list[str] = []
    if c.subject in profile.interests:
        total += W_INTEREST
        reasons.append(R_INTEREST)
    if c.subject in profile.expertise:
        total += W_EXPERTISE
        reasons.append(R_EXPERTISE)
    past = min(profile.past_subjects.get(c.subject, 0), W_PAST_MAX_COUNT)
    if past:
        total += W_PAST_EACH * past
        reasons.append(R_PAST)
    if fits_availability(c, profile.slots):
        total += W_AVAILABILITY
        reasons.append(R_AVAILABILITY)
    starts = datetime.combine(c.meeting_date, c.start)
    days = max((starts - now).total_seconds() / 86400, 0)
    total += W_PROXIMITY / (1 + days / 7)
    return round(total, 6), reasons


def rank(candidates: list[Candidate], profile: Profile, now: datetime) -> list[tuple[Candidate, float, list[str]]]:
    """Ordena de mayor a menor puntaje; a igual puntaje, la que empieza antes."""
    scored = [(c, *score(c, profile, now)) for c in candidates]
    scored.sort(key=lambda t: (-t[1], datetime.combine(t[0].meeting_date, t[0].start), t[0].id))
    return scored
