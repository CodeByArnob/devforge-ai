# Contributing to DevForge AI

Thank you for contributing to DevForge AI! Follow these guidelines to ensure smooth integration of features and bug fixes.

## Development Setup

1. **Backend Environment**:
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # Or on Windows: .venv\Scripts\Activate.ps1
   pip install -e ".[dev]"
   alembic upgrade head
   ```

2. **Runner Service**:
   ```bash
   python -m runner.runner_service --control-plane http://localhost:8000 --token dev-worker-token
   ```

3. **Flutter / Android Client**:
   ```bash
   cd client
   flutter pub get
   flutter run -d chrome  # Or: flutter run -d android
   ```

## Code Quality Standards

Before opening a pull request or committing code, ensure all local checks pass:

- **Backend tests**: `pytest`
- **Python linter**: `ruff check backend runner`
- **Flutter tests**: `flutter test` (in `client/`)
- **Flutter analyze**: `flutter analyze` (in `client/`)

## Pull Request Guidelines

- Create a feature branch: `git checkout -b feat/your-feature-name`
- Follow conventional commits (`feat: ...`, `fix: ...`, `test: ...`, `docs: ...`).
- Never commit credentials, `.env` files, or signing keys.
- Ensure all CI/CD checks pass cleanly.
