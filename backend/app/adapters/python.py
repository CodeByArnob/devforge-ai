"""Language adapter for Python (pytest and ruff)."""
import re

from app.adapters.base import BaseLanguageAdapter, DiagnosticItem, TestSummary


class PythonAdapter(BaseLanguageAdapter):
    key = "python"
    display_name = "Python"
    manifest_files = ("pyproject.toml", "requirements.txt", "setup.py")
    pinned_image = "docker.io/library/python@sha256:7b5d19bf9b05c3b17409c2a1e0b0439f0dd186c3d19dd40e8e8ce13a96752dc4"

    def get_dependency_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        if any(f == "requirements.txt" or f.endswith("/requirements.txt") for f in workspace_files):
            return ("python", "-m", "pip", "install", "--no-cache-dir", "-r", "requirements.txt")
        return ("python", "-m", "pip", "install", "--no-cache-dir", "-e", ".")

    def get_lint_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        return ("ruff", "check", ".")

    def get_test_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        return ("pytest", "-q")

    def get_build_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        return ("python", "-m", "build")

    def parse_lint_output(self, stdout: str, stderr: str, exit_code: int) -> list[DiagnosticItem]:
        diagnostics: list[DiagnosticItem] = []
        # Format: path/to/file.py:line:col: RULE message
        pattern = re.compile(r"^(.*?\.py):(\d+):(\d+):\s*([A-Z0-9]+)\s*(.*)", re.MULTILINE)
        for match in pattern.finditer(stdout + "\n" + stderr):
            file_path, line_str, col_str, rule, message = match.groups()
            diagnostics.append(DiagnosticItem(
                file=file_path.strip(),
                line=int(line_str),
                column=int(col_str),
                severity="error",
                message=message.strip(),
                rule=rule.strip(),
            ))
        return diagnostics

    def parse_test_output(self, stdout: str, stderr: str, exit_code: int) -> TestSummary:
        passed = 0
        failed = 0
        errors = 0
        skipped = 0
        failures: list[str] = []

        # Pytest: "5 passed, 1 failed, 2 errors in 0.42s"
        pass_match = re.search(r"(\d+)\s+passed", stdout)
        fail_match = re.search(r"(\d+)\s+failed", stdout)
        err_match = re.search(r"(\d+)\s+error", stdout)
        skip_match = re.search(r"(\d+)\s+skipped", stdout)

        if pass_match:
            passed = int(pass_match.group(1))
        if fail_match:
            failed = int(fail_match.group(1))
        if err_match:
            errors = int(err_match.group(1))
        if skip_match:
            skipped = int(skip_match.group(1))

        total = passed + failed + errors + skipped
        if total == 0 and exit_code == 0:
            total = 1
            passed = 1

        for line in stdout.splitlines():
            if line.startswith("FAILED ") or line.startswith("ERROR "):
                failures.append(line.strip())

        return TestSummary(
            total=total,
            passed=passed,
            failed=failed,
            errors=errors,
            skipped=skipped,
            duration_seconds=0.0,
            failures=failures[:20],
        )

    def parse_build_output(self, stdout: str, stderr: str, exit_code: int) -> list[DiagnosticItem]:
        return self.parse_lint_output(stdout, stderr, exit_code)
