# DevForge isolated runner

The runner is deliberately a separate deployment unit from the FastAPI control
plane. It uses a **rootless Podman** service running on a dedicated, disposable
runner host or Kubernetes node pool. The control plane never mounts a container
runtime socket and workloads never receive a socket, host path, cloud identity,
SSH agent, or API/OpenRouter credential.

The runner accepts a claimed job over a private, mutually authenticated network
and creates one container per command. Its policy is deny-by-default: non-root
UID, read-only root, all capabilities dropped, no-new-privileges, seccomp,
PIDs/CPU/memory/tmpfs limits, bounded output and wall time. Network is `none`
unless a separately approved package-proxy policy is selected. Images must be
pinned by digest and commands come from the backend adapter registry, never
from an LLM response.

`runtime_policy.py` is intentionally testable without a container runtime; the
deployment operator supplies the rootless Podman API/CLI on the runner host.

