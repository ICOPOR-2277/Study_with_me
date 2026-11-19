from __future__ import annotations

import uuid

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.errors import AppError, NotFound
from app.models import AvailabilitySlot, MonitorSubject, Subject, User, UserInterest
from app.schemas.user import MAX_MONITOR_SUBJECTS, SlotIO, UserOut
from app.services.subject_service import subjects_by_names


def get_user(db: Session, user_id: str) -> User:
    try:
        uid = uuid.UUID(user_id)
    except ValueError:
        raise NotFound("Usuario no encontrado")
    user = db.get(User, uid)
    if user is None:
        raise NotFound("Usuario no encontrado")
    return user


def expertise_names(db: Session, user_id: uuid.UUID) -> list[str]:
    return list(db.scalars(select(Subject.name).join(MonitorSubject, MonitorSubject.subject_id == Subject.id)
                           .where(MonitorSubject.user_id == user_id).order_by(Subject.name)))


def interest_names(db: Session, user_id: uuid.UUID) -> list[str]:
    return list(db.scalars(select(Subject.name).join(UserInterest, UserInterest.subject_id == Subject.id)
                           .where(UserInterest.user_id == user_id).order_by(Subject.name)))


def slots_of(db: Session, user_id: uuid.UUID) -> list[AvailabilitySlot]:
    return list(db.scalars(select(AvailabilitySlot).where(AvailabilitySlot.user_id == user_id)
                           .order_by(AvailabilitySlot.weekday, AvailabilitySlot.start_time)))


def to_user_out(db: Session, user: User) -> UserOut:
    return UserOut(
        id=str(user.id), full_name=user.full_name, username=user.username, email=user.email, role=user.role,
        subjects=expertise_names(db, user.id), interests=interest_names(db, user.id),
        availability=[SlotIO(weekday=s.weekday, start_time=s.start_time, end_time=s.end_time) for s in slots_of(db, user.id)],
    )


def set_interests(db: Session, user: User, names: list[str]) -> UserOut:
    subjects = subjects_by_names(db, names)
    db.execute(delete(UserInterest).where(UserInterest.user_id == user.id))
    db.add_all(UserInterest(user_id=user.id, subject_id=s.id) for s in subjects)
    db.commit()
    return to_user_out(db, user)


def set_monitor_subjects(db: Session, user: User, names: list[str]) -> UserOut:
    if not user.is_monitor:
        raise AppError("Solo los monitores tienen materias que dominan", code="not_monitor")
    subjects = subjects_by_names(db, names)
    if not 1 <= len(subjects) <= MAX_MONITOR_SUBJECTS:
        raise AppError(f"Elige de 1 a {MAX_MONITOR_SUBJECTS} materias", code="invalid_subjects")
    db.execute(delete(MonitorSubject).where(MonitorSubject.user_id == user.id))
    db.flush()
    db.add_all(MonitorSubject(user_id=user.id, subject_id=s.id) for s in subjects)
    db.commit()
    return to_user_out(db, user)


def set_availability(db: Session, user: User, slots: list[SlotIO]) -> UserOut:
    unique = {(s.weekday, s.start_time, s.end_time) for s in slots}
    db.execute(delete(AvailabilitySlot).where(AvailabilitySlot.user_id == user.id))
    db.flush()
    db.add_all(AvailabilitySlot(user_id=user.id, weekday=w, start_time=a, end_time=b) for w, a, b in sorted(unique))
    db.commit()
    return to_user_out(db, user)
