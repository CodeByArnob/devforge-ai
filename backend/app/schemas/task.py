from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class TaskStatus(str, Enum):
    queued = "queued"
    inspecting = "inspecting"
    planning = "planning"
    awaiting_approval = "awaiting_approval"
    editing = "editing"
    validating = "validating"
    repairing = "repairing"
    building = "building"
    completed = "completed"
    failed = "failed"
    cancelled = "cancelled"


class TaskCreate(BaseModel):
    project_id: str = Field(min_length=1, max_length=128)
    instruction: str = Field(min_length=1, max_length=20_000)
    selected_model: str | None = Field(default=None, max_length=255)


class TaskApprovalRequest(BaseModel):
    decision: str = Field(pattern="^(approved|rejected)$")
    note: str | None = Field(default=None, max_length=2000)


class TaskRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    project_id: str
    instruction: str
    status: TaskStatus
    selected_model: str | None
    approval_decision: str
    approval_note: str | None
    approval_at: datetime | None
    created_at: datetime
    updated_at: datetime


class TaskApprovalResponse(BaseModel):
    task: TaskRead
    execution_started: bool = False
    message: str


class TaskEventRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    sequence: int
    event_type: str
    message: str
    payload: dict
    created_at: datetime
