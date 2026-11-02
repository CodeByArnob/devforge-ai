"""Language adapter for Java (Gradle and Maven)."""
import re

from app.adapters.base import BaseLanguageAdapter, DiagnosticItem, TestSummary


class JavaAdapter(BaseLanguageAdapter):
    key = "java"
    display_name = "Java"
    manifest_files = ("pom.xml", "build.gradle", "build.gradle.kts")
    pinned_image = "docker.io/library/gradle@sha256:d89db7880998aa9fa4a2cf529aa24e16ff258ea0b345f8b9ec3a882a16d86db4"

    def _is_maven(self, workspace_files: list[str]) -> bool:
        return any(f == "pom.xml" or f.endswith("/pom.xml") for f in workspace_files)

    def _gradle_bin(self, workspace_files: list[str]) -> str:
        if any(f in ("gradlew", "./gradlew") for f in workspace_files):
            return "./gradlew"
        return "gradle"

    def _mvn_bin(self, workspace_files: list[str]) -> str:
        if any(f in ("mvnw", "./mvnw") for f in workspace_files):
            return "./mvnw"
        return "mvn"

    def get_dependency_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        if self._is_maven(workspace_files):
            return (self._mvn_bin(workspace_files), "dependency:resolve", "-B")
        return (self._gradle_bin(workspace_files), "dependencies", "--no-daemon")

    def get_lint_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        if self._is_maven(workspace_files):
            return (self._mvn_bin(workspace_files), "checkstyle:check", "-B")
        return (self._gradle_bin(workspace_files), "check", "--no-daemon")

    def get_test_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        if self._is_maven(workspace_files):
            return (self._mvn_bin(workspace_files), "test", "-B")
        return (self._gradle_bin(workspace_files), "test", "--no-daemon")

    def get_build_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        if self._is_maven(workspace_files):
            return (self._mvn_bin(workspace_files), "compile", "-B")
        return (self._gradle_bin(workspace_files), "build", "-x", "test", "--no-daemon")

    def parse_lint_output(self, stdout: str, stderr: str, exit_code: int) -> list[DiagnosticItem]:
        diagnostics: list[DiagnosticItem] = []
        # Pattern: [ERROR] /path/to/File.java:[line,col] message
        pattern = re.compile(r"\[(ERROR|WARNING)\]\s*(.*?\.java):\[(\d+),(\d+)\]\s*(.*)", re.MULTILINE)
        for match in pattern.finditer(stdout + "\n" + stderr):
            severity, file_path, line_str, col_str, message = match.groups()
            diagnostics.append(DiagnosticItem(
                file=file_path.strip(),
                line=int(line_str),
                column=int(col_str),
                severity=severity.lower(),
                message=message.strip(),
            ))
        return diagnostics

    def parse_test_output(self, stdout: str, stderr: str, exit_code: int) -> TestSummary:
        total = 0
        passed = 0
        failed = 0
        errors = 0
        skipped = 0
        failures: list[str] = []

        # Maven style: Tests run: 5, Failures: 1, Errors: 0, Skipped: 0
        mvn_match = re.search(r"Tests run:\s*(\d+),\s*Failures:\s*(\d+),\s*Errors:\s*(\d+),\s*Skipped:\s*(\d+)", stdout)
        if mvn_match:
            total = int(mvn_match.group(1))
            failed = int(mvn_match.group(2))
            errors = int(mvn_match.group(3))
            skipped = int(mvn_match.group(4))
            passed = max(0, total - failed - errors - skipped)

        # Gradle style: 10 tests completed, 2 failed
        gradle_match = re.search(r"(\d+)\s+tests completed,\s*(\d+)\s+failed", stdout)
        if gradle_match:
            total = int(gradle_match.group(1))
            failed = int(gradle_match.group(2))
            passed = max(0, total - failed)

        if total == 0 and exit_code == 0:
            total = 1
            passed = 1

        for line in stdout.splitlines():
            if "FAILURE" in line or "FAILED" in line or "ERROR" in line:
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
