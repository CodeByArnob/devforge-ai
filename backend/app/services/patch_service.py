"""Bounded structured changes, review diff, copy-on-write application, and rollback."""
import difflib
import hashlib
import os
import shutil
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import PatchProposal, Project, Task
from app.services.workspace_snapshot import (
    WorkspaceSafetyError, create_snapshot, read_file, rollback_snapshot, validate_path_safety,
)

MAX_CHANGES = 100
MAX_PATCH_BYTES = 2 * 1024 * 1024


class PatchSafetyError(ValueError):
    pass


@dataclass(frozen=True)
class Change:
    path: str
    content: str | None
    expected_sha256: str | None


def _hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def proposal(base: Path, changes: list[Change]) -> tuple[str, str, list[dict]]:
    if not 1 <= len(changes) <= MAX_CHANGES:
        raise PatchSafetyError("A proposal must contain between 1 and 100 changes.")
    diff_parts: list[str] = []
    normalized: list[dict] = []
    total = 0
    seen: set[str] = set()

    for change in changes:
        safe_path = validate_path_safety(change.path)
        if safe_path in seen:
            raise PatchSafetyError("A path may appear only once in a proposal.")
        seen.add(safe_path)

        try:
            before = read_file(base, safe_path)
            file_exists = True
        except WorkspaceSafetyError:
            before = b""
            file_exists = False

        if change.expected_sha256 is not None:
            if not file_exists:
                raise PatchSafetyError("File checksum precondition failed: expected file does not exist.")
            if _hash(before) != change.expected_sha256:
                raise PatchSafetyError("File checksum precondition failed: content has changed.")
        elif file_exists and change.content is not None and before == change.content.encode():
            continue  # No-op change

        after = b"" if change.content is None else change.content.encode()
        total += len(before) + len(after)
        if total > MAX_PATCH_BYTES:
            raise PatchSafetyError("Patch exceeds the 2 MB content limit.")

        diff_parts.extend(difflib.unified_diff(
            before.decode("utf-8", "replace").splitlines(keepends=True),
            after.decode("utf-8", "replace").splitlines(keepends=True),
            fromfile=f"a/{safe_path}", tofile=f"b/{safe_path}", lineterm="",
        ))
        normalized.append({
            "path": safe_path,
            "content": change.content,
            "expected_sha256": change.expected_sha256,
        })

    diff = "\n".join(diff_parts)
    digest = _hash(repr(normalized).encode())
    return digest, diff, normalized


def apply(base: Path, snapshots_root: Path, changes: list[dict]) -> tuple[Path, str]:
    """Apply only a previously reviewed structure into a private temporary copy."""
    staging = Path(tempfile.mkdtemp(prefix=".patch-", dir=snapshots_root.parent))
    try:
        shutil.copytree(base, staging, dirs_exist_ok=True, symlinks=False)
        for raw in changes:
            change = Change(**raw)
            safe_path = validate_path_safety(change.path)
            target = staging / safe_path
            resolved_parent = target.parent.resolve()
            if not resolved_parent.is_relative_to(staging.resolve()):
                raise PatchSafetyError("Patch target escapes workspace boundary.")

            if change.content is None:
                if target.exists():
                    os.chmod(target, 0o600)
                    target.unlink()
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.exists():
                    os.chmod(target, 0o600)
                target.write_text(change.content, encoding="utf-8", newline="")

        snapshot, _, digest = create_snapshot(staging, snapshots_root)
        return snapshot, digest
    finally:
        shutil.rmtree(staging, ignore_errors=True)


def reject_proposal(
    db: Session, task_id: UUID, patch_id: UUID, note: str | None = None
) -> PatchProposal:
    from app.services.task_service import TaskService

    record = db.scalar(
        select(PatchProposal)
        .where(PatchProposal.id == patch_id, PatchProposal.task_id == task_id)
        .with_for_update()
    )
    if record is None:
        raise LookupError("Patch proposal not found.")
    if record.status != "proposed":
        raise ValueError(f"Cannot reject patch proposal in status '{record.status}'.")

    record.status = "rejected"
    record.approval_note = note
    TaskService(db)._append_event(
        task_id,
        "patch.rejected",
        "Owner rejected the proposed code patch.",
        {"patch_id": str(record.id), "note": note},
    )
    db.commit()
    db.refresh(record)
    return record


def rollback_patch(
    db: Session,
    task_id: UUID,
    patch_id: UUID,
    snapshots_root: Path,
    owner_id: UUID | None = None,
) -> tuple[PatchProposal, str]:
    from app.services.task_service import TaskService

    record = db.scalar(
        select(PatchProposal)
        .where(PatchProposal.id == patch_id, PatchProposal.task_id == task_id)
        .with_for_update()
    )
    if record is None:
        raise LookupError("Patch proposal not found.")
    if record.status != "applied":
        raise ValueError("Only successfully applied patches can be rolled back.")

    task = db.scalar(select(Task).where(Task.id == task_id))
    if task is None:
        raise LookupError("Task not found.")

    project_stmt = select(Project).where(Project.id == task.project_id)
    if owner_id is not None:
        project_stmt = project_stmt.where(Project.owner_id == owner_id)
    project = db.scalar(project_stmt)
    if project is None:
        raise LookupError("Project not found.")

    # Roll back workspace to base snapshot
    rollback_snapshot(Path(project.workspace_path), record.base_snapshot_digest, snapshots_root)

    record.status = "rolled_back"
    record.approval_note = f"Rolled back at {datetime.now(timezone.utc).isoformat()}"

    TaskService(db)._append_event(
        task_id,
        "patch.rolled_back",
        "Owner rolled back applied patch; workspace restored to base snapshot.",
        {
            "patch_id": str(record.id),
            "restored_snapshot": record.base_snapshot_digest,
            "previous_snapshot": record.applied_snapshot_digest,
        },
    )
    db.commit()
    db.refresh(record)
    return record, record.base_snapshot_digest
