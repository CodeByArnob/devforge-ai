# DevForge AI

**Autonomous, multi-language software development platform.**

DevForge AI separates its conversational client, model gateway, agent orchestration and isolated execution workers.

> **Current status:** Backend foundation plus OpenRouter free-model discovery, streaming chat proxy and a planning-only agent runtime. The agent can generate and persist a proposed plan with an approval checkpoint. It cannot yet inspect or modify a repository, execute shell commands, run tests or build artifacts; secure project ingestion and isolated workers are still required.

## Backend stack
- Python 3.12, FastAPI, Pydantic and SQLAlchemy
- PostgreSQL (Docker Compose) / SQLite for local tests
- OpenRouter live catalogue and Server-Sent Events streaming
- Durable task/event records and a plan-first agent workflow

## Run locally
```bash
python -m venv .venv
# Windows: .venv\\Scripts\\activate
# macOS/Linux: source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --app-dir backend --reload
```

## OpenRouter endpoints
- `GET /api/v1/ai/models?free_only=true` — fetches the live catalogue and returns only model IDs ending in `:free` plus `openrouter/free`.
- `POST /api/v1/ai/chat/stream` — streams SSE from OpenRouter. Supply `X-OpenRouter-Api-Key`; keys are not written to the database or logs.
- `POST /api/v1/tasks` — create a task.
- `POST /api/v1/tasks/{task_id}/agent/run` — generate a plan using a free model. The response moves to `awaiting_approval`; no code is executed.

Example chat request:
```json
{
  "model": "openrouter/free",
  "messages": [{"role": "user", "content": "Explain this repository"}]
}
```

## Quality checks
```bash
ruff check backend
pytest
```

See [Architecture](docs/architecture.md), [Security Model](docs/security-model.md), and [Roadmap](docs/roadmap.md).
