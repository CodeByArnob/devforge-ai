import asyncio
import json

import httpx
import pytest

from app.services.multi_agent_orchestrator import MultiAgentOrchestrator
from app.services.openrouter_gateway import OpenRouterError


def response_for(role: str) -> dict:
    return {
        "id": f"test-{role}",
        "choices": [{
            "message": {
                "content": json.dumps({
                    "role": role,
                    "summary": f"{role} summary",
                    "findings": [f"{role} finding"],
                    "proposed_steps": [f"{role} step"],
                    "risks": [f"{role} risk"],
                    "requires_human_approval": True,
                })
            }
        }],
    }


def test_runs_four_specialists_and_aggregates_their_results():
    requested_roles = []

    async def handler(request: httpx.Request) -> httpx.Response:
        body = json.loads(request.content)
        system_prompt = body["messages"][0]["content"] + body["messages"][1]["content"]
        role = next(
            name for name in ("architect", "planner", "security_reviewer", "qa_engineer")
            if f"role: {name}" in system_prompt
        )
        requested_roles.append(role)
        return httpx.Response(200, json=response_for(role))

    async def scenario():
        orchestrator = MultiAgentOrchestrator(transport=httpx.MockTransport(handler))
        return await orchestrator.run_team(
            api_key="test-provider-key",
            model="openrouter/free",
            instruction="Add an isolated execution worker.",
        )

    plan = asyncio.run(scenario())
    assert set(requested_roles) == {"architect", "planner", "security_reviewer", "qa_engineer"}
    assert len(plan.agents) == 4
    assert len(plan.steps) == 4
    assert plan.approval_required is True
    assert plan.execution_enabled is False
    assert any(item.startswith("security_reviewer:") for item in plan.assumptions)


def test_free_model_policy_is_enforced_before_provider_call():
    orchestrator = MultiAgentOrchestrator()
    with pytest.raises(ValueError, match="free"):
        orchestrator.validate_model("paid/model")


def test_provider_error_fails_the_team_without_partial_plan():
    async def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(429, json={"error": {"message": "rate limited"}})

    async def scenario():
        orchestrator = MultiAgentOrchestrator(transport=httpx.MockTransport(handler))
        await orchestrator.run_team(
            api_key="test-provider-key",
            model="test-model:free",
            instruction="Do a safe change.",
        )

    with pytest.raises(OpenRouterError):
        asyncio.run(scenario())


def test_invalid_role_identity_is_rejected():
    async def handler(_: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json=response_for("planner"))

    async def scenario():
        orchestrator = MultiAgentOrchestrator(transport=httpx.MockTransport(handler))
        await orchestrator.run_team(
            api_key="test-provider-key",
            model="test-model:free",
            instruction="Do a safe change.",
        )

    with pytest.raises(OpenRouterError, match="mismatched"):
        asyncio.run(scenario())


def test_runs_all_eight_specialist_agents_concurrently():
    from app.services.multi_agent_orchestrator import ALL_SPECIALIST_ROLES

    requested_roles = []

    async def handler(request: httpx.Request) -> httpx.Response:
        body = json.loads(request.content)
        system_prompt = body["messages"][0]["content"] + body["messages"][1]["content"]
        role = next(name for name in ALL_SPECIALIST_ROLES if f"role: {name}" in system_prompt)
        requested_roles.append(role)
        return httpx.Response(200, json=response_for(role))

    async def scenario():
        orchestrator = MultiAgentOrchestrator(transport=httpx.MockTransport(handler))
        return await orchestrator.run_full_team(
            api_key="test-provider-key",
            model="openrouter/free",
            instruction="Implement complete feature with build, test, and repair verification.",
        )

    plan = asyncio.run(scenario())
    assert set(requested_roles) == set(ALL_SPECIALIST_ROLES)
    assert len(plan.agents) == 8
    assert len(plan.steps) == 8
    assert plan.approval_required is True

    # Check permitted tools are populated on agents
    coder_agent = next(a for a in plan.agents if a.role == "coder")
    assert "propose_patch" in coder_agent.permitted_tools
    assert "run_build" not in coder_agent.permitted_tools

    build_agent = next(a for a in plan.agents if a.role == "build_engineer")
    assert "run_build" in build_agent.permitted_tools
