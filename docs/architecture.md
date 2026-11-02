# Architecture

## Boundaries
- Flutter client: chat, project navigation, activity stream, approvals and artifacts.
- FastAPI control plane: task/project APIs, model gateway and event persistence.
- Agent runtime: plan generation and approval checkpoints; execution is not enabled yet.
- Execution plane: separately deployed rootless runner hosts per task and language; the API has no container runtime socket.
- Persistence: PostgreSQL task/event metadata and future private object storage.

## OpenRouter gateway
The backend retrieves the live model catalogue and filters explicit free model IDs (`:free`) plus the `openrouter/free` router. Chat completions are proxied as Server-Sent Events. The user API key is supplied per request and is not persisted. A future authenticated client should store it in OS secure storage and never ship it inside a repository.

## Agent lifecycle
queued -> planning -> awaiting_approval -> editing -> validating -> repairing -> building -> completed. This milestone implements planning and the approval checkpoint only. The task event stream is durable and sequence-numbered.

## Language adapters
The manifest registry recognizes Flutter/Dart, JS/TS, Python, Kotlin/Java, Go, Rust, PHP, Ruby, .NET, C/C++ and Swift. It detects project types only; it does not execute their toolchains.

## Next
Authentication and ownership, project ingestion, workspace snapshots, patch/diff approval, isolated worker runtime, language build adapters, artifact storage and Flutter client.

