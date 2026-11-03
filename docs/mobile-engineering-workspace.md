# Mobile Engineering Workspace — Implementation Blueprint

Status: Architecture baseline; implementation must proceed through independently testable milestones.

Reference: [Mobile-Harness](https://github.com/techjarves/Mobile-Harness)

## Product direction

Evolve DevForge AI into a mobile-first engineering workspace without copying Mobile-Harness source code or replacing DevForge's existing FastAPI, Flutter, eight-agent, and remote rootless-Podman architecture.

The Android application should provide a project workspace, file explorer, editor, terminal, agent activity, diff approvals, web preview, Git operations, and build artifact access.

## Non-negotiable architecture decisions

1. Keep Flutter as the application UI and existing FastAPI as the remote control plane.
2. Add an Android-native runtime adapter behind a typed Flutter platform interface. Do not put process execution logic in widgets.
3. Treat on-device Linux userspace (potentially PRoot on supported ARM64 devices) as a convenience execution environment, not as a security boundary equivalent to rootless Podman.
4. Keep remote untrusted builds in the existing dedicated rootless Podman runner. Never expose a container socket to the API process or mobile client.
5. Make local and remote execution explicit selectable backends with capability reporting; never silently fall back between trust boundaries.
6. Do not execute arbitrary model-generated shell strings. Commands must be represented as structured argv and pass through an explicit policy/consent layer.
7. Keep credentials in Android Keystore-backed storage or server-side secret handling. Never mount provider credentials into build containers.
8. Preserve application ID, release signing continuity, database compatibility, existing user data, and current API contracts.

## Target architecture

```text
Flutter Workspace UI
  ├── Project Explorer / Editor / Terminal / Preview
  ├── Agent Timeline / Patch Review / Build Center
  └── Typed repositories and platform interfaces
          ├── Android Runtime Adapter (Kotlin)
          │     ├── Runtime installer and integrity verifier
          │     ├── Process supervisor and lifecycle
          │     ├── App-private workspace and SAF bridge
          │     └── Local runtime capability reporting
          └── FastAPI Remote Adapter
                ├── Existing 8-agent orchestration
                ├── Approval-gated patch service
                ├── Existing isolated runner service
                └── Build artifacts / SSE event stream
```

## Milestones and acceptance criteria

### M0 — Baseline and compatibility audit
- Record current Flutter, Android Gradle Plugin, Kotlin, compile/target/min SDK, backend API, database schema, CI, and release-signing constraints.
- Map existing screens/services before changing them.
- Establish baseline test results and capture current release artifact metadata.
- No feature work may break existing login, GitHub connection, project ownership, AI Studio, or task APIs.

### M1 — Mobile workspace shell
- Add responsive workspace navigation and project-scoped context.
- Add project tree, file preview/editor surface, terminal surface, agent event timeline, diff viewer, and artifact list.
- Connect every screen to real repository/service state; no mock success states.
- Provide loading, empty, offline, permission-denied, and failure states.

### M2 — Android runtime contract
- Define typed operations: inspect runtime, install/update runtime bundle, list workspace entries, read/write a file, start a structured command, stream output, cancel process, and inspect process status.
- Implement Kotlin adapter and Flutter Pigeon/platform interface.
- Use app-private storage by default; use Storage Access Framework only for explicit user-selected external folders.
- Validate path containment, symlinks, archive traversal, file size, process lifetime, output limits, and cancellation.
- Add unit/instrumentation tests for lifecycle and path policy.

### M3 — ARM64 Linux userspace
- Evaluate PRoot and rootfs compatibility against supported Android versions and device ABIs.
- Pin runtime bundle versions and SHA-256 digests; verify before extraction.
- Use atomic installation, resumable downloads, disk-space checks, rollback, and clear uninstall behavior.
- Do not claim Docker/Podman, systemd, nested virtualization, or kernel isolation inside PRoot.
- Document battery, thermal, storage, and background-execution limitations.

### M4 — Terminal and preview
- Run commands as argv arrays, never by concatenating untrusted strings into a shell command.
- Provide bounded stdout/stderr streaming, timeout, cancellation, process cleanup, and persistent session metadata.
- Bind preview servers to loopback only; restrict WebView navigation and block file/content access and untrusted external origins.
- Add integration tests for terminal and preview lifecycle.

### M5 — GitHub and build workflow
- Preserve the current GitHub authorization flow and project permission model.
- Add clone/fetch/branch/commit/push/PR flows with least-privilege scopes and explicit confirmation for writes.
- Keep tokens out of logs, environment dumps, runner mounts, and generated artifacts.
- Route remote builds through the existing runner; expose build logs, artifact checksums, and download metadata.

### M6 — Quality and release
- Run Flutter analyze/test, backend pytest/lint, Android unit/instrumentation tests, runtime policy tests, and CI.
- Add security regression tests for path traversal, archive bombs, symlink escapes, command injection, SSRF, and credential leakage.
- Build and verify debug/release artifacts; release signing must use the existing authorized key outside the repository.
- Update README, architecture, security model, setup, troubleshooting, and release notes with only verified capabilities.

## Definition of done

A milestone is complete only when implementation, tests, CI, documentation, and a reproducible verification report exist. A design document or compiling placeholder is not a completed runtime. Any unsupported device/runtime combination must fail closed with a clear explanation.
