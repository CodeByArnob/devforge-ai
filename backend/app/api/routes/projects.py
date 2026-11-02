import shutil
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.models import Project
from app.db.session import get_db
from app.services.project_ingestion import ProjectArchiveError, ingest_zip

router = APIRouter(prefix="/projects", tags=["projects"])


class ProjectImportResponse(BaseModel):
    project_id: str
    file_count: int
    languages: list[dict]


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
    file: UploadFile = File(...), db: Session = Depends(get_db)
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
    )
    try:
        db.add(project)
        db.commit()
    except Exception:
        db.rollback()
        shutil.rmtree(result["workspace_path"], ignore_errors=True)
        raise
    return ProjectImportResponse(
        project_id=project.id,
        file_count=project.file_count,
        languages=project.languages,
    )


@router.get("", response_model=list[ProjectRead])
def list_projects(
    limit: int = 20, db: Session = Depends(get_db)
) -> list[Project]:
    if not 1 <= limit <= 100:
        raise HTTPException(status_code=422, detail="Limit must be between 1 and 100.")
    return list(db.scalars(select(Project).order_by(Project.created_at.desc()).limit(limit)))


@router.get("/{project_id}", response_model=ProjectRead)
def get_project(project_id: str, db: Session = Depends(get_db)) -> Project:
    project = db.get(Project, project_id)
    if project is None:
        raise HTTPException(status_code=404, detail="Project not found.")
    return project
