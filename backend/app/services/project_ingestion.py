import os
import shutil
import stat
import tempfile
import uuid
import zipfile
from pathlib import Path, PurePosixPath

from app.core.project_detection import detect_project

MAX_ARCHIVE_BYTES = 100 * 1024 * 1024
MAX_UNCOMPRESSED_BYTES = 500 * 1024 * 1024
MAX_ENTRIES = 10_000
MAX_SINGLE_FILE_BYTES = 50 * 1024 * 1024


class ProjectArchiveError(ValueError):
    pass


def _safe_relative_path(name: str) -> Path:
    normalized = name.replace("\\", "/")
    pure = PurePosixPath(normalized)
    if pure.is_absolute() or not pure.parts or any(part in {"", ".", ".."} for part in pure.parts):
        raise ProjectArchiveError("Archive contains an unsafe file path.")
    if pure.parts[0].endswith(":"):
        raise ProjectArchiveError("Archive contains a drive-qualified path.")
    return Path(*pure.parts)


def ingest_zip(data: bytes, workspace_root: Path) -> dict:
    if not data or len(data) > MAX_ARCHIVE_BYTES:
        raise ProjectArchiveError("ZIP must be between 1 byte and 100 MB.")
    workspace_root.mkdir(parents=True, exist_ok=True)
    project_id = uuid.uuid4().hex
    staging = Path(tempfile.mkdtemp(prefix=f".{project_id}-", dir=workspace_root))
    destination = workspace_root / project_id
    try:
        try:
            archive = zipfile.ZipFile(__import__("io").BytesIO(data))
        except zipfile.BadZipFile as exc:
            raise ProjectArchiveError("Uploaded file is not a valid ZIP archive.") from exc
        with archive:
            infos = archive.infolist()
            if not infos or len(infos) > MAX_ENTRIES:
                raise ProjectArchiveError("Archive has an invalid number of entries.")
            total = 0
            manifests: list[str] = []
            for info in infos:
                relative = _safe_relative_path(info.filename.rstrip("/"))
                mode = info.external_attr >> 16
                if stat.S_ISLNK(mode):
                    raise ProjectArchiveError("Symbolic links are not accepted in project archives.")
                if info.flag_bits & 0x1:
                    raise ProjectArchiveError("Encrypted ZIP entries are not supported.")
                if info.file_size > MAX_SINGLE_FILE_BYTES:
                    raise ProjectArchiveError("An archive file exceeds the 50 MB per-file limit.")
                total += info.file_size
                if total > MAX_UNCOMPRESSED_BYTES:
                    raise ProjectArchiveError("Archive expands beyond the 500 MB safety limit.")
                if info.is_dir():
                    (staging / relative).mkdir(parents=True, exist_ok=True)
                    continue
                target = staging / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                written = 0
                with archive.open(info) as source, target.open("xb") as output:
                    while chunk := source.read(1024 * 1024):
                        written += len(chunk)
                        if written > info.file_size or written > MAX_SINGLE_FILE_BYTES:
                            raise ProjectArchiveError("Archive entry exceeded its declared size.")
                        output.write(chunk)
                if written != info.file_size:
                    raise ProjectArchiveError("Archive entry size does not match its directory record.")
                manifests.append(relative.as_posix())
        os.replace(staging, destination)
        detected = detect_project(manifests)
        return {
            "project_id": project_id,
            "workspace_path": str(destination),
            "file_count": len(manifests),
            "languages": [item.model_dump() if hasattr(item, "model_dump") else {
                "key": item.key, "display_name": item.display_name,
                "capabilities": list(item.capabilities),
            } for item in detected],
        }
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
