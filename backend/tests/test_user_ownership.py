from uuid import uuid4

from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.models import Project, User
from app.schemas.task import TaskCreate
from app.services.task_service import TaskService


def make_session():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    return Session(engine, expire_on_commit=False)


def test_project_queries_are_isolated_by_owner():
    with make_session() as db:
        first = User(id=uuid4(), email="one@example.com", password_hash="hash")
        second = User(id=uuid4(), email="two@example.com", password_hash="hash")
        db.add_all([first, second])
        db.flush()
        db.add(Project(
            id="private-project", name="Private", source_type="zip",
            workspace_path="/tmp/private", file_count=1, languages=[], owner_id=first.id,
        ))
        db.commit()
        assert db.scalars(select(Project).where(Project.owner_id == second.id)).all() == []
        assert db.scalar(
            select(Project).where(Project.id == "private-project", Project.owner_id == first.id)
        ) is not None


def test_task_creation_rejects_foreign_owned_project():
    with make_session() as db:
        owner = User(id=uuid4(), email="owner@example.com", password_hash="hash")
        intruder_id = uuid4()
        db.add(owner)
        db.flush()
        db.add(Project(
            id="owned", name="Owned", source_type="zip", workspace_path="/tmp/owned",
            file_count=1, languages=[], owner_id=owner.id,
        ))
        db.commit()
        try:
            TaskService(db).create(
                TaskCreate(project_id="owned", instruction="Try cross-tenant access"),
                owner_id=intruder_id,
            )
        except LookupError as exc:
            assert "Project not found" in str(exc)
        else:
            raise AssertionError("Task creation must enforce project ownership")


def test_task_lists_are_scoped_to_owner():
    with make_session() as db:
        owner = User(id=uuid4(), email="owner@example.com", password_hash="hash")
        other = User(id=uuid4(), email="other@example.com", password_hash="hash")
        db.add_all([owner, other])
        db.flush()
        db.add_all([
            Project(id="owner-project", name="Owner", source_type="zip",
                    workspace_path="/tmp/a", file_count=0, languages=[], owner_id=owner.id),
            Project(id="other-project", name="Other", source_type="zip",
                    workspace_path="/tmp/b", file_count=0, languages=[], owner_id=other.id),
        ])
        db.commit()
        service = TaskService(db)
        service.create(TaskCreate(project_id="owner-project", instruction="Own task"), owner_id=owner.id)
        service.create(TaskCreate(project_id="other-project", instruction="Other task"), owner_id=other.id)
        assert len(service.list_tasks(owner_id=owner.id)) == 1
        assert len(service.list_tasks(owner_id=other.id)) == 1
