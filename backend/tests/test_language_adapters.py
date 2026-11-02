from app.adapters.flutter import FlutterAdapter
from app.adapters.java import JavaAdapter
from app.adapters.javascript import JavaScriptAdapter
from app.adapters.python import PythonAdapter
from app.adapters.registry import detect_adapter, get_adapter, list_adapters


def test_flutter_adapter_commands_and_parsing():
    adapter = FlutterAdapter()
    assert "@sha256:" in adapter.pinned_image
    assert adapter.get_dependency_command([]) == ("dart", "pub", "get")
    assert adapter.get_lint_command([]) == ("dart", "analyze", "--fatal-infos")
    assert adapter.get_test_command([]) == ("dart", "test")
    assert adapter.get_build_command([]) == ("dart", "compile", "exe", "lib/main.dart", "-o", "build/app.exe")

    analyzer_output = (
        "Analyzing project...\n"
        "  error • Undefined name 'foo' • lib/main.dart:12:7 • undefined_identifier\n"
        "  warning • Unused import • lib/widgets.dart:2:8 • unused_import\n"
    )
    diagnostics = adapter.parse_lint_output(analyzer_output, "", 1)
    assert len(diagnostics) == 2
    assert diagnostics[0].file == "lib/main.dart"
    assert diagnostics[0].line == 12
    assert diagnostics[0].severity == "error"
    assert diagnostics[0].rule == "undefined_identifier"
    assert diagnostics[1].severity == "warning"

    test_output = "00:03 +14 -1: Some tests failed.\n[E] Failed expectation: expected true but got false\n"
    summary = adapter.parse_test_output(test_output, "", 1)
    assert summary.passed == 14
    assert summary.failed == 1
    assert len(summary.failures) == 1


def test_java_adapter_gradle_and_maven():
    adapter = JavaAdapter()
    assert "@sha256:" in adapter.pinned_image

    # Gradle detection
    gradle_files = ["build.gradle", "gradlew", "src/main/java/App.java"]
    assert adapter.get_dependency_command(gradle_files) == ("./gradlew", "dependencies", "--no-daemon")
    assert adapter.get_lint_command(gradle_files) == ("./gradlew", "check", "--no-daemon")
    assert adapter.get_test_command(gradle_files) == ("./gradlew", "test", "--no-daemon")
    assert adapter.get_build_command(gradle_files) == ("./gradlew", "build", "-x", "test", "--no-daemon")

    # Maven detection
    mvn_files = ["pom.xml", "mvnw", "src/main/java/App.java"]
    assert adapter.get_dependency_command(mvn_files) == ("./mvnw", "dependency:resolve", "-B")
    assert adapter.get_lint_command(mvn_files) == ("./mvnw", "checkstyle:check", "-B")
    assert adapter.get_test_command(mvn_files) == ("./mvnw", "test", "-B")
    assert adapter.get_build_command(mvn_files) == ("./mvnw", "compile", "-B")

    # Error parsing
    compiler_output = "[ERROR] /app/src/main/java/App.java:[42,15] cannot find symbol\n"
    diagnostics = adapter.parse_lint_output(compiler_output, "", 1)
    assert len(diagnostics) == 1
    assert diagnostics[0].file == "/app/src/main/java/App.java"
    assert diagnostics[0].line == 42
    assert diagnostics[0].column == 15
    assert diagnostics[0].message == "cannot find symbol"

    # Test summary parsing
    mvn_test_output = "Results : \n\nTests run: 12, Failures: 1, Errors: 0, Skipped: 1\n"
    summary = adapter.parse_test_output(mvn_test_output, "", 1)
    assert summary.total == 12
    assert summary.failed == 1
    assert summary.skipped == 1
    assert summary.passed == 10


def test_python_and_javascript_adapters():
    py = PythonAdapter()
    assert "@sha256:" in py.pinned_image
    assert py.get_test_command([]) == ("pytest", "-q")
    py_test = "5 passed, 1 failed in 0.12s\nFAILED tests/test_a.py::test_foo\n"
    py_summary = py.parse_test_output(py_test, "", 1)
    assert py_summary.passed == 5
    assert py_summary.failed == 1

    js = JavaScriptAdapter()
    assert "@sha256:" in js.pinned_image
    assert js.get_dependency_command([]) == ("npm", "ci")
    assert js.get_lint_command([]) == ("npm", "run", "lint")


def test_adapter_registry_and_detection():
    assert isinstance(get_adapter("flutter"), FlutterAdapter)
    assert isinstance(get_adapter("java"), JavaAdapter)
    assert isinstance(get_adapter("python"), PythonAdapter)

    assert isinstance(detect_adapter(["pubspec.yaml", "lib/main.dart"]), FlutterAdapter)
    assert isinstance(detect_adapter(["pom.xml", "src/App.java"]), JavaAdapter)
    assert isinstance(detect_adapter(["pyproject.toml", "src/main.py"]), PythonAdapter)
    assert isinstance(detect_adapter(["package.json", "index.js"]), JavaScriptAdapter)
    assert detect_adapter(["unrelated.txt"]) is None

    assert len(list_adapters()) >= 4
