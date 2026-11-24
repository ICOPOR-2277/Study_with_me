from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import current_user, now_dep
from app.db.session import get_db
from app.models import User
from app.schemas.meeting import SummaryOut
from app.schemas.common import Message
from app.schemas.user import AvailabilityIn, PasswordChangeIn, ProfileUpdateIn, SubjectNamesIn, UserOut
from app.services import report_service, user_service

router = APIRouter(prefix="/users/me", tags=["users"])


@router.get("", response_model=UserOut)
def me(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return user_service.to_user_out(db, user)


@router.put("", response_model=UserOut)
def update_me(data: ProfileUpdateIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    """Editar perfil: nombre y username."""
    return user_service.update_profile(db, user, data)


@router.post("/password", response_model=Message)
def change_password(data: PasswordChangeIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    user_service.change_password(db, user, data)
    return Message(message="Contraseña actualizada.")


@router.get("/summary", response_model=SummaryOut)
def summary(user: User = Depends(current_user), db: Session = Depends(get_db), now=Depends(now_dep)):
    return report_service.summary(db, user, now)


@router.put("/interests", response_model=UserOut)
def put_interests(data: SubjectNamesIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return user_service.set_interests(db, user, data.subjects)


@router.put("/subjects", response_model=UserOut)
def put_subjects(data: SubjectNamesIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return user_service.set_monitor_subjects(db, user, data.subjects)


@router.put("/availability", response_model=UserOut)
def put_availability(data: AvailabilityIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    return user_service.set_availability(db, user, data.slots)