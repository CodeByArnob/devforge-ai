# Roadmap

## Phase 0 — Backend foundation
- [x] FastAPI, PostgreSQL/SQLite persistence and CI
- [x] Durable task events and SSE replay
- [x] Language manifest detection

## Phase 1 — OpenRouter and planning
- [x] Live OpenRouter free-model catalogue
- [x] SSE chat proxy with request-scoped provider key
- [x] Planning-only agent and approval checkpoint

## Phase 2 — Project ingestion and identity
- [x] ZIP import with archive safety limits
- [x] Public GitHub repository import
- [x] JWT registration/login with Argon2 password hashing
- [x] User identity, project ownership and tenant-scoped project/task/agent APIs
- [x] Additive Alembic migration for user identity and project ownership
- [ ] Account recovery, token revocation/rotation and persistent rate limiting
- [ ] GitHub App/OAuth integration and immutable source snapshots
- [ ] Verified ownership reassignment workflow for legacy unowned projects

## Phase 3 — Autonomous execution
- [ ] Disposable isolated workers with CPU/memory/disk/network limits
- [ ] Tool registry and language-specific lint/test/build adapters
- [ ] Patch generation, diff approval and bounded repair loops
- [ ] Artifact storage, provenance and audit history

## Phase 4 — Client and local models
- [ ] Flutter chat workspace, secure key vault and live activity timeline
- [ ] Project explorer, diff viewer, approvals and artifact viewer
- [ ] Local GGUF catalogue with license, checksum, ABI and RAM validation

**Production status:** Identity and tenant authorization are now implemented in the backend branch, but the complete product is not production-ready. It still lacks isolated workers, code editing/execution, verification/build pipelines, the Flutter client, operational monitoring, persistent abuse controls and a deployment hardening review.
