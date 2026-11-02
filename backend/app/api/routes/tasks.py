import json
import time
from collections.abc import Iterator
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import get_db
from app.schemas.task import TaskCreate, TaskEventRead, TaskRead
from app.services.task_service import TaskService

router = APIRouter()


@router.post("/tasks", response_model=TaskRead, status_code=201)
def create_task(payload: TaskCreate, db: Session = Depends(get_db)) -> TaskRead:
    return TaskService(db).create(payload)


@router.get("/tasks", response_model=list[TaskRead])
def list_tasks(limit: int = Query(default=20, ge=1, le=100), db: Session = Depends(get_db)) -> list[TaskRead]:
    return TaskService(db).list_tasks(limit)


@router.get("/tasks/{task_id}", response_model=TaskRead)
def get_task(task_id: UUID, db: Session = Depends(get_db)) -> TaskRead:
    task = TaskService(db).get(task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@router.get("/tasks/{task_id}/events")
def stream_task_events(task_id: UUID, after: int = Query(default=0, ge=0), db: Session = Depends(get_db)) -> StreamingResponse:
    service = TaskService(db)
    if service.get(task_id) is None:
        raise HTTPException(status_code=404, detail="Task not found")

    def generate() -> Iterator[str]:
        cursor, idle = after, 0
        while idle < 30:
            events = service.events(task_id, after=cursor)
            if events:
                idle = 0
                for event in events:
                    cursor = event.sequence
                    data = json.dumps(TaskEventRead.model_validate(event).model_dump(mode="json"))
                    yield f"id: {cursor}\\nevent: task\\ndata: {data}\\n\\n"
            else:
                idle += 1
                yield ": keep-alive\\n\\n"
                time.sleep(get_settings().task_event_poll_interval_seconds)
            current = service.get(task_id)
            if current and current.status.value in {"completed", "failed", "cancelled"} and not events:
                break

    return StreamingResponse(generate(), media_type="text/event-stream", headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})
