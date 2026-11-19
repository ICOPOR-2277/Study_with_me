from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.models import Subject


def list_subject_names(db: Session) -> list[str]:
    return list(db.scalars(select(Subject.name).order_by(Subject.name)))


def subjects_by_names(db: Session, names: list[str]) -> list[Subject]:
    unique = list(dict.fromkeys(n.strip() for n in names))
    if not unique:
        return []
    found = {s.name: s for s in db.scalars(select(Subject).where(Subject.name.in_(unique)))}
    missing = [n for n in unique if n not in found]
    if missing:
        raise AppError(f"Materia desconocida: {', '.join(missing)}", code="unknown_subject")
    return [found[n] for n in unique]


def subject_by_name(db: Session, name: str) -> Subject:
    return subjects_by_names(db, [name])[0]
