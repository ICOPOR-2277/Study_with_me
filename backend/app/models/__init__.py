"""Importar todos los modelos aquí hace que Alembic y SQLAlchemy los registren."""
from app.models.meeting import Meeting, Payment, Registration, SavedMeeting  # noqa: F401
from app.models.subject import Subject  # noqa: F401
from app.models.user import AvailabilitySlot, EmailVerification, MonitorSubject, User, UserInterest  # noqa: F401
