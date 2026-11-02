# Architecture

## Control plane
- Flutter client (planned): chat, projects, approvals, diffs, timeline and artifacts.
- FastAPI: authenticated project/task APIs, OpenRouter gateway and event persistence.
- Multi-agent planner: five independent specialists (architecture, implementation, security, QA, reviewer) run concurrently with bounded fan-out and timeout. Their result is persisted and waits for human approval.

## Execution plane (not yet implemented)
A separate worker service must execute jobs in disposable, unprivileged sandboxes. The API process must never execute untrusted project code. Workers should default to no network, read-only base images, bounded writable workspaces, CPU/memory/PID/disk/time quotas, dropped Linux capabilities, seccomp/AppArmor or equivalent, and explicit tool allowlists. Never mount the host Docker socket or user home into a worker.

## Agent capability boundary
Current specialist agents have no tools. They receive only the task instruction and must explicitly acknowledge that repository files have not been inspected. Their output is advisory and cannot be treated as a patch, test result or build artifact. Human approval remains mandatory before future patch application.

## Model gateway
The backend retrieves the live OpenRouter catalogue and filters explicit free model IDs (`:free`) plus `openrouter/free`. User keys are request-scoped and not persisted. Do not silently fall back to paid models.

## Event lifecycle
queued -> planning -> awaiting_approval -> editing -> validating -> repairing -> building -> completed. This release implements parallel planning and event persistence only; later states are not yet executable.
