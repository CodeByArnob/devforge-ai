# Security Policy

DevForge AI treats sandbox containment, credential secrecy, and multi-tenant isolation as foundational security requirements.

## Reporting Vulnerabilities

If you discover a security vulnerability within DevForge AI, please report it privately:

- **Email**: `security@devforge.ai` (or via GitHub Private Vulnerability Reporting on this repository)
- **Do NOT** open a public issue or discuss potential security vulnerabilities on public forums.
- We will acknowledge receipt within 24 hours and provide an assessment and timeline for a fix.

## Security Architecture & Defenses

1. **Sandbox Execution Isolation**:
   - Workload containers are executed using Podman with `--network=none` by default.
   - Dropped Linux capabilities (`cap-drop=ALL`), read-only root filesystems, PID limits, CPU/memory ceilings, and default seccomp profiles.
   - Workloads run as unprivileged UID `65532:65532`. No host Docker sockets or ambient credentials are ever mounted.

2. **Workspace & Path Traversal Protections**:
   - All repository file access is verified against canonical base directory roots.
   - Strict rejection of DOS reserved device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`), Windows Alternate Data Streams (`:`), UNC paths, and null bytes.

3. **Patch Verification & Human Gate**:
   - Automated agent patch proposals produce unified diffs and are staged in isolated copy-on-write scratch directories.
   - Precondition file checksums (`sha256`) guarantee patch application matches the inspected source tree.
   - Human approval is required before mutating the project workspace.

4. **Authentication & Token Governance**:
   - Passwords hashed with Argon2id.
   - Access tokens (JWT) validated with sliding-window expiration; blacklisted tokens stored in persistent revocations database.
   - Rate limiting enforced on all authentication and AI invocation endpoints.
