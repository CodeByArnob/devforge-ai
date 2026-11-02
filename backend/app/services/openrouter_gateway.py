import json
from collections.abc import AsyncIterator
from typing import Any

import httpx

OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
FREE_ROUTER_ID = "openrouter/free"


def is_free_model(model_id: str) -> bool:
    """Only expose OpenRouter's explicit free variants and free-model router."""
    return model_id == FREE_ROUTER_ID or model_id.endswith(":free")


class OpenRouterError(RuntimeError):
    pass


class OpenRouterGateway:
    def __init__(
        self,
        timeout_seconds: float = 90.0,
        transport: httpx.AsyncBaseTransport | None = None,
    ):
        self.timeout = httpx.Timeout(timeout_seconds, connect=15.0)
        self.transport = transport

    async def list_models(self, free_only: bool = True) -> list[dict[str, Any]]:
        async with httpx.AsyncClient(timeout=self.timeout, transport=self.transport) as client:
            response = await client.get(f"{OPENROUTER_BASE_URL}/models")
            response.raise_for_status()
        payload = response.json()
        models = payload.get("data", [])
        if free_only:
            models = [item for item in models if is_free_model(str(item.get("id", "")))]
        normalized = [
            {
                "id": item.get("id"),
                "name": item.get("name") or item.get("id"),
                "context_length": item.get("context_length"),
                "description": item.get("description"),
                "pricing_prompt": (item.get("pricing") or {}).get("prompt"),
                "pricing_completion": (item.get("pricing") or {}).get("completion"),
            }
            for item in models
            if item.get("id")
        ]
        return sorted(normalized, key=lambda item: str(item["name"]).casefold())

    async def open_stream(self, api_key: str, body: dict[str, Any]) -> tuple[httpx.AsyncClient, Any]:
        client = httpx.AsyncClient(timeout=self.timeout, transport=self.transport)
        request = client.build_request(
            "POST",
            f"{OPENROUTER_BASE_URL}/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://github.com/CodeByArnob/devforge-ai",
                "X-Title": "DevForge AI",
            },
            json={**body, "stream": True},
        )
        response = await client.send(request, stream=True)
        if response.is_error:
            detail = (await response.aread()).decode("utf-8", errors="replace")[:1000]
            await response.aclose()
            await client.aclose()
            raise OpenRouterError(
                f"OpenRouter rejected the request ({response.status_code}): {detail}"
            )
        return client, response

    async def stream_sse(self, response: httpx.Response) -> AsyncIterator[str]:
        async for line in response.aiter_lines():
            if line.startswith("data:"):
                yield f"{line}\n\n"
