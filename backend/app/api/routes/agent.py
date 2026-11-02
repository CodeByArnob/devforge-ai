from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser
from app.db.session import get_db
from app.schemas.ai import AgentRunRequest
from app.schemas.task import TaskRead
from app.services.agent_runtime import AgentRuntime
from app.services.openrouter_gateway import OpenRouterError

router = APIRouter(prefix="/tasks", tags=["agent"])


@router.post("/{task_id}/agent/run", response_model=TaskRead, summary="Generate an implementation plan")
async def run_agent(
    task_id: UUID,
    payload: AgentRunRequest,
    user: CurrentUser,
    x_openrouter_api_key: str = Header(..., alias="X-OpenRouter-Api-Key", min_length=10, max_length=512),
    db: Session = Depends(get_db),
) -> TaskRead:
    try:
        task, _ = await AgentRuntime(db).create_plan(
            task_id, x_openrouter_api_key, payload.model, owner_id=user.id
        )
        return task
    except LookupError as exc:
        raise HTTPException(status_code=404, detail="Task not found") from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except OpenRouterError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
