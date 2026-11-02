## 🛠️ Pull Request Description

### 1. Summary of Changes
<!-- Provide a clear, concise summary of what bug was resolved or what feature was introduced. -->

### 2. Issue Reference
<!-- Link the issue resolved by this PR (e.g., Fixes #12, Closes #45). -->
Fixes #

### 3. Impacted Area
- [ ] `backend/` (FastAPI, SQLAlchemy, Database, Sandboxing)
- [ ] `client/` (Flutter Mobile/Desktop UI, State Management, Vault)
- [ ] `runner/` (Autonomous worker lifecycle, leasing, tool execution)
- [ ] `infra/` (Docker, Podman, Deployment configurations)
- [ ] `docs/` (Architecture guides, API documentation, GitHub Pages)
- [ ] `.github/` (Workflows, automation, CI/CD)

### 4. Verification & Testing Evidence
<!-- Paste terminal outputs or test evidence demonstrating that local tests pass cleanly. -->
- **Backend Tests (`pytest`)**:
  ```bash
  # Output: 77 passed
  ```
- **Flutter Analysis & Tests**:
  ```bash
  # Output: No issues found! / All tests passed!
  ```

### 5. Contributor Security & Quality Checklist
- [ ] PR title adheres to **Conventional Commits** (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `perf:`, `chore:`).
- [ ] No secrets, `.env` files, keystores, or private tokens are staged or committed.
- [ ] Code is formatted and passes linters (`ruff check`, `flutter analyze`).
- [ ] New code includes corresponding unit or widget tests.
- [ ] Documentation has been updated to reflect architectural changes where appropriate.
