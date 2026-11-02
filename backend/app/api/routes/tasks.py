import json
import time
from collections.abc import Iterator
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser
from app.core.config import get_settings
from app.db.session import get_db
from app.schemas.task import (
    TaskApprovalRequest, TaskApprovalResponse, TaskCreate, TaskEventRead, TaskRead,
)
from app.services.task_service import TaskService

router = APIRouter()


@router.post("/tasks", response_model=TaskRead, status_code=201)
def create_task(
    payload: TaskCreate, user: CurrentUser, db: Session = Depends(get_db)
) -> TaskRead:
    try:
        return TaskService(db).create(payload, owner_id=user.id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/tasks", response_model=list[TaskRead])
def list_tasks(
    user: CurrentUser,
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
) -> list[TaskRead]:
    return TaskService(db).list_tasks(limit, owner_id=user.id)


@router.get("/tasks/{task_id}", response_model=TaskRead)
def get_task(task_id: UUID, user: CurrentUser, db: Session = Depends(get_db)) -> TaskRead:
    task = TaskService(db).get(task_id, owner_id=user.id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@router.post(
    "/tasks/{task_id}/approval",
    response_model=TaskApprovalResponse,
    summary="Approve or reject an agent plan",
)
def decide_task_approval(
    task_id: UUID,
    payload: TaskApprovalRequest,
    user: CurrentUser,
    db: Session = Depends(get_db),
) -> TaskApprovalResponse:
    try:
        task = TaskService(db).decide_approval(task_id, payload, owner_id=user.id)
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    message = (
        "Approval recorded. Code execution has not started because the isolated worker "
        "runtime is not yet available."
        if payload.decision == "approved"
        else "Plan rejected and task cancelled."
    )
    return TaskApprovalResponse(task=task, execution_started=False, message=message)


@router.get("/tasks/{task_id}/events")
def stream_task_events(
    task_id: UUID,
    user: CurrentUser,
    after: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> StreamingResponse:
    service = TaskService(db)
    if service.get(task_id, owner_id=user.id) is None:
        raise HTTPException(status_code=404, detail="Task not found")

    def generate() -> Iterator[str]:
        cursor, idle = after, 0
        while idle < 30:
            events = service.events(task_id, after=cursor, owner_id=user.id)
            if events:
                idle = 0
                for event in events:
                    cursor = event.sequence
                    data = json.dumps(TaskEventRead.model_validate(event).model_dump(mode="json"))
                    yield f"id: {cursor}\nevent: task\ndata: {data}\n\n"
            else:
                idle += 1
                yield ": keep-alive\n\n"
                time.sleep(get_settings().task_event_poll_interval_seconds)
            current = service.get(task_id, owner_id=user.id)
            if current and current.status.value in {"completed", "failed", "cancelled"} and not events:
                break

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
