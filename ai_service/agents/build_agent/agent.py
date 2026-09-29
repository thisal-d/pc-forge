"""
PC Build & Compatibility Agent — PCForge (Member 03)
====================================================
Architecture:
  - Lab 05: Tool calling via bind_tools(BUILD_TOOLS) & ReAct execution loop
  - Lab 06: LangGraph StateGraph with messages reducer and ToolNode routing
  - Lecture 07: Strict boundary isolation, bounded iterations, and deterministic clearance proof
"""

import json
from typing import Annotated, Any, Dict, List, Optional, TypedDict

from langchain_core.messages import AIMessage, HumanMessage, SystemMessage, ToolMessage
from langgraph.graph import END, START, StateGraph
from langgraph.graph.message import add_messages

from ai_service.agents.build_agent.models import (
    BuildGenerationRequest,
    BuildGenerationResponse,
    CompatibilityChecklist,
    ComponentItem,
    ValidatedBuild,
)
from ai_service.agents.build_agent.tools import (
    BUILD_TOOLS,
    build_context_var,
    check_case_fit,
    check_memory_compatibility,
    check_psu_wattage,
    check_socket_compatibility,
    fetch_live_products,
    get_candidate_components,
    submit_validated_build,
)
from ai_service.config import get_llm

MAX_AGENT_ITERATIONS = 8  # Hard iteration cap (Lecture 07 Slide 122)
TOOLS_MAP = {t.name: t for t in BUILD_TOOLS}


# ------------------------------------------------------------------------------
# 1. State Definition (Lab 06 explicit StateGraph with add_messages)
# ------------------------------------------------------------------------------
class BuildAgentState(TypedDict):
    """Workflow state for the PC Build & Compatibility Agent."""
    messages: Annotated[list, add_messages]
    request: BuildGenerationRequest
    target_budget_usd: float
    selected_components: Dict[str, ComponentItem]
    checklist: CompatibilityChecklist
    iteration_count: int
    retry_count: int
    is_validated: bool
    summary: str
    trace_steps: List[str]
    error_message: Optional[str]


# ------------------------------------------------------------------------------
# 2. System Prompt & Persona
# ------------------------------------------------------------------------------
BUILD_SYSTEM_PROMPT = """\
You are the PC Build & Compatibility Agent (Member 03) for PCForge, an expert hardware systems architect.

YOUR MISSION:
Select a complete, balanced, and 100% technically compatible 8-component PC build matching the customer's \
workload, budget, and resolution targets.

REQUIRED SLOTS:
  1. cpu
  2. motherboard
  3. ram
  4. gpu
  5. psu
  6. storage
  7. pc_case
  8. cooler

REASONING WORKFLOW (ReAct):
  1. Call `get_candidate_components` for the necessary categories to inspect current database hardware and prices.
  2. Select 8 components tailored to the customer's purpose (e.g. Gaming, Workstation), target resolution, and budget.
  3. Call deterministic clearance tools to prove physical and electrical fit:
     - `check_socket_compatibility(cpu_socket, motherboard_socket)`
     - `check_memory_compatibility(ram_type, motherboard_memory_type)`
     - `check_psu_wattage(cpu_tdp, gpu_tdp, psu_wattage)`
     - `check_case_fit(motherboard_form_factor, case_form_factor)`
  4. Once all 4 checks pass, call `submit_validated_build` with the product IDs and your engineering rationale.

BOUNDARIES (Least Privilege — Lecture 07):
  - You do NOT verify warehouse shelf inventory or reserve stock — that belongs to Member 02 (Inventory Agent).
  - You do NOT apply discount vouchers or calculate shipping — that belongs to Member 04 (Order Planning Agent).
"""


# ------------------------------------------------------------------------------
# 3. Deterministic Safety Clearance Helpers
# ------------------------------------------------------------------------------
def _normalize_budget_to_usd(amount: float, currency: str) -> float:
    """Normalizes customer budget to USD reference price for catalog matching."""
    curr = (currency or "LKR").strip().upper()
    if curr == "LKR" or amount > 5000:
        return max(amount / 305.0, 350.0)
    return amount


def _run_compatibility_checks(components: Dict[str, ComponentItem]) -> CompatibilityChecklist:
    """Invokes deterministic clearance tools to generate the clearance checklist."""
    cpu = components.get("cpu")
    mobo = components.get("motherboard")
    ram = components.get("ram")
    gpu = components.get("gpu")
    psu = components.get("psu")
    case = components.get("pc_case")

    # 1. Socket Check
    sock_raw = check_socket_compatibility.invoke({
        "cpu_socket": cpu.socket if cpu else "",
        "motherboard_socket": mobo.socket if mobo else ""
    })
    sock_res = json.loads(sock_raw)

    # 2. Memory Check
    mem_raw = check_memory_compatibility.invoke({
        "ram_type": ram.memory_type if ram else "",
        "motherboard_memory_type": mobo.memory_type if mobo else ""
    })
    mem_res = json.loads(mem_raw)

    # 3. PSU Wattage Check
    cpu_w = cpu.power_wattage or 105 if cpu else 105
    gpu_w = gpu.power_wattage or 220 if gpu else 220
    psu_w = psu.power_wattage or 650 if psu else 650
    psu_raw = check_psu_wattage.invoke({
        "cpu_tdp": cpu_w,
        "gpu_tdp": gpu_w,
        "psu_wattage": psu_w
    })
    psu_res = json.loads(psu_raw)

    # 4. Case Fit Check
    case_raw = check_case_fit.invoke({
        "motherboard_form_factor": mobo.form_factor if mobo else "ATX",
        "case_form_factor": case.form_factor if case else "ATX"
    })
    case_res = json.loads(case_raw)

    all_passed = (
        sock_res["compatible"]
        and mem_res["compatible"]
        and psu_res["compatible"]
        and case_res["compatible"]
    )

    return CompatibilityChecklist(
        socket_match=sock_res["compatible"],
        socket_details=sock_res["details"],
        memory_match=mem_res["compatible"],
        memory_details=mem_res["details"],
        wattage_ok=psu_res["compatible"],
        estimated_wattage=psu_res["estimated_system_load_w"],
        psu_wattage=psu_res["psu_wattage_w"],
        headroom_watts=psu_res["net_headroom_w"],
        case_fit_ok=case_res["compatible"],
        case_fit_details=case_res["details"],
        all_passed=all_passed
    )





# ------------------------------------------------------------------------------
# 4. LangGraph ReAct Agent Nodes (Lab 05 Task 02 + Lab 06 StateGraph)
# ------------------------------------------------------------------------------
def agent_reasoning_node(state: BuildAgentState) -> Dict[str, Any]:
    """Calls the LLM with allow-listed tools bound to let it reason over hardware selections."""
    llm = get_llm()
    steps = list(state.get("trace_steps", []))
    it_count = state.get("iteration_count", 0) + 1

    if llm is None:
        err = "Google Gemini LLM is not configured for Build Agent. Please check GOOGLE_API_KEY in .env."
        steps.append(f"[Member 03 Error] {err}")
        return {
            "error_message": err,
            "iteration_count": it_count,
            "trace_steps": steps
        }

    llm_with_tools = llm.bind_tools(BUILD_TOOLS)
    response = llm_with_tools.invoke(state["messages"])

    if hasattr(response, "tool_calls") and response.tool_calls:
        tool_names = [tc["name"] for tc in response.tool_calls]
        steps.append(f"[Member 03 LLM Decision #{it_count}] Invoking tools: {', '.join(tool_names)}")
    elif response.content:
        thought_str = response.content if isinstance(response.content, str) else str(response.content)
        if thought_str.strip():
            steps.append(f"[Member 03 LLM Reasoning] {thought_str.strip()[:180]}")

    return {
        "messages": [response],
        "iteration_count": it_count,
        "trace_steps": steps
    }


def tools_execution_node(state: BuildAgentState) -> Dict[str, Any]:
    """Executes tool calls emitted by the LLM and appends ToolMessages."""
    last_msg = state["messages"][-1]
    tool_messages = []
    steps = list(state.get("trace_steps", []))
    comps = dict(state.get("selected_components", {}))
    is_valid = state.get("is_validated", False)
    summary = state.get("summary", "")
    checklist = state.get("checklist", CompatibilityChecklist())

    if hasattr(last_msg, "tool_calls") and last_msg.tool_calls:
        for tc in last_msg.tool_calls:
            tname = tc["name"]
            targs = tc["args"]
            tool_fn = TOOLS_MAP.get(tname)
            if not tool_fn:
                continue

            try:
                res_str = tool_fn.invoke(targs)
            except Exception as e:
                res_str = json.dumps({"error": str(e)})

            # Log execution summary
            if tname == "submit_validated_build":
                steps.append(f"[Member 03 Proposal Submitted] Final 8-component build submitted for validation.")
                try:
                    submitted = json.loads(res_str)
                    live_prods = fetch_live_products()
                    prod_map = {p["product_id"]: p for p in live_prods}

                    slot_map = {
                        "cpu": submitted.get("cpu_product_id"),
                        "motherboard": submitted.get("motherboard_product_id"),
                        "ram": submitted.get("ram_product_id"),
                        "gpu": submitted.get("gpu_product_id"),
                        "psu": submitted.get("psu_product_id"),
                        "storage": submitted.get("storage_product_id"),
                        "pc_case": submitted.get("case_product_id"),
                        "cooler": submitted.get("cooler_product_id"),
                    }
                    for slot, pid in slot_map.items():
                        if pid and pid in prod_map:
                            comps[slot] = ComponentItem(**prod_map[pid])

                    if len(comps) == 8:
                        checklist = _run_compatibility_checks(comps)
                        is_valid = checklist.all_passed
                        summary = submitted.get("engineering_notes") or submitted.get("build_name", "")
                except Exception as ex:
                    steps.append(f"[Member 03 Warning] Failed parsing submitted build: {ex}")
            else:
                steps.append(f"[Member 03 Tool Execution] {tname} -> {res_str[:110]}...")

            tool_messages.append(ToolMessage(
                content=res_str,
                name=tname,
                tool_call_id=tc["id"]
            ))

    return {
        "messages": tool_messages,
        "selected_components": comps,
        "checklist": checklist,
        "is_validated": is_valid,
        "summary": summary,
        "trace_steps": steps
    }


def should_continue(state: BuildAgentState) -> str:
    """Conditional Edge: Routes to tools if tool calls exist, or ends if complete."""
    if state.get("is_validated", False):
        return "finish"

    if state.get("iteration_count", 0) >= MAX_AGENT_ITERATIONS:
        return "finish"

    last_msg = state["messages"][-1]
    if hasattr(last_msg, "tool_calls") and last_msg.tool_calls:
        return "tools"

    return "finish"


# ------------------------------------------------------------------------------
# 5. Build Graph Assembly (Lab 06)
# ------------------------------------------------------------------------------
workflow = StateGraph(BuildAgentState)
workflow.add_node("agent", agent_reasoning_node)
workflow.add_node("tools", tools_execution_node)

workflow.add_edge(START, "agent")
workflow.add_conditional_edges(
    "agent",
    should_continue,
    {"tools": "tools", "finish": END}
)
workflow.add_edge("tools", "agent")

BUILD_GRAPH = workflow.compile()


# ------------------------------------------------------------------------------
# 6. Public Entry Point
# ------------------------------------------------------------------------------
def generate_compatible_build(request: BuildGenerationRequest) -> BuildGenerationResponse:
    """Public function executing Member 03's Build & Compatibility Agent.
    Invokes the Gemini LLM ReAct loop over live store inventory.
    """
    build_context_var.set({"catalog": request.catalog or []})
    budget_usd = _normalize_budget_to_usd(request.budget_amount, request.currency)

    system_msg = SystemMessage(content=BUILD_SYSTEM_PROMPT)
    user_msg = HumanMessage(content=f"""\
Customer PC Build Request:
- Purpose / Workload: {request.purpose}
- Target Resolution: {request.target_resolution}
- Budget: {request.budget_amount} {request.currency} (~${budget_usd:.0f} USD)
- Preferences: {', '.join(request.preferences) if request.preferences else 'None'}

Please:
1. Call `get_candidate_components` to retrieve available hardware from the catalog.
2. Select all 8 components (cpu, motherboard, ram, gpu, psu, storage, pc_case, cooler).
3. Call `check_socket_compatibility`, `check_memory_compatibility`, `check_psu_wattage`, and `check_case_fit` to prove they are physically and electrically compatible.
4. Once verified, call `submit_validated_build` with the product IDs and your engineering summary.
""")

    initial_state: BuildAgentState = {
        "messages": [system_msg, user_msg],
        "request": request,
        "target_budget_usd": budget_usd,
        "selected_components": {},
        "checklist": CompatibilityChecklist(),
        "iteration_count": 0,
        "retry_count": 0,
        "is_validated": False,
        "summary": "",
        "trace_steps": [
            f"[Member 03 Agent Initiated] Target: {request.target_resolution} {request.purpose} Build "
            f"(Budget: {request.budget_amount} {request.currency})"
        ],
        "error_message": None,
    }

    final_state = BUILD_GRAPH.invoke(initial_state)

    components = final_state.get("selected_components", {})
    checklist = final_state.get("checklist", CompatibilityChecklist())
    is_valid = final_state.get("is_validated", False)
    trace = final_state.get("trace_steps", [])
    summary = final_state.get("summary", "")

    err_msg = final_state.get("error_message")
    if err_msg:
        return BuildGenerationResponse(
            success=False,
            build=None,
            summary="Build generation failed.",
            trace_steps=trace,
            error=err_msg
        )

    if len(components) < 8 or not is_valid:
        return BuildGenerationResponse(
            success=False,
            build=None,
            summary="Build generation failed to find compatible components for all 8 required slots.",
            trace_steps=trace,
            error="The Build Agent was unable to assemble a complete 100% compatible 8-component build."
        )

    total_price = sum(c.price for c in components.values())
    est_wattage = checklist.estimated_wattage or sum((c.power_wattage or 0) for c in components.values())

    cpu_name = components.get("cpu").name if components.get("cpu") else "Custom CPU"
    gpu_name = components.get("gpu").name if components.get("gpu") else "Custom GPU"
    build_name = f"Gaming Rig — {cpu_name} / {gpu_name}"

    validated_build = ValidatedBuild(
        build_name=build_name,
        purpose=request.purpose,
        target_resolution=request.target_resolution,
        components=components,
        total_price=round(total_price, 2),
        estimated_wattage=est_wattage,
        compatibility=checklist,
        is_valid=is_valid,
        status="VALIDATED_PENDING_STOCK"
    )

    if not summary:
        summary = (
            f"PCForge Member 03 Agent verified 100% technical compatibility across all 8 hardware slots. "
            f"CPU/Motherboard socket verified ({checklist.socket_details}), RAM generation verified, "
            f"and PSU verified with +{checklist.headroom_watts}W transient safety headroom."
        )

    return BuildGenerationResponse(
        success=True,
        build=validated_build,
        summary=summary,
        trace_steps=trace
    )
