from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.deps import current_user, now_dep
from app.db.session import get_db
from app.models import User
from app.schemas.meeting import MeetingCreateIn, MeetingOut, MeetingUpdateIn, SortKey
from app.services import meeting_service as ms

router = APIRouter(prefix="/meetings", tags=["meetings"])


@router.get("", response_model=list[MeetingOut])
def search(q: str = Query("", max_length=100), subject: str | None = None,
           time_of_day: str | None = Query(None, pattern="^(Mañana|Tarde|Noche)$"), day: date | None = None,
           modality: str | None = Query(None, pattern="^(Presencial|Virtual)$"),
           price_min: int | None = Query(None, ge=0), price_max: int | None = Query(None, ge=0),
           sort: SortKey = "soonest", limit: int = Query(100, ge=1, le=200), offset: int = Query(0, ge=0),
           user: User = Depends(current_user), db: Session = Depends(get_db), now=Depends(now_dep)):
    """Búsqueda con filtros manuales; sort=recommended aplica las recomendaciones automáticas."""
    params = ms.SearchParams(q=q, subject=subject, time_of_day=time_of_day, day=day, modality=modality,
                             price_min=price_min, price_max=price_max, sort=sort, limit=limit, offset=offset)
    return ms.search(db, user, params, now)


@router.post("", response_model=MeetingOut, status_code=201)
def create(data: MeetingCreateIn, user: User = Depends(current_user), db: Session = Depends(get_db), now=Depends(now_dep)):
    return ms.create(db, user, data, now)


@router.get("/{meeting_id}", response_model=MeetingOut)
def get_one(meeting_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return ms.get_one(db, user, meeting_id)


@router.put("/{meeting_id}", response_model=MeetingOut)
def update(meeting_id: str, data: MeetingUpdateIn, user: User = Depends(current_user), db: Session = Depends(get_db),
           now=Depends(now_dep)):
    """Edita una reunión publicada (solo quien la creó; ver reglas en meeting_service.update)."""
    return ms.update(db, user, meeting_id, data, now)


@router.post("/{meeting_id}/join", response_model=MeetingOut)
def join(meeting_id: str, user: User = Depends(current_user), db: Session = Depends(get_db), now=Depends(now_dep)):
    return ms.join(db, user, meeting_id, now)


@router.put("/{meeting_id}/save", response_model=MeetingOut)
def save(meeting_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return ms.set_saved(db, user, meeting_id, True)


@router.delete("/{meeting_id}/save", response_model=MeetingOut)
def unsave(meeting_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return ms.set_saved(db, user, meeting_id, False)


@router.post("/{meeting_id}/cancel", response_model=MeetingOut)
def cancel(meeting_id: str, user: User = Depends(current_user), db: Session = Depends(get_db), now=Depends(now_dep)):
    return ms.cancel(db, user, meeting_id, now)