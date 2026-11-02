import asyncio

from fastapi import HTTPException

from app.core.auth import require_api_token
from app.core.config import get_settings


def test_auth_disabled_in_development(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "app_env", "development")
    monkeypatch.setattr(settings, "api_access_token", "")
    asyncio.run(require_api_token(None))


def test_auth_fails_closed_in_production(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "api_access_token", "")
    try:
        asyncio.run(require_api_token(None))
    except HTTPException as exc:
        assert exc.status_code == 503
    else:
        raise AssertionError("Production must fail closed without an API token")


def test_auth_rejects_wrong_token(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "api_access_token", "correct-token")
    try:
        asyncio.run(require_api_token("wrong-token"))
    except HTTPException as exc:
        assert exc.status_code == 401
    else:
        raise AssertionError("Wrong API token must be rejected")


def test_auth_accepts_matching_token(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "api_access_token", "correct-token")
    asyncio.run(require_api_token("correct-token"))
