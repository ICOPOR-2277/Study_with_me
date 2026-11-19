from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.errors import AppError
from app.core.deps import current_user, now_dep, settings_dep
from app.db.session import get_db
from app.models import User
from app.schemas.meeting import CalendarEventOut, HistoryMeetingOut, PaymentOut
from app.services import report_service

router = APIRouter(tags=["reports"])


@router.get("/calendar", response_model=list[CalendarEventOut])
def calendar(from_: date = Query(..., alias="from"), to: date = Query(...), user: User = Depends(current_user),
             db: Session = Depends(get_db)):
    """Reuniones en las que participo (creadas o inscritas) entre dos fechas."""
    if to < from_ or (to - from_).days > 62:
        raise AppError("Rango de fechas no válido (máximo 62 días)", code="invalid_range")
    return report_service.calendar_events(db, user, from_, to)


@router.get("/history/meetings", response_model=list[HistoryMeetingOut])
def history_meetings(year: int = Query(..., ge=2000, le=2100), month: int = Query(..., ge=1, le=12),
                     subject: str | None = None, user: User = Depends(current_user), db: Session = Depends(get_db),
                     now=Depends(now_dep)):
    return report_service.history_meetings(db, user, year, month, subject, now)


@router.get("/history/payments", response_model=list[PaymentOut])
def history_payments(year: int = Query(..., ge=2000, le=2100), month: int = Query(..., ge=1, le=12),
                     subject: str | None = None, movement: str = Query("all", pattern="^(all|income|expense)$"),
                     user: User = Depends(current_user), db: Session = Depends(get_db),
                     settings: Settings = Depends(settings_dep)):
    return report_service.history_payments(db, user, year, month, subject, movement, settings.app_timezone)
