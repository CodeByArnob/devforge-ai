from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool
from app.db.base import Base
from app.db.models import TaskEvent
from app.schemas.task import TaskCreate
from app.services.task_service import TaskService


def session():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False},
                           poolclass=StaticPool)
    Base.metadata.create_all(engine)
    return Session(engine, expire_on_commit=False)


def test_create_persists_queued_event():
    with session() as db:
        task = TaskService(db).create(TaskCreate(project_id="demo", instruction="Add health endpoint"))
        assert task.status.value == "queued"
        events = db.query(TaskEvent).filter_by(task_id=task.id).all()
        assert [(e.sequence, e.event_type) for e in events] == [(1, "task.queued")]


def test_cancel_is_recorded():
    with session() as db:
        service = TaskService(db)
        task = service.create(TaskCreate(project_id="demo", instruction="Inspect project"))
        cancelled = service.cancel(task.id)
        assert cancelled and cancelled.status.value == "cancelled"
        assert [e.event_type for e in service.events(task.id)] == ["task.queued", "task.cancelled"]
