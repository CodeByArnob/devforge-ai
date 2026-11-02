from typing import Literal

from pydantic import BaseModel, Field


class ChatMessage(BaseModel):
    role: Literal["system", "user", "assistant"]
    content: str = Field(min_length=1, max_length=32_000)


class ChatStreamRequest(BaseModel):
    model: str = Field(min_length=1, max_length=255)
    messages: list[ChatMessage] = Field(min_length=1, max_length=100)
    temperature: float = Field(default=0.2, ge=0, le=2)
    max_tokens: int = Field(default=2048, ge=1, le=8192)


class ModelInfo(BaseModel):
    id: str
    name: str
    context_length: int | None = None
    description: str | None = None
    pricing_prompt: str | None = None
    pricing_completion: str | None = None


class AgentRunRequest(BaseModel):
    model: str | None = Field(default=None, min_length=1, max_length=255)


class AgentPlan(BaseModel):
    summary: str
    assumptions: list[str] = Field(default_factory=list, max_length=20)
    steps: list[str] = Field(min_length=1, max_length=20)
    risks: list[str] = Field(default_factory=list, max_length=20)
    needs_project_files: bool = True


class AgentRoleResult(BaseModel):
    role: Literal["architect", "implementer", "security", "qa", "reviewer"]
    summary: str = Field(min_length=1, max_length=4000)
    findings: list[str] = Field(default_factory=list, max_length=20)
    blockers: list[str] = Field(default_factory=list, max_length=20)
    proposed_actions: list[str] = Field(default_factory=list, max_length=20)


class AgentTeamPlan(BaseModel):
    task_id: str
    model: str
    status: Literal["awaiting_human_approval"] = "awaiting_human_approval"
    execution_enabled: bool = False
    agents: list[AgentRoleResult] = Field(min_length=5, max_length=5)
    integration_summary: str = Field(min_length=1, max_length=6000)
    approval_required: bool = True
