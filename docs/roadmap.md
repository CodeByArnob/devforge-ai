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

## Phase 5 - Mobile engineering workspace (new)
- [ ] Baseline Android/Flutter compatibility and release-signing audit
- [x] Add Device Workspace navigation destination and native workspace screen shell
- [x] Typed Flutter MethodChannel contract for native workspace operations
- [x] Android app-private workspace with bounded listing, UTF-8 read/write, directory/file creation, and canonical-path containment checks\n- [ ] Storage Access Framework integration
- [ ] ARM64 Linux userspace evaluation and verified runtime bundle installer
- [ ] Process supervisor, structured argv execution, output streaming and cancellation
- [ ] Loopback-only web preview with WebView origin restrictions
- [ ] Explicit local/remote execution backend selection and capability reporting
- [ ] GitHub clone/branch/commit/push/PR workflow with explicit write confirmation
- [ ] Remote build dispatch, logs, checksums and artifact retrieval
- [ ] Security regression suite and reproducible release verification

Implementation contract: [Mobile Engineering Workspace Blueprint](mobile-engineering-workspace.md). PRoot is a userspace compatibility layer, not a hardened security boundary; untrusted remote builds remain on the dedicated rootless Podman runner.


### Implemented first vertical slice (unverified by CI at authoring time)
- Android native workspace bridge reports device ABI/API and explicitly reports Linux runtime as not installed unless an executable runtime entry point is present.
- Workspace files are stored under the app-private files directory; no broad storage permission is requested.
- File listing is bounded by depth and entry count; editor read/write is capped at 1 MiB.
- Canonical path checks prevent traversal and symlink targets from escaping the private workspace.
- Flutter Device tab supports nested folder navigation, folder/file creation, text-file editing, and save.
- Flutter CI now compiles a debug APK so Kotlin/Android integration is checked on pull requests.
- This slice does not implement PRoot, shell/terminal execution, runtime bundle installation, web preview, or remote build orchestration.
