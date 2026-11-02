# Roadmap

## Backend foundation
- [x] FastAPI, database persistence, Alembic and CI
- [x] JWT identity and per-user project/task authorization
- [x] ZIP and public GitHub repository import
- [x] OpenRouter streaming gateway and free-model enforcement

## Multi-agent orchestration
- [x] Five specialist planning roles: architect, implementer, security, QA and reviewer
- [x] Concurrent specialist execution with bounded fan-out and request timeout
- [x] Persisted team-plan event and explicit human approval checkpoint
- [ ] Repository-aware context retrieval and token-budgeted file selection
- [ ] Agent tool registry with scoped capabilities and audit logs
- [ ] Implementer patch generation and independent reviewer feedback loop
- [ ] Human-approved patch application and bounded repair cycles

## Execution and delivery
- [ ] Isolated worker service with disposable containers, non-root user, no network by default, CPU/memory/PID/disk/time limits
- [ ] Language-specific dependency, lint, test and build adapters
- [ ] Artifact storage, checksum, provenance and download authorization
- [ ] Worker lifecycle, retries, cancellation, idempotency and dead-letter handling

## Client and operations
- [ ] Flutter client: project import, chat, task timeline, diffs, approvals, artifacts
- [ ] Persistent rate limits, quotas, account recovery, token revocation and audit retention
- [ ] Production deployment, backups, metrics, tracing, alerting and incident runbooks

**Current boundary:** Multi-agent endpoint performs independent planning/review only. It has no repository or shell tools and does not modify code or run builds. The full product is not production-ready.
