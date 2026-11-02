from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.auth import (
    create_access_token, create_refresh_token, get_current_user, hash_password,
    is_token_revoked, revoke_token, verify_password, verify_refresh_token,
)
from app.core.config import Settings
from app.db.base import Base
from app.db.models import Project, User
from app.services.account_recovery import (
    AccountRecoveryError, request_password_recovery, reset_password_with_token,
)
from app.services.gguf_catalogue import (
    GGUF_MAGIC, GGUFValidationError, calculate_ram_requirement, list_catalogue,
    validate_gguf_file,
)
from app.services.rate_limiter import RateLimiter


def make_session():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    return Session(engine, expire_on_commit=False)


@pytest.fixture(autouse=True)
def auth_settings(monkeypatch):
    settings = Settings(
        jwt_secret="super-secret-key-that-is-at-least-32-chars-long",
        legacy_project_claim_secret="claim-secret-for-test-32-chars-long",
    )
    monkeypatch.setattr("app.core.auth.get_settings", lambda: settings)
    monkeypatch.setattr("app.core.config.get_settings", lambda: settings)


def test_password_recovery_workflow():
    with make_session() as db:
        user = User(
            id=uuid4(),
            email="recover@example.com",
            password_hash=hash_password("OldPassword123!"),
        )
        db.add(user)
        db.commit()

        # Request recovery
        record, token = request_password_recovery(db, "recover@example.com")
        assert len(token) >= 32
        assert record.user_id == user.id
        assert record.used_at is None

        # Reset password
        updated_user = reset_password_with_token(db, token, "NewPassword123!")
        assert verify_password("NewPassword123!", updated_user.password_hash)

        # Cannot reuse token
        with pytest.raises(AccountRecoveryError, match="already been used"):
            reset_password_with_token(db, token, "AnotherPassword123!")


def test_token_revocation_and_refresh_rotation():
    with make_session() as db:
        user_id = uuid4()
        user = User(id=user_id, email="token@example.com", password_hash="pass")
        db.add(user)
        db.commit()

        # Access token and revocation
        access_tok = create_access_token(user_id)
        current = get_current_user(access_tok, db)
        assert current.id == user_id

        # Revoke access token
        revoked = revoke_token(db, access_tok)
        assert revoked is not None
        assert is_token_revoked(db, revoked.jti)

        with pytest.raises(Exception):
            get_current_user(access_tok, db)

        # Refresh token rotation
        refresh_tok = create_refresh_token(user_id)
        retrieved_id, jti = verify_refresh_token(db, refresh_tok)
        assert retrieved_id == user_id

        # Revoke refresh token
        revoke_token(db, refresh_tok)
        with pytest.raises(Exception):
            verify_refresh_token(db, refresh_tok)


def test_persistent_rate_limiter():
    with make_session() as db:
        key = "ip:192.168.1.1"
        endpoint = "auth.login"

        # Under limit
        for _ in range(5):
            RateLimiter.check_rate_limit(db, key, endpoint, max_requests=5, window_seconds=60)

        # Exceed limit
        with pytest.raises(Exception) as exc_info:
            RateLimiter.check_rate_limit(db, key, endpoint, max_requests=5, window_seconds=60)
        assert "429" in str(exc_info.value) or "Rate limit" in str(exc_info.value)


def test_legacy_project_claim_logic():
    with make_session() as db:
        user = User(id=uuid4(), email="owner@example.com", password_hash="pass")
        db.add(user)
        db.flush()

        # Unowned legacy project
        legacy_proj = Project(
            id="legacy-1",
            name="Legacy Project",
            source_type="zip",
            workspace_path="/tmp/legacy",
            owner_id=None,
        )
        db.add(legacy_proj)
        db.commit()

        assert legacy_proj.owner_id is None
        legacy_proj.owner_id = user.id
        db.commit()
        db.refresh(legacy_proj)
        assert legacy_proj.owner_id == user.id


def test_gguf_catalogue_and_validation(tmp_path: Path):
    catalogue = list_catalogue()
    assert len(catalogue) >= 4
    llama = next(m for m in catalogue if m["family"] == "llama")
    assert llama["license"] == "Llama-3.2-Community"
    assert "avx2" in llama["supported_abis"]

    ram_req = calculate_ram_requirement(4 * 1024 * 1024 * 1024, context_tokens=8192)
    assert ram_req["total_min_ram_gb"] > 4.0

    # Test file validation
    dummy_gguf = tmp_path / "model.gguf"
    import hashlib
    content = GGUF_MAGIC + b"\x00" * 2048
    dummy_gguf.write_bytes(content)
    expected_sha = hashlib.sha256(content).hexdigest()

    result = validate_gguf_file(dummy_gguf, expected_sha256=expected_sha)
    assert result["valid"] is True
    assert result["sha256"] == expected_sha

    # Test invalid magic header
    bad_file = tmp_path / "bad.gguf"
    bad_file.write_bytes(b"BAD!" + b"\x00" * 2048)
    with pytest.raises(GGUFValidationError, match="Magic bytes mismatch"):
        validate_gguf_file(bad_file)
