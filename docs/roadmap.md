# Roadmap

## Phase 0 — Foundation
- [x] FastAPI backend, task/event persistence, SSE event replay
- [x] Language manifest detection, Docker Compose, CI and baseline tests

## Phase 1 — Model gateway and agent planning
- [x] Live OpenRouter model catalogue with explicit free-model filtering
- [x] OpenRouter chat-completion SSE proxy; API key is request-scoped and never persisted
- [x] Agent planning runtime with durable activity events and approval checkpoint
- [ ] Flutter chat client, key management and model selector UI
- [ ] Authentication, per-user quotas and encrypted provider-key vault

## Phase 2 — Secure project ingestion
- [ ] ZIP upload with archive-bomb/path-traversal defenses
- [ ] GitHub App/OAuth integration and least-privilege project access
- [ ] Immutable source snapshots and workspace lifecycle

## Phase 3 — Autonomous execution
- [ ] Evaluate OpenHands SDK and LangGraph for durable orchestration
- [ ] Sandboxed tool registry and disposable isolated workers
- [ ] Language-specific lint/test/build adapters and resource quotas
- [ ] Patch generation, diff approval, bounded repair loops and artifact provenance

## Phase 4 — Local models and client
- [ ] Local GGUF runtime catalogue with license/checksum/RAM validation
- [ ] Flutter chat workspace, live activity timeline and reconnect/replay
- [ ] Diff viewer, approval UX, project explorer and artifact viewer

A milestone is complete only after tests, failure-path checks and documentation match shipped behavior.
