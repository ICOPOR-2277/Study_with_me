"""Envío del código de verificación.

Orden de proveedores:
  1. Resend (RESEND_API_KEY)  -> API HTTP, sin dependencias nuevas (solo la librería estándar).
  2. SMTP (SMTP_HOST)         -> STARTTLS.
  3. Ninguno                  -> el código solo se escribe en el LOG del servidor (desarrollo).
No hay credenciales en el código: todo viene de variables de entorno.
"""
from __future__ import annotations

import html
import json
import logging
import smtplib
import urllib.error
import urllib.request
from email.message import EmailMessage

from app.core.config import Settings
from app.core.errors import BadGateway

logger = logging.getLogger("study_with_me.email")

RESEND_URL = "https://api.resend.com/emails"
SUBJECT = "Tu código de Study With Me"


def _text_body(code: str, minutes: int) -> str:
    return f"Tu código de verificación es {code}. Vence en {minutes} minutos. Si no creaste una cuenta, ignora este correo."


def _html_body(code: str, minutes: int) -> str:
    return (f"<div style=\"font-family:Arial,sans-serif;max-width:420px\">"
            f"<h2>Study With Me</h2><p>Tu código de verificación es:</p>"
            f"<p style=\"font-size:32px;letter-spacing:6px;font-weight:bold\">{html.escape(code)}</p>"
            f"<p>Vence en {minutes} minutos. Si no creaste una cuenta, ignora este correo.</p></div>")


def _send_resend(settings: Settings, to_email: str, code: str) -> None:
    minutes = settings.verification_code_ttl_minutes
    payload = {"from": settings.resend_from, "to": [to_email], "subject": SUBJECT,
               "html": _html_body(code, minutes), "text": _text_body(code, minutes)}
    req = urllib.request.Request(
        RESEND_URL, data=json.dumps(payload).encode("utf-8"), method="POST",
        headers={"Authorization": f"Bearer {settings.resend_api_key}", "Content-Type": "application/json",
                 # Resend (Cloudflare) rechaza el User-Agent por defecto de urllib.
                 "User-Agent": "study-with-me/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:  # noqa: S310 (URL fija, https)
            resp.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:300]
        logger.error("Resend rechazó el envío a %s (HTTP %s): %s", to_email, exc.code, detail)
        raise BadGateway("No pudimos enviar el correo. Intenta reenviar el código en unos segundos.",
                         code="email_send_failed")
    except (urllib.error.URLError, OSError) as exc:
        logger.error("No se pudo contactar a Resend para %s: %s", to_email, exc)
        raise BadGateway("No pudimos enviar el correo. Intenta reenviar el código en unos segundos.",
                         code="email_send_failed")


def _send_smtp(settings: Settings, to_email: str, code: str) -> None:
    msg = EmailMessage()
    msg["Subject"] = SUBJECT
    msg["From"] = settings.smtp_from or settings.smtp_user
    msg["To"] = to_email
    msg.set_content(_text_body(code, settings.verification_code_ttl_minutes))
    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as smtp:
            smtp.starttls()
            if settings.smtp_user:
                smtp.login(settings.smtp_user, settings.smtp_password)
            smtp.send_message(msg)
    except (OSError, smtplib.SMTPException):
        logger.exception("No se pudo enviar el correo de verificación a %s", to_email)
        raise BadGateway("No pudimos enviar el correo. Intenta reenviar el código en unos segundos.",
                         code="email_send_failed")


def send_verification_code(settings: Settings, to_email: str, code: str) -> None:
    if settings.resend_enabled:
        if not settings.resend_from:
            raise RuntimeError("RESEND_API_KEY está definida pero falta RESEND_FROM.")
        _send_resend(settings, to_email, code)
    elif settings.smtp_enabled:
        _send_smtp(settings, to_email, code)
    else:
        # Solo desarrollo: sin proveedor de correo, el código queda en el log del servidor.
        logger.warning("[VERIFICACIÓN] Código para %s: %s (vence en %d min)", to_email, code,
                       settings.verification_code_ttl_minutes)
