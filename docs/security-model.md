# Security Model

Treat repositories, archives, prompts, dependencies, generated patches and model output as untrusted.

Before enabling execution:
- Use disposable, unprivileged containers or stronger isolation per task.
- Never mount Docker socket, host home, SSH agent, cloud credentials or API keys into workers.
- Reject path traversal and symlink escapes; use immutable source snapshots and task-specific writable workspaces.
- Enforce CPU, memory, process, disk, network, output and wall-clock quotas.
- Deny network by default; allow approved dependency registries through controlled proxies only.
- Keep secrets in a dedicated vault; redact prompts, logs, traces, events and artifacts.
- Require explicit approval for destructive edits, publishing, deployment and signing.
- Validate patches and paths; preserve baseline and audit trail.
- Pin worker images; scan dependencies and images.
- Authenticate/authorize every project and task endpoint; scope by user and project.
- Rate-limit tasks, model calls, archive extraction and artifact downloads.

Threat tests: prompt injection, malicious build scripts, zip bombs, symlink traversal, credential exfiltration, resource exhaustion, poisoned model output, cross-tenant workspace access and event-stream authorization bypass.

Current foundation does not execute user code. UUIDs and CORS are not authentication. Production exposure requires identity, ownership checks, migrations, rate limits, worker isolation and security review. Compose credentials are local-only examples.
