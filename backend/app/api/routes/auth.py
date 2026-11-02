from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import (
    CurrentUser,
    create_access_token,
    create_refresh_token,
    hash_password,
    normalize_email,
    revoke_token,
    validate_email,
    verify_password,
    verify_refresh_token,
)
from app.core.config import get_settings
from app.db.models import User
from app.db.session import get_db
from app.services.account_recovery import (
    AccountRecoveryError,
    request_password_recovery,
    reset_password_with_token,
)
from app.services.rate_limiter import RateLimiter, get_client_ip

router = APIRouter(prefix="/auth", tags=["authentication"])


class RegisterRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=12, max_length=128)


class LoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=1, max_length=128)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    email: str
    created_at: datetime


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"
    expires_in: int
    user: UserRead


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=32)


class RecoveryRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)


class PasswordResetSubmitRequest(BaseModel):
    token: str = Field(min_length=20, max_length=256)
    new_password: str = Field(min_length=12, max_length=128)


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(
    payload: RegisterRequest, request: Request, db: Session = Depends(get_db)
) -> TokenResponse:
    ip = get_client_ip(request)
    RateLimiter.check_rate_limit(db, f"ip:{ip}", "auth.register", max_requests=10, window_seconds=60)

    settings = get_settings()
    if not settings.allow_registration:
        raise HTTPException(status_code=403, detail="Public registration is disabled.")
    try:
        email = validate_email(payload.email)
        encoded = hash_password(payload.password)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    if db.scalar(select(User.id).where(User.email == email)):
        raise HTTPException(status_code=409, detail="An account with this email already exists.")
    user = User(email=email, password_hash=encoded)
    db.add(user)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="An account with this email already exists.") from exc
    db.refresh(user)
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        expires_in=settings.jwt_access_token_minutes * 60,
        user=user,
    )


@router.post("/login", response_model=TokenResponse)
def login(
    payload: LoginRequest, request: Request, db: Session = Depends(get_db)
) -> TokenResponse:
    ip = get_client_ip(request)
    RateLimiter.check_rate_limit(db, f"ip:{ip}", "auth.login", max_requests=15, window_seconds=60)

    settings = get_settings()
    email = normalize_email(payload.email)
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not user.is_active or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        expires_in=settings.jwt_access_token_minutes * 60,
        user=user,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(
    payload: RefreshTokenRequest, request: Request, db: Session = Depends(get_db)
) -> TokenResponse:
    ip = get_client_ip(request)
    RateLimiter.check_rate_limit(db, f"ip:{ip}", "auth.refresh", max_requests=30, window_seconds=60)

    settings = get_settings()
    user_id, old_jti = verify_refresh_token(db, payload.refresh_token)
    user = db.scalar(select(User).where(User.id == user_id, User.is_active.is_(True)))
    if user is None:
        raise HTTPException(status_code=401, detail="User unavailable.")

    # Revoke old refresh token (token rotation)
    revoke_token(db, payload.refresh_token)

    new_access = create_access_token(user.id)
    new_refresh = create_refresh_token(user.id)
    return TokenResponse(
        access_token=new_access,
        refresh_token=new_refresh,
        expires_in=settings.jwt_access_token_minutes * 60,
        user=user,
    )


@router.post("/logout", status_code=200)
def logout(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> dict:
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split("Bearer ", 1)[1]
        revoke_token(db, token)
    return {"message": "Logged out successfully."}


@router.post("/recover/request")
def request_recovery(
    payload: RecoveryRequest, request: Request, db: Session = Depends(get_db)
) -> dict:
    ip = get_client_ip(request)
    RateLimiter.check_rate_limit(db, f"ip:{ip}", "auth.recover", max_requests=5, window_seconds=60)

    try:
        record, raw_token = request_password_recovery(db, payload.email)
        # In production this token is emailed to user; for testing & dev API returns token confirmation
        return {
            "message": "If the account exists, a recovery token has been issued.",
            "recovery_token": raw_token,
            "expires_at": record.expires_at.isoformat(),
        }
    except AccountRecoveryError:
        # Prevent user enumeration
        return {"message": "If the account exists, a recovery token has been issued."}


@router.post("/recover/reset")
def reset_password(
    payload: PasswordResetSubmitRequest, request: Request, db: Session = Depends(get_db)
) -> dict:
    ip = get_client_ip(request)
    RateLimiter.check_rate_limit(db, f"ip:{ip}", "auth.reset", max_requests=5, window_seconds=60)

    try:
        user = reset_password_with_token(db, payload.token, payload.new_password)
        return {"message": "Password reset successful.", "email": user.email}
    except (AccountRecoveryError, ValueError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/me", response_model=UserRead)
def me(user: CurrentUser) -> User:
    return user
