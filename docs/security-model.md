# Security Model

Treat repository archives, source files, prompts, dependencies, generated patches and model output as untrusted.

## Identity and authorization
- User passwords are hashed with Argon2; plaintext passwords are never stored.
- Access tokens are signed JWTs with a configured high-entropy secret, issuer, audience, expiry and explicit access-token type.
- Registration is disabled by default and must be enabled only for controlled provisioning.
- Every AI, project, task, event-stream and agent API route requires an authenticated active user.
- Project list/detail/import and task creation/read/list/event/agent operations are scoped to the authenticated project owner.
- Legacy projects are migrated with owner_id=NULL and are not exposed to users until ownership is explicitly verified and assigned.
- JWT_SECRET must never be committed, logged or embedded in a client.
- Add persistent rate limiting, account recovery, token revocation/rotation, audit records and abuse controls before public multi-tenant launch.

## Ingestion and execution
- API keys are request-scoped and must not be persisted or logged.
- Do not execute untrusted project code in the API process or host.
- Before enabling tools, use disposable unprivileged sandboxes with CPU, memory, disk, process, network and wall-clock limits.
- Never mount Docker socket, host home, SSH agent or cloud credentials into workers.
- Reject archive traversal, symlink escapes and zip bombs.
- Require explicit human approval before applying patches, publishing, signing or deploying.

Authentication and ownership are necessary but not sufficient for production deployment. CORS and UUID task IDs are not security boundaries. Docker Compose credentials are local-only examples.
