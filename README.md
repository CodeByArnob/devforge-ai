# DevForge AI

**Autonomous, multi-language software development platform — backend milestone.**

## Implemented
- FastAPI API, durable task events and per-user project/task ownership.
- JWT identity with Argon2 password hashing and expiring access tokens.
- OpenRouter live model catalogue, explicit free-model filtering and SSE chat proxy.
- Planning-only single agent and a five-specialist parallel review endpoint (architecture, implementation, security, QA and independent review).
- ZIP and public GitHub repository import with archive and redirect safety controls.

## Multi-agent planning

Create a task, then call `POST /api/v1/tasks/{task_id}/agent/team-plan` with a Bearer access token and `X-OpenRouter-Api-Key`. The endpoint runs five independent specialist prompts concurrently using the selected free OpenRouter model and returns findings, blockers and proposed actions. Results are persisted to the task event stream and the task pauses at `awaiting_approval`.

This is an approval-gated planning/review milestone only. The specialists currently have no repository, shell, patch or build tools; they cannot inspect files or change code. Never interpret a proposed action as an executed change.

## Authentication

Configure a high-entropy `JWT_SECRET` (at least 32 characters). Registration is disabled by default. Enable `ALLOW_REGISTRATION=true` only during controlled provisioning. Clients send `Authorization: Bearer <access_token>`. Passwords use Argon2 hashes.

## Database

Run `alembic upgrade head` before starting the API. Back up production databases before migrations. Legacy projects with null owners remain inaccessible until an administrator verifies and assigns ownership.

## Run locally

```bash
pip install -e ".[dev]"
uvicorn app.main:app --app-dir backend --reload
```

## Execution boundary and remaining work

No untrusted project code is executed. The complete autonomous product still requires isolated disposable workers, repository snapshot/file inspection, patch generation and diff approval, language-specific test/build adapters, artifact storage, persistent quotas/rate limits, operational monitoring, and the Flutter client.
