import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.orm import Session, joinedload

from app.core.config import get_settings
from app.db.models import Task, TaskEvent, TaskStatus, WorkerJob, WorkerJobStatus


class WorkerQueue:
    """Lease protocol for trusted worker processes; never executes repository code."""

    def __init__(self, db: Session):
        self.db = db

    def enqueue_approved_task(self, task: Task) -> WorkerJob:
        if task.status != TaskStatus.awaiting_approval or task.approval_decision != "approved":
            raise ValueError("Only owner-approved plans can be queued.")
        job = self.db.scalar(select(WorkerJob).where(WorkerJob.task_id == task.id))
        if job is None:
            job = WorkerJob(task_id=task.id, status=WorkerJobStatus.queued)
            self.db.add(job)
            self.db.flush()
            self._event(task.id, "worker.queued", "Approved plan entered the worker queue.", {})
        return job

    def claim(self, worker_id: str) -> dict | None:
        now = datetime.now(timezone.utc)
        statement = (
            select(WorkerJob)
            .join(Task)
            .options(joinedload(WorkerJob.task))
            .where(
                Task.status == TaskStatus.awaiting_approval,
                Task.approval_decision == "approved",
                WorkerJob.attempt < WorkerJob.max_attempts,
                or_(
                    WorkerJob.status == WorkerJobStatus.queued,
                    (WorkerJob.status == WorkerJobStatus.leased)
                    & (WorkerJob.lease_expires_at < now),
                ),
            )
            .order_by(WorkerJob.created_at.asc())
            .with_for_update(skip_locked=True)
            .limit(1)
        )
        job = self.db.scalar(statement)
        if job is None:
            return None
        token = secrets.token_urlsafe(32)
        lease_seconds = get_settings().worker_lease_seconds
        job.status = WorkerJobStatus.leased
        job.attempt += 1
        job.lease_owner = worker_id
        job.lease_token_hash = hashlib.sha256(token.encode()).hexdigest()
        job.lease_expires_at = now + timedelta(seconds=lease_seconds)
        self._event(
            job.task_id, "worker.leased", "Worker queue lease issued; execution remains disabled.",
            {"worker_id": worker_id, "attempt": job.attempt},
        )
        self.db.commit()
        self.db.refresh(job)
        return {
            "job_id": job.id,
            "task_id": job.task_id,
            "lease_token": token,
            "lease_expires_at": job.lease_expires_at,
            "attempt": job.attempt,
        }

    def heartbeat(self, job_id: UUID, token: str) -> WorkerJob | None:
        job = self._valid_lease(job_id, token)
        if job is None:
            return None
        now = datetime.now(timezone.utc)
        settings = get_settings()
        ceiling = now + timedelta(seconds=settings.worker_max_lease_seconds)
        requested = now + timedelta(seconds=settings.worker_lease_seconds)
        job.lease_expires_at = min(requested, ceiling)
        self.db.commit()
        self.db.refresh(job)
        return job

    def fail(self, job_id: UUID, token: str, error: str) -> WorkerJob | None:
        job = self._valid_lease(job_id, token)
        if job is None:
            return None
        job.last_error = error
        job.lease_owner = None
        job.lease_token_hash = None
        job.lease_expires_at = None
        retry = job.attempt < job.max_attempts
        job.status = WorkerJobStatus.queued if retry else WorkerJobStatus.failed
        self._event(
            job.task_id,
            "worker.failed",
            "Worker reported a failed attempt; task code was not executed by the API.",
            {"attempt": job.attempt, "retry_scheduled": retry, "error": error},
        )
        self.db.commit()
        self.db.refresh(job)
        return job

    def _valid_lease(self, job_id: UUID, token: str) -> WorkerJob | None:
        job = self.db.scalar(
            select(WorkerJob).where(
                WorkerJob.id == job_id, WorkerJob.status == WorkerJobStatus.leased
            ).with_for_update()
        )
        if job is None or not job.lease_token_hash or not job.lease_expires_at:
            return None
        supplied = hashlib.sha256(token.encode()).hexdigest()
        if not secrets.compare_digest(supplied, job.lease_token_hash):
            return None
        if job.lease_expires_at <= datetime.now(timezone.utc):
            return None
        return job

    def _event(self, task_id: UUID, event_type: str, message: str, payload: dict) -> None:
        from sqlalchemy import func

        last = self.db.scalar(
            select(func.max(TaskEvent.sequence)).where(TaskEvent.task_id == task_id)
        ) or 0
        self.db.add(TaskEvent(
            task_id=task_id, sequence=last + 1, event_type=event_type,
            message=message, payload=payload,
        ))
