import io
import stat
import zipfile
from pathlib import Path

import pytest

from app.services.project_ingestion import ProjectArchiveError, ingest_zip


def make_zip(entries: list[tuple[str, bytes]]) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        for name, content in entries:
            archive.writestr(name, content)
    return buffer.getvalue()


def test_import_detects_flutter_project(tmp_path: Path):
    result = ingest_zip(make_zip([
        ("pubspec.yaml", b"name: demo"),
        ("lib/main.dart", b"void main() {}"),
    ]), tmp_path)
    assert result["file_count"] == 2
    assert result["languages"][0]["key"] == "flutter"
    assert (tmp_path / result["project_id"] / "pubspec.yaml").read_bytes() == b"name: demo"


@pytest.mark.parametrize("name", [
    "../escape.txt", "/absolute.txt", "C:/windows.txt", "folder/../../escape.txt",
    r"..\\escape.txt", r"\\server\\share\\file.txt", "file.txt:stream",
    "CON.txt", "folder/NUL", "trailing. ", "folder/..",
])
def test_rejects_unsafe_paths(tmp_path: Path, name: str):
    with pytest.raises(ProjectArchiveError):
        ingest_zip(make_zip([(name, b"bad")]), tmp_path)
    assert not (tmp_path.parent / "escape.txt").exists()


def test_rejects_duplicate_paths(tmp_path: Path):
    with pytest.raises(ProjectArchiveError, match="duplicate"):
        ingest_zip(make_zip([("src/main.py", b"one"), ("src/main.py", b"two")]), tmp_path)


def test_rejects_case_colliding_paths(tmp_path: Path):
    with pytest.raises(ProjectArchiveError, match="duplicate"):
        ingest_zip(make_zip([("Readme.md", b"one"), ("README.md", b"two")]), tmp_path)


def test_rejects_file_directory_collision(tmp_path: Path):
    with pytest.raises(ProjectArchiveError, match="collision"):
        ingest_zip(make_zip([("src", b"file"), ("src/main.py", b"code")]), tmp_path)


def test_rejects_symlink_entry(tmp_path: Path):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        info = zipfile.ZipInfo("link")
        info.create_system = 3
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        archive.writestr(info, "target")
    with pytest.raises(ProjectArchiveError, match="Symbolic"):
        ingest_zip(buffer.getvalue(), tmp_path)


def test_rejects_invalid_zip(tmp_path: Path):
    with pytest.raises(ProjectArchiveError):
        ingest_zip(b"not a zip", tmp_path)


def test_failed_import_leaves_no_project_directory(tmp_path: Path):
    with pytest.raises(ProjectArchiveError):
        ingest_zip(make_zip([("../escape", b"bad")]), tmp_path)
    assert list(tmp_path.iterdir()) == []
