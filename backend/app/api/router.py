from fastapi import APIRouter, Depends

from app.api.routes.agent import router as agent_router
from app.api.routes.ai import router as ai_router
from app.api.routes.health import router as health_router
from app.api.routes.projects import router as projects_router
from app.api.routes.tasks import router as tasks_router
from app.core.auth import require_api_token
from app.core.config import get_settings

api_router = APIRouter()
api_router.include_router(health_router, tags=["system"])
protected = [Depends(require_api_token)]
api_router.include_router(ai_router, prefix=get_settings().api_v1_prefix, dependencies=protected)
api_router.include_router(tasks_router, prefix=get_settings().api_v1_prefix, tags=["tasks"], dependencies=protected)
api_router.include_router(agent_router, prefix=get_settings().api_v1_prefix, dependencies=protected)
api_router.include_router(projects_router, prefix=get_settings().api_v1_prefix, dependencies=protected)
