"""
Tests for PC Build & Compatibility Agent (Member 03)
====================================================
Verifies deterministic compatibility tools, LangGraph workflow execution,
and FastAPI endpoint contracts.
"""

import json
import pytest
from fastapi.testclient import TestClient

from ai_service.main import app
from ai_service.agents.build_agent.models import BuildGenerationRequest
from ai_service.agents.build_agent.tools import (
    BUILD_TOOLS,
    check_case_fit,
    check_memory_compatibility,
    check_psu_wattage,
    check_socket_compatibility,
    get_candidate_components,
)
from ai_service.agents.build_agent.agent import generate_compatible_build

client = TestClient(app)


# ------------------------------------------------------------------------------
# 1. Deterministic Tool Tests (Lab 05 Tool Contract Verification)
# ------------------------------------------------------------------------------
def test_socket_compatibility_tool():
    """Validates CPU to Motherboard socket matching logic."""
    # AM5 matches AM5
    pass_res = json.loads(check_socket_compatibility.invoke({"cpu_socket": "AM5", "motherboard_socket": "AM5"}))
    assert pass_res["compatible"] is True
    assert "Verified" in pass_res["details"]

    # AM5 does NOT match LGA1700
    fail_res = json.loads(check_socket_compatibility.invoke({"cpu_socket": "AM5", "motherboard_socket": "LGA1700"}))
    assert fail_res["compatible"] is False
    assert "INCOMPATIBLE" in fail_res["details"]


def test_memory_compatibility_tool():
    """Validates DDR RAM generation matching."""
    # DDR5 matches DDR5
    pass_res = json.loads(check_memory_compatibility.invoke({"ram_type": "DDR5", "motherboard_memory_type": "DDR5"}))
    assert pass_res["compatible"] is True

    # DDR4 cannot go into DDR5 board
    fail_res = json.loads(check_memory_compatibility.invoke({"ram_type": "DDR4", "motherboard_memory_type": "DDR5"}))
    assert fail_res["compatible"] is False


def test_psu_wattage_headroom_tool():
    """Validates power supply sizing formula (CPU TDP + GPU TDP + 75W + 150W headroom <= PSU)."""
    # 105W CPU + 220W GPU + 75W base = 400W load. Headroom needed: +150W -> 550W min.
    # 750W PSU has +350W headroom -> PASS
    pass_res = json.loads(check_psu_wattage.invoke({
        "cpu_tdp": 105,
        "gpu_tdp": 220,
        "psu_wattage": 750
    }))
    assert pass_res["compatible"] is True
    assert pass_res["estimated_system_load_w"] == 400
    assert pass_res["net_headroom_w"] == 350

    # 450W PSU with 400W load has only +50W headroom (< +150W safety requirement) -> FAIL
    fail_res = json.loads(check_psu_wattage.invoke({
        "cpu_tdp": 105,
        "gpu_tdp": 220,
        "psu_wattage": 450
    }))
    assert fail_res["compatible"] is False
    assert "INSUFFICIENT" in fail_res["details"]


def test_case_fit_tool():
    """Validates chassis form factor hierarchy."""
    # Micro-ATX board fits inside ATX case
    fit_res = json.loads(check_case_fit.invoke({
        "motherboard_form_factor": "Micro-ATX",
        "case_form_factor": "ATX"
    }))
    assert fit_res["compatible"] is True

    # ATX board does NOT fit inside Mini-ITX chassis
    nofit_res = json.loads(check_case_fit.invoke({
        "motherboard_form_factor": "ATX",
        "case_form_factor": "Mini-ITX"
    }))
    assert nofit_res["compatible"] is False


def test_get_candidate_components_filter():
    """Validates catalog retrieval and category filtering."""
    cpus_raw = get_candidate_components.invoke({"category": "CPU"})
    cpus = json.loads(cpus_raw)
    assert len(cpus) > 0
    assert all("CPU" in c["category"] for c in cpus)

    # Filter with socket constraint
    am5_cpus = json.loads(get_candidate_components.invoke({"category": "CPU", "socket": "AM5"}))
    assert len(am5_cpus) > 0
    assert all("AM5" in c["socket"] for c in am5_cpus)


# ------------------------------------------------------------------------------
# 2. Agent Workflow & Clearance Tests (Member 03 ReAct / LangGraph)
# ------------------------------------------------------------------------------
def test_generate_compatible_build_gaming_1440p():
    """Verifies complete build generation for 1440p Gaming rig."""
    req = BuildGenerationRequest(
        purpose="Gaming",
        budget_amount=400000.0,
        currency="LKR",
        target_resolution="1440p",
        preferences=["RGB", "WiFi"]
    )

    resp = generate_compatible_build(req)
    assert resp.success is True
    assert resp.build is not None

    b = resp.build
    assert len(b.components) == 8
    assert "cpu" in b.components
    assert "motherboard" in b.components
    assert "ram" in b.components
    assert "gpu" in b.components
    assert "psu" in b.components
    assert "storage" in b.components
    assert "pc_case" in b.components
    assert "cooler" in b.components

    # Verify clearance checklist
    chk = b.compatibility
    assert chk.all_passed is True
    assert chk.socket_match is True
    assert chk.memory_match is True
    assert chk.wattage_ok is True
    assert chk.case_fit_ok is True
    assert chk.headroom_watts >= 150
    assert b.status == "VALIDATED_PENDING_STOCK"


def test_generate_compatible_build_high_end_4k():
    """Verifies high-end 4K build selection and wattage headroom."""
    req = BuildGenerationRequest(
        purpose="3D Rendering & 4K Gaming",
        budget_amount=3500.0,
        currency="USD",
        target_resolution="4K",
        preferences=["Liquid Cooling"]
    )

    resp = generate_compatible_build(req)
    assert resp.success is True
    b = resp.build
    assert b is not None
    assert b.compatibility.all_passed is True
    # In 4K high budget, PSU should be 850W or higher
    assert b.components["psu"].power_wattage >= 850


# ------------------------------------------------------------------------------
# 3. FastAPI Endpoint Integration Tests
# ------------------------------------------------------------------------------
def test_get_build_tools_endpoint():
    """Verify GET /agent/build/tools exposes schemas for Lab 05 compliance."""
    response = client.get("/agent/build/tools")
    assert response.status_code == 200
    data = response.json()
    assert data["member"] == "Member 03"
    tools = data["tools"]
    tool_names = [t["name"] for t in tools]
    assert "get_candidate_components" in tool_names
    assert "check_socket_compatibility" in tool_names
    assert "check_memory_compatibility" in tool_names
    assert "check_psu_wattage" in tool_names
    assert "check_case_fit" in tool_names


def test_post_build_generate_endpoint():
    """Verify POST /agent/build/generate executes and returns ValidatedBuild."""
    payload = {
        "purpose": "Esports Gaming",
        "budget_amount": 1500.0,
        "currency": "USD",
        "target_resolution": "1440p",
        "preferences": ["Fast NVMe"]
    }
    response = client.post("/agent/build/generate", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert data["build"]["is_valid"] is True
    assert data["build"]["compatibility"]["all_passed"] is True
    assert len(data["build"]["components"]) == 8
