"""
Tests for Inventory Agent (Member 02)
=====================================
Verifies deterministic warehouse inventory tools, LangGraph agent workflow execution,
15-minute reservation hold creation, and FastAPI endpoint contracts.
"""

import json
import pytest
from fastapi.testclient import TestClient

from ai_service.main import app
from ai_service.agents.inventory_agent.models import InventoryCheckRequest
from ai_service.agents.inventory_agent.tools import (
    INVENTORY_TOOLS,
    get_stock_level,
    find_compatible_substitute,
    reserve_stock,
)
from ai_service.agents.inventory_agent.agent import verify_build_inventory

client = TestClient(app)


# ------------------------------------------------------------------------------
# 1. Allow-listed Deterministic Tool Tests
# ------------------------------------------------------------------------------
def test_inventory_tools_manifest():
    """Validates that exactly 3 inventory tools are registered and available."""
    tool_names = [t.name for t in INVENTORY_TOOLS]
    assert "get_stock_level" in tool_names
    assert "find_compatible_substitute" in tool_names
    assert "reserve_stock" in tool_names
    assert len(INVENTORY_TOOLS) == 3


def test_get_stock_level_tool():
    """Validates querying stock for a component from live database."""
    # Product 1 is AMD Ryzen 5 7600X
    result_str = get_stock_level.invoke({"product_id": 1})
    data = json.loads(result_str)

    assert "product_id" in data
    assert data["product_id"] == 1
    assert "stock_quantity" in data
    assert isinstance(data["stock_quantity"], int)
    assert data["stock_quantity"] >= 0
    assert "status" in data
    assert "price" in data


def test_find_compatible_substitute_tool():
    """Validates finding an in-stock substitute within the same category."""
    result_str = find_compatible_substitute.invoke({
        "category": "CPU",
        "failed_product_id": 99999,
        "socket": "AM5",
        "max_price": 500.0,
    })
    candidates = json.loads(result_str)

    assert isinstance(candidates, list)
    if len(candidates) > 0:
        assert candidates[0]["stock_quantity"] > 0
        assert candidates[0]["category"] == "CPU"
        assert "product_id" in candidates[0]


def test_reserve_stock_tool():
    """Validates creation of a temporary 15-minute reservation hold."""
    result_str = reserve_stock.invoke({
        "product_ids_json": "[1, 3]",
        "session_id": "TEST_UNIT_SESSION",
        "hold_minutes": 15,
    })
    data = json.loads(result_str)

    assert data["status"] == "RESERVED"
    assert "reservation_id" in data
    assert data["reservation_id"].startswith("RES-")
    assert "expires_at" in data
    assert len(data["reserved_product_ids"]) == 2


# ------------------------------------------------------------------------------
# 2. FastAPI Endpoint Contract Tests
# ------------------------------------------------------------------------------
def test_api_inventory_tools_endpoint():
    """GET /agent/inventory/tools should return all 3 inventory tools with schemas."""
    response = client.get("/agent/inventory/tools")
    assert response.status_code == 200
    data = response.json()
    assert data["agent"] == "inventory_agent"
    assert data["member"] == "Member 02"
    assert len(data["tools"]) == 3
    tool_names = [t["name"] for t in data["tools"]]
    assert "get_stock_level" in tool_names
    assert "find_compatible_substitute" in tool_names
    assert "reserve_stock" in tool_names


def test_api_verify_stock_endpoint():
    """POST /agent/inventory/verify-stock should execute inventory agent and return reservation."""
    payload = {
        "component_ids": {
            "cpu": 1,
            "cooler": 2,
            "motherboard": 3,
            "ram": 5,
            "gpu": 8,
            "storage": 9,
            "psu": 12,
            "case": 14,
        },
        "build_name": "FastAPI Test Build",
        "target_resolution": "1440p",
    }
    response = client.post("/agent/inventory/verify-stock", json=payload)
    assert response.status_code == 200
    data = response.json()

    assert data["success"] is True
    assert "components" in data
    assert len(data["components"]) == 8
    assert "reservation" in data
    assert data["reservation"]["status"] in ["Reserved", "ACTIVE"]
    assert data["reservation"]["reservation_id"].startswith("RES-")
