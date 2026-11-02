from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import Project, Task, TaskEvent, TaskStatus
from app.schemas.task import TaskCreate


class TaskService:
    def __init__(self, db: Session):
        self.db = db

    def create(self, payload: TaskCreate, owner_id: UUID | None = None) -> Task:
        statement = select(Project).where(Project.id == payload.project_id)
        if owner_id is not None:
            statement = statement.where(Project.owner_id == owner_id)
        if self.db.scalar(statement) is None:
            raise LookupError("Project not found.")
        task = Task(
            project_id=payload.project_id,
            instruction=payload.instruction,
            selected_model=payload.selected_model,
            status=TaskStatus.queued,
        )
        self.db.add(task)
        self.db.flush()
        self._append_event(task.id, "task.queued", "Task accepted and queued.", {})
        self.db.commit()
        self.db.refresh(task)
        return task

    def get(self, task_id: UUID, owner_id: UUID | None = None) -> Task | None:
        statement = select(Task).join(Project).where(Task.id == task_id)
        if owner_id is not None:
            statement = statement.where(Project.owner_id == owner_id)
        return self.db.scalar(statement)

    def list_tasks(self, limit: int = 20, owner_id: UUID | None = None) -> list[Task]:
        statement = select(Task).join(Project)
        if owner_id is not None:
            statement = statement.where(Project.owner_id == owner_id)
        statement = statement.order_by(Task.created_at.desc()).limit(limit)
        return list(self.db.scalars(statement))

    def events(
        self, task_id: UUID, after: int = 0, owner_id: UUID | None = None
    ) -> list[TaskEvent]:
        statement = (
            select(TaskEvent).join(Task).join(Project)
            .where(TaskEvent.task_id == task_id, TaskEvent.sequence > after)
        )
        if owner_id is not None:
            statement = statement.where(Project.owner_id == owner_id)
        statement = statement.order_by(TaskEvent.sequence.asc()).limit(200)
        return list(self.db.scalars(statement))

    def cancel(self, task_id: UUID, owner_id: UUID | None = None) -> Task | None:
        task = self.get(task_id, owner_id)
        if task is None:
            return None
        if task.status not in {TaskStatus.completed, TaskStatus.failed, TaskStatus.cancelled}:
            task.status = TaskStatus.cancelled
            self._append_event(task.id, "task.cancelled", "Cancellation recorded.", {})
            self.db.commit()
            self.db.refresh(task)
        return task

    def _append_event(self, task_id: UUID, event_type: str, message: str, payload: dict) -> None:
        last = self.db.scalar(
            select(func.max(TaskEvent.sequence)).where(TaskEvent.task_id == task_id)
        ) or 0
        self.db.add(
            TaskEvent(
                task_id=task_id,
                sequence=last + 1,
                event_type=event_type,
                message=message,
                payload=payload,
            )
        )
