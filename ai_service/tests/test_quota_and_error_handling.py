"""
Tests verifying that no fake hardcoded fallbacks exist when quota limits or network errors occur.
Ensures that all agents halt and return clear error responses instead of fabricating state.
"""

from unittest.mock import MagicMock, patch
import pytest

from ai_service.agents.requirement_agent.models import RequirementProfile
from ai_service.agents.build_agent.models import BuildGenerationRequest
from ai_service.agents.order_planning_agent.models import OrderPlanningRequest
from ai_service.agents.inventory_agent.models import InventoryCheckRequest
from ai_service.agents.after_sales_agent.models import AfterSalesChatRequest


def test_no_hardcoded_fallback_functions_exist():
    """Verify that forbidden fake fallback helper functions have been eradicated."""
    import ai_service.agents.requirement_agent.agent as req_agent
    import ai_service.agents.build_agent.agent as build_agent

    assert not hasattr(req_agent, "_heuristic_slot_extraction"), (
        "_heuristic_slot_extraction must not exist. Fake hardcoded fallbacks are removed."
    )
    assert not hasattr(build_agent, "_deterministic_build_assembly"), (
        "_deterministic_build_assembly must not exist. Fake hardcoded fallbacks are removed."
    )


def test_requirement_agent_quota_exhaustion_stops_with_error():
    """When Gemini throws 429 RESOURCE_EXHAUSTED, requirement agent must halt with an error
    and must NOT fabricate extracted requirement fields.
    """
    from ai_service.agents.requirement_agent.agent import run_requirement_chat

    mock_llm = MagicMock()
    mock_bound = MagicMock()
    mock_bound.invoke.side_effect = Exception("429 RESOURCE_EXHAUSTED: You exceeded your current quota")
    mock_llm.bind_tools.return_value = mock_bound

    with patch("ai_service.agents.requirement_agent.agent.get_llm", return_value=mock_llm):
        result = run_requirement_chat(
            session_id="test_quota_err_req",
            message="I need a high-end 4K gaming PC with budget Rs. 800,000"
        )

    assert result["is_complete"] is False
    profile = result["profile"]
    # Profile MUST NOT have fabricated fields from regex/heuristics
    assert profile.purpose is None, "Must not fabricate purpose on LLM error"
    assert profile.budget_amount is None, "Must not fabricate budget on LLM error"
    assert profile.target_resolution is None, "Must not fabricate resolution on LLM error"

    # Message must inform customer of quota / demand limit
    reply = result["reply"].lower()
    assert any(term in reply for term in ["quota", "demand", "unavailable", "apologize", "temporarily"])


def test_build_agent_quota_exhaustion_stops_with_error():
    """When Gemini throws 429 RESOURCE_EXHAUSTED, build agent must return success=False
    and must NOT fabricate a deterministic 8-component build.
    """
    from ai_service.agents.build_agent.agent import generate_compatible_build

    mock_llm = MagicMock()
    mock_bound = MagicMock()
    mock_bound.invoke.side_effect = Exception("429 RESOURCE_EXHAUSTED: Quota limit reached")
    mock_llm.bind_tools.return_value = mock_bound

    sample_catalog = [
        {"product_id": 1, "name": "AMD Ryzen 5 7600", "category": "CPU", "price": 65000.0, "socket": "AM5", "memory_type": "DDR5"},
        {"product_id": 2, "name": "MSI B650 Motherboard", "category": "Motherboard", "price": 55000.0, "socket": "AM5", "memory_type": "DDR5", "form_factor": "ATX"},
        {"product_id": 3, "name": "Corsair 32GB RAM", "category": "RAM", "price": 35000.0, "memory_type": "DDR5"},
        {"product_id": 4, "name": "Nvidia RTX 4070", "category": "GPU", "price": 220000.0, "power_wattage": 200},
        {"product_id": 5, "name": "Corsair 750W PSU", "category": "PSU", "price": 38000.0, "power_wattage": 750},
        {"product_id": 6, "name": "Samsung 1TB SSD", "category": "Storage", "price": 28000.0},
        {"product_id": 7, "name": "NZXT H5 Case", "category": "Case", "price": 32000.0, "form_factor": "ATX"},
        {"product_id": 8, "name": "DeepCool AK620 Cooler", "category": "Cooler", "price": 22000.0, "socket": "AM5"},
    ]

    req = BuildGenerationRequest(
        purpose="Gaming",
        budget_amount=500000.0,
        currency="LKR",
        target_resolution="1440p",
        preferences=["RGB"],
        catalog=sample_catalog
    )

    with patch("ai_service.agents.build_agent.agent.get_llm", return_value=mock_llm):
        resp = generate_compatible_build(req)

    assert resp.success is False
    assert resp.build is None
    assert resp.error is not None
    assert "RESOURCE_EXHAUSTED" in resp.error or "quota" in resp.error.lower()


def test_order_planning_agent_quota_exhaustion_stops_with_error():
    """When Gemini throws 429 RESOURCE_EXHAUSTED, order planning agent must return success=False
    and must NOT fabricate a fallback order proposal.
    """
    from ai_service.agents.order_planning_agent.agent import generate_order_proposal

    mock_llm = MagicMock()
    mock_bound = MagicMock()
    mock_bound.invoke.side_effect = Exception("429 RESOURCE_EXHAUSTED: Quota limit reached")
    mock_llm.bind_tools.return_value = mock_bound

    req = OrderPlanningRequest(
        reservation_id="RES-QUOTA123",
        build_name="Test Rig",
        components={"cpu": {"product_id": 3, "name": "Ryzen 5", "price": 60000.0}},
        promo_code="WELCOME5",
        shipping_method="standard",
        currency="Rs."
    )

    with patch("ai_service.agents.order_planning_agent.agent.get_llm", return_value=mock_llm):
        resp = generate_order_proposal(req)

    assert resp.success is False
    assert resp.proposal is None
    assert resp.error is not None
    assert "RESOURCE_EXHAUSTED" in resp.error or "quota" in resp.error.lower()


def test_after_sales_agent_quota_exhaustion_stops_with_error():
    """When Gemini throws 429 RESOURCE_EXHAUSTED, after-sales agent must return success=False
    with an error explanation rather than faking fallback mode.
    """
    from ai_service.agents.after_sales_agent.agent import run_after_sales_chat

    mock_llm = MagicMock()
    mock_bound = MagicMock()
    mock_bound.invoke.side_effect = Exception("429 RESOURCE_EXHAUSTED: Quota limit reached")
    mock_llm.bind_tools.return_value = mock_bound

    req = AfterSalesChatRequest(
        user_id=1,
        message="My PC won't turn on",
        session_id="test_quota_after_sales"
    )

    with patch("ai_service.agents.after_sales_agent.agent.get_llm", return_value=mock_llm):
        resp = run_after_sales_chat(req)

    assert resp.success is False
    assert "quota" in resp.reply.lower() or "demand" in resp.reply.lower()
