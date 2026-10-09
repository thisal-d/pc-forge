"""Tests for the FastAPI endpoints of the PCForge AI service."""
from fastapi.testclient import TestClient
from ai_service.main import app

client = TestClient(app)


def test_health_endpoint():
    """Liveness & configuration test (0 API requests consumed)."""
    res = client.get("/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "healthy"
    assert data["service"] == "pcforge-ai-service"


def test_tools_schema_endpoint():
    """Validates advertised tool schemas (0 API requests consumed)."""
    res = client.get("/agent/requirements/tools")
    assert res.status_code == 200
    data = res.json()
    assert data["agent"] == "requirement_agent"
    tool_names = [t["name"] for t in data["tools"]]
    assert "update_requirement_profile" in tool_names
    assert "confirm_requirements" in tool_names


def test_chat_and_session_endpoints():
    """Validates full HTTP flow: chat turn -> session snapshot retrieval."""
    session_id = "test_http_session_react"
    res = client.post(
        "/agent/requirements/chat",
        json={"session_id": session_id, "message": "I want a video editing PC for $2500"}
    )
    assert res.status_code == 200
    data = res.json()
    assert data["session_id"] == session_id
    assert data["reply"]  # Should have a non-empty reply
    assert data["is_complete"] is False

    # Check session retrieval endpoint
    session_res = client.get(f"/agent/requirements/session/{session_id}")
    assert session_res.status_code == 200
    session_data = session_res.json()
    assert session_data["found"] is True
    assert session_data["messages_count"] >= 2
