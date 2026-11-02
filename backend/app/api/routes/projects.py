import shutil
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser
from app.core.config import get_settings
from app.db.models import Project
from app.db.session import get_db
from app.services.github_import import GitHubImportError, import_public_repository
from app.services.project_ingestion import ProjectArchiveError, ingest_zip
from app.services.workspace_snapshot import WorkspaceSafetyError, inspect_workspace, read_file_safe

router = APIRouter(prefix="/projects", tags=["projects"])


class ProjectImportResponse(BaseModel):
    project_id: str
    file_count: int
    languages: list[dict]


class GitHubImportRequest(BaseModel):
    owner: str = Field(min_length=1, max_length=100)
    repository: str = Field(min_length=1, max_length=100)
    ref: str | None = Field(default=None, max_length=200)


class ProjectRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    source_type: str
    file_count: int
    languages: list[dict]
    created_at: datetime


@router.post("/import/zip", response_model=ProjectImportResponse, status_code=201)
async def import_zip(
    user: CurrentUser, file: UploadFile = File(...), db: Session = Depends(get_db)
) -> ProjectImportResponse:
    if file.content_type not in {
        "application/zip", "application/x-zip-compressed", "application/octet-stream"
    }:
        raise HTTPException(status_code=415, detail="Upload a ZIP archive.")
    settings = get_settings()
    data = await file.read(100 * 1024 * 1024 + 1)
    await file.close()
    try:
        result = ingest_zip(data, Path(settings.workspace_root))
    except ProjectArchiveError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    project = Project(
        id=result["project_id"],
        name=Path(file.filename or "Imported project").stem[:255] or "Imported project",
        source_type="zip",
        workspace_path=result["workspace_path"],
        file_count=result["file_count"],
        languages=result["languages"],
        owner_id=user.id,
    )
    try:
        db.add(project)
        db.commit()
    except Exception:
        db.rollback()
        shutil.rmtree(result["workspace_path"], ignore_errors=True)
        raise
    return ProjectImportResponse(
        project_id=project.id, file_count=project.file_count, languages=project.languages
    )


@router.post("/import/github", response_model=ProjectImportResponse, status_code=201)
async def import_github_repository(
    payload: GitHubImportRequest, user: CurrentUser, db: Session = Depends(get_db)
) -> ProjectImportResponse:
    settings = get_settings()
    try:
        result = await import_public_repository(
            payload.owner, payload.repository, Path(settings.workspace_root), payload.ref
        )
    except GitHubImportError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    project = Project(
        id=result["project_id"],
        name=f"{payload.owner}/{payload.repository}"[:255],
        source_type="github",
        workspace_path=result["workspace_path"],
        file_count=result["file_count"],
        languages=result["languages"],
        owner_id=user.id,
    )
    try:
        db.add(project)
        db.commit()
    except Exception:
        db.rollback()
        shutil.rmtree(result["workspace_path"], ignore_errors=True)
        raise
    return ProjectImportResponse(
        project_id=project.id, file_count=project.file_count, languages=project.languages
    )


@router.get("", response_model=list[ProjectRead])
def list_projects(
    user: CurrentUser, limit: int = 20, db: Session = Depends(get_db)
) -> list[Project]:
    if not 1 <= limit <= 100:
        raise HTTPException(status_code=422, detail="Limit must be between 1 and 100.")
    statement = (
        select(Project).where(Project.owner_id == user.id)
        .order_by(Project.created_at.desc()).limit(limit)
    )
    return list(db.scalars(statement))


@router.get("/{project_id}", response_model=ProjectRead)
def get_project(project_id: str, user: CurrentUser, db: Session = Depends(get_db)) -> Project:
    project = db.scalar(
        select(Project).where(Project.id == project_id, Project.owner_id == user.id)
    )
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found.")
    return project


@router.get("/{project_id}/inventory")
def get_project_inventory(
    project_id: str,
    user: CurrentUser,
    max_depth: int = Query(default=10, ge=1, le=20),
    limit: int = Query(default=500, ge=1, le=2000),
    db: Session = Depends(get_db),
) -> dict:
    project = db.scalar(
        select(Project).where(Project.id == project_id, Project.owner_id == user.id)
    )
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found.")
    try:
        items = inspect_workspace(Path(project.workspace_path), max_depth=max_depth, limit=limit)
        return {
            "project_id": project_id,
            "total_items": len(items),
            "items": items,
        }
    except WorkspaceSafetyError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/{project_id}/files/inspect")
def inspect_project_file(
    project_id: str,
    path: str,
    user: CurrentUser,
    max_bytes: int = Query(default=64 * 1024, ge=1, le=1024 * 1024),
    db: Session = Depends(get_db),
) -> dict:
    project = db.scalar(
        select(Project).where(Project.id == project_id, Project.owner_id == user.id)
    )
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found.")
    try:
        return read_file_safe(Path(project.workspace_path), path, max_bytes=max_bytes)
    except WorkspaceSafetyError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
