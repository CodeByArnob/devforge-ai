import io
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
MAX_COMPRESSION_RATIO = 200
MAX_PATH_DEPTH = 32
_WINDOWS_RESERVED = {
    "CON", "PRN", "AUX", "NUL",
    *(f"COM{i}" for i in range(1, 10)),
    *(f"LPT{i}" for i in range(1, 10)),
}


class ProjectArchiveError(ValueError):
    pass


def _safe_relative_path(name: str) -> Path:
    if not name or "\x00" in name or name.startswith(("/", "\\")):
        raise ProjectArchiveError("Archive contains an unsafe file path.")
    normalized = name.replace("\\", "/")
    pure = PurePosixPath(normalized.rstrip("/"))
    if pure.is_absolute() or not pure.parts or len(pure.parts) > MAX_PATH_DEPTH:
        raise ProjectArchiveError("Archive contains an unsafe file path.")
    for part in pure.parts:
        stem = part.split(".", 1)[0].upper()
        if (
            part in {"", ".", ".."}
            or ":" in part
            or part.endswith((" ", "."))
            or stem in _WINDOWS_RESERVED
        ):
            raise ProjectArchiveError("Archive contains an unsafe file path.")
    return Path(*pure.parts)

def _entry_kind(info: zipfile.ZipInfo) -> str:
    mode = info.external_attr >> 16
    file_type = stat.S_IFMT(mode)
    if stat.S_ISLNK(mode):
        raise ProjectArchiveError("Symbolic links are not accepted in project archives.")
    if file_type not in (0, stat.S_IFREG, stat.S_IFDIR):
        raise ProjectArchiveError("Special files are not accepted in project archives.")
    if info.is_dir() or file_type == stat.S_IFDIR:
        return "directory"
    return "file"


def ingest_zip(data: bytes, workspace_root: Path) -> dict:
    if not data or len(data) > MAX_ARCHIVE_BYTES:
        raise ProjectArchiveError("ZIP must be between 1 byte and 100 MB.")
    workspace_root.mkdir(parents=True, exist_ok=True)
    project_id = uuid.uuid4().hex
    staging = Path(tempfile.mkdtemp(prefix=f".{project_id}-", dir=workspace_root))
    destination = workspace_root / project_id
    try:
        try:
            archive = zipfile.ZipFile(io.BytesIO(data))
        except (zipfile.BadZipFile, OSError) as exc:
            raise ProjectArchiveError("Uploaded file is not a valid ZIP archive.") from exc
        with archive:
            infos = archive.infolist()
            if not infos or len(infos) > MAX_ENTRIES:
                raise ProjectArchiveError("Archive has an invalid number of entries.")
            total = 0
            manifests: list[str] = []
            seen: dict[str, str] = {}
            file_paths: set[str] = set()
            directory_paths: set[str] = set()
            for info in infos:
                relative = _safe_relative_path(info.filename)
                key = relative.as_posix().casefold()
                kind = _entry_kind(info)
                if key in seen:
                    raise ProjectArchiveError("Archive contains duplicate or case-colliding paths.")
                seen[key] = kind
                if kind == "directory":
                    directory_paths.add(key)
                else:
                    file_paths.add(key)
                    if info.flag_bits & 0x1:
                        raise ProjectArchiveError("Encrypted ZIP entries are not supported.")
                    if info.file_size > MAX_SINGLE_FILE_BYTES:
                        raise ProjectArchiveError("An archive file exceeds the 50 MB per-file limit.")
                    if info.file_size and info.compress_size == 0:
                        raise ProjectArchiveError("Archive contains an invalid compressed entry.")
                    if info.compress_size and info.file_size / info.compress_size > MAX_COMPRESSION_RATIO:
                        raise ProjectArchiveError("Archive entry exceeds the compression-ratio safety limit.")
                total += info.file_size
                if total > MAX_UNCOMPRESSED_BYTES:
                    raise ProjectArchiveError("Archive expands beyond the 500 MB safety limit.")

            for file_path in file_paths:
                parts = file_path.split("/")
                if any("/".join(parts[:i]) in file_paths for i in range(1, len(parts))):
                    raise ProjectArchiveError("Archive contains a file/directory path collision.")

            for info in infos:
                relative = _safe_relative_path(info.filename)
                kind = _entry_kind(info)
                target = staging / relative
                if kind == "directory":
                    target.mkdir(parents=True, exist_ok=True)
                    continue
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

        detected = detect_project(manifests)
        os.replace(staging, destination)
        return {
            "project_id": project_id,
            "workspace_path": str(destination),
            "file_count": len(manifests),
            "languages": [item.model_dump() if hasattr(item, "model_dump") else {
                "key": item.key, "display_name": item.display_name,
                "capabilities": list(item.capabilities),
            } for item in detected],
        }
    except ProjectArchiveError:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    except (zipfile.BadZipFile, RuntimeError, OSError) as exc:
        shutil.rmtree(staging, ignore_errors=True)
        raise ProjectArchiveError("Archive could not be safely extracted.") from exc
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
