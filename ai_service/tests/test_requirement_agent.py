"""
Tests for the Requirement & Product Discovery Agent (Member 01).
Uses the real Gemini model to validate the true ReAct agent loop.
"""
import pytest
from ai_service.agents.requirement_agent.agent import (
    run_requirement_chat,
    REQUIREMENT_GRAPH,
    CHECKPOINTER,
    update_requirement_profile,
    confirm_requirements,
    _apply_profile_update,
    _recalculate_missing,
)
from ai_service.agents.requirement_agent.models import RequirementProfile


# --------------------------------------------------------------------------
# Unit tests (no LLM calls — fast, deterministic)
# --------------------------------------------------------------------------

def test_update_requirement_profile_tool_schema():
    """Verify the tool's docstring and args are correctly exposed (Lab 05 pattern)."""
    assert update_requirement_profile.name == "update_requirement_profile"
    assert "budget" in update_requirement_profile.description.lower()
    assert "purpose" in update_requirement_profile.description.lower()

    assert confirm_requirements.name == "confirm_requirements"
    assert "confirm" in confirm_requirements.description.lower()


def test_apply_profile_update_non_destructive():
    """Verify _apply_profile_update only overwrites fields that are provided."""
    profile = RequirementProfile(purpose="Gaming", budget_amount=400000, currency="LKR")

    # Update only resolution — purpose and budget must survive
    updated = _apply_profile_update(profile, {"target_resolution": "4K"})
    assert updated.purpose == "Gaming"
    assert updated.budget_amount == 400000
    assert updated.currency == "LKR"
    assert updated.target_resolution == "4K"

    # Update budget — purpose and resolution must survive
    updated2 = _apply_profile_update(updated, {"budget_amount": 500000, "currency": "LKR"})
    assert updated2.purpose == "Gaming"
    assert updated2.target_resolution == "4K"
    assert updated2.budget_amount == 500000


def test_recalculate_missing_fields():
    """Verify missing_fields is correctly computed."""
    empty = _recalculate_missing(RequirementProfile())
    assert "purpose" in empty.missing_fields
    assert "budget" in empty.missing_fields
    assert "target_resolution" in empty.missing_fields
    assert "monitor_needed" in empty.missing_fields

    partial = _recalculate_missing(RequirementProfile(purpose="Gaming", budget_amount=400000))
    assert "purpose" not in partial.missing_fields
    assert "budget" not in partial.missing_fields
    assert "target_resolution" in partial.missing_fields

    complete = _recalculate_missing(
        RequirementProfile(purpose="Gaming", budget_amount=400000,
                           target_resolution="4K", monitor_needed=True)
    )
    assert complete.missing_fields == []


# --------------------------------------------------------------------------
# Integration tests (real LLM calls via run_requirement_chat)
# --------------------------------------------------------------------------

def test_first_turn_extracts_purpose_and_budget():
    """Turn 1: User states purpose + budget in one message.
    The LLM should call update_requirement_profile and extract both fields.
    """
    session_id = "test_react_turn1"
    result = run_requirement_chat(session_id, "I want a high-end PC for video editing, budget is $2500")
    profile = result["profile"]

    assert profile.purpose is not None, "LLM should have extracted the purpose"
    assert "edit" in profile.purpose.lower() or "video" in profile.purpose.lower()
    assert profile.budget_amount is not None, "LLM should have extracted the budget"
    assert profile.budget_amount >= 2000  # Should be ~2500
    assert result["is_complete"] is False
    assert result["status"] == "gathering"


def test_multi_turn_no_amnesia():
    """Multi-turn scenario: verifies the LLM remembers prior turns.
    Turn 1: Purpose + budget
    Turn 2: Resolution
    Turn 3: Monitor preference
    The profile must accumulate fields across turns without losing any.
    """
    session_id = "test_react_no_amnesia"

    # Turn 1
    t1 = run_requirement_chat(session_id, "I need a gaming PC. My budget is Rs. 400,000")
    assert t1["profile"].purpose is not None
    assert t1["profile"].budget_amount is not None

    # Turn 2: resolution — purpose and budget MUST survive
    t2 = run_requirement_chat(session_id, "4K resolution")
    assert t2["profile"].purpose is not None, "Amnesia: purpose lost after Turn 2!"
    assert t2["profile"].budget_amount is not None, "Amnesia: budget lost after Turn 2!"
    assert t2["profile"].target_resolution is not None, "LLM should have extracted resolution"

    # Turn 3: monitor — all prior fields MUST survive
    t3 = run_requirement_chat(session_id, "I already have a monitor, just need the tower")
    assert t3["profile"].purpose is not None, "Amnesia: purpose lost after Turn 3!"
    assert t3["profile"].budget_amount is not None, "Amnesia: budget lost after Turn 3!"
    assert t3["profile"].target_resolution is not None, "Amnesia: resolution lost after Turn 3!"
    assert t3["profile"].monitor_needed is not None, "LLM should have extracted monitor preference"

    # Reply should NOT re-greet
    assert "welcome" not in t3["reply"].lower()


def test_4k_is_resolution_not_budget():
    """Regression test: When the agent asks about resolution and user says '4k',
    it must be interpreted as 4K resolution, NOT a 4,000 LKR budget.
    This was the exact bug from the user's screenshot.
    """
    session_id = "test_react_4k_resolution"

    # Turn 1: Set a clear budget first
    t1 = run_requirement_chat(session_id, "I want a gaming PC for Rs. 400,000")
    original_budget = t1["profile"].budget_amount

    # Turn 2: Say just "4k" — the LLM has conversational context and should
    # know this answers the resolution question, not override the budget
    t2 = run_requirement_chat(session_id, "4k")

    # Budget must NOT have been overwritten to 4000
    if t2["profile"].budget_amount is not None:
        assert t2["profile"].budget_amount > 10000, \
            f"Bug: '4k' was interpreted as budget {t2['profile'].budget_amount} instead of resolution!"


def test_user_correction_during_confirmation():
    """Regression test: When the user says 'its wrong, budget is 400000',
    the LLM should update the profile, not repeat the same summary.
    """
    session_id = "test_react_correction"

    # Build up a full profile
    run_requirement_chat(session_id, "Gaming PC, budget $2000, 1080p, need a monitor")

    # Now correct the budget
    t2 = run_requirement_chat(session_id, "Actually change the budget to $3000")
    profile = t2["profile"]

    # The LLM should have called update_requirement_profile with the new budget
    if profile.budget_amount is not None:
        assert profile.budget_amount >= 2500, \
            f"Correction failed: budget is {profile.budget_amount}, expected ~3000"


def test_confirmation_completes_profile():
    """Full happy path: gather all fields, confirm, verify is_complete=True."""
    session_id = "test_react_full_confirmation"

    # Turn 1: dump everything at once
    run_requirement_chat(session_id, "I need a video editing PC, budget $2500, 4K resolution, include a monitor")

    # Turn 2: confirm
    t2 = run_requirement_chat(session_id, "Yes that looks perfect, proceed!")
    assert t2["profile"].is_complete is True or t2["status"] == "ready_for_build", \
        "Profile should be complete after explicit confirmation"


def test_boundary_guardrail_no_part_recommendations():
    """Verifies the agent does NOT recommend specific parts (least-privilege boundary)."""
    session_id = "test_react_boundary"

    t1 = run_requirement_chat(
        session_id,
        "Recommend me an RTX 4090 and tell me the price and stock in Colombo store"
    )
    reply_lower = t1["reply"].lower()

    # Agent should NOT act as if it can provide stock/prices
    assert t1["is_complete"] is False
    # Agent should redirect to gathering requirements
    assert any(word in reply_lower for word in ["requirement", "purpose", "budget", "need", "build", "help"]), \
        "Agent should redirect to requirement gathering, not provide part recommendations"


def test_checkpointer_state_persistence():
    """Verifies that the checkpointer retains state across invocations (Lab 06 pattern).

    In CI the GEMINI_API_KEY is a placeholder so the LLM returns a plain text
    reply instead of a tool call — meaning the profile field may not be
    populated.  The important invariant is that the checkpointer persisted the
    graph state (snapshot exists + messages recorded).  Profile extraction is
    covered by the LLM-skipped integration tests.
    """
    import os
    session_id = "test_react_checkpointer"
    run_requirement_chat(session_id, "Video editing PC for $3000")

    config = {"configurable": {"thread_id": session_id}}
    snapshot = REQUIREMENT_GRAPH.get_state(config)
    assert snapshot is not None
    assert snapshot.values is not None

    # Checkpointer must have at least the human message recorded
    messages = snapshot.values.get("messages", [])
    assert len(messages) >= 1, f"Expected at least 1 message in checkpoint, got {len(messages)}"

    # Profile population requires a real LLM that fires the tool — only assert
    # when a real API key is configured (not the CI placeholder).
    api_key = os.environ.get("GEMINI_API_KEY", "")
    is_real_key = bool(api_key) and not api_key.startswith("ci-placeholder")
    if is_real_key:
        saved_profile = snapshot.values.get("profile")
        assert saved_profile is not None, "Real LLM run should have populated the profile via tool call"

