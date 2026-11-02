import hashlib
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.models import PatchProposal, Project, Task, TaskStatus, User
from app.services.patch_service import (
    Change, PatchSafetyError, apply, proposal, reject_proposal, rollback_patch,
)
from app.services.workspace_snapshot import create_snapshot


def make_session():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    return Session(engine, expire_on_commit=False)


def test_patch_needs_checksum_and_applies_to_new_snapshot(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    (source / "app.txt").write_bytes(b"before\n")
    snapshots = tmp_path / "snapshots"
    base, _, digest = create_snapshot(source, snapshots)
    checksum = hashlib.sha256(b"before\n").hexdigest()
    _, diff, changes = proposal(base, [Change("app.txt", "after\n", checksum)])
    _, applied = apply(base, snapshots, changes)
    assert applied != digest
    assert "-before" in diff and "+after" in diff
    assert (snapshots / applied / "app.txt").read_bytes() == b"after\n"
    assert (snapshots / digest / "app.txt").read_bytes() == b"before\n"


def test_patch_rejects_stale_checksum(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    (source / "app.txt").write_text("before")
    base, _, _ = create_snapshot(source, tmp_path / "snapshots")
    with pytest.raises(PatchSafetyError, match="checksum"):
        proposal(base, [Change("app.txt", "after", "0" * 64)])


def test_patch_reject_and_rollback_lifecycle(tmp_path: Path):
    workspace = tmp_path / "proj"
    workspace.mkdir()
    (workspace / "code.py").write_text("v1")
    snapshots = tmp_path / "snapshots"

    _, _, base_digest = create_snapshot(workspace, snapshots)

    with make_session() as db:
        user = User(id=uuid4(), email="owner@example.com", password_hash="pass")
        db.add(user)
        db.flush()
        project = Project(
            id="p1", name="Proj", workspace_path=str(workspace), owner_id=user.id
        )
        task = Task(id=uuid4(), project_id="p1", instruction="test", status=TaskStatus.planning)
        db.add_all([project, task])
        db.commit()

        # Proposal 1: Rejected
        c1 = hashlib.sha256(b"v1").hexdigest()
        digest1, diff1, changes1 = proposal(snapshots / base_digest, [Change("code.py", "v2-bad", c1)])
        prop1 = PatchProposal(
            id=uuid4(),
            task_id=task.id,
            base_snapshot_digest=base_digest,
            patch_digest=digest1,
            changes=changes1,
            unified_diff=diff1,
        )
        db.add(prop1)
        db.commit()

        rejected = reject_proposal(db, task.id, prop1.id, note="Security vulnerability detected")
        assert rejected.status == "rejected"
        assert rejected.approval_note == "Security vulnerability detected"

        # Proposal 2: Approved, applied, then rolled back
        digest2, diff2, changes2 = proposal(snapshots / base_digest, [Change("code.py", "v2-good", c1)])
        _, applied_digest = apply(snapshots / base_digest, snapshots, changes2)

        # Update actual project workspace to match applied state
        (workspace / "code.py").write_text("v2-good")

        prop2 = PatchProposal(
            id=uuid4(),
            task_id=task.id,
            base_snapshot_digest=base_digest,
            patch_digest=digest2,
            changes=changes2,
            unified_diff=diff2,
            status="applied",
            applied_snapshot_digest=applied_digest,
        )
        db.add(prop2)
        db.commit()

        # Verify rollback
        rolled_back_prop, restored = rollback_patch(db, task.id, prop2.id, snapshots, owner_id=user.id)
        assert rolled_back_prop.status == "rolled_back"
        assert restored == base_digest
        assert (workspace / "code.py").read_text() == "v1"
