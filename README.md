# DevForge AI

**Autonomous, multi-language software development platform.**

DevForge AI is designed to inspect, modify, test and build software through a conversational AI workspace. Its architecture separates the client, agent orchestration, model providers and isolated execution workers.

> **Status: Foundation stage.** This repository currently provides a FastAPI backend skeleton, durable task/event records, manifest-based language detection, containerized development setup, CI and architecture/security documentation. It does not yet execute repository code or provide a complete autonomous agent.

## Principles
- Language-agnostic adapters: Flutter/Dart, JavaScript/TypeScript, Python, Kotlin/Java, Go, Rust, PHP, Ruby, .NET, C/C++ and Swift.
- User-selected local and cloud models; no silent paid-model fallback.
- Human approval for consequential changes.
- Untrusted code runs only in isolated, resource-limited workers.
- Report verifiable tests, builds and artifacts; never claim unverified success.

## Layout
```
backend/              FastAPI service, domain logic and tests
docs/                 Architecture, security model and roadmap
infra/                API container image
.github/workflows/    CI
```

## Run locally
Requires Python 3.12+.
```bash
cd backend
python -m venv .venv
# Windows: .venv\\Scripts\\activate
# macOS/Linux: source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --reload
```
API docs: http://localhost:8000/docs

Or run API + PostgreSQL with `docker compose up --build`.

## Current endpoints
- `GET /health`
- `POST /api/v1/tasks`
- `GET /api/v1/tasks`
- `GET /api/v1/tasks/{task_id}`
- `GET /api/v1/tasks/{task_id}/events` (SSE replay)
- `POST /api/v1/tasks/{task_id}/cancel`

Task creation currently records a queued task; it does **not** execute code. A secured worker runtime is a later milestone.

## Quality checks
```bash
cd backend
ruff check .
ruff format --check .
pytest
```

See [Architecture](docs/architecture.md), [Security Model](docs/security-model.md), and [Roadmap](docs/roadmap.md). MIT licensed.
