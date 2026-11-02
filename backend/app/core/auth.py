import hmac

from fastapi import Header, HTTPException, status

from app.core.config import get_settings


async def require_api_token(
    x_devforge_token: str | None = Header(default=None, alias="X-DevForge-Token"),
) -> None:
    settings = get_settings()
    expected = settings.api_access_token
    if not expected:
        if settings.app_env == "production":
            raise HTTPException(status_code=503, detail="API authentication is not configured.")
        return
    if not x_devforge_token or not hmac.compare_digest(x_devforge_token, expected):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid DevForge API token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
