from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.db.models import Project, Task, TaskEvent, TaskStatus
from app.schemas.task import TaskApprovalRequest, TaskCreate
from app.services.worker_queue import WorkerQueue


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

    def decide_approval(
        self,
        task_id: UUID,
        payload: TaskApprovalRequest,
        owner_id: UUID | None = None,
    ) -> Task | None:
        statement = (
            select(Task).join(Project).where(Task.id == task_id).with_for_update()
        )
        if owner_id is not None:
            statement = statement.where(Project.owner_id == owner_id)
        task = self.db.scalar(statement)
        if task is None:
            return None
        if task.status != TaskStatus.awaiting_approval:
            raise ValueError("Only tasks awaiting approval can receive an approval decision.")
        if task.approval_decision != "not_required":
            raise ValueError("An approval decision has already been recorded.")

        decision_time = datetime.now(timezone.utc)
        task.approval_decision = payload.decision
        task.approval_note = payload.note
        task.approval_at = decision_time
        if payload.decision == "rejected":
            task.status = TaskStatus.cancelled
        self._append_event(
            task.id,
            f"task.approval.{payload.decision}",
            (
                "Plan approved by the project owner; it is queued for a worker lease. "
                "No repository code is executed by this API."
                if payload.decision == "approved"
                else "Plan rejected by the project owner; task cancelled."
            ),
            {
                "decision": payload.decision,
                "note": payload.note,
                "execution_started": False,
            },
        )
        if payload.decision == "approved":
            WorkerQueue(self.db).enqueue_approved_task(task)
        self.db.commit()
        self.db.refresh(task)
        return task

    def cancel(self, task_id: UUID, owner_id: UUID | None = None) -> Task | None:
        task = self.get(task_id, owner_id)
        if task is None:
            return None
        if task.status not in {TaskStatus.completed, TaskStatus.failed, TaskStatus.cancelled}:
            task.status = TaskStatus.cancelled
            WorkerQueue(self.db).request_cancellation(task.id)
            self._append_event(task.id, "task.cancelled", "Cancellation recorded.", {})
            self.db.commit()
            self.db.refresh(task)
        return task

    def _append_event(self, task_id: UUID, event_type: str, message: str, payload: dict) -> None:
        # Allocate the sequence inside the same transaction as the event. This
        # is a single atomic UPDATE on PostgreSQL and avoids MAX()+1 races.
        sequence = self.db.execute(
            update(Task).where(Task.id == task_id).values(event_sequence=Task.event_sequence + 1)
            .returning(Task.event_sequence)
        ).scalar_one()
        self.db.add(
            TaskEvent(
                task_id=task_id,
            sequence=sequence,
                event_type=event_type,
                message=message,
                payload=payload,
            )
        )

