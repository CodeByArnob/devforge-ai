from app.core.project_detection import detect_project


def test_detects_multiple_ecosystems():
    matches = detect_project(["pubspec.yaml", "package.json", "tsconfig.json"])
    assert {item.key for item in matches} == {"flutter", "javascript", "typescript"}


def test_unknown_manifest_returns_empty():
    assert detect_project(["README.md", "LICENSE"]) == []


def test_absolute_paths_are_ignored():
    assert detect_project(["/etc/passwd", "Cargo.toml"])[0].key == "rust"
