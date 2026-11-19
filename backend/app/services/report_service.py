"""Calendario, Historial (reuniones y pagos) y Resumen (Inicio / Perfil)."""
from __future__ import annotations

import calendar as pycal
from datetime import date, datetime, time

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, aliased, contains_eager

from app.core.timeutil import duration_hours, week_range
from app.models import Meeting, MonitorSubject, Payment, Subject, User, UserInterest
from app.schemas.meeting import (CalendarEventOut, HistoryMeetingOut, PaymentOut, SubjectCountOut, SummaryOut,
                                 WeekSummaryOut)
from app.services import meeting_service as ms


def _participating(user: User):
    return (select(Meeting).join(Subject, Meeting.subject_id == Subject.id)
            .options(contains_eager(Meeting.subject)).where(ms.participates(user.id)))


def calendar_events(db: Session, user: User, start: date, end: date) -> list[CalendarEventOut]:
    stmt = (_participating(user).where(Meeting.status == "scheduled", Meeting.meeting_date.between(start, end))
            .order_by(Meeting.meeting_date, Meeting.start_time))
    return [CalendarEventOut(meeting_id=str(m.id), title=m.title, subject=m.subject.name, date=m.meeting_date,
                             start_time=m.start_time, end_time=m.end_time) for m in db.scalars(stmt).unique()]


def _month_bounds(year: int, month: int) -> tuple[date, date]:
    return date(year, month, 1), date(year, month, pycal.monthrange(year, month)[1])


def history_meetings(db: Session, user: User, year: int, month: int, subject: str | None, now: datetime) -> list[HistoryMeetingOut]:
    first, last = _month_bounds(year, month)
    finished = or_(Meeting.status == "cancelled", Meeting.meeting_date < now.date(),
                   (Meeting.meeting_date == now.date()) & (Meeting.end_time <= now.time()))
    stmt = _participating(user).where(Meeting.meeting_date.between(first, last), finished)
    if subject:
        stmt = stmt.where(Subject.name == subject)
    stmt = stmt.order_by(Meeting.meeting_date.desc(), Meeting.start_time.desc())
    return [HistoryMeetingOut(meeting_id=str(m.id), title=m.title, subject=m.subject.name, date=m.meeting_date,
                              created_by_me=m.creator_id == user.id, cancelled=m.status == "cancelled")
            for m in db.scalars(stmt).unique()]


def history_payments(db: Session, user: User, year: int, month: int, subject: str | None, movement: str,
                     tz_name: str) -> list[PaymentOut]:
    """movement: 'all' | 'income' | 'expense'. Ingreso = pagaron a una reunión mía; salida = yo pagué."""
    first, last = _month_bounds(year, month)
    local_ts = func.timezone(tz_name, Payment.created_at)
    payer = aliased(User)
    stmt = (select(Payment, Meeting, Subject, payer, User)
            .join(Meeting, Meeting.id == Payment.meeting_id)
            .join(Subject, Subject.id == Meeting.subject_id)
            .join(payer, payer.id == Payment.payer_id)
            .join(User, User.id == Meeting.creator_id)
            .where(or_(Payment.payer_id == user.id, Meeting.creator_id == user.id),
                   local_ts >= datetime.combine(first, time.min),
                   local_ts < datetime.combine(last, time.max)))
    if subject:
        stmt = stmt.where(Subject.name == subject)
    if movement == "income":
        stmt = stmt.where(Meeting.creator_id == user.id)
    elif movement == "expense":
        stmt = stmt.where(Payment.payer_id == user.id)
    stmt = stmt.order_by(Payment.created_at.desc())
    out: list[PaymentOut] = []
    for pay, meeting, subj, payer_user, creator in db.execute(stmt).all():
        is_income = meeting.creator_id == user.id
        local_date = pay.created_at.astimezone(_zone(tz_name)).date()
        out.append(PaymentOut(
            meeting_id=str(meeting.id), title=meeting.title, subject=subj.name,
            detail=f"Pago de {payer_user.full_name}" if is_income else f"Pago a {creator.full_name}",
            date=local_date, amount=pay.amount_cop if is_income else -pay.amount_cop))
    return out


def _zone(tz_name: str):
    from zoneinfo import ZoneInfo
    return ZoneInfo(tz_name)


def summary(db: Session, user: User, now: datetime) -> SummaryOut:
    """Cifras de Inicio y Perfil.

    - sessions_completed / hours_completed: reuniones (no canceladas) en las que participé y ya terminaron.
    - week: semana domingo-sábado. scheduled = aún no terminadas; hours = horas de todas las de la semana;
      completed = ya terminadas.
    - subjects: materias propias (domina + intereses); si no tiene ninguna, todas. 'upcoming' = reuniones próximas.
    """
    mine = list(db.scalars(_participating(user).where(Meeting.status == "scheduled").order_by(Meeting.meeting_date, Meeting.start_time)).unique())
    done = [m for m in mine if ms.has_ended(m, now)]
    ahead = [m for m in mine if not ms.has_ended(m, now)]
    w_start, w_end = week_range(now.date())
    in_week = [m for m in mine if w_start <= m.meeting_date <= w_end]

    own = set(db.scalars(select(Subject.name).join(MonitorSubject, MonitorSubject.subject_id == Subject.id).where(MonitorSubject.user_id == user.id)))
    own |= set(db.scalars(select(Subject.name).join(UserInterest, UserInterest.subject_id == Subject.id).where(UserInterest.user_id == user.id)))
    counts = dict(db.execute(select(Subject.name, func.count(Meeting.id)).select_from(Subject)
                             .outerjoin(Meeting, (Meeting.subject_id == Subject.id) & (Meeting.status == "scheduled") & ms.upcoming(now))
                             .group_by(Subject.name)).all())
    names = sorted(own) if own else sorted(counts)
    nxt = ms.build_outs(db, user, [ahead[0]])[0] if ahead else None
    return SummaryOut(
        sessions_completed=len(done),
        hours_completed=round(sum(duration_hours(m.start_time, m.end_time) for m in done), 1),
        week=WeekSummaryOut(scheduled=sum(1 for m in in_week if not ms.has_ended(m, now)),
                            hours=round(sum(duration_hours(m.start_time, m.end_time) for m in in_week), 1),
                            completed=sum(1 for m in in_week if ms.has_ended(m, now))),
        subjects=[SubjectCountOut(name=n, upcoming=int(counts.get(n, 0))) for n in names],
        next_meeting=nxt)
