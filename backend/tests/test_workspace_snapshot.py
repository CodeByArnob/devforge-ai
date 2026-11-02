from pathlib import Path

import pytest

from app.services.workspace_snapshot import (
    WorkspaceSafetyError, create_snapshot, inspect_workspace, read_file,
    read_file_safe, rollback_snapshot, validate_path_safety,
)


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


def test_path_safety_rejects_dangerous_patterns():
    with pytest.raises(WorkspaceSafetyError, match="prohibited"):
        validate_path_safety("../secret.txt")
    with pytest.raises(WorkspaceSafetyError, match="prohibited"):
        validate_path_safety("lib/../../secret.txt")
    with pytest.raises(WorkspaceSafetyError, match="forbidden"):
        validate_path_safety("CON.txt")
    with pytest.raises(WorkspaceSafetyError, match="forbidden"):
        validate_path_safety("aux")
    with pytest.raises(WorkspaceSafetyError, match="forbidden"):
        validate_path_safety(".git/config")
    with pytest.raises(WorkspaceSafetyError, match="forbidden"):
        validate_path_safety(".env")
    with pytest.raises(WorkspaceSafetyError, match="null bytes"):
        validate_path_safety("lib/file\x00.txt")
    with pytest.raises(WorkspaceSafetyError, match="Alternate Data Stream"):
        validate_path_safety("test.txt:hidden")


def test_inspect_workspace_and_safe_read(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    (source / "src").mkdir()
    (source / "src" / "index.ts").write_text("console.log('hello');\n")
    (source / "data.bin").write_bytes(b"\x00\x01\x02\x03")

    items = inspect_workspace(source)
    assert len(items) == 3
    paths = {item["path"] for item in items}
    assert "src" in paths
    assert "src/index.ts" in paths
    assert "data.bin" in paths

    text_info = read_file_safe(source, "src/index.ts")
    assert text_info["is_binary"] is False
    assert "console.log" in text_info["content"]
    assert text_info["line_count"] == 1

    bin_info = read_file_safe(source, "data.bin")
    assert bin_info["is_binary"] is True
    assert bin_info["content"] is None


def test_rollback_snapshot_restores_workspace(tmp_path: Path):
    source = tmp_path / "source"
    source.mkdir()
    (source / "main.py").write_text("initial version")
    snapshots = tmp_path / "snapshots"

    _, _, snap1_digest = create_snapshot(source, snapshots)

    # Modify workspace
    (source / "main.py").write_text("corrupted version")
    (source / "malicious.py").write_text("bad")

    # Roll back
    rollback_snapshot(source, snap1_digest, snapshots)

    assert (source / "main.py").read_text() == "initial version"
    assert not (source / "malicious.py").exists()
