import json
import urllib.error
from dataclasses import replace
from unittest.mock import MagicMock, patch

import pytest

from app.core.config import load_settings
from app.core.errors import BadGateway
from app.services import email_service

BASE = {"SECRET_KEY": "k" * 40, "DATABASE_URL": "postgresql://u:p@h/d"}


def _settings(**extra):
    return load_settings({**BASE, **extra})


def test_resend_enabled_flags():
    assert not _settings().resend_enabled
    assert _settings(RESEND_API_KEY="  re_x ").resend_enabled


def test_without_provider_logs_code(caplog):
    with caplog.at_level("WARNING", logger="study_with_me.email"):
        email_service.send_verification_code(_settings(), "a@b.co", "123456")
    assert "123456" in caplog.text


def test_resend_request_shape(caplog):
    s = _settings(RESEND_API_KEY="re_secret", RESEND_FROM="Study <onboarding@resend.dev>")
    cm = MagicMock()
    cm.__enter__.return_value.read.return_value = b"{}"
    with patch("urllib.request.urlopen", return_value=cm) as op, caplog.at_level("WARNING"):
        email_service.send_verification_code(s, "a@b.co", "654321")
    req = op.call_args[0][0]
    body = json.loads(req.data)
    assert req.full_url == "https://api.resend.com/emails" and req.get_method() == "POST"
    assert req.get_header("Authorization") == "Bearer re_secret"
    assert req.get_header("User-agent")  # Cloudflare rechaza el UA por defecto
    assert body["to"] == ["a@b.co"] and body["from"] == "Study <onboarding@resend.dev>"
    assert "654321" in body["text"] and "654321" in body["html"]
    assert "654321" not in caplog.text  # con proveedor real el código NO va al log


def test_resend_http_error_becomes_bad_gateway():
    s = _settings(RESEND_API_KEY="re_secret", RESEND_FROM="x@y.z")
    err = urllib.error.HTTPError("u", 403, "forbidden", {}, MagicMock(read=lambda: b"not allowed"))
    with patch("urllib.request.urlopen", side_effect=err):
        with pytest.raises(BadGateway) as ei:
            email_service.send_verification_code(s, "a@b.co", "111111")
    assert ei.value.status_code == 502 and ei.value.code == "email_send_failed"


def test_resend_network_error_becomes_bad_gateway():
    s = _settings(RESEND_API_KEY="re_secret", RESEND_FROM="x@y.z")
    with patch("urllib.request.urlopen", side_effect=urllib.error.URLError("sin red")):
        with pytest.raises(BadGateway):
            email_service.send_verification_code(s, "a@b.co", "111111")


def test_resend_without_from_is_config_error():
    with pytest.raises(RuntimeError):
        email_service.send_verification_code(_settings(RESEND_API_KEY="re_x"), "a@b.co", "1")
