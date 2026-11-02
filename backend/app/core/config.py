from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")
    app_env: str = "development"
    app_name: str = "DevForge AI API"
    api_v1_prefix: str = "/api/v1"
    database_url: str = "sqlite:///./devforge.db"
    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]
    log_level: str = "INFO"
    task_event_poll_interval_seconds: float = 1.0
    api_access_token: str = ""
    jwt_secret: str = ""
    jwt_issuer: str = "devforge-ai"
    jwt_audience: str = "devforge-ai-api"
    jwt_access_token_minutes: int = 30
    allow_registration: bool = False
    workspace_root: str = "./workspace"

    @field_validator("task_event_poll_interval_seconds")
    @classmethod
    def validate_poll_interval(cls, value: float) -> float:
        if not 0.2 <= value <= 10:
            raise ValueError("Poll interval must be between 0.2 and 10 seconds")
        return value

    @field_validator("jwt_access_token_minutes")
    @classmethod
    def validate_jwt_ttl(cls, value: int) -> int:
        if not 5 <= value <= 1440:
            raise ValueError("JWT access token lifetime must be between 5 and 1440 minutes")
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
