"""Panel administrativo: estadísticas, usuarios y reuniones.

Solo lo usa app/routers/admin.py (protegido con require_admin).
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.core import security
from app.core.errors import AppError, Conflict, Forbidden, NotFound
from app.models import Meeting, Payment, Registration, Subject, User
from app.schemas.admin import AdminMeetingOut, AdminStatsOut, AdminUserOut, CountItem
from app.services import meeting_service as ms

logger = logging.getLogger("study_with_me.admin")
MAX_ROWS = 200


# ---------------------------------------------------------------- crear / asegurar al administrador

def ensure_admin(db: Session, email: str, password: str) -> str:
    """Crea la cuenta de administrador si no existe. Devuelve 'created' | 'exists' | 'conflict'.

    - 'exists': ya hay un admin con ese correo (se reactiva y se verifica si hiciera falta; NO cambia su contraseña).
    - 'conflict': el correo pertenece a una cuenta que no es admin; no se toca.
    """
    email = email.strip().lower()
    user = db.scalar(select(User).where(User.email == email))
    if user is not None:
        if user.role != "admin":
            return "conflict"
        changed = False
        if user.email_verified_at is None:
            user.email_verified_at = datetime.now(timezone.utc)
            changed = True
        if not user.is_active:
            user.is_active = True
            changed = True
        if changed:
            db.commit()
        return "exists"
    username = "admin"
    n = 0
    while db.scalar(select(User.id).where(User.username == username)):
        n += 1
        username = f"admin{n}"
    db.add(User(full_name="Administrador", username=username, email=email,
                password_hash=security.hash_password(password), role="admin",
                email_verified_at=datetime.now(timezone.utc)))
    db.commit()
    return "created"


# ---------------------------------------------------------------- estadísticas

def stats(db: Session, now: datetime) -> AdminStatsOut:
    by_role = dict(db.execute(select(User.role, func.count()).group_by(User.role)).all())
    users_total = sum(by_role.values())
    pending = db.scalar(select(func.count()).select_from(User).where(User.email_verified_at.is_(None))) or 0
    suspended = db.scalar(select(func.count()).select_from(User).where(User.is_active.is_(False))) or 0
    by_status = dict(db.execute(select(Meeting.status, func.count()).group_by(Meeting.status)).all())
    upcoming = db.scalar(select(func.count()).select_from(Meeting).where(Meeting.status == "scheduled", ms.upcoming(now))) or 0
    regs = db.scalar(select(func.count()).select_from(Registration)) or 0
    pay_count, pay_sum = db.execute(select(func.count(), func.coalesce(func.sum(Payment.amount_cop), 0))).one()
    subjects = db.execute(select(Subject.name, func.count(Meeting.id)).select_from(Subject)
                          .outerjoin(Meeting, Meeting.subject_id == Subject.id)
                          .group_by(Subject.name).order_by(Subject.name)).all()
    return AdminStatsOut(
        users_total=users_total, users_students=by_role.get("student", 0), users_monitors=by_role.get("monitor", 0),
        users_admins=by_role.get("admin", 0), users_pending=pending, users_suspended=suspended,
        meetings_total=sum(by_status.values()), meetings_scheduled=by_status.get("scheduled", 0),
        meetings_cancelled=by_status.get("cancelled", 0), meetings_upcoming=upcoming,
        registrations_total=regs, payments_total=pay_count, payments_amount_cop=int(pay_sum),
        meetings_by_subject=[CountItem(name=n, count=c) for n, c in subjects])


# ---------------------------------------------------------------- usuarios

def list_users(db: Session, q: str, role: str | None, status: str | None, limit: int, offset: int) -> list[AdminUserOut]:
    created = (select(func.count()).select_from(Meeting).where(Meeting.creator_id == User.id)
               .correlate(User).scalar_subquery())
    joined = (select(func.count()).select_from(Registration).where(Registration.user_id == User.id)
              .correlate(User).scalar_subquery())
    stmt = select(User, created, joined)
    text = q.strip()
    if text:
        like = f"%{ms._escape_like(text)}%"
        stmt = stmt.where(or_(User.full_name.ilike(like, escape="\\"), User.username.ilike(like, escape="\\"),
                              User.email.ilike(like, escape="\\")))
    if role:
        stmt = stmt.where(User.role == role)
    if status == "pending":
        stmt = stmt.where(User.email_verified_at.is_(None))
    elif status == "suspended":
        stmt = stmt.where(User.is_active.is_(False))
    elif status == "active":
        stmt = stmt.where(User.is_active.is_(True), User.email_verified_at.is_not(None))
    stmt = stmt.order_by(User.created_at.desc(), User.id).limit(min(limit, MAX_ROWS)).offset(offset)
    return [AdminUserOut(id=str(u.id), full_name=u.full_name, username=u.username, email=u.email, role=u.role,
                         verified=u.email_verified_at is not None, is_active=u.is_active, created_at=u.created_at,
                         meetings_created=int(c), registrations=int(j))
            for u, c, j in db.execute(stmt).all()]


def set_user_active(db: Session, admin: User, user_id: str, active: bool) -> None:
    try:
        uid = uuid.UUID(user_id)
    except ValueError:
        raise NotFound("Usuario no encontrado")
    target = db.get(User, uid)
    if target is None:
        raise NotFound("Usuario no encontrado")
    if target.id == admin.id:
        raise AppError("No puedes suspender tu propia cuenta", code="cannot_disable_self")
    if target.role == "admin":
        raise Forbidden("No se puede suspender a otro administrador", code="cannot_disable_admin")
    target.is_active = active
    db.commit()


# ---------------------------------------------------------------- reuniones

def list_meetings(db: Session, q: str, status: str | None, limit: int, offset: int) -> list[AdminMeetingOut]:
    taken = (select(func.count()).select_from(Registration).where(Registration.meeting_id == Meeting.id)
             .correlate(Meeting).scalar_subquery())
    stmt = (select(Meeting.id, Meeting.title, Subject.name, User.full_name, User.email, Meeting.meeting_date,
                   Meeting.start_time, Meeting.end_time, Meeting.is_virtual, Meeting.capacity, taken,
                   Meeting.price_cop, Meeting.status)
            .join(Subject, Subject.id == Meeting.subject_id).join(User, User.id == Meeting.creator_id))
    text = q.strip()
    if text:
        like = f"%{ms._escape_like(text)}%"
        stmt = stmt.where(or_(Meeting.title.ilike(like, escape="\\"), Subject.name.ilike(like, escape="\\"),
                              User.full_name.ilike(like, escape="\\")))
    if status in ("scheduled", "cancelled"):
        stmt = stmt.where(Meeting.status == status)
    stmt = (stmt.order_by(Meeting.meeting_date.desc(), Meeting.start_time.desc(), Meeting.id)
            .limit(min(limit, MAX_ROWS)).offset(offset))
    return [AdminMeetingOut(id=str(i), title=t, subject=s, host=h, host_email=he, date=d, start_time=st, end_time=en,
                            is_virtual=v, capacity=cap, taken=int(tk), price=pr, status=stt)
            for i, t, s, h, he, d, st, en, v, cap, tk, pr, stt in db.execute(stmt).all()]


def cancel_meeting(db: Session, meeting_id: str, now: datetime) -> None:
    m = ms._load(db, ms.parse_id(meeting_id), lock=True)
    if m.status == "cancelled":
        raise Conflict("La reunión ya estaba cancelada", code="already_cancelled")
    if ms.has_ended(m, now):
        raise Conflict("La reunión ya terminó", code="meeting_ended")
    m.status = "cancelled"
    db.commit()
    logger.info("Reunión %s cancelada por el administrador", meeting_id)