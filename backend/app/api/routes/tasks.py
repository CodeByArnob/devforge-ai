import json
import time
from collections.abc import Iterator
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser
from app.core.config import get_settings
from app.db.models import PatchProposal, Project
from app.db.session import get_db
from app.schemas.task import (
    PatchApprovalRequest, PatchProposalRequest, TaskApprovalRequest, TaskApprovalResponse,
    TaskCreate, TaskEventRead, TaskRead,
)
from app.services.patch_service import (
    Change, PatchSafetyError, apply, proposal, reject_proposal, rollback_patch,
)
from app.services.task_service import TaskService
from app.services.workspace_snapshot import create_snapshot

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


@router.post("/tasks/{task_id}/cancel", response_model=TaskRead)
def cancel_task(task_id: UUID, user: CurrentUser, db: Session = Depends(get_db)) -> TaskRead:
    task = TaskService(db).cancel(task_id, owner_id=user.id)
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
        "Approval recorded. Approved plan is queued for execution."
        if payload.decision == "approved"
        else "Plan rejected and task cancelled."
    )
    return TaskApprovalResponse(task=task, execution_started=False, message=message)


@router.get("/tasks/{task_id}/patches")
def list_task_patches(task_id: UUID, user: CurrentUser, db: Session = Depends(get_db)) -> list[dict]:
    task = TaskService(db).get(task_id, owner_id=user.id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    records = db.scalars(
        select(PatchProposal)
        .where(PatchProposal.task_id == task_id)
        .order_by(PatchProposal.created_at.desc())
    ).all()
    return [
        {
            "patch_id": str(r.id),
            "base_snapshot_digest": r.base_snapshot_digest,
            "patch_digest": r.patch_digest,
            "status": r.status,
            "applied_snapshot_digest": r.applied_snapshot_digest,
            "approval_note": r.approval_note,
            "created_at": r.created_at.isoformat() if r.created_at else None,
            "approved_at": r.approved_at.isoformat() if r.approved_at else None,
        }
        for r in records
    ]


@router.get("/tasks/{task_id}/patches/{patch_id}")
def get_task_patch(
    task_id: UUID, patch_id: UUID, user: CurrentUser, db: Session = Depends(get_db)
) -> dict:
    task = TaskService(db).get(task_id, owner_id=user.id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    record = db.scalar(
        select(PatchProposal).where(PatchProposal.id == patch_id, PatchProposal.task_id == task_id)
    )
    if record is None:
        raise HTTPException(status_code=404, detail="Patch not found")
    return {
        "patch_id": str(record.id),
        "task_id": str(record.task_id),
        "base_snapshot_digest": record.base_snapshot_digest,
        "patch_digest": record.patch_digest,
        "unified_diff": record.unified_diff,
        "changes": record.changes,
        "status": record.status,
        "applied_snapshot_digest": record.applied_snapshot_digest,
        "approval_note": record.approval_note,
        "created_at": record.created_at.isoformat() if record.created_at else None,
        "approved_at": record.approved_at.isoformat() if record.approved_at else None,
    }


@router.post("/tasks/{task_id}/patches", status_code=201)
def propose_patch(
    task_id: UUID, payload: PatchProposalRequest, user: CurrentUser, db: Session = Depends(get_db)
) -> dict:
    task = TaskService(db).get(task_id, owner_id=user.id)
    project = (
        db.scalar(select(Project).where(Project.id == task.project_id, Project.owner_id == user.id))
        if task
        else None
    )
    if task is None or project is None:
        raise HTTPException(status_code=404, detail="Task or project not found")
    snapshots = Path(get_settings().workspace_root) / ".snapshots"
    try:
        _, _, base_digest = create_snapshot(Path(project.workspace_path), snapshots)
        patch_digest, unified_diff, changes = proposal(
            snapshots / base_digest, [Change(**item.model_dump()) for item in payload.changes]
        )
    except (PatchSafetyError, ValueError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    record = PatchProposal(
        task_id=task.id,
        base_snapshot_digest=base_digest,
        patch_digest=patch_digest,
        changes=changes,
        unified_diff=unified_diff,
    )
    db.add(record)
    db.flush()
    TaskService(db)._append_event(
        task.id,
        "patch.proposed",
        "Patch proposal awaits owner approval.",
        {"patch_id": str(record.id), "base_snapshot": base_digest, "patch_digest": patch_digest},
    )
    db.commit()
    return {
        "patch_id": record.id,
        "base_snapshot_digest": base_digest,
        "patch_digest": patch_digest,
        "unified_diff": unified_diff,
        "status": record.status,
    }


@router.post("/tasks/{task_id}/patches/{patch_id}/approve")
def approve_patch(
    task_id: UUID,
    patch_id: UUID,
    payload: PatchApprovalRequest,
    user: CurrentUser,
    db: Session = Depends(get_db),
) -> dict:
    task = TaskService(db).get(task_id, owner_id=user.id)
    record = db.scalar(
        select(PatchProposal)
        .where(PatchProposal.id == patch_id, PatchProposal.task_id == task_id)
        .with_for_update()
    )
    if task is None or record is None:
        raise HTTPException(status_code=404, detail="Task or patch not found")
    if record.status != "proposed":
        raise HTTPException(status_code=409, detail="Patch is no longer awaiting approval")
    snapshots = Path(get_settings().workspace_root) / ".snapshots"
    try:
        _, applied_digest = apply(snapshots / record.base_snapshot_digest, snapshots, record.changes)
    except (PatchSafetyError, ValueError, OSError) as exc:
        raise HTTPException(status_code=409, detail=f"Patch could not be applied safely: {exc}") from exc
    record.status, record.approved_at, record.approval_note = "applied", datetime.now(timezone.utc), payload.note
    record.applied_snapshot_digest = applied_digest
    TaskService(db)._append_event(
        task_id,
        "patch.applied",
        "Owner-approved patch applied to a new immutable snapshot.",
        {"patch_id": str(record.id), "snapshot": applied_digest},
    )
    db.commit()
    return {"patch_id": record.id, "status": record.status, "snapshot_digest": applied_digest}


@router.post("/tasks/{task_id}/patches/{patch_id}/reject")
def reject_task_patch(
    task_id: UUID,
    patch_id: UUID,
    payload: PatchApprovalRequest,
    user: CurrentUser,
    db: Session = Depends(get_db),
) -> dict:
    task = TaskService(db).get(task_id, owner_id=user.id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    try:
        record = reject_proposal(db, task_id, patch_id, note=payload.note)
        return {"patch_id": str(record.id), "status": record.status, "note": record.approval_note}
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.post("/tasks/{task_id}/patches/{patch_id}/rollback")
def rollback_task_patch(
    task_id: UUID,
    patch_id: UUID,
    user: CurrentUser,
    db: Session = Depends(get_db),
) -> dict:
    task = TaskService(db).get(task_id, owner_id=user.id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    snapshots = Path(get_settings().workspace_root) / ".snapshots"
    try:
        record, restored_digest = rollback_patch(db, task_id, patch_id, snapshots, owner_id=user.id)
        return {
            "patch_id": str(record.id),
            "status": record.status,
            "restored_snapshot_digest": restored_digest,
        }
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


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
