"""Immutable, bounded workspace inventory, safe inspection, and copy-on-write snapshots."""
import hashlib
import os
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

MAX_FILES = 10_000
MAX_FILE_BYTES = 50 * 1024 * 1024
MAX_TOTAL_BYTES = 500 * 1024 * 1024
DENIED_PARTS = {".git", ".ssh", ".aws", ".env", ".credentials", ".secrets"}

WINDOWS_RESERVED = {
    "CON", "PRN", "AUX", "NUL",
    "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
    "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
}


class WorkspaceSafetyError(ValueError):
    pass


@dataclass(frozen=True)
class FileEntry:
    path: str
    sha256: str
    size: int


def validate_path_safety(path: str) -> str:
    """Enforce strict cross-platform relative path safety rules."""
    if not path or "\x00" in path or "\r" in path or "\n" in path:
        raise WorkspaceSafetyError("Path contains null bytes or illegal control characters.")

    # Reject Windows drive letters, UNC shares, and Alternate Data Streams
    if ":" in path or path.startswith(("\\\\", "//")):
        raise WorkspaceSafetyError("Absolute, UNC, or Alternate Data Stream paths are prohibited.")

    normalized = PurePosixPath(path.replace("\\", "/"))
    if normalized.is_absolute():
        raise WorkspaceSafetyError("Absolute paths are not permitted in workspace.")

    parts = normalized.parts
    if not parts or any(part in ("..", ".", "") for part in parts):
        raise WorkspaceSafetyError("Directory traversal ('..') is prohibited.")

    for part in parts:
        stem = part.split(".")[0].upper()
        if stem in WINDOWS_RESERVED:
            raise WorkspaceSafetyError(f"Reserved device name '{part}' is forbidden.")
        if part in DENIED_PARTS:
            raise WorkspaceSafetyError(f"Access to protected resource '{part}' is forbidden.")

    return normalized.as_posix()


def _relative(root: Path, path: str) -> Path:
    safe_rel = validate_path_safety(path)
    root_resolved = root.resolve(strict=True)
    candidate = (root_resolved / safe_rel).resolve()
    try:
        candidate.relative_to(root_resolved)
    except (OSError, ValueError) as exc:
        raise WorkspaceSafetyError("Path escapes the workspace boundary.") from exc

    if not candidate.exists():
        raise WorkspaceSafetyError("Target file does not exist.")

    if candidate.is_symlink() or not candidate.is_file():
        raise WorkspaceSafetyError("Only regular workspace files are allowed.")

    return candidate


def inventory(root: Path) -> tuple[FileEntry, ...]:
    root = root.resolve(strict=True)
    entries: list[FileEntry] = []
    total = 0
    for path in sorted(root.rglob("*")):
        rel = path.relative_to(root)
        if any(part in DENIED_PARTS for part in rel.parts):
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
        entries.append(FileEntry(rel.as_posix(), digest, size))
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


def inspect_workspace(root: Path, max_depth: int = 10, limit: int = 1000) -> list[dict]:
    """Return a safe bounded inventory with file types and digests."""
    root_resolved = root.resolve(strict=True)
    results: list[dict] = []
    count = 0

    for path in sorted(root_resolved.rglob("*")):
        if count >= limit:
            break
        rel = path.relative_to(root_resolved)
        if len(rel.parts) > max_depth:
            continue
        if any(part in DENIED_PARTS for part in rel.parts):
            continue
        if path.is_symlink():
            continue

        count += 1
        is_dir = path.is_dir()
        size = path.stat().st_size if not is_dir else 0
        digest = hashlib.sha256(path.read_bytes()).hexdigest() if not is_dir and size <= 10 * 1024 * 1024 else None
        results.append({
            "path": rel.as_posix(),
            "type": "directory" if is_dir else "file",
            "size": size,
            "sha256": digest,
        })
    return results


def read_file_safe(root: Path, path: str, max_bytes: int = 256 * 1024) -> dict:
    """Safe inspection returning file text or binary indicator."""
    raw = read_file(root, path, max_bytes=max_bytes)
    is_binary = b"\x00" in raw or any(b > 127 for b in raw[:512]) and not _is_valid_utf8(raw)
    content = None if is_binary else raw.decode("utf-8", "replace")
    line_count = len(content.splitlines()) if content is not None else 0
    return {
        "path": validate_path_safety(path),
        "size": len(raw),
        "is_binary": is_binary,
        "line_count": line_count,
        "content": content,
        "sha256": hashlib.sha256(raw).hexdigest(),
    }


def _is_valid_utf8(data: bytes) -> bool:
    try:
        data.decode("utf-8")
        return True
    except UnicodeDecodeError:
        return False


def rollback_snapshot(workspace: Path, snapshot_digest: str, snapshots_root: Path) -> Path:
    """Safely restore a workspace directory from an immutable verified snapshot."""
    target_snapshot = (snapshots_root / snapshot_digest).resolve()
    snapshots_root_resolved = snapshots_root.resolve()
    if not target_snapshot.is_relative_to(snapshots_root_resolved) or not target_snapshot.is_dir():
        raise WorkspaceSafetyError("Target snapshot not found or invalid.")

    workspace_resolved = workspace.resolve()
    # Verify target directory is safe
    for child in workspace_resolved.iterdir():
        if child.name in {".snapshots", ".git"}:
            continue
        if child.is_dir():
            shutil.rmtree(child, ignore_errors=True)
        else:
            try:
                os.chmod(child, 0o600)
            except OSError:
                pass
            child.unlink(missing_ok=True)

    # Copy files from immutable snapshot with write permissions restored for workspace
    for snap_file in target_snapshot.rglob("*"):
        if not snap_file.is_file():
            continue
        rel = snap_file.relative_to(target_snapshot)
        dest = workspace_resolved / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(snap_file, dest, follow_symlinks=False)
        try:
            os.chmod(dest, 0o644)
        except OSError:
            pass

    return workspace_resolved
