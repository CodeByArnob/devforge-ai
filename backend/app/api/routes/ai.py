from collections.abc import AsyncIterator
from pathlib import Path

from fastapi import APIRouter, Header, HTTPException, Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from app.schemas.ai import ChatStreamRequest, ModelInfo
from app.services.gguf_catalogue import (
    GGUFValidationError,
    list_catalogue,
    validate_gguf_file,
)
from app.services.openrouter_gateway import OpenRouterError, OpenRouterGateway

router = APIRouter(prefix="/ai", tags=["AI"])
gateway = OpenRouterGateway()


class GGUFValidateRequest(BaseModel):
    file_path: str = Field(min_length=1, max_length=1000)
    expected_sha256: str | None = Field(default=None, min_length=64, max_length=64)


@router.get("/models", response_model=list[ModelInfo], summary="List live OpenRouter free models")
async def list_free_models(free_only: bool = Query(default=True)) -> list[dict]:
    try:
        return await gateway.list_models(free_only=free_only)
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Unable to retrieve OpenRouter model catalogue.") from exc


@router.post("/chat/stream", summary="Stream a chat completion from OpenRouter")
async def stream_chat(
    payload: ChatStreamRequest,
    x_openrouter_api_key: str = Header(..., alias="X-OpenRouter-Api-Key", min_length=10, max_length=512),
) -> StreamingResponse:
    if not (payload.model == "openrouter/free" or payload.model.endswith(":free")):
        raise HTTPException(status_code=400, detail="Select an explicitly free OpenRouter model (model ID ending in :free).")
    body = {
        "model": payload.model,
        "messages": [message.model_dump() for message in payload.messages],
        "temperature": payload.temperature,
        "max_tokens": payload.max_tokens,
    }
    try:
        client, upstream = await gateway.open_stream(x_openrouter_api_key, body)
    except OpenRouterError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    async def events() -> AsyncIterator[str]:
        try:
            async for line in gateway.stream_sse(upstream):
                yield line
        finally:
            await upstream.aclose()
            await client.aclose()

    return StreamingResponse(
        events(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.get("/local/catalogue", summary="List local GGUF models with license, checksum, ABI, and RAM validation")
def get_local_gguf_catalogue() -> list[dict]:
    return list_catalogue()


@router.post("/local/validate", summary="Validate local GGUF model file checksum, magic bytes, and RAM requirement")
def validate_local_gguf(payload: GGUFValidateRequest) -> dict:
    try:
        return validate_gguf_file(Path(payload.file_path), expected_sha256=payload.expected_sha256)
    except GGUFValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
