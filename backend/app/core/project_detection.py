from dataclasses import dataclass
from pathlib import PurePosixPath


@dataclass(frozen=True, slots=True)
class LanguageAdapter:
    key: str
    display_name: str
    manifest_files: tuple[str, ...]
    capabilities: tuple[str, ...]


ADAPTERS = (
    LanguageAdapter("flutter", "Flutter / Dart", ("pubspec.yaml",), ("inspect", "format", "analyze", "test", "build")),
    LanguageAdapter("javascript", "JavaScript", ("package.json",), ("inspect", "lint", "test", "build")),
    LanguageAdapter("typescript", "TypeScript", ("tsconfig.json", "package.json"), ("inspect", "lint", "test", "build")),
    LanguageAdapter("python", "Python", ("pyproject.toml", "requirements.txt", "setup.py"), ("inspect", "lint", "typecheck", "test")),
    LanguageAdapter("kotlin", "Kotlin", ("build.gradle.kts",), ("inspect", "build", "test")),
    LanguageAdapter("java", "Java", ("pom.xml", "build.gradle", "build.gradle.kts"), ("inspect", "build", "test")),
    LanguageAdapter("go", "Go", ("go.mod",), ("inspect", "format", "test", "build")),
    LanguageAdapter("rust", "Rust", ("Cargo.toml",), ("inspect", "format", "lint", "test", "build")),
    LanguageAdapter("php", "PHP", ("composer.json",), ("inspect", "lint", "test")),
    LanguageAdapter("ruby", "Ruby", ("Gemfile",), ("inspect", "lint", "test")),
    LanguageAdapter("dotnet", ".NET", (".sln", ".csproj"), ("inspect", "build", "test")),
    LanguageAdapter("cpp", "C / C++", ("CMakeLists.txt", "meson.build"), ("inspect", "build", "test")),
    LanguageAdapter("swift", "Swift", ("Package.swift",), ("inspect", "build", "test")),
)


def detect_project(manifest_paths: list[str]) -> list[LanguageAdapter]:
    """Identify project ecosystems from relative manifest paths; never opens files."""
    names = {PurePosixPath(path).name for path in manifest_paths if path and not path.startswith("/")}
    return [adapter for adapter in ADAPTERS if names.intersection(adapter.manifest_files)]
