import pytest

from app.services.tool_registry import (
    ToolPermissionError, ToolRegistry, ToolRegistryError,
)


def test_tool_registry_lists_all_tools():
    tools = ToolRegistry.list_all_tools()
    assert len(tools) >= 7
    names = {t.name for t in tools}
    assert "inspect_workspace" in names
    assert "read_file" in names
    assert "propose_patch" in names
    assert "run_test" in names
    assert "run_lint" in names
    assert "run_build" in names
    assert "run_dependency_resolve" in names


def test_role_permissions_enforced():
    # Architect is read-only
    t1 = ToolRegistry.validate_tool_access("architect", "inspect_workspace")
    assert t1.name == "inspect_workspace"

    with pytest.raises(ToolPermissionError, match="does not have permission"):
        ToolRegistry.validate_tool_access("architect", "propose_patch")

    with pytest.raises(ToolPermissionError, match="does not have permission"):
        ToolRegistry.validate_tool_access("planner", "run_test")

    # Coder can propose patches
    t2 = ToolRegistry.validate_tool_access("coder", "propose_patch")
    assert t2.requires_human_approval is True

    # QA engineer can run tests
    t3 = ToolRegistry.validate_tool_access("qa_engineer", "run_test")
    assert t3.execution_plane == "runner_sandbox"

    # Build engineer can run build and dependencies
    ToolRegistry.validate_tool_access("build_engineer", "run_build")
    ToolRegistry.validate_tool_access("build_engineer", "run_dependency_resolve")


def test_unregistered_tool_or_role():
    with pytest.raises(ToolRegistryError, match="not registered"):
        ToolRegistry.get_tool("dangerous_shell")

    with pytest.raises(ToolRegistryError, match="not a recognized specialist role"):
        ToolRegistry.get_tools_for_role("untrusted_agent")
