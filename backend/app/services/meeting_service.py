from __future__ import annotations

import uuid
from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime, time

from sqlalchemy import and_, exists, func, or_, select
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session, contains_eager

from app.core.errors import AppError, Conflict, Forbidden, NotFound
from app.models import Meeting, MonitorSubject, Payment, Registration, SavedMeeting, Subject, User, UserInterest
from app.schemas.meeting import MeetingCreateIn, MeetingOut, MeetingUpdateIn
from app.services import recommendation as rec
from app.services.subject_service import subject_by_name
from app.services.user_service import slots_of

TIME_BUCKETS = {"Mañana": (time(0, 0), time(12, 0)), "Tarde": (time(12, 0), time(18, 0)), "Noche": (time(18, 0), None)}
MAX_ROWS = 500


@dataclass
class SearchParams:
    q: str = ""
    subject: str | None = None
    time_of_day: str | None = None
    day: date | None = None
    modality: str | None = None  # 'Presencial' | 'Virtual'
    price_min: int | None = None
    price_max: int | None = None
    sort: str = "soonest"
    limit: int = 100
    offset: int = 0


# ---------------------------------------------------------------- helpers

def parse_id(value: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except ValueError:
        raise NotFound("Reunión no encontrada")


def has_ended(m: Meeting, now: datetime) -> bool:
    return datetime.combine(m.meeting_date, m.end_time) <= now


def participates(user_id: uuid.UUID):
    """Condición SQL: la persona creó la reunión o está inscrita."""
    return or_(Meeting.creator_id == user_id,
               exists().where(Registration.meeting_id == Meeting.id, Registration.user_id == user_id))


def upcoming(now: datetime):
    return or_(Meeting.meeting_date > now.date(), and_(Meeting.meeting_date == now.date(), Meeting.end_time > now.time()))


def _escape_like(text: str) -> str:
    return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def taken_counts(db: Session, meeting_ids: list[uuid.UUID]) -> dict[uuid.UUID, int]:
    if not meeting_ids:
        return {}
    rows = db.execute(select(Registration.meeting_id, func.count()).where(Registration.meeting_id.in_(meeting_ids))
                      .group_by(Registration.meeting_id)).all()
    return {mid: n for mid, n in rows}


def build_outs(db: Session, user: User, meetings: list[Meeting]) -> list[MeetingOut]:
    ids = [m.id for m in meetings]
    taken = taken_counts(db, ids)
    joined = set(db.scalars(select(Registration.meeting_id).where(Registration.user_id == user.id, Registration.meeting_id.in_(ids)))) if ids else set()
    saved = set(db.scalars(select(SavedMeeting.meeting_id).where(SavedMeeting.user_id == user.id, SavedMeeting.meeting_id.in_(ids)))) if ids else set()
    return [MeetingOut(
        id=str(m.id), title=m.title, subject=m.subject.name, host=m.creator.full_name, host_id=str(m.creator_id),
        description=m.description, date=m.meeting_date, start_time=m.start_time, end_time=m.end_time,
        is_virtual=m.is_virtual, location=m.location, capacity=m.capacity, price=m.price_cop,
        spots=max(m.capacity - taken.get(m.id, 0), 0), saved=m.id in saved, joined=m.id in joined,
        created_by_me=m.creator_id == user.id, status=m.status) for m in meetings]


def _load(db: Session, meeting_id: uuid.UUID, *, lock: bool = False) -> Meeting:
    stmt = select(Meeting).where(Meeting.id == meeting_id)
    if lock:
        stmt = stmt.with_for_update(of=Meeting)
    m = db.scalars(stmt).unique().first()
    if m is None:
        raise NotFound("Reunión no encontrada")
    return m


# ---------------------------------------------------------------- consultas

def search(db: Session, user: User, p: SearchParams, now: datetime) -> list[MeetingOut]:
    stmt = (select(Meeting).join(Subject, Meeting.subject_id == Subject.id).join(User, Meeting.creator_id == User.id)
            .options(contains_eager(Meeting.subject), contains_eager(Meeting.creator))
            .where(Meeting.status == "scheduled", upcoming(now)))
    text = p.q.strip()
    if text:
        like = f"%{_escape_like(text)}%"
        stmt = stmt.where(or_(Meeting.title.ilike(like, escape="\\"), Subject.name.ilike(like, escape="\\"),
                              User.full_name.ilike(like, escape="\\")))
    if p.subject:
        stmt = stmt.where(Subject.name == p.subject)
    if p.time_of_day:
        lo, hi = TIME_BUCKETS[p.time_of_day]
        stmt = stmt.where(Meeting.start_time >= lo)
        if hi:
            stmt = stmt.where(Meeting.start_time < hi)
    if p.day:
        stmt = stmt.where(Meeting.meeting_date == p.day)
    if p.modality:
        stmt = stmt.where(Meeting.is_virtual == (p.modality == "Virtual"))
    if p.price_min is not None:
        stmt = stmt.where(Meeting.price_cop >= p.price_min)
    if p.price_max is not None:
        stmt = stmt.where(Meeting.price_cop <= p.price_max)
    stmt = stmt.order_by(Meeting.meeting_date, Meeting.start_time, Meeting.id).limit(MAX_ROWS)
    meetings = list(db.scalars(stmt).unique())
    outs = build_outs(db, user, meetings)

    if p.sort == "price":
        outs.sort(key=lambda o: (o.price, o.date, o.start_time))
    elif p.sort == "spots":
        outs.sort(key=lambda o: (-o.spots, o.date, o.start_time))
    elif p.sort == "recommended":
        outs = _recommended_order(db, user, meetings, outs, now)
    return outs[p.offset:p.offset + p.limit]


def _profile(db: Session, user: User) -> rec.Profile:
    interests = set(db.scalars(select(Subject.name).join(UserInterest, UserInterest.subject_id == Subject.id).where(UserInterest.user_id == user.id)))
    expertise = set(db.scalars(select(Subject.name).join(MonitorSubject, MonitorSubject.subject_id == Subject.id).where(MonitorSubject.user_id == user.id)))
    past = Counter(db.scalars(select(Subject.name).join(Meeting, Meeting.subject_id == Subject.id)
                              .join(Registration, Registration.meeting_id == Meeting.id).where(Registration.user_id == user.id)))
    slots = [rec.Slot(s.weekday, s.start_time, s.end_time) for s in slots_of(db, user.id)]
    return rec.Profile(interests=interests, expertise=expertise, past_subjects=past, slots=slots)


def _recommended_order(db: Session, user: User, meetings: list[Meeting], outs: list[MeetingOut], now: datetime) -> list[MeetingOut]:
    """Ordena por puntaje; las que no puedes tomar (propias, ya inscritas, sin cupos) quedan al final."""
    profile = _profile(db, user)
    by_id = {o.id: o for o in outs}
    cands = [rec.Candidate(str(m.id), m.subject.name, m.meeting_date, m.start_time, m.end_time) for m in meetings]
    ranked = [by_id[c.id] for c, _, _ in rec.rank(cands, profile, now)]
    available = [o for o in ranked if not (o.created_by_me or o.joined or o.spots == 0)]
    others = [o for o in ranked if o.created_by_me or o.joined or o.spots == 0]
    return available + others


def get_one(db: Session, user: User, meeting_id: str) -> MeetingOut:
    return build_outs(db, user, [_load(db, parse_id(meeting_id))])[0]


# ---------------------------------------------------------------- acciones

def create(db: Session, user: User, data: MeetingCreateIn, now: datetime) -> MeetingOut:
    subject = subject_by_name(db, data.subject)
    if data.price > 0 and not user.is_monitor:
        raise Forbidden("Las reuniones de estudiantes son gratuitas", code="students_free_only")
    if datetime.combine(data.date, data.start_time) <= now:
        raise AppError("La reunión debe empezar en el futuro", code="meeting_in_past")
    m = Meeting(creator_id=user.id, subject_id=subject.id, title=data.title, description=data.description,
                meeting_date=data.date, start_time=data.start_time, end_time=data.end_time, is_virtual=data.is_virtual,
                location=data.location, capacity=data.capacity, price_cop=data.price)
    db.add(m)
    db.commit()
    return get_one(db, user, str(m.id))


def update(db: Session, user: User, meeting_id: str, data: MeetingUpdateIn, now: datetime) -> MeetingOut:
    """Edita una reunión. Reglas:
    - solo la persona que la creó; no se edita una cancelada ni una que ya terminó;
    - si cambia la fecha u hora de inicio, el nuevo inicio debe ser futuro;
    - el aforo no puede quedar por debajo de las personas ya inscritas;
    - con personas inscritas NO se puede cambiar la materia ni el precio (ya pagaron/eligieron con esos datos);
    - los estudiantes solo pueden dejarla gratis (igual que al crearla).
    """
    m = _load(db, parse_id(meeting_id), lock=True)  # el mismo bloqueo que join: cupos y aforo no se pisan
    if m.creator_id != user.id:
        raise Forbidden("Solo quien creó la reunión puede editarla", code="not_creator")
    if m.status == "cancelled":
        raise Conflict("La reunión está cancelada", code="meeting_cancelled")
    if has_ended(m, now):
        raise Conflict("La reunión ya terminó", code="meeting_ended")
    if data.price > 0 and not user.is_monitor:
        raise Forbidden("Las reuniones de estudiantes son gratuitas", code="students_free_only")
    if (data.date, data.start_time) != (m.meeting_date, m.start_time) and datetime.combine(data.date, data.start_time) <= now:
        raise AppError("La reunión debe empezar en el futuro", code="meeting_in_past")
    subject = subject_by_name(db, data.subject)
    taken = db.scalar(select(func.count()).select_from(Registration).where(Registration.meeting_id == m.id)) or 0
    if data.capacity < taken:
        raise Conflict(f"Ya hay {taken} personas inscritas: el aforo no puede ser menor", code="capacity_below_registered")
    if taken > 0 and (subject.id != m.subject_id or data.price != m.price_cop):
        raise Conflict("Con personas inscritas no se puede cambiar la materia ni el precio",
                       code="locked_has_registrations")
    m.subject = subject  # asigna la relación (no solo el id) para que la respuesta salga con la materia nueva
    m.title, m.description = data.title, data.description
    m.meeting_date, m.start_time, m.end_time = data.date, data.start_time, data.end_time
    m.is_virtual, m.location, m.capacity, m.price_cop = data.is_virtual, data.location, data.capacity, data.price
    db.commit()
    return get_one(db, user, meeting_id)


def join(db: Session, user: User, meeting_id: str, now: datetime) -> MeetingOut:
    mid = parse_id(meeting_id)
    m = _load(db, mid, lock=True)  # bloquea la fila: dos personas no pueden tomar el último cupo a la vez
    if m.status != "scheduled":
        raise Conflict("La reunión fue cancelada", code="meeting_cancelled")
    if m.creator_id == user.id:
        raise Conflict("No puedes unirte a tu propia reunión", code="own_meeting")
    if has_ended(m, now):
        raise Conflict("La reunión ya terminó", code="meeting_ended")
    if db.get(Registration, (mid, user.id)) is not None:
        raise Conflict("Ya estás inscrito en esta reunión", code="already_joined")
    taken = db.scalar(select(func.count()).select_from(Registration).where(Registration.meeting_id == mid)) or 0
    if taken >= m.capacity:
        raise Conflict("La reunión no tiene cupos disponibles", code="no_spots")
    try:
        db.add(Registration(meeting_id=mid, user_id=user.id))
        db.flush()
        if m.price_cop > 0:  # pago SIMULADO: solo se guarda el monto
            db.add(Payment(meeting_id=mid, payer_id=user.id, amount_cop=m.price_cop))
        db.commit()
    except DBAPIError:
        db.rollback()
        raise Conflict("No fue posible inscribirte. Intenta de nuevo.", code="join_failed")
    return get_one(db, user, meeting_id)


def set_saved(db: Session, user: User, meeting_id: str, saved: bool) -> MeetingOut:
    mid = parse_id(meeting_id)
    _load(db, mid)
    row = db.get(SavedMeeting, (user.id, mid))
    if saved and row is None:
        db.add(SavedMeeting(user_id=user.id, meeting_id=mid))
    elif not saved and row is not None:
        db.delete(row)
    db.commit()
    return get_one(db, user, meeting_id)


def cancel(db: Session, user: User, meeting_id: str, now: datetime) -> MeetingOut:
    m = _load(db, parse_id(meeting_id), lock=True)
    if m.creator_id != user.id:
        raise Forbidden("Solo quien creó la reunión puede cancelarla", code="not_creator")
    if m.status == "cancelled":
        raise Conflict("La reunión ya estaba cancelada", code="already_cancelled")
    if has_ended(m, now):
        raise Conflict("La reunión ya terminó", code="meeting_ended")
    m.status = "cancelled"
    db.commit()
    return get_one(db, user, meeting_id)
