from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import Task, TaskEvent, TaskStatus
from app.schemas.task import TaskCreate


class TaskService:
    def __init__(self, db: Session):
        self.db = db

    def create(self, payload: TaskCreate) -> Task:
        task = Task(project_id=payload.project_id, instruction=payload.instruction, selected_model=payload.selected_model, status=TaskStatus.queued)
        self.db.add(task)
        self.db.flush()
        self._append_event(task.id, "task.queued", "Task accepted and queued.", {})
        self.db.commit()
        self.db.refresh(task)
        return task

    def get(self, task_id: UUID) -> Task | None:
        return self.db.get(Task, task_id)

    def list_tasks(self, limit: int = 20) -> list[Task]:
        statement = select(Task).order_by(Task.created_at.desc()).limit(limit)
        return list(self.db.scalars(statement))

    def events(self, task_id: UUID, after: int = 0) -> list[TaskEvent]:
        statement = select(TaskEvent).where(TaskEvent.task_id == task_id, TaskEvent.sequence > after).order_by(TaskEvent.sequence.asc()).limit(200)
        return list(self.db.scalars(statement))

    def cancel(self, task_id: UUID) -> Task | None:
        task = self.get(task_id)
        if task is None:
            return None
        if task.status not in {TaskStatus.completed, TaskStatus.failed, TaskStatus.cancelled}:
            task.status = TaskStatus.cancelled
            self._append_event(task.id, "task.cancelled", "Cancellation recorded.", {})
            self.db.commit()
            self.db.refresh(task)
        return task

    def _append_event(self, task_id: UUID, event_type: str, message: str, payload: dict) -> None:
        last = self.db.scalar(select(func.max(TaskEvent.sequence)).where(TaskEvent.task_id == task_id)) or 0
        self.db.add(TaskEvent(task_id=task_id, sequence=last + 1, event_type=event_type, message=message, payload=payload))
