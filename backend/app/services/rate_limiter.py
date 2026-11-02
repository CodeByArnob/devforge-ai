"""Persistent sliding-window rate limiter."""
from datetime import datetime, timezone

from fastapi import HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import RateLimitRecord


class RateLimiter:
    """Enforces request limits per client key (IP or user ID) and endpoint."""

    @staticmethod
    def check_rate_limit(
        db: Session,
        key: str,
        endpoint: str,
        max_requests: int = 60,
        window_seconds: int = 60,
    ) -> None:
        now = datetime.now(timezone.utc)
        record = db.scalar(
            select(RateLimitRecord)
            .where(RateLimitRecord.rate_key == key, RateLimitRecord.endpoint == endpoint)
            .with_for_update()
        )

        if record is None:
            record = RateLimitRecord(
                rate_key=key,
                endpoint=endpoint,
                count=1,
                window_start=now,
            )
            db.add(record)
            db.commit()
            return

        window_start = record.window_start
        if window_start.tzinfo is None:
            window_start = window_start.replace(tzinfo=timezone.utc)

        elapsed = (now - window_start).total_seconds()
        if elapsed >= window_seconds:
            # New window
            record.count = 1
            record.window_start = now
            db.commit()
            return

        if record.count >= max_requests:
            retry_after = int(window_seconds - elapsed) + 1
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Rate limit exceeded. Try again in {retry_after} seconds.",
                headers={"Retry-After": str(retry_after)},
            )

        record.count += 1
        db.commit()


def get_client_ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    client = request.client
    return client.host if client else "unknown"
