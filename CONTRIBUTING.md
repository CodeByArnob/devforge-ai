# Contributing to DevForge AI

Welcome to the **DevForge AI** open-source contributor guide. DevForge AI is an autonomous, multi-language software engineering platform engineered with isolated Podman sandboxes, an 8-role specialist AI agent team, copy-on-write workspace snapshots with human-in-the-loop diff approvals, and a native Flutter client for Android, Web, and Desktop.

We actively encourage and appreciate genuine bug fixes, security enhancements, documentation improvements, and architectural extensions from engineers and researchers worldwide.

This guide provides a step-by-step walkthrough of our development standards, testing methodologies, and automated pull request verification system.

---

## Table of Contents
1. [Architecture & Codebase Overview](#1-architecture--codebase-overview)
2. [Code of Conduct & Principles](#2-code-of-conduct--principles)
3. [Finding Issues & Reporting Bugs](#3-finding-issues--reporting-bugs)
4. [Setting Up Local Development](#4-setting-up-local-development)
5. [Step-by-Step Bug Fixing Guide](#5-step-by-step-bug-fixing-guide)
6. [Local Quality & Verification Commands](#6-local-quality--verification-commands)
7. [Conventional Commits Standard](#7-conventional-commits-standard)
8. [Automated PR Triage & Verification Bot](#8-automated-pr-triage--verification-bot)
9. [Zero-Tolerance Security Invariants](#9-zero-tolerance-security-invariants)
10. [Contributor Checklist](#10-contributor-checklist)

---

## 1. Architecture & Codebase Overview

Before making changes, familiarize yourself with the four core components of DevForge AI:

```
devforge-ai/
├── backend/                  # FastAPI Control Plane (Python 3.12+)
│   ├── app/
│   │   ├── api/v1/          # REST & SSE endpoints (auth, projects, agents, tasks)
│   │   ├── core/            # Security, JWT tokens, Argon2 hashing, config
│   │   ├── models/          # SQLAlchemy relational data models
│   │   └── services/        # Ingestion, OpenRouter proxy, snapshot engine
│   └── tests/               # 77+ Pytest unit and integration test suite
├── runner/                   # Isolated Execution Engine (Python)
│   ├── runner_service.py    # Atomic task leasing, heartbeats, cancellation
│   ├── container_engine.py  # Rootless Podman runtime (UID 65532, --network=none)
│   └── tool_registry.py     # Role-based tool registry with sandboxed execution
├── client/                   # Cross-Platform Developer IDE (Flutter 3.44+)
│   ├── lib/ui/screens/      # 5 primary tabs: Home, Projects, AI Studio, Editor, Builds
│   ├── lib/core/            # SecureVault, API clients, local persistence
│   └── test/                # Unit and widget test suite
├── infra/                    # Deployment, Alembic migrations, Docker Compose
└── docs/                     # Documentation, GitHub Pages showcase, architecture specs
```

---

## 2. Code of Conduct & Principles

- **Security First**: Never expose ambient credentials, private keys, or bypass container sandbox restrictions.
- **Human-in-the-Loop**: Autonomous agent patches must always produce reviewable unified diffs before disk mutation.
- **Zero Flakiness**: Unit, widget, and integration tests must pass deterministically across all operating systems.
- **Clean Communication**: Be respectful, constructive, and precise in issue discussions and pull request reviews.

---

## 3. Finding Issues & Reporting Bugs

### Finding an Issue to Work On
Explore the repository's [Issues](https://github.com/CodeByArnob/devforge-ai/issues) tab. Look for issues labeled:
- `good first issue`: Ideal starting tasks for new contributors.
- `bug`: Confirmed defects needing reproduction and a verified patch.
- `help wanted`: Architectural features or optimizations ready for implementation.

Before writing code for a new feature, comment on the issue or open a proposal discussion to align with maintainers.

### Reporting a Genuine Bug
When reporting an issue, provide:
1. **Clear Description**: What occurred versus what was expected.
2. **Environment Details**: Operating System, Python version, Flutter version, container runtime (Podman or Docker).
3. **Minimal Reproduction Steps**: Exact commands or API payloads that reproduce the failure.
4. **Relevant Logs**: Terminal stack traces or error logs (sanitize any personal tokens or IPs).

---

## 4. Setting Up Local Development

### Prerequisites
- Python 3.12 or newer
- Flutter SDK 3.44 or newer
- Git 2.40+
- Podman (recommended for sandbox execution) or Docker

### Step 1: Clone the Repository
```bash
git clone https://github.com/CodeByArnob/devforge-ai.git
cd devforge-ai
```

### Step 2: Backend Control Plane Setup
```bash
# Create and activate a Python virtual environment
python -m venv .venv

# On Linux/macOS:
source .venv/bin/activate
# On Windows (PowerShell):
.venv\Scripts\Activate.ps1

# Install backend dependencies in editable mode
pip install --upgrade pip
pip install -e ".[dev]"

# Apply database migrations
alembic upgrade head

# Start local FastAPI server
uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload
```
The API Swagger documentation will be available at: `http://localhost:8000/docs`.

### Step 3: Runner Engine Setup
In a separate terminal with the virtual environment activated:
```bash
python -m runner.runner_service --control-plane http://localhost:8000 --token dev-worker-token
```

### Step 4: Flutter Client Setup
In a third terminal:
```bash
cd client
flutter pub get

# Run on Chrome (Web):
flutter run -d chrome

# Run on Android (Connected device or emulator):
flutter run -d android

# Run on Windows Desktop:
flutter run -d windows
```

---

## 5. Step-by-Step Bug Fixing Guide

Follow this proven workflow to fix bugs cleanly:

### Step 1: Create a Dedicated Branch
Never commit directly to `main`. Create a descriptive feature/bugfix branch:
```bash
git checkout -b fix/auth-token-refresh
# Or for features:
git checkout -b feat/add-go-builder
```

### Step 2: Reproduce with a Failing Test
Adopt a Test-Driven Development (TDD) approach:
1. Locate the test directory for the affected component (`backend/tests/` or `client/test/`).
2. Write a unit or integration test that reproduces the bug and demonstrates failure.
3. Run the test to confirm it fails:
   ```bash
   pytest backend/tests/test_failing_case.py
   ```

### Step 3: Implement the Fix
Write the minimal, clean code change that resolves the failure without causing regressions:
- Respect data models and database migrations (if altering schemas, generate a new Alembic migration via `alembic revision -m "..."`).
- Adhere to rootless Podman execution security boundaries (UID 65532, dropped capabilities).
- Maintain offline-first error resilience in Flutter screens (`editor_screen.dart`, `login_screen.dart`).

### Step 4: Verify Locally
Ensure your new test and all existing test suites pass:
```bash
pytest
cd client && flutter test
```

---

## 6. Local Quality & Verification Commands

Before opening a pull request, run the exact test commands used by our CI system:

### Backend Quality Suite
```bash
# 1. Python code linting
ruff check backend runner

# 2. Database migrations check
alembic upgrade head

# 3. Unit and integration tests with coverage
pytest --cov=app --cov-report=term-missing
```

### Flutter Client Quality Suite
```bash
cd client

# 1. Dependency check
flutter pub get

# 2. Static analysis
flutter analyze

# 3. Widget & unit tests
flutter test
```

---

## 7. Conventional Commits Standard

We require standardized conventional commits so our automated release and changelog pipelines function seamlessly.

Format: `<type>(<optional-scope>): <description>`

### Allowed Types:
- `fix`: A bug fix (e.g., `fix(client): handle socket timeout gracefully during offline mode`).
- `feat`: A new feature (e.g., `feat(runner): add isolated Go build adapter`).
- `docs`: Documentation updates (e.g., `docs: clarify podman installation prerequisites`).
- `test`: Adding or correcting tests (e.g., `test(backend): add test for zip path traversal rejection`).
- `refactor`: Code change that neither fixes a bug nor adds a feature.
- `perf`: A code change that improves performance.
- `ci`: Changes to CI/CD workflows and automation scripts.
- `chore`: Maintenance tasks, dependency bumps, or tool configurations.

> [!IMPORTANT]
> **Typography Constraint**: Never use the em-dash character (long dash) in commit messages or code. Use standard ASCII hyphens (`-`).

---

## 8. Automated PR Triage & Verification Bot

DevForge AI features an automated pull request verification system (`.github/workflows/pr-automation.yml`).

When you open a pull request targeting `main`:
1. **Conventional Commit Check**: The bot verifies that your PR title follows Conventional Commits.
2. **Security & Secret Scanner**: The bot scans all modified files to ensure zero private keys, certificates, or `.env` files are leaked.
3. **Full Automated Test Suite**:
   - Executes Pytest backend tests (77+ tests).
   - Validates Alembic schema migrations.
   - Executes Ruff static linting.
   - Executes Flutter static analysis and widget/unit tests.
4. **Automated Triage & Labeling**:
   - The bot automatically applies component labels (`area:backend`, `area:client`, `area:runner`, `area:docs`, `area:ci`).
   - If all quality and security checks succeed, the bot awards the **`status: verified`** and **`genuine-contribution`** badges and approves the pull request.
5. **Maintainer Merge**: Once verified by the automation and reviewed by maintainers, your contribution is merged into `main` and included in the next production release!

---

## 9. Zero-Tolerance Security Invariants

We enforce strict security boundaries. Any PR violating these invariants will be rejected by the automated gate:

1. **No Staged Secrets**: Never commit `.env`, `credentials.json`, `*.keystore`, `*.jks`, `*.pem`, `*.key`, or private tokens.
2. **Hardened Sandbox Isolation**: The runner must never run untrusted code outside the rootless container sandbox. Containers must execute with dropped capabilities (`cap-drop=ALL`), non-root UID 65532, and default-deny networking.
3. **Fenced Worker Leases**: Job processing must respect cryptographic lease tokens and periodic heartbeat expiry to prevent split-brain execution.
4. **Copy-on-Write Snapshots**: All filesystem modifications must be bounded by snapshot history allowing instant rollback.

---

## 10. Contributor Checklist

Before submitting your pull request, verify:

- [ ] I branched from latest `main`.
- [ ] My PR title follows Conventional Commits (e.g., `fix(runner): prevent lease expiry race condition`).
- [ ] I have not committed any `.env` files, API keys, or private signing keystores.
- [ ] Backend tests pass locally (`pytest`, 77/77 passed).
- [ ] Python linter passes locally (`ruff check backend runner`).
- [ ] Flutter analysis passes locally (`flutter analyze`, 0 issues).
- [ ] Flutter tests pass locally (`flutter test`, 4/4 passed).
- [ ] I filled out the [Pull Request Template](.github/pull_request_template.md) completely with testing evidence.

Thank you for building the future of autonomous software engineering with DevForge AI!
