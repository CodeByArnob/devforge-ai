"""Language adapter for Flutter and Dart."""
import re

from app.adapters.base import BaseLanguageAdapter, DiagnosticItem, TestSummary


class FlutterAdapter(BaseLanguageAdapter):
    key = "flutter"
    display_name = "Flutter / Dart"
    manifest_files = ("pubspec.yaml",)
    pinned_image = "docker.io/library/dart@sha256:8b09339e08dd16c14178385a8523fc67243aa5ee289f6b9868be22086438eeeb"

    def get_dependency_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        return ("dart", "pub", "get")

    def get_lint_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        return ("dart", "analyze", "--fatal-infos")

    def get_test_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        return ("dart", "test")

    def get_build_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        # If lib/main.dart exists, compile exe or flutter build bundle
        return ("dart", "compile", "exe", "lib/main.dart", "-o", "build/app.exe")

    def parse_lint_output(self, stdout: str, stderr: str, exit_code: int) -> list[DiagnosticItem]:
        diagnostics: list[DiagnosticItem] = []
        # Example format: "  error • Undefined name 'x' • lib/main.dart:10:5 • undefined_identifier"
        pattern = re.compile(r"^\s*(error|warning|info)\s*•\s*(.*?)\s*•\s*(.*?):(\d+):(\d+)\s*•\s*([a-zA-Z0-9_]+)", re.MULTILINE)
        for match in pattern.finditer(stdout + "\n" + stderr):
            severity, message, file_path, line_str, col_str, rule = match.groups()
            diagnostics.append(DiagnosticItem(
                file=file_path.strip(),
                line=int(line_str),
                column=int(col_str),
                severity=severity.lower(),
                message=message.strip(),
                rule=rule.strip(),
            ))
        return diagnostics

    def parse_test_output(self, stdout: str, stderr: str, exit_code: int) -> TestSummary:
        total = 0
        passed = 0
        failed = 0
        failures: list[str] = []

        # Example summary: "All tests passed!" or "00:01 +10 -2: Some tests failed."
        summary_match = re.search(r"\+(\d+)(?:\s+-(\d+))?", stdout)
        if summary_match:
            passed = int(summary_match.group(1))
            failed = int(summary_match.group(2) or 0)
            total = passed + failed
        elif "All tests passed!" in stdout or exit_code == 0:
            passed = 1
            total = 1

        for line in stdout.splitlines():
            if line.startswith("[E] ") or "Expected: " in line:
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
