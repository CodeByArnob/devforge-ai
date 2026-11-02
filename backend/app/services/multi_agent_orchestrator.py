import asyncio
import json

import httpx
from pydantic import ValidationError

from app.schemas.ai import AgentRoleResult, AgentTeamPlan
from app.services.openrouter_gateway import FREE_ROUTER_ID, OpenRouterError

OPENROUTER_CHAT_URL = "https://openrouter.ai/api/v1/chat/completions"

ROLE_PROMPTS: dict[str, str] = {
    "architect": (
        "Act as the software architect. Identify boundaries, data flow, interfaces, dependencies, "
        "migration and integration strategy. Do not assume files were inspected."
    ),
    "planner": (
        "Act as the implementation planner. Break the request into ordered, small, testable tasks. "
        "Identify prerequisites and acceptance criteria. Do not claim work was performed."
    ),
    "security_reviewer": (
        "Act as an application security reviewer. Identify trust boundaries, authorization, secrets, "
        "input validation, supply-chain and sandbox risks. Prefer deny-by-default and least privilege."
    ),
    "qa_engineer": (
        "Act as a senior QA engineer. Define unit, integration, regression and failure-path tests, "
        "and measurable acceptance criteria. Do not claim tests were run."
    ),
}


class MultiAgentOrchestrator:
    """Runs independent specialist agents concurrently; it never executes project code."""

    def __init__(
        self,
        transport: httpx.AsyncBaseTransport | None = None,
        timeout_seconds: float = 90.0,
    ) -> None:
        self.transport = transport
        self.timeout_seconds = timeout_seconds

    @staticmethod
    def validate_model(model: str) -> None:
        if not (model == FREE_ROUTER_ID or model.endswith(":free")):
            raise ValueError("Only explicitly free OpenRouter models are enabled.")

    async def _run_role(
        self,
        client: httpx.AsyncClient,
        api_key: str,
        model: str,
        role: str,
        instruction: str,
        project_context: str,
    ) -> AgentRoleResult:
        system_prompt = (
            "You are one specialist in a multi-agent software engineering team. "
            "Return a JSON object only with keys role, summary, findings, proposed_steps, risks, "
            "requires_human_approval. role must exactly equal the assigned role. "
            "Do not invent repository facts, claim tools were used, expose secrets, or propose "
            "running untrusted code on the API host. Require human approval for all code changes. "
            + ROLE_PROMPTS[role]
        )
        response = await client.post(
            OPENROUTER_CHAT_URL,
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            json={
                "model": model,
                "temperature": 0.1,
                "max_tokens": 1400,
                "response_format": {"type": "json_object"},
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {
                        "role": "user",
                        "content": (
                            f"Assigned role: {role}\nUser request:\n{instruction}\n"
                            f"Verified project context (may be empty):\n{project_context[:12000]}"
                        ),
                    },
                ],
            },
        )
        response.raise_for_status()
        try:
            raw = response.json()["choices"][0]["message"]["content"]
            result = AgentRoleResult.model_validate(json.loads(raw))
        except (KeyError, IndexError, TypeError, json.JSONDecodeError, ValidationError) as exc:
            raise OpenRouterError(f"The {role} agent returned an invalid structured response.") from exc
        if result.role != role:
            raise OpenRouterError(f"The {role} agent returned a mismatched role identity.")
        return result

    async def run_team(
        self,
        api_key: str,
        model: str,
        instruction: str,
        project_context: str = "",
    ) -> AgentTeamPlan:
        self.validate_model(model)
        try:
            async with httpx.AsyncClient(
                timeout=self.timeout_seconds, transport=self.transport
            ) as client:
                results = await asyncio.gather(
                    *(
                        self._run_role(client, api_key, model, role, instruction, project_context)
                        for role in ROLE_PROMPTS
                    )
                )
        except OpenRouterError:
            raise
        except (httpx.HTTPError, ValueError) as exc:
            raise OpenRouterError(
                "Multi-agent planning failed. Check the provider key, free model and network response."
            ) from exc

        unique_steps: list[str] = []
        assumptions: list[str] = []
        risks: list[str] = []
        for agent in results:
            for step in agent.proposed_steps:
                if step not in unique_steps and len(unique_steps) < 20:
                    unique_steps.append(step)
            for finding in agent.findings:
                if len(assumptions) < 20 and finding not in assumptions:
                    assumptions.append(f"{agent.role}: {finding}")
            for risk in agent.risks:
                if len(risks) < 30 and risk not in risks:
                    risks.append(f"{agent.role}: {risk}")

        if not unique_steps:
            raise OpenRouterError("The agent team did not produce an actionable implementation plan.")
        summary = next((agent.summary for agent in results if agent.role == "architect"), results[0].summary)
        return AgentTeamPlan(
            summary=summary,
            model=model,
            agents=results,
            assumptions=assumptions,
            steps=unique_steps,
            risks=risks,
            approval_required=True,
            execution_enabled=False,
        )
