"""Account recovery and password reset workflow."""
import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.auth import hash_password, normalize_email
from app.db.models import PasswordResetToken, User


class AccountRecoveryError(ValueError):
    pass


def request_password_recovery(
    db: Session, email: str, expires_minutes: int = 15
) -> tuple[PasswordResetToken, str]:
    normalized = normalize_email(email)
    user = db.scalar(select(User).where(User.email == normalized, User.is_active.is_(True)))
    if user is None:
        raise AccountRecoveryError("Account not found.")

    raw_token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(minutes=expires_minutes)

    reset_record = PasswordResetToken(
        user_id=user.id,
        token_hash=token_hash,
        expires_at=expires_at,
    )
    db.add(reset_record)
    db.commit()
    db.refresh(reset_record)
    return reset_record, raw_token


def reset_password_with_token(db: Session, raw_token: str, new_password: str) -> User:
    if len(raw_token) < 20:
        raise AccountRecoveryError("Invalid recovery token.")

    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
    record = db.scalar(
        select(PasswordResetToken)
        .where(PasswordResetToken.token_hash == token_hash)
        .with_for_update()
    )
    if record is None or record.used_at is not None:
        raise AccountRecoveryError("Recovery token is invalid or has already been used.")

    now = datetime.now(timezone.utc)
    expires_at = record.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if expires_at <= now:
        raise AccountRecoveryError("Recovery token has expired.")

    user = db.scalar(select(User).where(User.id == record.user_id, User.is_active.is_(True)))
    if user is None:
        raise AccountRecoveryError("Associated user account is unavailable.")

    user.password_hash = hash_password(new_password)
    record.used_at = now
    db.commit()
    db.refresh(user)
    return user
