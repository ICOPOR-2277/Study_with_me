"""API del panel administrativo (/admin/...). Todas las rutas exigen una cuenta con rol admin."""
from __future__ import annotations

from datetime import datetime
from typing import Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.core.deps import now_dep, require_admin
from app.db.session import get_db
from app.models import User
from app.schemas.admin import ActiveIn, AdminMeetingOut, AdminStatsOut, AdminUserOut
from app.schemas.common import Message
from app.services import admin_service

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/stats", response_model=AdminStatsOut)
def stats(_: User = Depends(require_admin), db: Session = Depends(get_db), now: datetime = Depends(now_dep)):
    return admin_service.stats(db, now)


@router.get("/users", response_model=list[AdminUserOut])
def users(q: str = "", role: Literal["student", "monitor", "admin"] | None = None,
          status: Literal["active", "pending", "suspended"] | None = None,
          limit: int = Query(100, ge=1, le=200), offset: int = Query(0, ge=0),
          _: User = Depends(require_admin), db: Session = Depends(get_db)):
    return admin_service.list_users(db, q, role, status, limit, offset)


@router.put("/users/{user_id}/active", response_model=Message)
def set_active(user_id: str, data: ActiveIn, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    admin_service.set_user_active(db, admin, user_id, data.is_active)
    return Message(message="Cuenta reactivada." if data.is_active else "Cuenta suspendida.")


@router.get("/meetings", response_model=list[AdminMeetingOut])
def meetings(q: str = "", status: Literal["scheduled", "cancelled"] | None = None,
             limit: int = Query(100, ge=1, le=200), offset: int = Query(0, ge=0),
             _: User = Depends(require_admin), db: Session = Depends(get_db)):
    return admin_service.list_meetings(db, q, status, limit, offset)


@router.post("/meetings/{meeting_id}/cancel", response_model=Message)
def cancel_meeting(meeting_id: str, _: User = Depends(require_admin), db: Session = Depends(get_db),
                   now: datetime = Depends(now_dep)):
    admin_service.cancel_meeting(db, meeting_id, now)
    return Message(message="Reunión cancelada.")