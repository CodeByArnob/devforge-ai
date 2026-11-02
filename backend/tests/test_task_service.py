import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.models import Project, TaskEvent
from app.schemas.task import TaskCreate
from app.services.task_service import TaskService


def make_session():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    return Session(engine, expire_on_commit=False)


def create_project(db: Session) -> None:
    db.add(Project(
        id="demo",
        name="Demo",
        source_type="zip",
        workspace_path="/tmp/demo",
        file_count=1,
        languages=[],
    ))
    db.commit()


def test_create_persists_queued_event():
    with make_session() as db:
        create_project(db)
        task = TaskService(db).create(TaskCreate(project_id="demo", instruction="Add health endpoint"))
        assert task.status.value == "queued"
        events = db.query(TaskEvent).filter_by(task_id=task.id).all()
        assert [(event.sequence, event.event_type) for event in events] == [(1, "task.queued")]


def test_create_rejects_unknown_project():
    with make_session() as db:
        with pytest.raises(LookupError, match="Project not found"):
            TaskService(db).create(TaskCreate(project_id="missing", instruction="Inspect project"))


def test_cancel_is_recorded():
    with make_session() as db:
        create_project(db)
        service = TaskService(db)
        task = service.create(TaskCreate(project_id="demo", instruction="Inspect project"))
        cancelled = service.cancel(task.id)
        assert cancelled and cancelled.status.value == "cancelled"
        assert [event.event_type for event in service.events(task.id)] == ["task.queued", "task.cancelled"]
