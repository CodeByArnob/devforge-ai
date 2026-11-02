from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class WorkerClaimRequest(BaseModel):
    worker_id: str = Field(min_length=1, max_length=128, pattern=r"^[a-zA-Z0-9._:-]+$")


class WorkerLeaseRead(BaseModel):
    job_id: UUID
    task_id: UUID
    lease_token: str
    lease_expires_at: datetime
    attempt: int


class WorkerHeartbeatRequest(BaseModel):
    lease_token: str = Field(min_length=32, max_length=128)


class WorkerHeartbeatRead(BaseModel):
    job_id: UUID
    lease_expires_at: datetime
    status: str
    cancellation_requested: bool = False


class WorkerFailureRequest(BaseModel):
    lease_token: str = Field(min_length=32, max_length=128)
    error: str = Field(min_length=1, max_length=2000)


class WorkerCompletionRequest(BaseModel):
    lease_token: str = Field(min_length=32, max_length=128)
    result: dict = Field(default_factory=dict)


class WorkerCancellationRequest(BaseModel):
    lease_token: str = Field(min_length=32, max_length=128)


class WorkerReleaseRead(BaseModel):
    job_id: UUID
    status: str
    retry_scheduled: bool


class WorkerCompletionRead(BaseModel):
    job_id: UUID
    status: str


class WorkerJobDetailsRead(BaseModel):
    job_id: UUID
    task_id: UUID
    project_id: str
    instruction: str
    workspace_path: str
    languages: list[dict]
    attempt: int
    status: str
    cancellation_requested: bool = False
