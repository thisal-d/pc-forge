import os
import sys
from pathlib import Path
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# Ensure parent directory is in sys.path when running directly inside the ai_service directory
_service_dir = Path(__file__).resolve().parent
if str(_service_dir.parent) not in sys.path:
    sys.path.insert(0, str(_service_dir.parent))

from ai_service.config import AI_SERVICE_HOST, AI_SERVICE_PORT, CHAT_MODEL, GOOGLE_API_KEY
from ai_service.agents.requirement_agent.models import (
    RequirementChatRequest,
    RequirementChatResponse,
    RequirementProfile,
)
from ai_service.agents.requirement_agent.agent import (
    run_requirement_chat,
    CHECKPOINTER,
    REQUIREMENT_GRAPH,
    update_requirement_profile,
    confirm_requirements,
    TOOL_LIST,
)
from ai_service.agents.build_agent import (
    BUILD_TOOLS,
    BuildGenerationRequest,
    BuildGenerationResponse,
    generate_compatible_build,
)
from ai_service.agents.inventory_agent import (
    INVENTORY_TOOLS,
    InventoryCheckRequest,
    StockVerificationResult,
    verify_build_inventory,
)
from ai_service.agents.order_planning_agent import (
    ORDER_PLANNING_TOOLS,
    OrderPlanningRequest,
    OrderProposalResponse,
    generate_order_proposal,
)
from ai_service.agents.after_sales_agent import (
    AFTER_SALES_TOOLS,
    AfterSalesChatRequest,
    AfterSalesChatResponse,
    run_after_sales_chat,
)

app = FastAPI(
    title="PCForge Agentic AI Service",
    description="Internal microservice hosting the 5 AI agents for PCForge (Member 01-05).",
    version="1.0.0",
)

# Enable CORS for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health_check():
    """Liveness & configuration probe (costs 0 quota)."""
    has_gemini_key = bool(GOOGLE_API_KEY and GOOGLE_API_KEY.strip() and not GOOGLE_API_KEY.strip().lower().startswith("your_"))
    return {
        "status": "healthy",
        "service": "pcforge-ai-service",
        "chat_model": CHAT_MODEL,
        "gemini_api_configured": has_gemini_key,
        "active_agents": [
            "Requirement & Product Discovery Agent (Member 01)",
            "PC Build & Compatibility Agent (Member 03)",
        ],
    }


@app.get("/agent/requirements/tools")
def get_tools():
    """Returns schemas of allow-listed tools advertised to the model (Lab 05 Task 05).
    These are the tools the LLM can call via native tool calling.
    """
    return {
        "agent": "requirement_agent",
        "tools": [
            {
                "name": t.name,
                "description": t.description,
                "args_schema": t.args,
            }
            for t in TOOL_LIST
        ],
    }


@app.post("/agent/requirements/chat", response_model=RequirementChatResponse)
def requirement_chat(request: RequirementChatRequest):
    """Processes a natural language message from customer for requirement discovery.
    Maintains state across turns per session_id using LangGraph checkpointing.
    """
    if not request.session_id or not request.session_id.strip():
        raise HTTPException(status_code=400, detail="session_id is required")
    if not request.message or not request.message.strip():
        raise HTTPException(status_code=400, detail="message cannot be empty")

    try:
        result = run_requirement_chat(
            session_id=request.session_id.strip(),
            message=request.message.strip()
        )
        return RequirementChatResponse(**result)
    except Exception as e:
        print(f"[api] Error running requirement chat: {e}")
        raise HTTPException(status_code=500, detail=f"Agent workflow error: {str(e)}")


@app.get("/agent/requirements/session/{session_id}")
def get_requirement_session(session_id: str):
    """Retrieves current state snapshot from checkpointer for given session."""
    config = {"configurable": {"thread_id": session_id}}
    try:
        snapshot = REQUIREMENT_GRAPH.get_state(config)
        if not snapshot or not snapshot.values:
            return {
                "session_id": session_id,
                "found": False,
                "profile": None,
                "messages_count": 0,
            }
        profile = snapshot.values.get("profile", RequirementProfile())
        messages = snapshot.values.get("messages", [])
        return {
            "session_id": session_id,
            "found": True,
            "profile": profile,
            "messages_count": len(messages),
            "status": "ready_for_build" if profile.is_complete else "gathering",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/agent/build/tools")
def get_build_tools():
    """Returns schemas of allow-listed tools for Member 03 PC Build & Compatibility Agent (Lab 05 Task 05)."""
    return {
        "agent": "build_compatibility_agent",
        "member": "Member 03",
        "tools": [
            {
                "name": t.name,
                "description": t.description,
                "args_schema": t.args,
            }
            for t in BUILD_TOOLS
        ],
    }


@app.post("/agent/build/generate", response_model=BuildGenerationResponse)
def generate_build(request: BuildGenerationRequest):
    """Executes Member 03's PC Build & Compatibility Agent.
    Produces an 8-component hardware BOM validated against socket, memory, wattage, and chassis rules.
    """
    try:
        response = generate_compatible_build(request)
        return response
    except Exception as e:
        print(f"[api] Error running build agent: {e}")
        raise HTTPException(status_code=500, detail=f"Build Agent error: {str(e)}")


@app.get("/agent/inventory/tools")
def get_inventory_tools():
    """Returns schemas of allow-listed tools for Member 02 Inventory Agent (Lab 05 Task 05)."""
    return {
        "agent": "inventory_agent",
        "member": "Member 02",
        "tools": [
            {
                "name": t.name,
                "description": t.description,
                "args_schema": t.args,
            }
            for t in INVENTORY_TOOLS
        ],
    }


@app.post("/agent/inventory/verify-stock", response_model=StockVerificationResult)
def verify_inventory(request: InventoryCheckRequest):
    """Executes Member 02's Inventory Agent.
    Verifies real shelf stock for all 8 components, applies substitutes if any are out of stock,
    and locks a 15-minute reservation hold.
    """
    try:
        response = verify_build_inventory(request)
        return response
    except Exception as e:
        print(f"[api] Error running inventory agent: {e}")
        raise HTTPException(status_code=500, detail=f"Inventory Agent error: {str(e)}")


@app.get("/agent/order-planning/tools")
def get_order_planning_tools():
    """Returns schemas of allow-listed tools for Member 04 Order Planning Agent (Lab 05 Task 05)."""
    return {
        "agent": "order_planning_agent",
        "member": "Member 04",
        "tools": [
            {
                "name": t.name,
                "description": t.description,
                "args_schema": t.args,
            }
            for t in ORDER_PLANNING_TOOLS
        ],
    }


@app.post("/agent/order-planning/create-proposal", response_model=OrderProposalResponse)
def create_order_proposal_endpoint(request: OrderPlanningRequest):
    """Executes Member 04's Order Planning Agent.
    Calculates subtotal, applies promotional discounts, computes delivery,
    and produces an order proposal holding status WAITING_FOR_APPROVAL.
    """
    try:
        response = generate_order_proposal(request)
        return response
    except Exception as e:
        print(f"[api] Error running order planning agent: {e}")
        raise HTTPException(status_code=500, detail=f"Order Planning Agent error: {str(e)}")


@app.get("/agent/after-sales/tools")
def get_after_sales_tools():
    """Returns schemas of allow-listed tools for Member 05 After-Sales Agent (Lab 05 Task 05)."""
    return {
        "agent": "after_sales_agent",
        "member": "Member 05",
        "tools": [
            {
                "name": t.name,
                "description": t.description,
                "args_schema": t.args,
            }
            for t in AFTER_SALES_TOOLS
        ],
    }


@app.post("/agent/after-sales/chat", response_model=AfterSalesChatResponse)
def after_sales_chat_endpoint(request: AfterSalesChatRequest):
    """Executes Member 05's After-Sales Agent.
    Answers post-purchase questions, checks hardware warranty terms,
    and opens RMA support tickets for staff technician inspection (UI 8).
    """
    try:
        response = run_after_sales_chat(request)
        return response
    except Exception as e:
        print(f"[api] Error running after-sales agent: {e}")
        raise HTTPException(status_code=500, detail=f"After-Sales Agent error: {str(e)}")


if __name__ == "__main__":
    uvicorn.run("ai_service.main:app", host=AI_SERVICE_HOST, port=AI_SERVICE_PORT, reload=True)
