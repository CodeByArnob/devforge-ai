"""Execution drivers for containerized and test sandboxes."""
import asyncio
from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path

from runner.runtime_policy import SandboxLimits, podman_args


@dataclass(frozen=True)
class ExecutionResult:
    exit_code: int
    stdout: str
    stderr: str
    duration_ms: float
    timed_out: bool = False
    truncated: bool = False

    @property
    def succeeded(self) -> bool:
        return self.exit_code == 0 and not self.timed_out


class BaseExecutionDriver(ABC):
    @abstractmethod
    async def execute(
        self,
        image: str,
        workspace: Path,
        command: tuple[str, ...],
        limits: SandboxLimits,
    ) -> ExecutionResult:
        """Execute command in isolated sandbox."""


class PodmanExecutionDriver(BaseExecutionDriver):
    """Executes workloads inside rootless Podman with strict isolation."""

    async def execute(
        self,
        image: str,
        workspace: Path,
        command: tuple[str, ...],
        limits: SandboxLimits,
    ) -> ExecutionResult:
        args = podman_args(image, workspace, command, limits)
        start_time = asyncio.get_event_loop().time()
        timed_out = False
        truncated = False

        process = await asyncio.create_subprocess_exec(
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        try:
            stdout_data, stderr_data = await asyncio.wait_for(
                process.communicate(), timeout=float(limits.timeout_seconds)
            )
        except asyncio.TimeoutError:
            timed_out = True
            try:
                process.kill()
                await process.wait()
            except ProcessLookupError:
                pass
            stdout_data, stderr_data = b"", b"Execution timed out."

        duration_ms = (asyncio.get_event_loop().time() - start_time) * 1000

        max_bytes = limits.max_output_bytes
        if len(stdout_data) > max_bytes:
            stdout_data = stdout_data[:max_bytes] + b"\n...[Output truncated]..."
            truncated = True
        if len(stderr_data) > max_bytes:
            stderr_data = stderr_data[:max_bytes] + b"\n...[Output truncated]..."
            truncated = True

        return ExecutionResult(
            exit_code=-1 if timed_out else (process.returncode or 0),
            stdout=stdout_data.decode("utf-8", "replace"),
            stderr=stderr_data.decode("utf-8", "replace"),
            duration_ms=duration_ms,
            timed_out=timed_out,
            truncated=truncated,
        )


class MockExecutionDriver(BaseExecutionDriver):
    """Test driver simulating sandbox execution with policy validation."""

    def __init__(self, handler=None):
        self.handler = handler
        self.recorded_calls: list[dict] = []

    async def execute(
        self,
        image: str,
        workspace: Path,
        command: tuple[str, ...],
        limits: SandboxLimits,
    ) -> ExecutionResult:
        # Validate that the podman arguments can be generated legally
        args = podman_args(image, workspace, command, limits)
        call_record = {
            "image": image,
            "workspace": workspace,
            "command": command,
            "limits": limits,
            "args": args,
        }
        self.recorded_calls.append(call_record)

        if self.handler:
            return await self.handler(call_record)

        return ExecutionResult(
            exit_code=0,
            stdout="Mock execution completed successfully.",
            stderr="",
            duration_ms=10.0,
            timed_out=False,
            truncated=False,
        )
