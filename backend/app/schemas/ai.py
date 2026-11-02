from typing import Literal

from pydantic import BaseModel, Field

AgentRole = Literal[
    "architect",
    "planner",
    "coder",
    "security_reviewer",
    "qa_engineer",
    "build_engineer",
    "repair_engineer",
    "integration_engineer",
]


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
    roles: list[AgentRole] | None = Field(default=None, max_length=8)


class AgentPlan(BaseModel):
    summary: str
    assumptions: list[str] = Field(default_factory=list, max_length=20)
    steps: list[str] = Field(min_length=1, max_length=20)
    risks: list[str] = Field(default_factory=list, max_length=20)
    needs_project_files: bool = True


class AgentRoleResult(BaseModel):
    role: AgentRole
    summary: str = Field(min_length=1, max_length=2000)
    findings: list[str] = Field(default_factory=list, max_length=12)
    proposed_steps: list[str] = Field(default_factory=list, max_length=12)
    risks: list[str] = Field(default_factory=list, max_length=12)
    requires_human_approval: bool = True
    permitted_tools: list[str] = Field(default_factory=list)
    role_payload: dict = Field(default_factory=dict)


class AgentTeamPlan(BaseModel):
    summary: str
    model: str
    agents: list[AgentRoleResult] = Field(min_length=1, max_length=16)
    assumptions: list[str] = Field(default_factory=list, max_length=20)
    steps: list[str] = Field(min_length=1, max_length=20)
    risks: list[str] = Field(default_factory=list, max_length=30)
    approval_required: bool = True
    execution_enabled: bool = False
