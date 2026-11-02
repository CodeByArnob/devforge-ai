from collections.abc import Sequence
from uuid import UUID

import httpx
from sqlalchemy.orm import Session

from app.db.models import Task, TaskStatus
from app.schemas.ai import AgentRole, AgentTeamPlan
from app.services.multi_agent_orchestrator import DEFAULT_PLANNING_ROLES, MultiAgentOrchestrator
from app.services.openrouter_gateway import OpenRouterError
from app.services.task_service import TaskService


class AgentRuntime:
    """Coordinates specialist agents and pauses for explicit human approval."""

    def __init__(
        self,
        db: Session,
        transport: httpx.AsyncBaseTransport | None = None,
    ):
        self.db = db
        self.tasks = TaskService(db)
        self.orchestrator = MultiAgentOrchestrator(transport=transport)

    async def create_plan(
        self,
        task_id: UUID,
        api_key: str,
        model: str | None,
        owner_id: UUID | None = None,
        roles: Sequence[AgentRole | str] = DEFAULT_PLANNING_ROLES,
    ) -> tuple[Task, AgentTeamPlan]:
        task = self.tasks.get(task_id, owner_id=owner_id)
        if task is None:
            raise LookupError("Task not found")
        if task.status in {TaskStatus.completed, TaskStatus.failed, TaskStatus.cancelled}:
            raise ValueError("A terminal task cannot be run again.")
        selected_model = model or task.selected_model or "openrouter/free"
        self.orchestrator.validate_model(selected_model)

        selected_roles = list(roles) if roles else list(DEFAULT_PLANNING_ROLES)
        task.selected_model = selected_model
        task.status = TaskStatus.planning
        self.tasks._append_event(
            task.id,
            "agent.team.started",
            f"{len(selected_roles)} specialist agents are starting independent reviews.",
            {
                "model": selected_model,
                "agents": selected_roles,
            },
        )
        self.db.commit()

        try:
            team_plan = await self.orchestrator.run_team(
                api_key=api_key,
                model=selected_model,
                instruction=task.instruction,
                roles=selected_roles,
            )
        except (OpenRouterError, ValueError) as exc:
            task.status = TaskStatus.failed
            self.tasks._append_event(
                task.id,
                "agent.team.failed",
                "The specialist team could not produce a valid plan.",
                {"reason": type(exc).__name__},
            )
            self.db.commit()
            if isinstance(exc, OpenRouterError):
                raise
            raise OpenRouterError("Multi-agent planning failed.") from exc

        for agent in team_plan.agents:
            self.tasks._append_event(
                task.id,
                f"agent.{agent.role}.completed",
                f"{agent.role.replace('_', ' ').title()} completed its independent review.",
                agent.model_dump(),
            )

        task.status = TaskStatus.awaiting_approval
        self.tasks._append_event(
            task.id,
            "agent.team.plan_ready",
            f"{len(selected_roles)}-agent plan is ready. Human approval is required; no code was changed or executed.",
            {
                "team_plan": team_plan.model_dump(),
                "execution_enabled": False,
                "approval_required": True,
            },
        )
        self.db.commit()
        self.db.refresh(task)
        return task, team_plan
