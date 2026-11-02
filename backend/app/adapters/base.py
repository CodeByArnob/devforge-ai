"""Base contract for language-specific build, lint, test, and dependency adapters."""
from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class DiagnosticItem:
    file: str
    line: int | None
    column: int | None
    severity: str  # error, warning, info
    message: str
    rule: str | None = None


@dataclass(frozen=True)
class TestSummary:
    total: int
    passed: int
    failed: int
    errors: int
    skipped: int
    duration_seconds: float
    failures: list[str]


class BaseLanguageAdapter(ABC):
    key: str
    display_name: str
    manifest_files: tuple[str, ...]
    pinned_image: str

    @abstractmethod
    def get_dependency_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        """Return non-empty argv command to resolve/fetch dependencies."""

    @abstractmethod
    def get_lint_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        """Return non-empty argv command to run linter or static analyzer."""

    @abstractmethod
    def get_test_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        """Return non-empty argv command to run automated tests."""

    @abstractmethod
    def get_build_command(self, workspace_files: list[str]) -> tuple[str, ...]:
        """Return non-empty argv command to build/compile the project."""

    @abstractmethod
    def parse_test_output(self, stdout: str, stderr: str, exit_code: int) -> TestSummary:
        """Parse test stdout/stderr into structured TestSummary."""

    @abstractmethod
    def parse_lint_output(self, stdout: str, stderr: str, exit_code: int) -> list[DiagnosticItem]:
        """Parse linter stdout/stderr into structured DiagnosticItems."""

    @abstractmethod
    def parse_build_output(self, stdout: str, stderr: str, exit_code: int) -> list[DiagnosticItem]:
        """Parse build compiler stdout/stderr into structured DiagnosticItems."""
