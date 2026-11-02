"""Dedicated runner daemon for isolated worker execution."""
import asyncio
import logging
from dataclasses import dataclass
from pathlib import Path

import httpx

from runner.execution_driver import BaseExecutionDriver, ExecutionResult, PodmanExecutionDriver
from runner.runtime_policy import SandboxLimits

logger = logging.getLogger(__name__)


@dataclass
class RunnerConfig:
    backend_url: str = "http://localhost:8000"
    worker_token: str = ""
    worker_id: str = "devforge-runner-1"
    poll_interval_seconds: float = 2.0
    heartbeat_interval_seconds: float = 10.0
    limits: SandboxLimits = SandboxLimits()


class RunnerService:
    """Consumes claimed jobs from the control plane and executes them in isolated sandboxes."""

    def __init__(
        self,
        config: RunnerConfig,
        driver: BaseExecutionDriver | None = None,
        client: httpx.AsyncClient | None = None,
    ):
        self.config = config
        self.driver = driver or PodmanExecutionDriver()
        self.client = client
        self._running = False

    def _headers(self) -> dict[str, str]:
        return {
            "X-DevForge-Worker-Token": self.config.worker_token,
            "Content-Type": "application/json",
        }

    async def claim_job(self, client: httpx.AsyncClient) -> dict | None:
        try:
            response = await client.post(
                f"{self.config.backend_url}/internal/worker/claim",
                headers=self._headers(),
                json={"worker_id": self.config.worker_id},
                timeout=10.0,
            )
            if response.status_code == 200:
                return response.json()
            return None
        except httpx.HTTPError as exc:
            logger.warning("Failed to claim job from control plane: %s", exc)
            return None

    async def get_job_details(self, client: httpx.AsyncClient, job_id: str) -> dict | None:
        try:
            response = await client.get(
                f"{self.config.backend_url}/internal/worker/{job_id}/details",
                headers=self._headers(),
                timeout=10.0,
            )
            if response.status_code == 200:
                return response.json()
            return None
        except httpx.HTTPError as exc:
            logger.warning("Failed to get job details: %s", exc)
            return None

    async def send_heartbeat(self, client: httpx.AsyncClient, job_id: str, lease_token: str) -> dict | None:
        try:
            response = await client.post(
                f"{self.config.backend_url}/internal/worker/{job_id}/heartbeat",
                headers=self._headers(),
                json={"lease_token": lease_token},
                timeout=10.0,
            )
            if response.status_code == 200:
                return response.json()
            return None
        except httpx.HTTPError as exc:
            logger.warning("Heartbeat failed for job %s: %s", job_id, exc)
            return None

    async def report_completion(
        self, client: httpx.AsyncClient, job_id: str, lease_token: str, result: dict
    ) -> bool:
        try:
            response = await client.post(
                f"{self.config.backend_url}/internal/worker/{job_id}/complete",
                headers=self._headers(),
                json={"lease_token": lease_token, "result": result},
                timeout=10.0,
            )
            return response.status_code == 200
        except httpx.HTTPError as exc:
            logger.error("Failed to report completion for job %s: %s", job_id, exc)
            return False

    async def report_failure(
        self, client: httpx.AsyncClient, job_id: str, lease_token: str, error: str
    ) -> bool:
        try:
            response = await client.post(
                f"{self.config.backend_url}/internal/worker/{job_id}/fail",
                headers=self._headers(),
                json={"lease_token": lease_token, "error": error[:2000]},
                timeout=10.0,
            )
            return response.status_code == 200
        except httpx.HTTPError as exc:
            logger.error("Failed to report failure for job %s: %s", job_id, exc)
            return False

    async def report_cancellation(
        self, client: httpx.AsyncClient, job_id: str, lease_token: str
    ) -> bool:
        try:
            response = await client.post(
                f"{self.config.backend_url}/internal/worker/{job_id}/cancelled",
                headers=self._headers(),
                json={"lease_token": lease_token},
                timeout=10.0,
            )
            return response.status_code == 200
        except httpx.HTTPError as exc:
            logger.error("Failed to report cancellation for job %s: %s", job_id, exc)
            return False

    async def execute_job(
        self,
        client: httpx.AsyncClient,
        claim: dict,
        image: str,
        workspace: Path,
        command: tuple[str, ...],
    ) -> ExecutionResult:
        job_id = str(claim["job_id"])
        lease_token = claim["lease_token"]

        cancel_event = asyncio.Event()

        async def heartbeat_loop():
            while not cancel_event.is_set():
                await asyncio.sleep(self.config.heartbeat_interval_seconds)
                if cancel_event.is_set():
                    break
                hb = await self.send_heartbeat(client, job_id, lease_token)
                if hb and hb.get("cancellation_requested"):
                    cancel_event.set()
                    break

        heartbeat_task = asyncio.create_task(heartbeat_loop())
        try:
            exec_task = asyncio.create_task(
                self.driver.execute(image, workspace, command, self.config.limits)
            )

            # Wait for either completion or cancellation
            done, _ = await asyncio.wait(
                [exec_task, asyncio.create_task(cancel_event.wait())],
                return_when=asyncio.FIRST_COMPLETED,
            )

            if cancel_event.is_set() and not exec_task.done():
                exec_task.cancel()
                await self.report_cancellation(client, job_id, lease_token)
                return ExecutionResult(
                    exit_code=-2,
                    stdout="",
                    stderr="Execution cancelled by user request.",
                    duration_ms=0.0,
                    timed_out=False,
                )

            res = await exec_task
            result_payload = {
                "exit_code": res.exit_code,
                "stdout": res.stdout,
                "stderr": res.stderr,
                "duration_ms": res.duration_ms,
                "timed_out": res.timed_out,
                "succeeded": res.succeeded,
            }
            if res.succeeded:
                await self.report_completion(client, job_id, lease_token, result_payload)
            else:
                await self.report_failure(
                    client,
                    job_id,
                    lease_token,
                    f"Execution failed with exit code {res.exit_code}: {res.stderr[:500]}",
                )
            return res
        except Exception as exc:
            await self.report_failure(client, job_id, lease_token, f"Runner internal error: {exc}")
            raise
        finally:
            cancel_event.set()
            heartbeat_task.cancel()
