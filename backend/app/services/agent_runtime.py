import json
from uuid import UUID

import httpx
from sqlalchemy.orm import Session

from app.db.models import Task, TaskStatus
from app.schemas.ai import AgentPlan
from app.services.openrouter_gateway import FREE_ROUTER_ID, OpenRouterError, OpenRouterGateway
from app.services.task_service import TaskService


class AgentRuntime:
    """Planning-stage agent. Tool execution is deliberately gated until sandbox workers exist."""

    def __init__(self, db: Session, gateway: OpenRouterGateway | None = None):
        self.db = db
        self.gateway = gateway or OpenRouterGateway()
        self.tasks = TaskService(db)

    async def create_plan(self, task_id: UUID, api_key: str, model: str | None) -> tuple[Task, AgentPlan]:
        task = self.tasks.get(task_id)
        if task is None:
            raise LookupError("Task not found")
        selected_model = model or task.selected_model or FREE_ROUTER_ID
        if not (selected_model == FREE_ROUTER_ID or selected_model.endswith(":free")):
            raise ValueError("Only explicitly free OpenRouter models are enabled in this agent milestone.")

        task.selected_model = selected_model
        task.status = TaskStatus.planning
        self.tasks._append_event(task.id, "agent.planning", "Agent is analyzing the request and preparing a plan.", {"model": selected_model})
        self.db.commit()

        prompt = (
            "You are DevForge AI, a careful senior software engineer. Create a safe implementation plan "
            "for the user's requested change. Do not claim to have inspected files or run commands. "
            "Return JSON only with keys: summary (string), assumptions (array of strings), "
            "steps (array of 1-20 concise strings), risks (array of strings), needs_project_files (boolean). "
            "If repository files are unavailable, explicitly say the plan is preliminary and list what must "
            "be inspected before edits. Never suggest exposing secrets or running untrusted code on the API host."
        )
        body = {
            "model": selected_model,
            "temperature": 0.2,
            "max_tokens": 1800,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": prompt},
                {"role": "user", "content": task.instruction},
            ],
        }
        try:
            async with httpx.AsyncClient(timeout=90.0) as client:
                response = await client.post(
                    "https://openrouter.ai/api/v1/chat/completions",
                    headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
                    json=body,
                )
                response.raise_for_status()
            content = response.json()["choices"][0]["message"]["content"]
            raw = json.loads(content)
            plan = AgentPlan.model_validate(raw)
        except (httpx.HTTPError, KeyError, IndexError, TypeError, json.JSONDecodeError, ValueError) as exc:
            task.status = TaskStatus.failed
            self.tasks._append_event(task.id, "agent.failed", "Agent could not generate a valid plan.", {"reason": str(exc)[:500]})
            self.db.commit()
            raise OpenRouterError("Agent planning failed. Check the API key, selected free model and provider response.") from exc

        task.status = TaskStatus.awaiting_approval
        self.tasks._append_event(
            task.id,
            "agent.plan_ready",
            "Preliminary plan generated. Human approval and project-file access are required before implementation.",
            {"plan": plan.model_dump(), "execution_enabled": False},
        )
        self.db.commit()
        self.db.refresh(task)
        return task, plan
