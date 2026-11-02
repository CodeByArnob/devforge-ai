# DevForge AI

**Autonomous, multi-language software development platform — backend milestone.**

## Implemented
- FastAPI API with task and durable activity-event persistence.
- OpenRouter live model catalogue, explicit free-model filtering and SSE chat proxy.
- Planning-only agent that stores a proposed plan and pauses at an approval checkpoint.
- ZIP project import with traversal, symlink, encrypted-entry, entry-count, per-file and total expansion limits.
- Optional shared API-token protection for all application routes except liveness. Production mode fails closed when no token is configured.
- Language manifest detection for Flutter/Dart, JS/TS, Python, Kotlin/Java, Go, Rust, PHP, Ruby, .NET, C/C++ and Swift.

## Run locally
```bash
python -m venv .venv
# Windows: .venv\\Scripts\\activate
# macOS/Linux: source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --app-dir backend --reload
```

## Configure
Copy .env.example to .env. Set a long random API_ACCESS_TOKEN before exposing the API. Send it as X-DevForge-Token for protected endpoints. Set WORKSPACE_ROOT to a private persistent directory. Do not commit .env.

## API
- GET /health — liveness probe.
- GET /api/v1/ai/models?free_only=true — live free-model catalogue.
- POST /api/v1/ai/chat/stream — SSE chat; requires X-OpenRouter-Api-Key.
- POST /api/v1/projects/import/zip — guarded ZIP project import; multipart field file.
- POST /api/v1/tasks — create task.
- POST /api/v1/tasks/{task_id}/agent/run — generate a plan, not execute code.
- GET /api/v1/tasks/{task_id}/events — task activity SSE.

All /api/v1 routes require X-DevForge-Token when configured. Production mode refuses requests if the token is not configured. The current shared-token mode is a deployment bootstrap, not multi-user identity or per-project authorization.

## Important execution boundary
The agent does NOT execute commands, modify repositories, run tests or produce builds. Never expose the API to the public internet as a complete autonomous coding service until user identities, project ownership, quotas, migrations, isolated disposable workers, monitoring and a client application are implemented and tested.

## Checks
```bash
ruff check backend
pytest --cov=app
```
