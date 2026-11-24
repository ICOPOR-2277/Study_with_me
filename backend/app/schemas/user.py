from __future__ import annotations

from typing import Literal

from pydantic import Field, field_validator, model_validator

from app.schemas.common import USERNAME_RE, ApiModel, HHMM, normalize_email

Role = Literal["student", "monitor"]
MAX_MONITOR_SUBJECTS = 3


class RegisterIn(ApiModel):
    full_name: str = Field(min_length=1, max_length=120)
    username: str
    email: str
    password: str = Field(min_length=8, max_length=128)
    role: Role
    subjects: list[str] = Field(default_factory=list)  # solo monitores: "Materias que dominas"

    @field_validator("username")
    @classmethod
    def _username(cls, v: str) -> str:
        v = v.strip().lstrip("@").lower()  # la app muestra '@lauraestudia'; se guarda sin '@'
        if not USERNAME_RE.match(v):
            raise ValueError("El username debe tener 3-30 caracteres: letras, números, '_' o '.'")
        return v

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return normalize_email(v)

    @model_validator(mode="after")
    def _subjects_by_role(self) -> "RegisterIn":
        unique = list(dict.fromkeys(self.subjects))
        if self.role == "monitor":
            if not 1 <= len(unique) <= MAX_MONITOR_SUBJECTS:
                raise ValueError(f"Un monitor debe elegir de 1 a {MAX_MONITOR_SUBJECTS} materias")
        elif unique:
            raise ValueError("Solo los monitores eligen materias que dominan")
        self.subjects = unique
        return self


class LoginIn(ApiModel):
    email: str
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return normalize_email(v)


class VerifyEmailIn(ApiModel):
    email: str
    code: str = Field(pattern=r"^\d{6}$")

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return normalize_email(v)


class ResendIn(ApiModel):
    email: str

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return normalize_email(v)


class ForgotPasswordIn(ResendIn):
    """Pide un código para restablecer la contraseña."""


class ResetPasswordIn(ApiModel):
    email: str
    code: str = Field(pattern=r"^\d{6}$")
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("email")
    @classmethod
    def _email(cls, v: str) -> str:
        return normalize_email(v)


class ProfileUpdateIn(ApiModel):
    full_name: str = Field(min_length=1, max_length=120)
    username: str

    @field_validator("username")
    @classmethod
    def _username(cls, v: str) -> str:
        v = v.strip().lstrip("@").lower()
        if not USERNAME_RE.match(v):
            raise ValueError("El username debe tener 3-30 caracteres: letras, números, '_' o '.'")
        return v


class PasswordChangeIn(ApiModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class SlotIO(ApiModel):
    weekday: int = Field(ge=0, le=6, description="0 = lunes ... 6 = domingo")
    start_time: HHMM
    end_time: HHMM

    @model_validator(mode="after")
    def _range(self) -> "SlotIO":
        if self.end_time <= self.start_time:
            raise ValueError("La hora final debe ser después de la inicial")
        return self


class SubjectNamesIn(ApiModel):
    subjects: list[str] = Field(default_factory=list, max_length=20)


class AvailabilityIn(ApiModel):
    slots: list[SlotIO] = Field(default_factory=list, max_length=60)


class UserOut(ApiModel):
    id: str
    full_name: str
    username: str
    email: str
    role: Role
    subjects: list[str]
    interests: list[str]
    availability: list[SlotIO]


class RegisterOut(ApiModel):
    email: str
    message: str
    verification_required: bool = True
    resend_seconds: int


class TokenOut(ApiModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
