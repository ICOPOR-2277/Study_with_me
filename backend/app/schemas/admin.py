"""Contratos JSON del panel administrativo."""
from __future__ import annotations

from datetime import date, datetime

from pydantic import Field

from app.schemas.common import ApiModel, HHMM
from app.schemas.user import AnyRole


class ActiveIn(ApiModel):
    is_active: bool


class AdminUserOut(ApiModel):
    id: str
    full_name: str
    username: str
    email: str
    role: AnyRole
    verified: bool
    is_active: bool
    created_at: datetime
    meetings_created: int
    registrations: int


class AdminMeetingOut(ApiModel):
    id: str
    title: str
    subject: str
    host: str
    host_email: str
    date: date
    start_time: HHMM
    end_time: HHMM
    is_virtual: bool
    capacity: int
    taken: int
    price: int
    status: str


class CountItem(ApiModel):
    name: str
    count: int


class AdminStatsOut(ApiModel):
    users_total: int
    users_students: int
    users_monitors: int
    users_admins: int
    users_pending: int  # sin verificar el correo
    users_suspended: int
    meetings_total: int
    meetings_scheduled: int
    meetings_cancelled: int
    meetings_upcoming: int
    registrations_total: int
    payments_total: int  # cantidad de pagos simulados
    payments_amount_cop: int  # suma de los montos simulados
    meetings_by_subject: list[CountItem] = Field(default_factory=list)