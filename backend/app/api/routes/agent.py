from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser
from app.db.session import get_db
from app.schemas.ai import AgentRunRequest, AgentTeamPlan
from app.schemas.task import TaskRead
from app.services.agent_runtime import AgentRuntime
from app.services.multi_agent_orchestrator import DEFAULT_PLANNING_ROLES
from app.services.openrouter_gateway import OpenRouterError
from app.services.tool_registry import ToolRegistry

router = APIRouter(prefix="/tasks", tags=["agent"])


class AgentTeamRunResponse(BaseModel):
    task: TaskRead
    team_plan: AgentTeamPlan


@router.post(
    "/{task_id}/agent/run",
    response_model=AgentTeamRunResponse,
    summary="Run the multi-agent planning team",
)
async def run_agent(
    task_id: UUID,
    payload: AgentRunRequest,
    user: CurrentUser,
    x_openrouter_api_key: str = Header(
        ..., alias="X-OpenRouter-Api-Key", min_length=10, max_length=512
    ),
    db: Session = Depends(get_db),
) -> AgentTeamRunResponse:
    try:
        task, team_plan = await AgentRuntime(db).create_plan(
            task_id,
            x_openrouter_api_key,
            payload.model,
            owner_id=user.id,
            roles=payload.roles or DEFAULT_PLANNING_ROLES,
        )
        return AgentTeamRunResponse(task=task, team_plan=team_plan)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail="Task not found") from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except OpenRouterError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.get("/tools/registry", summary="List allowlisted tool registry and permissions")
def get_tool_registry():
    tools = ToolRegistry.list_all_tools()
    return [
        {
            "name": t.name,
            "description": t.description,
            "parameters": t.parameters,
            "allowed_roles": sorted(list(t.allowed_roles)),
            "execution_plane": t.execution_plane,
            "requires_human_approval": t.requires_human_approval,
        }
        for t in tools
    ]
