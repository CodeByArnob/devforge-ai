# Security Model

Treat repository archives, source files, prompts, dependencies, generated patches and model output as untrusted.

- API keys are request-scoped and must not be persisted or logged.
- Do not execute untrusted project code in the API process or host.
- Before enabling tools, use disposable unprivileged sandboxes with CPU, memory, disk, process, network and wall-clock limits.
- Never mount Docker socket, host home, SSH agent or cloud credentials into workers.
- Reject archive traversal, symlink escapes and zip bombs.
- Require explicit human approval before applying patches, publishing, signing or deploying.
- Authenticate and authorize every project/task endpoint before public deployment.
- Add per-user quotas, rate limits, audit records, secret redaction and dependency scanning.

This milestone does not execute code. CORS and UUID task IDs are not authentication. Docker Compose credentials are local-only examples.
