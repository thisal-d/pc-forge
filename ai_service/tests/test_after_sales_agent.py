"""
Tests for AI After-Sales Service Agent (Member 05)
==================================================
Verifies RAG knowledge base retrieval, allow-listed tools, order & warranty verification,
safe troubleshooting guidance, attempt tracking, and Service Request creation.
"""

import json
from datetime import datetime, timedelta
import pytest
from fastapi.testclient import TestClient

from ai_service.main import app
from ai_service.agents.after_sales_agent.tools import (
    AFTER_SALES_TOOLS,
    after_sales_context_var,
    check_warranty,
    create_service_request,
    get_customer,
    get_order,
    get_order_products,
    search_troubleshooting_knowledge,
    validate_service_appointment,
)
from ai_service.agents.after_sales_agent.models import AfterSalesChatRequest
from ai_service.agents.after_sales_agent.agent import run_after_sales_chat, clean_chat_formatting

client = TestClient(app)


# ------------------------------------------------------------------------------
# 1. Allow-listed Tools & Manifest
# ------------------------------------------------------------------------------
def test_after_sales_tools_manifest():
    """Validates that all essential after-sales tools are registered."""
    tool_names = [t.name for t in AFTER_SALES_TOOLS]
    assert "search_troubleshooting_knowledge" in tool_names
    assert "get_customer" in tool_names
    assert "get_order" in tool_names
    assert "get_order_products" in tool_names
    assert "check_warranty" in tool_names
    assert "validate_service_appointment" in tool_names
    assert "create_service_request" in tool_names
    assert "get_service_request" in tool_names
    assert "get_customer_service_requests" in tool_names


def test_search_troubleshooting_knowledge_tool():
    """Validates RAG knowledge retrieval for standard symptom vs safety emergency."""
    # 1. Standard symptom
    res_power = json.loads(search_troubleshooting_knowledge.invoke({"problem": "My PC is not turning on"}))
    assert res_power["matched_category"] == "Power / Boot Failure"
    assert res_power["is_safety_hazard"] is False
    assert len(res_power["steps_available"]) >= 3

    # 2. Critical Safety Hazard
    res_hazard = json.loads(search_troubleshooting_knowledge.invoke({"problem": "There is a burning smell and smoke coming from my PC"}))
    assert res_hazard["is_safety_hazard"] is True
    assert res_hazard["recommended_action"] == "IMMEDIATE_ESCALATION"
    assert "disconnect" in res_hazard["hazard_instructions"].lower() or "power" in res_hazard["hazard_instructions"].lower()


def test_get_order_and_warranty_tools():
    """Validates order retrieval and computed manufacturer warranty status."""
    from ai_service.agents.after_sales_agent.tools import after_sales_context_var
    after_sales_context_var.set({
        "orders": [
            {
                "order_id": 1,
                "order_number": "PCF-10001",
                "purchase_date": "2025-08-15",
                "items": [
                    {
                        "product_id": 8,
                        "product_name": "NVIDIA GeForce RTX 4070 Ti 12GB",
                        "category": "GPU",
                        "unit_price": 799.0,
                        "quantity": 1
                    }
                ]
            }
        ]
    })
    warranty_raw = check_warranty.invoke({
        "order_id": 1,
        "product_name_or_id": "RTX 4070"
    })
    data = json.loads(warranty_raw)

    assert "order_id" in data
    assert "warranty_status" in data
    assert data["warranty_status"] in ("Active", "Expired")
    assert "warranty_expiry_date" in data
    assert "warranty_period" in data


def test_validate_service_appointment_tool():
    """Validates service appointment validation rules (requires both date and time, rejects past dates and outside hours)."""
    # 1. Both date and time provided
    after_sales_context_var.set({})
    val_both = validate_service_appointment.invoke({
        "preferred_date": "Tomorrow",
        "preferred_time": "10:00 AM"
    })
    d_both = json.loads(val_both)
    assert d_both["valid"] is True
    assert "date" in d_both
    assert "10:00 AM" in d_both["time"]

    # 2. Date only provided -> must return valid=False with missing='time' and cache date
    after_sales_context_var.set({})
    val_date_only = validate_service_appointment.invoke({
        "preferred_date": "Tomorrow",
        "preferred_time": ""
    })
    d_date_only = json.loads(val_date_only)
    assert d_date_only["valid"] is False
    assert d_date_only["missing"] == "time"

    # 2b. Context preservation: follow-up with time only -> combines with cached date
    val_followup_time = validate_service_appointment.invoke({
        "preferred_time": "2 PM"
    })
    d_followup_time = json.loads(val_followup_time)
    assert d_followup_time["valid"] is True
    assert "02:00 PM" in d_followup_time["time"]
    assert "date" in d_followup_time

    # 2c. Time only provided first -> must return valid=False with missing='date' and cache time
    after_sales_context_var.set({})
    val_time_only = validate_service_appointment.invoke({
        "preferred_time": "2 PM"
    })
    d_time_only = json.loads(val_time_only)
    assert d_time_only["valid"] is False
    assert d_time_only["missing"] == "date"

    # Follow-up with date only -> combines with cached time
    val_followup_date = validate_service_appointment.invoke({
        "preferred_date": "Tomorrow"
    })
    d_followup_date = json.loads(val_followup_date)
    assert d_followup_date["valid"] is True
    assert "02:00 PM" in d_followup_date["time"]

    # 3. Past date provided -> must return valid=False with error='past_date' and explain date has passed
    after_sales_context_var.set({})
    val_past = validate_service_appointment.invoke({
        "preferred_date": "2020-01-01",
        "preferred_time": "10:00 AM"
    })
    d_past = json.loads(val_past)
    assert d_past["valid"] is False
    assert d_past["error"] == "past_date"
    assert "already passed" in d_past["message"]

    # 4. Outside operating hours (< 9 AM or > 6 PM) -> must return valid=False with error='outside_hours'
    after_sales_context_var.set({})
    val_early = validate_service_appointment.invoke({
        "preferred_date": "Tomorrow",
        "preferred_time": "07:30 AM"
    })
    d_early = json.loads(val_early)
    assert d_early["valid"] is False
    assert d_early["error"] == "outside_hours"
    assert "9:00 AM" in d_early["message"]

    after_sales_context_var.set({})
    val_late = validate_service_appointment.invoke({
        "preferred_date": "Tomorrow",
        "preferred_time": "08:00 PM"
    })
    d_late = json.loads(val_late)
    assert d_late["valid"] is False
    assert d_late["error"] == "outside_hours"
    assert "6:00 PM" in d_late["message"]


def test_update_service_appointment_tool():
    """Validates rescheduling an existing service request appointment without duplicates."""
    from ai_service.agents.after_sales_agent.tools import update_service_appointment
    target_date = (datetime.now() + timedelta(days=10)).strftime("%Y-%m-%d")
    res_raw = update_service_appointment.invoke({
        "service_request_id_or_number": "1",
        "preferred_date": target_date,
        "preferred_time": "03:30 PM"
    })
    data = json.loads(res_raw)
    assert data["success"] is True
    assert "03:30 PM" in data["preferred_time"]
    assert target_date in data["preferred_date"]


def test_create_service_request_tool():
    """Validates Service Request database insertion and SR-XXXXXX number generation."""
    target_date = (datetime.now() + timedelta(days=5)).strftime("%Y-%m-%d")
    sr_raw = create_service_request.invoke({
        "user_id": 1,
        "problem_description": "PC will not turn on after pressing power button",
        "problem_category": "Power / Boot Failure",
        "troubleshooting_summary": "1. Checked power cable firmness. 2. Checked PSU switch. 3. Power drain attempted.",
        "attempt_count": 3,
        "order_id": 1,
        "product_name": "GeForce RTX 4070 Ti",
        "warranty_status": "Active",
        "preferred_date": target_date,
        "preferred_time": "11:00 AM",
        "priority": "Normal"
    })
    data = json.loads(sr_raw)

    assert data["success"] is True
    assert "service_request_id" in data
    assert data["service_request_number"].startswith("SR-")
    assert data["status"] == "PENDING"
    assert data["attempt_count"] == 3
    assert "title" in data
    assert "description" in data


def test_create_service_request_with_title_and_description():
    """Validates that title and optional description are stored properly in service request."""
    target_date = (datetime.now() + timedelta(days=7)).strftime("%Y-%m-%d")
    sr_raw = create_service_request.invoke({
        "user_id": 1,
        "title": "GPU Artifacting under load",
        "description": "Green squares and lines appear on screen during 3D gaming.",
        "problem_description": "Green squares and lines appear on screen during 3D gaming.",
        "problem_category": "Display / GPU",
        "preferred_date": target_date,
        "preferred_time": "02:00 PM"
    })
    data = json.loads(sr_raw)
    assert data["success"] is True
    assert data["title"] == "GPU Artifacting under load"
    assert data["description"] == "Green squares and lines appear on screen during 3D gaming."
    assert data["status"] == "PENDING"


def test_validate_and_create_service_request_max_capacity():
    """Validates that a date with 10 existing appointments triggers capacity limit error."""
    from ai_service.agents.after_sales_agent.tools import after_sales_context_var
    target_date = (datetime.now() + timedelta(days=20)).strftime("%Y-%m-%d")
    # Populate context with 10 appointments on target_date
    fake_srs = [
        {"service_request_id": i, "service_request_number": f"SR-{i:06d}", "preferred_date": f"{target_date}T10:00:00Z", "status": "PENDING"}
        for i in range(1, 11)
    ]
    after_sales_context_var.set({"service_requests": fake_srs})

    # Validate appointment should reject due to capacity
    val_res = json.loads(validate_service_appointment.invoke({
        "preferred_date": target_date,
        "preferred_time": "11:00 AM"
    }))
    assert val_res["valid"] is False
    assert val_res["error"] == "capacity_exceeded"
    assert "maximum capacity of 10" in val_res["message"]

    # Create service request should also reject due to capacity
    sr_res = json.loads(create_service_request.invoke({
        "user_id": 1,
        "problem_description": "Need thermal paste replacement",
        "preferred_date": target_date,
        "preferred_time": "11:00 AM"
    }))
    assert sr_res["success"] is False
    assert sr_res["error"] == "capacity_exceeded"



# ------------------------------------------------------------------------------
# 2. FastAPI Endpoint Contract Tests
# ------------------------------------------------------------------------------
def test_api_after_sales_tools_endpoint():
    """GET /agent/after-sales/tools returns registered tool schemas."""
    response = client.get("/agent/after-sales/tools")
    assert response.status_code == 200
    data = response.json()
    assert data["agent"] == "after_sales_agent"
    assert data["member"] == "Member 05"
    assert len(data["tools"]) >= 9


def test_api_after_sales_chat_troubleshooting():
    """POST /agent/after-sales/chat guides customer with safe troubleshooting instructions and prompts for SR."""
    payload = {
        "user_id": 1,
        "message": "My PC won't turn on",
        "session_id": "test_troubleshoot_turn1"
    }
    response = client.post("/agent/after-sales/chat", json=payload)
    assert response.status_code == 200
    data = response.json()

    assert data["success"] is True
    assert len(data["reply"]) > 0
    # Customer should receive safe troubleshooting instructions (e.g. cable, power switch)
    reply_lower = data["reply"].lower()
    assert any(w in reply_lower for w in ["cable", "power", "switch", "outlet", "plug", "button", "check"])
    # Agent must prompt the customer that they can stop chatting and create a service request
    assert "service request" in reply_lower


def test_api_after_sales_chat_switch_to_service_request_mode():
    """POST /agent/after-sales/chat stops chatting and switches to Service Request mode on request."""
    session_id = "test_sr_switch_session_1"

    # Step 1: Initial symptom report
    r1 = client.post("/agent/after-sales/chat", json={
        "user_id": 1,
        "message": "My PC screen is completely black",
        "session_id": session_id
    })
    assert r1.status_code == 200
    d1 = r1.json()
    assert d1["success"] is True

    # Step 2: Customer asks to stop chatting and create a service request
    r2 = client.post("/agent/after-sales/chat", json={
        "user_id": 1,
        "message": "I want to stop chatting and create a service request",
        "session_id": session_id
    })
    assert r2.status_code == 200
    d2 = r2.json()
    assert d2["success"] is True
    assert d2["service_request_mode"] is True
    assert d2["service_request_required"] is True
    reply_lower2 = d2["reply"].lower()
    # The agent should ask for preferred appointment date and time, NOT Order ID
    assert any(term in reply_lower2 for term in ["date", "time", "appointment", "schedule", "prefer"])
    assert "order id" not in reply_lower2


def test_after_sales_chat_suggest_service_request_after_5_attempts():
    """Verifies that after 5 unsuccessful troubleshooting attempts, the agent suggests creating a Service Request."""
    req = AfterSalesChatRequest(
        user_id=1,
        message="I tried Step 5 and the PC still will not turn on.",
        session_id="test_5_attempts_session",
    )
    res = run_after_sales_chat(req)
    assert res.success is True
    assert res.service_request_mode is True or res.service_request_required is True
    reply_lower = res.reply.lower()
    assert "service request" in reply_lower


def test_clean_chat_formatting():
    """Verifies that markdown symbols (**bold**, *, headers, etc.) are stripped cleanly for a natural conversational message."""
    raw = "**Hello!** Here is step 1:\n### Step 1: Check Power Cable\n* Inspect the *power switch*\n`done`"
    cleaned = clean_chat_formatting(raw)
    assert "**" not in cleaned
    assert "*" not in cleaned
    assert "###" not in cleaned
    assert "Hello!" in cleaned
    assert "Step 1: Check Power Cable" in cleaned


