from pathlib import Path

from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel

from app.core.config import get_settings
from app.services.project_ingestion import ProjectArchiveError, ingest_zip

router = APIRouter(prefix="/projects", tags=["projects"])


class ProjectImportResponse(BaseModel):
    project_id: str
    file_count: int
    languages: list[dict]


@router.post("/import/zip", response_model=ProjectImportResponse, status_code=201)
async def import_zip(file: UploadFile = File(...)) -> ProjectImportResponse:
    if file.content_type not in {"application/zip", "application/x-zip-compressed", "application/octet-stream"}:
        raise HTTPException(status_code=415, detail="Upload a ZIP archive.")
    settings = get_settings()
    data = await file.read(100 * 1024 * 1024 + 1)
    await file.close()
    try:
        result = ingest_zip(data, Path(settings.workspace_root))
    except ProjectArchiveError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return ProjectImportResponse(**{key: value for key, value in result.items() if key != "workspace_path"})
