"""Build non-negotiable rootless container arguments and policies for untrusted jobs."""
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path


class NetworkPolicy(str, Enum):
    NONE = "none"
    PACKAGE_PROXY = "package_proxy"


@dataclass(frozen=True)
class SandboxLimits:
    cpu: float = 1.0
    memory_mb: int = 1024
    pids: int = 128
    timeout_seconds: int = 900
    tmpfs_mb: int = 512
    max_output_bytes: int = 2 * 1024 * 1024
    network_policy: NetworkPolicy = NetworkPolicy.NONE
    env_vars: dict[str, str] = field(default_factory=dict)


DANGEROUS_HOST_PATHS = {
    "/var/run/docker.sock",
    "/run/podman/podman.sock",
    "/root",
    "/etc/shadow",
    "/etc/sudoers",
    "C:\\ProgramData\\docker\\run\\docker.sock",
}

SAFE_ENV_ALLOWLIST = {
    "CI",
    "LANG",
    "LC_ALL",
    "PATH",
    "HOME",
    "TMPDIR",
    "PUB_CACHE",
    "GRADLE_USER_HOME",
    "MAVEN_CONFIG",
    "PIP_NO_CACHE_DIR",
}


def sanitize_env(env: dict[str, str]) -> dict[str, str]:
    """Allowlist explicit safe environment variables, stripping secrets and host paths."""
    sanitized: dict[str, str] = {}
    for key, value in env.items():
        if key.upper() in SAFE_ENV_ALLOWLIST and not any(secret in key.upper() for secret in ("KEY", "SECRET", "TOKEN", "AUTH", "PASS")):
            sanitized[key] = value
    return sanitized


def validate_image_digest(image: str) -> None:
    if "@sha256:" not in image:
        raise ValueError("Runner images must be pinned by immutable digest.")
    _, digest = image.split("@sha256:", 1)
    if len(digest) != 64 or not all(c in "0123456789abcdefABCDEF" for c in digest):
        raise ValueError("Runner image digest must be a valid 64-character SHA-256 hex string.")


def podman_args(
    image: str,
    workspace: Path,
    command: tuple[str, ...],
    limits: SandboxLimits,
    extra_mounts: tuple[tuple[Path, str, str], ...] = (),
) -> list[str]:
    """Return a command that has no ambient host privilege or unauthorized network access."""
    validate_image_digest(image)

    resolved = workspace.resolve(strict=True)
    if not resolved.is_dir():
        raise ValueError("Workspace must be an existing directory.")

    if not command or any(not part or "\x00" in part for part in command):
        raise ValueError("A non-empty argv command is required.")

    # Check for forbidden host mounts or socket exposure
    for src, dst, _ in extra_mounts:
        src_str = str(src.resolve() if src.exists() else src)
        for dangerous in DANGEROUS_HOST_PATHS:
            if dangerous in src_str or dangerous in dst:
                raise ValueError(f"Mounting dangerous host resource '{dangerous}' is strictly prohibited.")

    network_flag = "--network=none"
    if limits.network_policy == NetworkPolicy.PACKAGE_PROXY:
        # Isolated container proxy network, no ambient host network access
        network_flag = "--network=slirp4netns:allow_host_loopback=false"

    base_args = [
        "podman",
        "run",
        "--rm",
        "--pull=never",
        network_flag,
        "--read-only",
        "--cap-drop=ALL",
        "--security-opt=no-new-privileges",
        "--security-opt=seccomp=default",
        "--user=65532:65532",
        "--pids-limit",
        str(limits.pids),
        "--cpus",
        str(limits.cpu),
        "--memory",
        f"{limits.memory_mb}m",
        "--tmpfs",
        f"/tmp:rw,nosuid,nodev,size={limits.tmpfs_mb}m",
        "--workdir",
        "/workspace",
        "--mount",
        f"type=bind,src={resolved},dst=/workspace,rw,nosuid,nodev",
    ]

    for src, dst, mode in extra_mounts:
        resolved_src = src.resolve(strict=True)
        mount_mode = "ro,nosuid,nodev" if "ro" in mode else "rw,nosuid,nodev"
        base_args.extend(["--mount", f"type=bind,src={resolved_src},dst={dst},{mount_mode}"])

    # Safe sanitized environment
    safe_env = sanitize_env(limits.env_vars)
    for k, v in sorted(safe_env.items()):
        base_args.extend(["--env", f"{k}={v}"])

    base_args.append(image)
    base_args.extend(command)
    return base_args
