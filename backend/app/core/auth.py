import re
import secrets
from datetime import datetime, timedelta, timezone
from typing import Annotated
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from pwdlib import PasswordHash
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.models import RevokedToken, User
from app.db.session import get_db

password_hash = PasswordHash.recommended()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)
EMAIL_PATTERN = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


def normalize_email(email: str) -> str:
    return email.strip().lower()


def validate_email(email: str) -> str:
    normalized = normalize_email(email)
    if len(normalized) > 320 or not EMAIL_PATTERN.fullmatch(normalized):
        raise ValueError("Enter a valid email address.")
    return normalized


def hash_password(password: str) -> str:
    if len(password) < 12 or len(password) > 128:
        raise ValueError("Password must contain between 12 and 128 characters.")
    return password_hash.hash(password)


def verify_password(password: str, encoded: str) -> bool:
    try:
        return password_hash.verify(password, encoded)
    except Exception:
        return False


def create_access_token(user_id: UUID, jti: str | None = None) -> str:
    settings = get_settings()
    if len(settings.jwt_secret) < 32:
        raise HTTPException(status_code=503, detail="JWT authentication is not configured.")
    now = datetime.now(timezone.utc)
    token_jti = jti or secrets.token_hex(16)
    payload = {
        "sub": str(user_id),
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
        "iat": now,
        "nbf": now,
        "exp": now + timedelta(minutes=settings.jwt_access_token_minutes),
        "type": "access",
        "jti": token_jti,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def create_refresh_token(user_id: UUID, days: int = 7) -> str:
    settings = get_settings()
    if len(settings.jwt_secret) < 32:
        raise HTTPException(status_code=503, detail="JWT authentication is not configured.")
    now = datetime.now(timezone.utc)
    token_jti = secrets.token_hex(16)
    payload = {
        "sub": str(user_id),
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
        "iat": now,
        "nbf": now,
        "exp": now + timedelta(days=days),
        "type": "refresh",
        "jti": token_jti,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def is_token_revoked(db: Session, jti: str) -> bool:
    return db.scalar(select(RevokedToken).where(RevokedToken.jti == jti)) is not None


def revoke_token(db: Session, token_string: str) -> RevokedToken | None:
    settings = get_settings()
    try:
        payload = jwt.decode(
            token_string,
            settings.jwt_secret,
            algorithms=["HS256"],
            issuer=settings.jwt_issuer,
            audience=settings.jwt_audience,
            options={"verify_exp": False},
        )
    except Exception:
        return None

    jti = payload.get("jti")
    token_type = payload.get("type", "access")
    exp_timestamp = payload.get("exp")
    if not jti or not exp_timestamp:
        return None

    expires_at = datetime.fromtimestamp(exp_timestamp, tz=timezone.utc)
    if is_token_revoked(db, jti):
        return None

    record = RevokedToken(
        jti=jti,
        token_type=token_type,
        expires_at=expires_at,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


def verify_refresh_token(db: Session, refresh_token: str) -> tuple[UUID, str]:
    settings = get_settings()
    try:
        payload = jwt.decode(
            refresh_token,
            settings.jwt_secret,
            algorithms=["HS256"],
            issuer=settings.jwt_issuer,
            audience=settings.jwt_audience,
            options={"require": ["sub", "exp", "iat", "nbf", "iss", "aud", "type", "jti"]},
        )
        if payload.get("type") != "refresh":
            raise jwt.InvalidTokenError("Not a refresh token")
        jti = payload["jti"]
        if is_token_revoked(db, jti):
            raise jwt.InvalidTokenError("Refresh token has been revoked")
        user_id = UUID(payload["sub"])
        return user_id, jti
    except (jwt.InvalidTokenError, ValueError, KeyError, TypeError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid, expired, or revoked refresh token.",
        ) from exc


def get_current_user(
    token: Annotated[str | None, Depends(oauth2_scheme)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    settings = get_settings()
    if len(settings.jwt_secret) < 32:
        raise HTTPException(status_code=503, detail="JWT authentication is not configured.")
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=["HS256"],
            issuer=settings.jwt_issuer,
            audience=settings.jwt_audience,
            options={"require": ["sub", "exp", "iat", "nbf", "iss", "aud", "type"]},
        )
        if payload.get("type") != "access":
            raise jwt.InvalidTokenError("Wrong token type")
        jti = payload.get("jti")
        if jti and is_token_revoked(db, jti):
            raise jwt.InvalidTokenError("Token has been revoked.")
        user_id = UUID(payload["sub"])
    except (jwt.InvalidTokenError, ValueError, KeyError, TypeError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
    user = db.scalar(select(User).where(User.id == user_id, User.is_active.is_(True)))
    if user is None:
        raise HTTPException(status_code=401, detail="User is unavailable.")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
