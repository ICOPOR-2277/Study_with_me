from datetime import datetime

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.deps import settings_dep
from app.db.session import get_db
from app.schemas.common import Message
from app.schemas.user import LoginIn, RegisterIn, RegisterOut, ResendIn, TokenOut, VerifyEmailIn
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=RegisterOut, status_code=status.HTTP_201_CREATED)
def register(data: RegisterIn, db: Session = Depends(get_db), settings: Settings = Depends(settings_dep)):
    user = auth_service.register(db, settings, data)
    return RegisterOut(email=user.email, resend_seconds=settings.verification_resend_seconds,
                       message="Cuenta creada. Te enviamos un código de verificación.")


@router.post("/verify-email", response_model=TokenOut)
def verify_email(data: VerifyEmailIn, db: Session = Depends(get_db), settings: Settings = Depends(settings_dep)):
    return auth_service.verify_email(db, settings, data.email, data.code)


@router.post("/resend-code", response_model=Message)
def resend_code(data: ResendIn, db: Session = Depends(get_db), settings: Settings = Depends(settings_dep)):
    auth_service.resend_code(db, settings, data.email)
    return Message(message="Si la cuenta existe y falta verificarla, enviamos un nuevo código.")


@router.post("/login", response_model=TokenOut)
def login(data: LoginIn, db: Session = Depends(get_db), settings: Settings = Depends(settings_dep)):
    return auth_service.login(db, settings, data)
