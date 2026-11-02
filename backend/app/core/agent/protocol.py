from dataclasses import dataclass
from typing import Protocol
from uuid import UUID


@dataclass(frozen=True, slots=True)
class AgentRequest:
    task_id: UUID
    project_id: str
    instruction: str


class AgentRuntime(Protocol):
    """Contract for a separately secured agent worker."""

    async def run(self, request: AgentRequest) -> None:
        """Run inside an isolated workspace and persist progress events."""
        ...
