import hmac
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import get_db
from app.schemas.worker import (
    WorkerCancellationRequest, WorkerClaimRequest, WorkerCompletionRead,
    WorkerCompletionRequest, WorkerFailureRequest, WorkerHeartbeatRead,
    WorkerHeartbeatRequest, WorkerJobDetailsRead, WorkerLeaseRead, WorkerReleaseRead,
)
from app.services.worker_queue import WorkerQueue

router = APIRouter(prefix="/internal/worker", tags=["worker-internal"])


def require_worker(
    token: Annotated[str | None, Header(alias="X-DevForge-Worker-Token")] = None,
) -> None:
    expected = get_settings().worker_shared_secret
    if len(expected) < 32 or token is None or not hmac.compare_digest(token, expected):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Worker authentication failed.",
        )


@router.post("/claim", response_model=WorkerLeaseRead | None, dependencies=[Depends(require_worker)])
def claim_job(payload: WorkerClaimRequest, db: Session = Depends(get_db)):
    return WorkerQueue(db).claim(payload.worker_id)


@router.get("/{job_id}/details", response_model=WorkerJobDetailsRead, dependencies=[Depends(require_worker)])
def get_job_details(job_id: UUID, db: Session = Depends(get_db)):
    details = WorkerQueue(db).get_details(job_id)
    if details is None:
        raise HTTPException(status_code=404, detail="Job not found.")
    return details


@router.post("/{job_id}/heartbeat", response_model=WorkerHeartbeatRead, dependencies=[Depends(require_worker)])
def heartbeat_job(
    job_id: UUID, payload: WorkerHeartbeatRequest, db: Session = Depends(get_db)
):
    job = WorkerQueue(db).heartbeat(job_id, payload.lease_token)
    if job is None:
        raise HTTPException(status_code=409, detail="Lease is invalid or expired.")
    return WorkerHeartbeatRead(
        job_id=job.id,
        lease_expires_at=job.lease_expires_at,
        status=job.status.value,
        cancellation_requested=job.cancellation_requested_at is not None,
    )


@router.post("/{job_id}/fail", response_model=WorkerReleaseRead, dependencies=[Depends(require_worker)])
def fail_job(
    job_id: UUID, payload: WorkerFailureRequest, db: Session = Depends(get_db)
):
    job = WorkerQueue(db).fail(job_id, payload.lease_token, payload.error)
    if job is None:
        raise HTTPException(status_code=409, detail="Lease is invalid or expired.")
    return WorkerReleaseRead(
        job_id=job.id,
        status=job.status.value,
        retry_scheduled=job.status.value == "queued",
    )


@router.post("/{job_id}/complete", response_model=WorkerCompletionRead, dependencies=[Depends(require_worker)])
def complete_job(job_id: UUID, payload: WorkerCompletionRequest, db: Session = Depends(get_db)):
    job = WorkerQueue(db).complete(job_id, payload.lease_token, payload.result)
    if job is None:
        raise HTTPException(status_code=409, detail="Lease is invalid, expired, or cancelled.")
    return WorkerCompletionRead(job_id=job.id, status=job.status.value)


@router.post("/{job_id}/cancelled", response_model=WorkerCompletionRead, dependencies=[Depends(require_worker)])
def acknowledge_cancellation(
    job_id: UUID, payload: WorkerCancellationRequest, db: Session = Depends(get_db)
):
    job = WorkerQueue(db).cancelled(job_id, payload.lease_token)
    if job is None:
        raise HTTPException(status_code=409, detail="Lease is invalid or expired.")
    return WorkerCompletionRead(job_id=job.id, status=job.status.value)
