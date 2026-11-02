from app.schemas.ai import AgentPlan


def test_agent_plan_schema_requires_actionable_steps():
    plan = AgentPlan.model_validate({
        "summary": "Inspect and plan a safe fix.",
        "assumptions": [],
        "steps": ["Inspect repository manifests", "Prepare a patch for approval"],
        "risks": ["No repository snapshot is attached yet"],
        "needs_project_files": True,
    })
    assert len(plan.steps) == 2


def test_agent_plan_rejects_empty_steps():
    try:
        AgentPlan.model_validate({
            "summary": "No steps",
            "steps": [],
        })
    except Exception:
        return
    raise AssertionError("An agent plan must contain at least one step")
