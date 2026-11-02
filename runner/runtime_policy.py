"""Build non-negotiable rootless container arguments for untrusted jobs."""
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SandboxLimits:
    cpu: float = 1.0
    memory_mb: int = 1024
    pids: int = 128
    timeout_seconds: int = 900
    tmpfs_mb: int = 512


def podman_args(image: str, workspace: Path, command: tuple[str, ...], limits: SandboxLimits) -> list[str]:
    """Return a command that has no ambient host privilege or network access."""
    if "@sha256:" not in image:
        raise ValueError("Runner images must be pinned by immutable digest.")
    resolved = workspace.resolve(strict=True)
    if not resolved.is_dir():
        raise ValueError("Workspace must be an existing directory.")
    if not command or any(not part or "\x00" in part for part in command):
        raise ValueError("A non-empty argv command is required.")
    return [
        "podman", "run", "--rm", "--pull=never", "--network=none", "--read-only",
        "--cap-drop=ALL", "--security-opt=no-new-privileges", "--security-opt=seccomp=default",
        "--user=65532:65532", "--pids-limit", str(limits.pids), "--cpus", str(limits.cpu),
        "--memory", f"{limits.memory_mb}m", "--tmpfs", f"/tmp:rw,nosuid,nodev,size={limits.tmpfs_mb}m",
        "--workdir", "/workspace", "--mount", f"type=bind,src={resolved},dst=/workspace,rw,nosuid,nodev,noexec",
        image, *command,
    ]

