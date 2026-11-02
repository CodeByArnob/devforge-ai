import hashlib
from pathlib import Path

import pytest

from app.services.patch_service import Change, PatchSafetyError, apply, proposal
from app.services.workspace_snapshot import create_snapshot


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

