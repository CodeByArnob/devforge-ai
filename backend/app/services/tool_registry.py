"""Strict allowlisted tool registry with per-role access control."""
from dataclasses import dataclass
from typing import Any


class ToolRegistryError(ValueError):
    pass


class ToolPermissionError(PermissionError):
    pass


@dataclass(frozen=True)
class ToolDefinition:
    name: str
    description: str
    parameters: dict[str, Any]
    allowed_roles: frozenset[str]
    execution_plane: str  # 'control_plane' or 'runner_sandbox'
    requires_human_approval: bool = False


ROLE_PERMISSIONS: dict[str, frozenset[str]] = {
    "architect": frozenset({"inspect_workspace", "read_file"}),
    "planner": frozenset({"inspect_workspace", "read_file"}),
    "coder": frozenset({"inspect_workspace", "read_file", "propose_patch"}),
    "security_reviewer": frozenset({"inspect_workspace", "read_file"}),
    "qa_engineer": frozenset({"inspect_workspace", "read_file", "run_test", "run_lint"}),
    "build_engineer": frozenset({"inspect_workspace", "read_file", "run_dependency_resolve", "run_build"}),
    "repair_engineer": frozenset({"inspect_workspace", "read_file", "propose_patch", "run_test", "run_lint"}),
    "integration_engineer": frozenset({"inspect_workspace", "read_file", "run_test", "run_build"}),
}


ALLOWLISTED_TOOLS: dict[str, ToolDefinition] = {
    "inspect_workspace": ToolDefinition(
        name="inspect_workspace",
        description="Inspect files, directory structure, sizes, and content digests within the project workspace.",
        parameters={
            "type": "object",
            "properties": {
                "max_depth": {"type": "integer", "default": 10, "minimum": 1, "maximum": 20},
                "limit": {"type": "integer", "default": 500, "minimum": 1, "maximum": 2000},
            },
        },
        allowed_roles=frozenset(ROLE_PERMISSIONS.keys()),
        execution_plane="control_plane",
    ),
    "read_file": ToolDefinition(
        name="read_file",
        description="Safely inspect bounded text contents of a project file. Binary files and paths escaping workspace are rejected.",
        parameters={
            "type": "object",
            "required": ["path"],
            "properties": {
                "path": {"type": "string", "maxLength": 500},
                "max_bytes": {"type": "integer", "default": 65536, "minimum": 1, "maximum": 1048576},
            },
        },
        allowed_roles=frozenset(ROLE_PERMISSIONS.keys()),
        execution_plane="control_plane",
    ),
    "propose_patch": ToolDefinition(
        name="propose_patch",
        description="Propose reviewable structured changes to workspace files with expected SHA-256 preconditions and unified diff generation.",
        parameters={
            "type": "object",
            "required": ["changes"],
            "properties": {
                "changes": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "required": ["path"],
                        "properties": {
                            "path": {"type": "string"},
                            "content": {"type": ["string", "null"]},
                            "expected_sha256": {"type": ["string", "null"]},
                        },
                    },
                },
            },
        },
        allowed_roles=frozenset({"coder", "repair_engineer"}),
        execution_plane="control_plane",
        requires_human_approval=True,
    ),
    "run_dependency_resolve": ToolDefinition(
        name="run_dependency_resolve",
        description="Resolve project dependencies through an allowlisted language adapter inside the isolated disposable sandbox.",
        parameters={
            "type": "object",
            "properties": {
                "adapter": {"type": "string"},
            },
        },
        allowed_roles=frozenset({"build_engineer"}),
        execution_plane="runner_sandbox",
    ),
    "run_lint": ToolDefinition(
        name="run_lint",
        description="Execute static analysis or linting via language adapter within the isolated disposable sandbox.",
        parameters={
            "type": "object",
            "properties": {
                "adapter": {"type": "string"},
            },
        },
        allowed_roles=frozenset({"qa_engineer", "repair_engineer"}),
        execution_plane="runner_sandbox",
    ),
    "run_test": ToolDefinition(
        name="run_test",
        description="Execute the test suite via language adapter in the isolated disposable sandbox.",
        parameters={
            "type": "object",
            "properties": {
                "adapter": {"type": "string"},
            },
        },
        allowed_roles=frozenset({"qa_engineer", "repair_engineer", "integration_engineer"}),
        execution_plane="runner_sandbox",
    ),
    "run_build": ToolDefinition(
        name="run_build",
        description="Compile or package the project via language adapter inside the isolated disposable sandbox.",
        parameters={
            "type": "object",
            "properties": {
                "adapter": {"type": "string"},
            },
        },
        allowed_roles=frozenset({"build_engineer", "integration_engineer"}),
        execution_plane="runner_sandbox",
    ),
}


class ToolRegistry:
    @staticmethod
    def get_tool(name: str) -> ToolDefinition:
        if name not in ALLOWLISTED_TOOLS:
            raise ToolRegistryError(f"Tool '{name}' is not registered in the allowlisted tool registry.")
        return ALLOWLISTED_TOOLS[name]

    @staticmethod
    def get_tools_for_role(role: str) -> list[ToolDefinition]:
        if role not in ROLE_PERMISSIONS:
            raise ToolRegistryError(f"Role '{role}' is not a recognized specialist role.")
        permitted = ROLE_PERMISSIONS[role]
        return [tool for name, tool in ALLOWLISTED_TOOLS.items() if name in permitted]

    @staticmethod
    def validate_tool_access(role: str, tool_name: str) -> ToolDefinition:
        tool = ToolRegistry.get_tool(tool_name)
        if role not in tool.allowed_roles:
            raise ToolPermissionError(f"Specialist agent '{role}' does not have permission to invoke tool '{tool_name}'.")
        return tool

    @staticmethod
    def list_all_tools() -> list[ToolDefinition]:
        return list(ALLOWLISTED_TOOLS.values())
