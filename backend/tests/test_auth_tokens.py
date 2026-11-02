import uuid

import jwt
import pytest
from fastapi import HTTPException

from app.core.auth import create_access_token, hash_password, verify_password
from app.core.config import get_settings


def test_password_hash_is_not_plaintext_and_verifies():
    encoded = hash_password("correct horse battery staple")
    assert encoded != "correct horse battery staple"
    assert verify_password("correct horse battery staple", encoded)
    assert not verify_password("incorrect password", encoded)


@pytest.mark.parametrize("password", ["short", "x" * 129])
def test_password_policy(password):
    with pytest.raises(ValueError):
        hash_password(password)


def test_access_token_has_issuer_audience_and_expiry(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "jwt_secret", "s" * 48)
    token = create_access_token(uuid.uuid4())
    payload = jwt.decode(
        token, settings.jwt_secret, algorithms=["HS256"],
        issuer=settings.jwt_issuer, audience=settings.jwt_audience,
    )
    assert payload["type"] == "access"
    assert payload["exp"] > payload["iat"]


def test_token_creation_fails_closed_without_secret(monkeypatch):
    monkeypatch.setattr(get_settings(), "jwt_secret", "")
    with pytest.raises(HTTPException) as error:
        create_access_token(uuid.uuid4())
    assert error.value.status_code == 503
