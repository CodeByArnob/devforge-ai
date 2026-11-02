"""Immutable, bounded workspace inventory and copy-on-write snapshots."""
import hashlib
import os
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path


MAX_FILES = 10_000
MAX_FILE_BYTES = 50 * 1024 * 1024
MAX_TOTAL_BYTES = 500 * 1024 * 1024
DENIED_PARTS = {".git", ".ssh", ".aws", ".env"}


class WorkspaceSafetyError(ValueError):
    pass


@dataclass(frozen=True)
class FileEntry:
    path: str
    sha256: str
    size: int


def _relative(root: Path, path: str) -> Path:
    candidate = root / path
    try:
        resolved = candidate.resolve(strict=True)
        resolved.relative_to(root.resolve(strict=True))
    except (OSError, ValueError) as exc:
        raise WorkspaceSafetyError("Path escapes the workspace or does not exist.") from exc
    if resolved.is_symlink() or not resolved.is_file():
        raise WorkspaceSafetyError("Only regular workspace files are allowed.")
    if any(part in DENIED_PARTS for part in Path(path).parts):
        raise WorkspaceSafetyError("Requested path is not inspectable.")
    return resolved


def inventory(root: Path) -> tuple[FileEntry, ...]:
    root = root.resolve(strict=True)
    entries: list[FileEntry] = []
    total = 0
    for path in sorted(root.rglob("*")):
        if any(part in DENIED_PARTS for part in path.relative_to(root).parts):
            continue
        if path.is_symlink():
            raise WorkspaceSafetyError("Workspace contains a symbolic link.")
        if not path.is_file():
            continue
        size = path.stat().st_size
        if size > MAX_FILE_BYTES:
            raise WorkspaceSafetyError("Workspace file exceeds the size limit.")
        total += size
        if total > MAX_TOTAL_BYTES or len(entries) >= MAX_FILES:
            raise WorkspaceSafetyError("Workspace inventory exceeds configured limits.")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        entries.append(FileEntry(path.relative_to(root).as_posix(), digest, size))
    return tuple(entries)


def snapshot_digest(entries: tuple[FileEntry, ...]) -> str:
    wire = "".join(f"{e.path}\0{e.sha256}\0{e.size}\n" for e in entries).encode()
    return hashlib.sha256(wire).hexdigest()


def create_snapshot(source: Path, snapshots_root: Path) -> tuple[Path, tuple[FileEntry, ...], str]:
    entries = inventory(source)
    digest = snapshot_digest(entries)
    destination = snapshots_root / digest
    if destination.exists():
        return destination, entries, digest
    snapshots_root.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".snapshot-", dir=snapshots_root))
    try:
        for entry in entries:
            origin = _relative(source, entry.path)
            target = staging / entry.path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(origin, target, follow_symlinks=False)
            os.chmod(target, 0o444)
        os.replace(staging, destination)
        return destination, entries, digest
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise


def read_file(root: Path, path: str, max_bytes: int = 256 * 1024) -> bytes:
    if not 1 <= max_bytes <= MAX_FILE_BYTES:
        raise WorkspaceSafetyError("Requested file limit is invalid.")
    file_path = _relative(root, path)
    if file_path.stat().st_size > max_bytes:
        raise WorkspaceSafetyError("Requested file exceeds inspection limit.")
    return file_path.read_bytes()

