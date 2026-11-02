"""Language adapter for JavaScript and TypeScript (npm, eslint, and test frameworks)."""
import re

from app.adapters.base import BaseLanguageAdapter, DiagnosticItem, TestSummary


class JavaScriptAdapter(BaseLanguageAdapter):
    key = "javascript"
    display_name = "JavaScript / TypeScript"
    manifest_files = ("package.json", "tsconfig.json")
    pinned_image = "docker.io/library/node@sha256:690cf83b772ae86772fa82d495fb6be3e045a2723c0f4f9f7bf67ddbb38fae5d"

    def get_dependency_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        return ("npm", "ci")

    def get_lint_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        return ("npm", "run", "lint")

    def get_test_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        return ("npm", "test")

    def get_build_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        return ("npm", "run", "build")

    def parse_lint_output(self, stdout: str, stderr: str, exit_code: int) -> list[DiagnosticItem]:
        diagnostics: list[DiagnosticItem] = []
        # ESLint: /path/to/file.js:line:col: message [rule]
        pattern = re.compile(r"^\s*(.*?):(\d+):(\d+):\s*(.*?)\s+\[(.*?)\]", re.MULTILINE)
        for match in pattern.finditer(stdout + "\n" + stderr):
            file_path, line_str, col_str, message, rule = match.groups()
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
        failures: list[str] = []

        pass_match = re.search(r"(\d+)\s+passing", stdout)
        fail_match = re.search(r"(\d+)\s+failing", stdout)
        if pass_match:
            passed = int(pass_match.group(1))
        if fail_match:
            failed = int(fail_match.group(1))

        # Jest style: Tests: 2 failed, 8 passed, 10 total
        jest_match = re.search(r"Tests:\s*(?:(\d+)\s+failed,\s*)?(?:(\d+)\s+passed,\s*)?(\d+)\s+total", stdout)
        if jest_match:
            failed = int(jest_match.group(1) or 0)
            passed = int(jest_match.group(2) or 0)

        total = passed + failed
        if total == 0 and exit_code == 0:
            total = 1
            passed = 1

        for line in stdout.splitlines():
            if "✕" in line or "FAIL " in line:
                failures.append(line.strip())

        return TestSummary(
            total=total,
            passed=passed,
            failed=failed,
            errors=0,
            skipped=0,
            duration_seconds=0.0,
            failures=failures[:20],
        )

    def parse_build_output(self, stdout: str, stderr: str, exit_code: int) -> list[DiagnosticItem]:
        return self.parse_lint_output(stdout, stderr, exit_code)
