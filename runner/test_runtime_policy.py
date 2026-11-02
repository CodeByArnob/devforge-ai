from pathlib import Path

import pytest

from runtime_policy import SandboxLimits, podman_args


def test_policy_is_default_deny(tmp_path: Path):
    args = podman_args("registry.local/python@sha256:" + "a" * 64, tmp_path, ("python", "-m", "pytest"), SandboxLimits())
    assert "--network=none" in args
    assert "--read-only" in args
    assert "--cap-drop=ALL" in args
    assert "--security-opt=no-new-privileges" in args
    assert "--user=65532:65532" in args


def test_unpinned_image_is_rejected(tmp_path: Path):
    with pytest.raises(ValueError, match="pinned"):
        podman_args("python:3.12", tmp_path, ("true",), SandboxLimits())

