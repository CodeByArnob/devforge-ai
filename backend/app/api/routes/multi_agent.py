from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser
from app.db.session import get_db
from app.schemas.ai import AgentRunRequest, AgentTeamPlan
from app.schemas.task import TaskRead
from app.services.multi_agent_runtime import MultiAgentRuntime
from app.services.openrouter_gateway import OpenRouterError

router = APIRouter(prefix="/tasks", tags=["multi-agent"])


@router.post(
    "/{task_id}/agent/team-plan",
    response_model=AgentTeamPlan,
    summary="Run five independent specialist reviews in parallel",
)
async def create_team_plan(
    task_id: UUID,
    payload: AgentRunRequest,
    user: CurrentUser,
    x_openrouter_api_key: str = Header(
        ..., alias="X-OpenRouter-Api-Key", min_length=10, max_length=512
    ),
    db: Session = Depends(get_db),
) -> AgentTeamPlan:
    try:
        _, plan = await MultiAgentRuntime(db).create_team_plan(
            task_id, x_openrouter_api_key, payload.model, owner_id=user.id
        )
        return plan
    except LookupError as exc:
        raise HTTPException(status_code=404, detail="Task not found") from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except OpenRouterError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
