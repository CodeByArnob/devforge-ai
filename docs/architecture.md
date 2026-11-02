# Architecture

## System boundaries
1. **Client workspace:** Flutter app for chat, project browsing, live activity, diff review, approvals and artifacts.
2. **API/control plane:** FastAPI identity, project/task APIs, event replay and artifact references.
3. **Agent orchestration:** planning, tool selection, checkpoints, approvals and bounded retries.
4. **Model gateway:** local inference and user-configured cloud providers, normalized behind provider interfaces.
5. **Execution plane:** disposable isolated workers with language-specific toolchains.
6. **Persistence:** PostgreSQL metadata/event records and private object storage for source snapshots, patches and artifacts.

## Task lifecycle
queued -> inspecting -> planning -> awaiting_approval -> editing -> validating -> repairing -> building -> completed; failed/cancelled are terminal states. Transitions must be validated centrally and emitted as durable ordered events.

## Language adapters
Manifest detection and capability registry are the first seam. Planned adapters: Flutter/Dart (pubspec.yaml), JS/TS (package.json/tsconfig.json), Python (pyproject.toml/requirements.txt), Kotlin/Java (Gradle/Maven), Go (go.mod), Rust (Cargo.toml), PHP (composer.json), Ruby (Gemfile), .NET (.sln/.csproj), C/C++ (CMakeLists.txt/Meson), Swift (Package.swift). Current code detects manifests only; no commands are executed.

## Model gateway
Normalize streaming, tool calls, structured output, context limits and usage across providers. Fetch OpenRouter catalogue dynamically and explicitly filter free model IDs. Never silently substitute paid models. Validate local model license, checksum, quantization, memory needs and runtime compatibility before offering download.

## Event delivery
Task events are durable and sequence-numbered per task. Clients reconnect with the last event ID and replay missed events. Current SSE implementation polls the database as a foundation; production scale requires a broker/outbox and worker fan-out.

## Deployment
Stateless API replicas; durable scheduler; isolated per-task workers; PostgreSQL with migrations/backups; private object storage; structured logs, metrics, traces and redaction.

## Not implemented yet
No repository code execution, arbitrary shell tools, agent worker, production authentication, GitHub write integration, or full Flutter client is included in this foundation.
