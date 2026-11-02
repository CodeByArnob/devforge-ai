# Architecture

## Boundaries
- Flutter client: chat, project navigation, activity stream, approvals and artifacts.
- FastAPI control plane: task/project APIs, model gateway, patch management, and durable event persistence.
- Agent runtime: 8 independent specialist agents (Architect, Planner, Coder, Security Reviewer, QA Engineer, Build Engineer, Repair Engineer, Integration Engineer) with structured outputs, role validation, and explicit tool permissions.
- Execution plane: dedicated disposable runner service running rootless Podman containers per command; the control plane has no container socket and workloads receive zero ambient credentials or host paths.
- Tool registry: strict allowlisted tools with role-based access control.
- Language adapters: Flutter/Dart, Java (Gradle/Maven), Python, and JavaScript/TypeScript adapters with digest-pinned images, command synthesis, and diagnostic output parsers.
- Persistence: PostgreSQL / SQLite task, project, patch, and worker lease metadata.

## OpenRouter Gateway
The backend retrieves the live model catalogue and filters explicit free model IDs (`:free`) plus the `openrouter/free` router. Chat completions are proxied as Server-Sent Events. The user API key is supplied per request and is not persisted.

## Agent Lifecycle
`queued` -> `inspecting` -> `planning` -> `awaiting_approval` -> `editing` -> `validating` -> `repairing` -> `building` -> `completed` (or `failed` / `cancelled`).
Every patch proposal requires explicit authenticated human approval before application, with full unified diff review and snapshot rollback capabilities.

## Language Adapters
The platform provides verified adapters with pinned container image digests (`@sha256:`):
- **Flutter / Dart**: `pubspec.yaml`, `dart pub get`, `dart analyze`, `dart test`, `dart compile exe / flutter build bundle`.
- **Java**: `pom.xml`, `build.gradle`, `build.gradle.kts`, `./gradlew` / `mvn` toolchain detection, dependency resolution, checkstyle/check, test, compile/assemble.
- **Python**: `pyproject.toml`, `requirements.txt`, `pip`, `ruff`, `pytest`, `python -m build`.
- **JavaScript / TypeScript**: `package.json`, `tsconfig.json`, `npm ci`, `eslint`, `npm test`, `npm run build`.
