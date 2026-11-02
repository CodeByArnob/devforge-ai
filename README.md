# DevForge AI

**Autonomous, multi-language software development platform — backend milestone.**

## Implemented
- FastAPI API with task and durable activity-event persistence.
- JWT identity endpoints with Argon2 password hashing, issuer/audience validation and expiring access tokens.
- Per-user project ownership and tenant-scoped project, task, event-stream and agent access.
- OpenRouter live model catalogue, explicit free-model filtering and SSE chat proxy.
- Planning-only agent that stores a proposed plan and pauses at an approval checkpoint.
- ZIP project import with traversal, symlink, encrypted-entry, duplicate-path, compression-ratio, entry-count, per-file and total expansion limits.
- Public GitHub repository import through the official GitHub archive endpoint, with redirect-host validation and the same ZIP safety checks.
- Language manifest detection for Flutter/Dart, JS/TS, Python, Kotlin/Java, Go, Rust, PHP, Ruby, .NET, C/C++ and Swift.
- Immutable, checksum-addressed workspace snapshot primitives and a rootless runner policy that never exposes a Docker socket to workloads.

## Authentication setup

Copy .env.example to .env and configure a high-entropy JWT secret (at least 32 characters):

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Set the generated value as JWT_SECRET. Registration is disabled by default. For controlled initial account provisioning, temporarily set ALLOW_REGISTRATION=true, register the account, then disable registration again. Access tokens expire after 30 minutes by default; clients should send `Authorization: Bearer <access_token>`.

- POST /api/v1/auth/register — create an account when registration is enabled.
- POST /api/v1/auth/login — obtain an access token.
- GET /api/v1/auth/me — inspect the authenticated account.

Passwords are hashed with Argon2 and are never stored in plaintext. JWT tokens are signed with HS256 and validated for issuer, audience, expiry and token type. Do not commit secrets or put JWT_SECRET in a client application.

## Database migrations

Apply versioned migrations before starting the service:

```bash
alembic upgrade head
uvicorn app.main:app --app-dir backend --reload
```

Docker startup runs migrations before Uvicorn. Existing projects receive a nullable owner_id during migration and are deliberately not assigned to an arbitrary account. Such legacy projects remain inaccessible through user-scoped endpoints until an administrator explicitly assigns ownership after verifying the owner. Back up production databases before applying migrations.

## Run locally

```bash
python -m venv .venv
# Windows: .venv\\Scripts\\activate
# macOS/Linux: source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --app-dir backend --reload
```

## API

- GET /health — liveness probe.
- GET /api/v1/ai/models?free_only=true — live free-model catalogue (authenticated).
- POST /api/v1/ai/chat/stream — SSE chat; authenticated and requires X-OpenRouter-Api-Key.
- POST /api/v1/projects/import/zip — guarded ZIP project import; multipart field `file`.
- POST /api/v1/projects/import/github — import a public repository using `{ "owner": "org", "repository": "repo", "ref": "main" }`.
- GET /api/v1/projects — list only the authenticated user's projects.
- POST /api/v1/tasks — create a task only for an owned project.
- POST /api/v1/tasks/{task_id}/agent/run — generate a plan for an owned task; does not execute code.
- GET /api/v1/tasks/{task_id}/events — owner-scoped task activity SSE.

All /api/v1 application endpoints except registration/login require a JWT access token. Registration remains disabled unless ALLOW_REGISTRATION is explicitly enabled.

## Important execution boundary

The control plane does not execute commands, modify repositories, run tests or produce builds. Execution belongs only on a separately deployed runner host. The supplied runner policy requires rootless Podman, a digest-pinned image, a non-root user, read-only root filesystem, dropped capabilities, no-new-privileges, seccomp, PID/CPU/RAM/tmpfs and wall-clock bounds, and no network by default. It never accepts a Docker socket or host credentials. Operators must still deploy the runner on dedicated infrastructure with mTLS, default-deny network policy and an approved package proxy before enabling execution.

## Checks

```bash
ruff check backend
pytest --cov=app
```

