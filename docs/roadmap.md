# Roadmap

## Phase 0 - Backend foundation
- [x] FastAPI, PostgreSQL/SQLite persistence and CI
- [x] Durable task events and SSE replay
- [x] Language manifest detection

## Phase 1 - OpenRouter and planning
- [x] Live OpenRouter free-model catalogue
- [x] SSE chat proxy with request-scoped provider key
- [x] Planning-only agent and approval checkpoint

## Phase 2 - Project ingestion and identity
- [x] ZIP import with archive safety limits
- [x] Public GitHub repository import
- [x] JWT registration/login with Argon2 password hashing
- [x] User identity, project ownership and tenant-scoped project/task/agent APIs
- [x] Additive Alembic migration for user identity and project ownership
- [ ] Account recovery, token revocation/rotation and persistent rate limiting
- [ ] GitHub App/OAuth integration and immutable source snapshots
- [ ] Verified ownership reassignment workflow for legacy unowned projects

## Phase 3 - Autonomous execution
- [x] Disposable isolated workers with CPU/memory/disk/network limits
- [x] Hardened rootless Podman execution runtime with dropped caps, seccomp, no-new-privileges, and default-deny network
- [x] Strict allowlisted tool registry with per-role access control
- [x] Language-specific dependency, lint, test, and build adapters (Flutter/Dart, Java, Python, JS/TS)
- [x] 8 independent specialist agents (Architect, Planner, Coder, Security Reviewer, QA, Build, Repair, Integration)
- [x] Bounded structured patch generation, unified diffs, human approval gate, and snapshot rollback
- [x] Resilient worker lifecycle with atomic claims, heartbeats, early cancellation, bounded retries, and audit history

## Phase 4 - Client and local models
- [ ] Flutter chat workspace, secure key vault and live activity timeline
- [ ] Project explorer, diff viewer, approvals and artifact viewer
- [ ] Local GGUF catalogue with license, checksum, ABI and RAM validation
