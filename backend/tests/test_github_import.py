import asyncio
import io
import zipfile
from pathlib import Path

import httpx
import pytest

from app.services.github_import import GitHubImportError, import_public_repository


def make_zip() -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("demo/package.json", '{"name":"demo"}')
        archive.writestr("demo/src/index.ts", "export {};")
    return buffer.getvalue()


def test_imports_public_github_archive(tmp_path: Path):
    archive = make_zip()
    seen = []

    async def handler(request: httpx.Request) -> httpx.Response:
        seen.append(str(request.url))
        if request.url.host == "api.github.com":
            return httpx.Response(
                302,
                headers={"Location": "https://codeload.github.com/acme/demo/legacy.zip/main"},
            )
        return httpx.Response(200, content=archive, headers={"Content-Length": str(len(archive))})

    result = asyncio.run(import_public_repository(
        "acme", "demo", tmp_path, "main", httpx.MockTransport(handler)
    ))
    assert len(seen) == 2
    assert result["file_count"] == 2
    assert (Path(result["workspace_path"]) / "demo" / "package.json").exists()


def test_rejects_untrusted_redirect(tmp_path: Path):
    async def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(302, headers={"Location": "https://attacker.example/archive.zip"})

    with pytest.raises(GitHubImportError, match="not trusted"):
        asyncio.run(import_public_repository(
            "acme", "demo", tmp_path, transport=httpx.MockTransport(handler)
        ))


def test_rejects_invalid_ref_before_network(tmp_path: Path):
    with pytest.raises(GitHubImportError, match="Invalid Git reference"):
        asyncio.run(import_public_repository("acme", "demo", tmp_path, "../secrets"))


def test_reports_missing_public_repository(tmp_path: Path):
    async def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(404)

    with pytest.raises(GitHubImportError, match="not found"):
        asyncio.run(import_public_repository(
            "acme", "missing", tmp_path, transport=httpx.MockTransport(handler)
        ))
