"""
Tests for Order Planning Agent (Member 04)
==========================================
Verifies deterministic pricing, voucher, and delivery tools,
LangGraph agent workflow execution, and FastAPI endpoint contracts.
"""

import json
import pytest
from fastapi.testclient import TestClient

from ai_service.main import app
from ai_service.agents.order_planning_agent.models import OrderPlanningRequest
from ai_service.agents.order_planning_agent.tools import (
    ORDER_PLANNING_TOOLS,
    apply_discount,
    calculate_delivery,
    calculate_pricing,
    create_order_proposal,
)
from ai_service.agents.order_planning_agent.agent import generate_order_proposal

client = TestClient(app)


# ------------------------------------------------------------------------------
# 1. Allow-listed Deterministic Tool Tests
# ------------------------------------------------------------------------------
def test_order_planning_tools_manifest():
    """Validates that exactly 4 order planning tools are registered."""
    tool_names = [t.name for t in ORDER_PLANNING_TOOLS]
    assert "calculate_pricing" in tool_names
    assert "apply_discount" in tool_names
    assert "calculate_delivery" in tool_names
    assert "create_order_proposal" in tool_names
    assert len(ORDER_PLANNING_TOOLS) == 4


def test_calculate_pricing_tool():
    """Validates itemized component summation."""
    sample_components = {
        "cpu": {"product_id": 1, "name": "AMD Ryzen 5 7600X", "price": 229.0},
        "motherboard": {"product_id": 3, "name": "MSI MAG B650 Tomahawk WiFi", "price": 199.0},
    }
    result_str = calculate_pricing.invoke({
        "components_json": json.dumps(sample_components),
        "currency": "Rs."
    })
    data = json.loads(result_str)

    assert "subtotal" in data
    assert data["components_count"] == 2
    assert "formatted_subtotal" in data
    assert len(data["items"]) == 2


def test_apply_discount_tool_welcome5():
    """Validates WELCOME5 promotional coupon deduction matching ui4.png."""
    result_str = apply_discount.invoke({
        "promo_code": "WELCOME5",
        "subtotal": 385000.0,
        "currency": "Rs."
    })
    data = json.loads(result_str)

    assert data["valid"] is True
    assert data["promo_code"] == "WELCOME5"
    assert data["discount_amount"] == 8000.0
    assert data["formatted_discount"] == "- Rs. 8,000"
    assert data["net_subtotal"] == 377000.0


def test_apply_discount_tool_invalid():
    """Validates rejection of non-existent voucher code."""
    result_str = apply_discount.invoke({
        "promo_code": "FAKECODE999",
        "subtotal": 200000.0,
        "currency": "Rs."
    })
    data = json.loads(result_str)

    assert data["valid"] is False
    assert data["discount_amount"] == 0.0


def test_calculate_delivery_tool():
    """Validates standard courier calculation matching ui4.png (Rs. 2,500)."""
    result_str = calculate_delivery.invoke({
        "shipping_method": "standard",
        "address_zone": "Colombo",
        "currency": "Rs."
    })
    data = json.loads(result_str)

    assert data["delivery_fee"] == 2500.0
    assert data["formatted_delivery"] == "Rs. 2,500"
    assert "3-5 business days" in data["estimated_delivery_days"]


def test_create_order_proposal_tool():
    """Validates creation of proposal holding status WAITING_FOR_APPROVAL."""
    result_str = create_order_proposal.invoke({
        "build_name": "Test Rig",
        "reservation_id": "RES-UNIT001",
        "subtotal": 385000.0,
        "discount_amount": 8000.0,
        "delivery_fee": 2500.0,
        "total_price": 379500.0,
        "promo_code": "WELCOME5",
        "currency": "Rs.",
        "order_number": "PCF-10492"
    })
    data = json.loads(result_str)

    assert data["order_number"] == "PCF-10492"
    assert data["status"] == "WAITING_FOR_APPROVAL"
    assert data["status_label"] == "Waiting for your approval"
    assert data["pricing"]["formatted_total"] == "Rs. 379,500"


# ------------------------------------------------------------------------------
# 2. FastAPI Endpoint Contract Tests
# ------------------------------------------------------------------------------
def test_api_order_planning_tools_endpoint():
    """GET /agent/order-planning/tools returns tool schemas."""
    response = client.get("/agent/order-planning/tools")
    assert response.status_code == 200
    data = response.json()
    assert data["agent"] == "order_planning_agent"
    assert data["member"] == "Member 04"
    assert len(data["tools"]) == 4


def test_api_create_proposal_endpoint():
    """POST /agent/order-planning/create-proposal executes agent and returns proposal."""
    payload = {
        "reservation_id": "RES-TESTFAST",
        "build_name": "FastAPI Build",
        "components": {
            "cpu": {"product_id": 1, "name": "AMD Ryzen 5 7600X", "price": 229.0},
            "gpu": {"product_id": 8, "name": "NVIDIA GeForce RTX 4070 Ti", "price": 799.0}
        },
        "promo_code": "WELCOME5",
        "shipping_method": "standard",
        "currency": "Rs."
    }
    response = client.post("/agent/order-planning/create-proposal", json=payload)
    assert response.status_code == 200
    data = response.json()

    assert data["success"] is True
    assert "proposal" in data
    assert data["proposal"]["status"] == "WAITING_FOR_APPROVAL"
    assert "pricing" in data["proposal"]
    assert data["proposal"]["pricing"]["discount_amount"] > 0
