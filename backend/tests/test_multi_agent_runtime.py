import asyncio
import json
from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.models import Project, Task, TaskStatus, User
from app.services.multi_agent_runtime import MultiAgentRuntime


def make_db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    db = Session(engine, expire_on_commit=False)
    owner = User(id=uuid4(), email="agent@example.com", password_hash="hash")
    db.add(owner)
    db.flush()
    db.add(Project(
        id="agent-project", name="Agent project", source_type="zip",
        workspace_path="/tmp/agent", file_count=0, languages=[], owner_id=owner.id,
    ))
    db.flush()
    task = Task(project_id="agent-project", instruction="Add a robust API endpoint", status=TaskStatus.queued)
    db.add(task)
    db.commit()
    return db, owner, task


def test_five_specialists_run_and_return_approval_gated_plan():
    db, owner, task = make_db()
    calls = []

    async def fake_request(role, body, api_key):
        calls.append(role)
        return {"choices": [{"message": {"content": json.dumps({
            "summary": f"{role} review",
            "findings": [f"{role} finding"],
            "blockers": [],
            "proposed_actions": [f"{role} action"],
        })}}]}

    runtime = MultiAgentRuntime(db, request=fake_request)
    updated, plan = asyncio.run(runtime.create_team_plan(
        task.id, "test-openrouter-key", "openrouter/free", owner.id
    ))
    assert set(calls) == {"architect", "implementer", "security", "qa", "reviewer"}
    assert len(plan.agents) == 5
    assert updated.status == TaskStatus.awaiting_approval
    assert plan.execution_enabled is False
    assert plan.approval_required is True


def test_team_plan_rejects_paid_model():
    db, owner, task = make_db()
    runtime = MultiAgentRuntime(db, request=lambda *_: None)
    with pytest.raises(ValueError, match="free"):
        asyncio.run(runtime.create_team_plan(
            task.id, "test-openrouter-key", "vendor/model-paid", owner.id
        ))


def test_team_plan_cannot_access_another_users_task():
    db, owner, task = make_db()
    runtime = MultiAgentRuntime(db, request=lambda *_: None)
    with pytest.raises(LookupError):
        asyncio.run(runtime.create_team_plan(
            task.id, "test-openrouter-key", "openrouter/free", uuid4()
        ))
