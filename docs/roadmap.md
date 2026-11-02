# Roadmap

## Phase 0 — Foundation
- [x] Monorepo conventions, FastAPI skeleton and health endpoint
- [x] Persistent task/event schema and task APIs
- [x] SSE event replay foundation
- [x] Language manifest detection registry
- [x] Docker Compose, CI, tests and security/architecture docs

## Phase 1 — Secure ingestion
- [ ] Authentication and project ownership
- [ ] ZIP upload with archive-bomb/path-traversal defenses
- [ ] Git provider integration with least-privilege OAuth/App scopes
- [ ] Immutable source snapshots and workspace lifecycle

## Phase 2 — Agent runtime
- [ ] Evaluate OpenHands SDK and LangGraph
- [ ] Durable scheduler, worker heartbeat and typed tool registry
- [ ] Planning, checkpointing, approval gates and bounded retries
- [ ] Persisted diffs and patch validation

## Phase 3 — Isolated execution
- [ ] Hardened worker images by ecosystem
- [ ] Resource quotas, network policy, timeout and process supervision
- [ ] Test/lint/build adapters and machine-readable results
- [ ] Artifact storage, provenance and checksums

## Phase 4 — Model gateway
- [ ] Provider-neutral streaming interface
- [ ] OpenRouter live catalogue and strict free-tier filtering
- [ ] Secure API-key vault and redaction
- [ ] Local GGUF catalogue, license metadata and compatibility checks

## Phase 5 — Client
- [ ] Flutter chat workspace and project explorer
- [ ] Live activity timeline with reconnect/replay
- [ ] Diff viewer, approval UX and provider settings
- [ ] Offline model manager and artifact viewer

A phase is complete only after unit, integration, security and failure-path tests pass and documentation matches shipped behavior.
