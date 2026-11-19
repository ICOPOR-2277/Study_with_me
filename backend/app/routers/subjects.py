from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.services import subject_service

router = APIRouter(tags=["subjects"])


@router.get("/subjects", response_model=list[str])
def subjects(db: Session = Depends(get_db)):
    """Catálogo de materias (público: lo necesita el formulario de registro)."""
    return subject_service.list_subject_names(db)
