import io
import zipfile
from pathlib import Path

import pytest

from app.services.project_ingestion import ProjectArchiveError, ingest_zip


def make_zip(entries: dict[str, bytes]) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        for name, content in entries.items():
            archive.writestr(name, content)
    return buffer.getvalue()


def test_import_detects_flutter_project(tmp_path: Path):
    result = ingest_zip(make_zip({"pubspec.yaml": b"name: demo", "lib/main.dart": b"void main() {}"}), tmp_path)
    assert result["file_count"] == 2
    assert result["languages"][0]["key"] == "flutter"
    assert (tmp_path / result["project_id"] / "pubspec.yaml").read_bytes() == b"name: demo"


@pytest.mark.parametrize("name", ["../escape.txt", "/absolute.txt", "C:/windows.txt", "folder/../../escape.txt"])
def test_rejects_path_traversal(tmp_path: Path, name: str):
    with pytest.raises(ProjectArchiveError):
        ingest_zip(make_zip({name: b"bad"}), tmp_path)
    assert not (tmp_path.parent / "escape.txt").exists()


def test_rejects_invalid_zip(tmp_path: Path):
    with pytest.raises(ProjectArchiveError):
        ingest_zip(b"not a zip", tmp_path)
