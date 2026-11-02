import asyncio
from pathlib import Path
from uuid import uuid4

import httpx
import pytest

from runner.execution_driver import MockExecutionDriver
from runner.runner_service import RunnerConfig, RunnerService
from runner.runtime_policy import (
    NetworkPolicy, SandboxLimits, podman_args, sanitize_env,
)


def test_policy_is_default_deny(tmp_path: Path):
    args = podman_args(
        "registry.local/python@sha256:" + "a" * 64,
        tmp_path,
        ("python", "-m", "pytest"),
        SandboxLimits(),
    )
    assert "--network=none" in args
    assert "--read-only" in args
    assert "--cap-drop=ALL" in args
    assert "--security-opt=no-new-privileges" in args
    assert "--user=65532:65532" in args


def test_unpinned_image_is_rejected(tmp_path: Path):
    with pytest.raises(ValueError, match="pinned"):
        podman_args("python:3.12", tmp_path, ("true",), SandboxLimits())


def test_malformed_image_digest_is_rejected(tmp_path: Path):
    with pytest.raises(ValueError, match="valid 64-character SHA-256"):
        podman_args("python@sha256:not-a-valid-sha", tmp_path, ("true",), SandboxLimits())


def test_dangerous_socket_mount_is_rejected(tmp_path: Path):
    with pytest.raises(ValueError, match="dangerous host resource"):
        podman_args(
            "registry.local/python@sha256:" + "a" * 64,
            tmp_path,
            ("true",),
            SandboxLimits(),
            extra_mounts=((Path("/var/run/docker.sock"), "/var/run/docker.sock", "ro"),),
        )


def test_env_sanitization_strips_secrets():
    env = {
        "CI": "true",
        "PATH": "/usr/bin:/bin",
        "AWS_SECRET_ACCESS_KEY": "supersecret",
        "OPENROUTER_API_KEY": "sk-or-v1-secret",
        "GITHUB_TOKEN": "ghp_123456",
        "DATABASE_PASSWORD": "dbpass",
    }
    sanitized = sanitize_env(env)
    assert "CI" in sanitized
    assert "PATH" in sanitized
    assert "AWS_SECRET_ACCESS_KEY" not in sanitized
    assert "OPENROUTER_API_KEY" not in sanitized
    assert "GITHUB_TOKEN" not in sanitized
    assert "DATABASE_PASSWORD" not in sanitized


def test_package_proxy_network_policy(tmp_path: Path):
    limits = SandboxLimits(network_policy=NetworkPolicy.PACKAGE_PROXY)
    args = podman_args(
        "registry.local/python@sha256:" + "a" * 64,
        tmp_path,
        ("true",),
        limits,
    )
    assert "--network=slirp4netns:allow_host_loopback=false" in args
    assert "--network=none" not in args


def test_mock_driver_and_runner_service_execution_flow(tmp_path: Path):
    job_id = uuid4()
    completed_payload = {}

    def handler(request: httpx.Request) -> httpx.Response:
        url = str(request.url)
        if "/internal/worker/claim" in url:
            return httpx.Response(200, json={
                "job_id": str(job_id),
                "task_id": str(uuid4()),
                "lease_token": "a" * 32,
                "lease_expires_at": "2026-11-02T22:00:00Z",
                "attempt": 1,
            })
        if f"/internal/worker/{job_id}/heartbeat" in url:
            return httpx.Response(200, json={
                "job_id": str(job_id),
                "lease_expires_at": "2026-11-02T22:05:00Z",
                "status": "leased",
                "cancellation_requested": False,
            })
        if f"/internal/worker/{job_id}/complete" in url:
            nonlocal completed_payload
            import json
            completed_payload = json.loads(request.content)
            return httpx.Response(200, json={"job_id": str(job_id), "status": "succeeded"})
        return httpx.Response(404)

    async def scenario():
        transport = httpx.MockTransport(handler)
        async with httpx.AsyncClient(transport=transport) as client:
            config = RunnerConfig(
                backend_url="http://testserver",
                worker_token="x" * 32,
                heartbeat_interval_seconds=0.1,
            )
            mock_driver = MockExecutionDriver()
            runner = RunnerService(config, driver=mock_driver)

            claim = await runner.claim_job(client)
            assert claim is not None
            assert claim["job_id"] == str(job_id)

            result = await runner.execute_job(
                client=client,
                claim=claim,
                image="registry.local/dart@sha256:" + "b" * 64,
                workspace=tmp_path,
                command=("dart", "test"),
            )
            assert result.succeeded
            assert completed_payload.get("result", {}).get("succeeded") is True
            assert len(mock_driver.recorded_calls) == 1

    asyncio.run(scenario())
