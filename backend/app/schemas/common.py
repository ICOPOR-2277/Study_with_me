from __future__ import annotations

import re
from datetime import time
from typing import Annotated

from pydantic import BaseModel, ConfigDict, PlainSerializer

# Las horas viajan como "HH:MM" (Flutter las convierte a TimeOfDay).
HHMM = Annotated[time, PlainSerializer(lambda t: t.strftime("%H:%M"), return_type=str, when_used="json")]

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
USERNAME_RE = re.compile(r"^[a-z0-9_.]{3,30}$")


class ApiModel(BaseModel):
    model_config = ConfigDict(from_attributes=True, str_strip_whitespace=True)


class Message(ApiModel):
    message: str


def normalize_email(value: str) -> str:
    value = value.strip().lower()
    if len(value) > 254 or not EMAIL_RE.match(value):
        raise ValueError("Correo no válido")
    return value
