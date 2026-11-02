"""Registry of language-specific execution and build adapters."""
from pathlib import PurePosixPath

from app.adapters.base import BaseLanguageAdapter
from app.adapters.flutter import FlutterAdapter
from app.adapters.java import JavaAdapter
from app.adapters.javascript import JavaScriptAdapter
from app.adapters.python import PythonAdapter

ADAPTERS: dict[str, BaseLanguageAdapter] = {
    "flutter": FlutterAdapter(),
    "dart": FlutterAdapter(),
    "java": JavaAdapter(),
    "kotlin": JavaAdapter(),
    "python": PythonAdapter(),
    "javascript": JavaScriptAdapter(),
    "typescript": JavaScriptAdapter(),
}


def get_adapter(key: str) -> BaseLanguageAdapter:
    normalized = key.strip().lower()
    if normalized not in ADAPTERS:
        raise LookupError(f"No execution adapter registered for language '{key}'.")
    return ADAPTERS[normalized]


def detect_adapter(manifest_paths: list[str]) -> BaseLanguageAdapter | None:
    names = {PurePosixPath(p).name for p in manifest_paths if p and not p.startswith("/")}
    for adapter in (FlutterAdapter(), JavaAdapter(), PythonAdapter(), JavaScriptAdapter()):
        if any(m in names for m in adapter.manifest_files):
            return adapter
    return None


def list_adapters() -> list[BaseLanguageAdapter]:
    seen = set()
    result = []
    for adapter in ADAPTERS.values():
        if adapter.key not in seen:
            seen.add(adapter.key)
            result.append(adapter)
    return result
