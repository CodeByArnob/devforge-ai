import httpx
import pytest

from app.services.openrouter_gateway import OpenRouterGateway


@pytest.mark.asyncio
async def test_catalogue_returns_only_explicit_free_variants():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/api/v1/models"
        return httpx.Response(
            200,
            json={
                "data": [
                    {"id": "vendor/paid", "name": "Paid", "pricing": {"prompt": "1"}},
                    {"id": "vendor/free:free", "name": "Free", "pricing": {"prompt": "0"}},
                    {"id": "openrouter/free", "name": "Free Router", "pricing": {"prompt": "0"}},
                ]
            },
        )

    gateway = OpenRouterGateway(transport=httpx.MockTransport(handler))
    models = await gateway.list_models()
    assert {item["id"] for item in models} == {"vendor/free:free", "openrouter/free"}


@pytest.mark.asyncio
async def test_stream_uses_request_key_and_forwards_sse():
    observed = {}

    def handler(request: httpx.Request) -> httpx.Response:
        observed["authorization"] = request.headers["Authorization"]
        body = request.read().decode()
        observed["stream"] = '"stream":true' in body
        return httpx.Response(
            200,
            headers={"content-type": "text/event-stream"},
            content=b'data: {"choices":[{"delta":{"content":"hello"}}]}\n\ndata: [DONE]\n\n',
        )

    gateway = OpenRouterGateway(transport=httpx.MockTransport(handler))
    client, response = await gateway.open_stream(
        "sk-or-test-secret",
        {"model": "vendor/free:free", "messages": [{"role": "user", "content": "hi"}]},
    )
    try:
        chunks = [chunk async for chunk in gateway.stream_sse(response)]
    finally:
        await response.aclose()
        await client.aclose()

    assert observed == {"authorization": "Bearer sk-or-test-secret", "stream": True}
    assert len(chunks) == 2
    assert "hello" in chunks[0]
    assert "[DONE]" in chunks[1]
