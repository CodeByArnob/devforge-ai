# Roadmap

## Phase 0 — Backend foundation
- [x] FastAPI, PostgreSQL/SQLite persistence and CI
- [x] Durable task events and SSE replay
- [x] Language manifest detection

## Phase 1 — OpenRouter and planning
- [x] Live OpenRouter free-model catalogue
- [x] SSE chat proxy with request-scoped provider key
- [x] Planning-only agent and approval checkpoint

## Phase 2 — Project ingestion and access baseline
- [x] ZIP import with path traversal, symlink, encryption, entry-count and expansion limits
- [x] Optional shared API-token authentication; production mode fails closed without configuration
- [ ] Persistent user identities, per-user project ownership and quotas
- [ ] GitHub App/OAuth integration and immutable source snapshots

## Phase 3 — Autonomous execution
- [ ] Disposable isolated workers with CPU/memory/disk/network limits
- [ ] Tool registry and language-specific lint/test/build adapters
- [ ] Patch generation, diff approval and bounded repair loops
- [ ] Artifact storage, provenance and audit history

## Phase 4 — Client and local models
- [ ] Flutter chat workspace, secure key vault and live activity timeline
- [ ] Project explorer, diff viewer, approvals and artifact viewer
- [ ] Local GGUF catalogue with license, checksum, ABI and RAM validation

**Production status:** This repository is a backend milestone, not yet a production-ready autonomous coding product. It must not execute untrusted code until isolated workers, user-level authorization, quotas, migration management and operational monitoring are implemented.

## Database and project persistence milestone
- [x] Persist imported project metadata and expose project list/detail endpoints.
- [x] Enforce task-to-project references at the service layer and relational schema level.
- [x] Add Alembic migration environment and initial schema revision.
- [x] Remove automatic `Base.metadata.create_all()` from API startup.
- [x] Run migrations before the single API container starts.
- [ ] Add multi-user identity, project ownership, and tenant-scoped authorization before public deployment.
- [ ] Add migration coverage for upgrades from every supported legacy schema.
