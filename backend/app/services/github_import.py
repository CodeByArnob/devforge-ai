import re
from pathlib import Path
from urllib.parse import quote, urlparse

import httpx

from app.services.project_ingestion import MAX_ARCHIVE_BYTES, ProjectArchiveError, ingest_zip

_GITHUB_NAME = re.compile(r"^[A-Za-z0-9_.-]{1,100}$")
_ALLOWED_ARCHIVE_HOSTS = {"api.github.com", "github.com", "codeload.github.com"}


class GitHubImportError(ValueError):
    pass


async def import_public_repository(
    owner: str,
    repository: str,
    workspace_root: Path,
    ref: str | None = None,
    transport: httpx.AsyncBaseTransport | None = None,
) -> dict:
    if not _GITHUB_NAME.fullmatch(owner) or not _GITHUB_NAME.fullmatch(repository):
        raise GitHubImportError("Invalid GitHub owner or repository name.")
    if ref is not None and (
        len(ref) > 200 or not re.fullmatch(r"[A-Za-z0-9_./-]+", ref)
        or ".." in ref or ref.startswith("/")
    ):
        raise GitHubImportError("Invalid Git reference.")

    suffix = f"/{quote(ref, safe='')}" if ref else ""
    url = f"https://api.github.com/repos/{quote(owner)}/{quote(repository)}/zipball{suffix}"
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "DevForge-AI"}
    timeout = httpx.Timeout(30.0, connect=10.0)
    try:
        async with httpx.AsyncClient(
            transport=transport, timeout=timeout, follow_redirects=False
        ) as client:
            for _ in range(4):
                async with client.stream("GET", url, headers=headers) as response:
                    if response.is_redirect:
                        location = response.headers.get("location")
                        if not location:
                            raise GitHubImportError("GitHub returned an invalid archive redirect.")
                        next_url = str(response.url.join(location))
                        parsed = urlparse(next_url)
                        if parsed.scheme != "https" or parsed.hostname not in _ALLOWED_ARCHIVE_HOSTS:
                            raise GitHubImportError("GitHub archive redirect target is not trusted.")
                        url = next_url
                        continue
                    if response.status_code == 404:
                        raise GitHubImportError("Public GitHub repository or ref was not found.")
                    if response.status_code in {401, 403}:
                        raise GitHubImportError("GitHub denied access or rate-limited this import.")
                    response.raise_for_status()
                    declared = response.headers.get("content-length")
                    if declared and int(declared) > MAX_ARCHIVE_BYTES:
                        raise GitHubImportError("GitHub repository archive exceeds the 100 MB limit.")
                    chunks = bytearray()
                    async for chunk in response.aiter_bytes():
                        chunks.extend(chunk)
                        if len(chunks) > MAX_ARCHIVE_BYTES:
                            raise GitHubImportError("GitHub repository archive exceeds the 100 MB limit.")
                    return ingest_zip(bytes(chunks), workspace_root)
            raise GitHubImportError("GitHub returned too many archive redirects.")
    except GitHubImportError:
        raise
    except (httpx.HTTPError, ValueError) as exc:
        raise GitHubImportError("Unable to download the public GitHub repository archive.") from exc
    except ProjectArchiveError as exc:
        raise GitHubImportError(str(exc)) from exc
