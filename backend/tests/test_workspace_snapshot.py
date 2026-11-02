from pathlib import Path

import pytest

from app.services.workspace_snapshot import WorkspaceSafetyError, create_snapshot, read_file


def test_snapshot_is_content_addressed_and_read_only(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    (source / "lib").mkdir()
    (source / "lib" / "a.py").write_bytes(b"print('ok')\n")
    snap, entries, digest = create_snapshot(source, tmp_path / "snapshots")
    assert snap.name == digest and entries[0].path == "lib/a.py"
    assert read_file(snap, "lib/a.py") == b"print('ok')\n"
    assert (snap / "lib" / "a.py").stat().st_mode & 0o222 == 0


def test_snapshot_rejects_escape_and_symlinks(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    (source / "a.txt").write_text("a")
    snap, _, _ = create_snapshot(source, tmp_path / "snapshots")
    with pytest.raises(WorkspaceSafetyError):
        read_file(snap, "../a.txt")

