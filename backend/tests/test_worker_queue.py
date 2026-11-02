from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.config import Settings
from app.db.base import Base
from app.db.models import (
    Project, TaskStatus, User, WorkerJob, WorkerJobStatus,
)
from app.schemas.task import TaskApprovalRequest, TaskCreate
from app.services.task_service import TaskService
from app.services.worker_queue import WorkerQueue


def make_session():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    return Session(engine, expire_on_commit=False)


def setup_approved_task(db):
    owner = User(id=uuid4(), email="worker-owner@example.com", password_hash="hash")
    db.add(owner)
    db.flush()
    db.add(Project(
        id="worker-project", name="Worker", source_type="zip",
        workspace_path="/tmp/worker", file_count=0, languages=[], owner_id=owner.id,
    ))
    db.commit()
    service = TaskService(db)
    task = service.create(
        TaskCreate(project_id="worker-project", instruction="Implement feature"),
        owner_id=owner.id,
    )
    task.status = TaskStatus.awaiting_approval
    db.commit()
    task = service.decide_approval(
        task.id, TaskApprovalRequest(decision="approved"), owner_id=owner.id
    )
    return task


@pytest.fixture(autouse=True)
def worker_settings(monkeypatch):
    settings = Settings(
        worker_shared_secret="x" * 48,
        worker_lease_seconds=60,
        worker_max_lease_seconds=300,
    )
    monkeypatch.setattr("app.services.worker_queue.get_settings", lambda: settings)


def test_approved_plan_is_queued_and_claimed_with_one_time_lease():
    with make_session() as db:
        task = setup_approved_task(db)
        queue = WorkerQueue(db)
        lease = queue.claim("worker-a")
        assert lease is not None
        assert lease["task_id"] == task.id
        assert lease["attempt"] == 1
        assert len(lease["lease_token"]) >= 32
        assert queue.claim("worker-b") is None


def test_lease_requires_correct_token_and_heartbeat_extends_it():
    with make_session() as db:
        setup_approved_task(db)
        queue = WorkerQueue(db)
        lease = queue.claim("worker-a")
        assert lease is not None
        assert queue.heartbeat(lease["job_id"], "wrong-token") is None
        updated = queue.heartbeat(lease["job_id"], lease["lease_token"])
        assert updated is not None
        assert updated.lease_expires_at > lease["lease_expires_at"]


def test_failed_attempt_is_requeued_until_max_attempts():
    with make_session() as db:
        setup_approved_task(db)
        queue = WorkerQueue(db)
        first = queue.claim("worker-a")
        assert first is not None
        failed = queue.fail(first["job_id"], first["lease_token"], "sandbox unavailable")
        assert failed is not None
        assert failed.status == WorkerJobStatus.queued
        second = queue.claim("worker-b")
        assert second is not None and second["attempt"] == 2
        failed = queue.fail(second["job_id"], second["lease_token"], "still unavailable")
        assert failed is not None and failed.status == WorkerJobStatus.queued
        third = queue.claim("worker-c")
        assert third is not None and third["attempt"] == 3
        failed = queue.fail(third["job_id"], third["lease_token"], "terminal failure")
        assert failed is not None and failed.status == WorkerJobStatus.failed
        assert queue.claim("worker-d") is None


def test_expired_lease_can_be_reclaimed():
    with make_session() as db:
        setup_approved_task(db)
        queue = WorkerQueue(db)
        first = queue.claim("worker-a")
        assert first is not None
        job = db.get(WorkerJob, first["job_id"])
        job.lease_expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        db.commit()
        second = queue.claim("worker-b")
        assert second is not None
        assert second["job_id"] == first["job_id"]
        assert second["attempt"] == 2
        assert queue.heartbeat(first["job_id"], first["lease_token"]) is None


def test_unapproved_task_cannot_enter_worker_queue():
    with make_session() as db:
        owner = User(id=uuid4(), email="not-approved@example.com", password_hash="hash")
        db.add(owner)
        db.flush()
        db.add(Project(
            id="unapproved-project", name="Unapproved", source_type="zip",
            workspace_path="/tmp/unapproved", file_count=0, languages=[], owner_id=owner.id,
        ))
        db.commit()
        task = TaskService(db).create(
            TaskCreate(project_id="unapproved-project", instruction="Do not run"),
            owner_id=owner.id,
        )
        with pytest.raises(ValueError, match="Only owner-approved"):
            WorkerQueue(db).enqueue_approved_task(task)
