"""Bounded structured changes, review diff, and copy-on-write application."""
import difflib
import hashlib
import os
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from app.services.workspace_snapshot import WorkspaceSafetyError, create_snapshot, read_file

MAX_CHANGES = 100
MAX_PATCH_BYTES = 2 * 1024 * 1024


class PatchSafetyError(ValueError):
    pass


@dataclass(frozen=True)
class Change:
    path: str
    content: str | None
    expected_sha256: str | None


def _hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def proposal(base: Path, changes: list[Change]) -> tuple[str, str, list[dict]]:
    if not 1 <= len(changes) <= MAX_CHANGES:
        raise PatchSafetyError("A proposal must contain between 1 and 100 changes.")
    diff_parts: list[str] = []
    normalized: list[dict] = []
    total = 0
    seen: set[str] = set()
    for change in changes:
        if change.path in seen:
            raise PatchSafetyError("A path may appear only once in a proposal.")
        seen.add(change.path)
        try:
            before = read_file(base, change.path)
        except WorkspaceSafetyError:
            if change.expected_sha256 is not None:
                raise PatchSafetyError("Existing-file precondition does not resolve safely.")
            before = b""
        if change.expected_sha256 is not None and _hash(before) != change.expected_sha256:
            raise PatchSafetyError("File checksum precondition failed.")
        after = b"" if change.content is None else change.content.encode()
        total += len(before) + len(after)
        if total > MAX_PATCH_BYTES:
            raise PatchSafetyError("Patch exceeds the 2 MB content limit.")
        diff_parts.extend(difflib.unified_diff(
            before.decode("utf-8", "replace").splitlines(keepends=True),
            after.decode("utf-8", "replace").splitlines(keepends=True),
            fromfile=f"a/{change.path}", tofile=f"b/{change.path}", lineterm="",
        ))
        normalized.append({"path": change.path, "content": change.content, "expected_sha256": change.expected_sha256})
    diff = "\n".join(diff_parts)
    digest = _hash(repr(normalized).encode())
    return digest, diff, normalized


def apply(base: Path, snapshots_root: Path, changes: list[dict]) -> tuple[Path, str]:
    """Apply only a previously reviewed structure into a private temporary copy."""
    staging = Path(tempfile.mkdtemp(prefix=".patch-", dir=snapshots_root.parent))
    try:
        shutil.copytree(base, staging, dirs_exist_ok=True, symlinks=False)
        for raw in changes:
            change = Change(**raw)
            target = staging / change.path
            resolved_parent = target.parent.resolve()
            if not resolved_parent.is_relative_to(staging.resolve()):
                raise PatchSafetyError("Patch target escapes workspace.")
            if change.content is None:
                if target.exists():
                    os.chmod(target, 0o600)
                    target.unlink()
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.exists():
                    os.chmod(target, 0o600)
                target.write_text(change.content, encoding="utf-8", newline="")
        snapshot, _, digest = create_snapshot(staging, snapshots_root)
        return snapshot, digest
    finally:
        shutil.rmtree(staging, ignore_errors=True)

