from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.models import Project, TaskStatus, User
from app.schemas.task import TaskApprovalRequest, TaskCreate
from app.services.task_service import TaskService


def make_session():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    return Session(engine, expire_on_commit=False)


def setup_awaiting_task(db):
    owner = User(id=uuid4(), email="approver@example.com", password_hash="hash")
    db.add(owner)
    db.flush()
    db.add(Project(
        id="approval-project", name="Approval", source_type="zip",
        workspace_path="/tmp/approval", file_count=0, languages=[], owner_id=owner.id,
    ))
    db.commit()
    service = TaskService(db)
    task = service.create(
        TaskCreate(project_id="approval-project", instruction="Add a feature"),
        owner_id=owner.id,
    )
    task.status = TaskStatus.awaiting_approval
    db.commit()
    return service, task, owner


def test_owner_can_approve_plan_without_starting_execution():
    with make_session() as db:
        service, task, owner = setup_awaiting_task(db)
        approved = service.decide_approval(
            task.id, TaskApprovalRequest(decision="approved", note="Reviewed"),
            owner_id=owner.id,
        )
        assert approved is not None
        assert approved.status == TaskStatus.awaiting_approval
        assert approved.approval_decision == "approved"
        assert approved.approval_note == "Reviewed"
        assert approved.approval_at is not None
        events = service.events(task.id, owner_id=owner.id)
        assert events[-2].event_type == "task.approval.approved"
        assert events[-2].payload["execution_started"] is False
        assert events[-1].event_type == "worker.queued"


def test_rejection_cancels_task_and_records_event():
    with make_session() as db:
        service, task, owner = setup_awaiting_task(db)
        rejected = service.decide_approval(
            task.id, TaskApprovalRequest(decision="rejected", note="Unsafe change"),
            owner_id=owner.id,
        )
        assert rejected is not None
        assert rejected.status == TaskStatus.cancelled
        assert rejected.approval_decision == "rejected"
        assert service.events(task.id, owner_id=owner.id)[-1].event_type == "task.approval.rejected"


def test_approval_is_owner_scoped():
    with make_session() as db:
        service, task, _ = setup_awaiting_task(db)
        assert service.decide_approval(
            task.id, TaskApprovalRequest(decision="approved"), owner_id=uuid4()
        ) is None


def test_duplicate_approval_is_rejected():
    with make_session() as db:
        service, task, owner = setup_awaiting_task(db)
        payload = TaskApprovalRequest(decision="approved")
        service.decide_approval(task.id, payload, owner_id=owner.id)
        with pytest.raises(ValueError, match="already been recorded"):
            service.decide_approval(task.id, payload, owner_id=owner.id)
