from __future__ import annotations

from datetime import date as Date
from typing import Literal

from pydantic import Field, model_validator

from app.schemas.common import ApiModel, HHMM

SortKey = Literal["soonest", "price", "spots", "recommended"]


class MeetingCreateIn(ApiModel):
    title: str = Field(min_length=1, max_length=120)
    subject: str
    description: str = Field(default="", max_length=2000)
    date: Date
    start_time: HHMM
    end_time: HHMM
    is_virtual: bool = False
    location: str = Field(min_length=1, max_length=255)
    capacity: int = Field(ge=1, le=500)
    price: int = Field(default=0, ge=0, le=10_000_000, description="COP; 0 = gratis")

    @model_validator(mode="after")
    def _range(self) -> "MeetingCreateIn":
        if self.end_time <= self.start_time:
            raise ValueError("La hora final debe ser después de la inicial")
        return self


class MeetingUpdateIn(MeetingCreateIn):
    """Edición de una reunión publicada (PUT): se envía la reunión completa, con las mismas reglas que al crearla."""


class MeetingOut(ApiModel):
    id: str
    title: str
    subject: str
    host: str
    host_id: str
    description: str
    date: Date
    start_time: HHMM
    end_time: HHMM
    is_virtual: bool
    location: str
    capacity: int
    price: int
    spots: int
    saved: bool
    joined: bool
    created_by_me: bool
    status: str


class CalendarEventOut(ApiModel):
    meeting_id: str
    title: str
    subject: str
    date: Date
    start_time: HHMM
    end_time: HHMM


class HistoryMeetingOut(ApiModel):
    meeting_id: str
    title: str
    subject: str
    date: Date
    created_by_me: bool
    cancelled: bool


class PaymentOut(ApiModel):
    meeting_id: str
    title: str
    subject: str
    detail: str  # "Pago de Mariana Cruz" / "Pago a Camila Gómez"
    date: Date
    amount: int  # positivo = ingreso, negativo = salida (igual que Payment de Flutter)


class SubjectCountOut(ApiModel):
    name: str
    upcoming: int


class WeekSummaryOut(ApiModel):
    scheduled: int
    hours: float
    completed: int


class SummaryOut(ApiModel):
    sessions_completed: int
    hours_completed: float
    week: WeekSummaryOut
    subjects: list[SubjectCountOut]
    next_meeting: MeetingOut | None
