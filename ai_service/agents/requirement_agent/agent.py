"""
Requirement & Product Discovery Agent — PCForge (Member 01)
===========================================================
Architecture: Lab 05 Task 02/03 ReAct Agent + Lab 06 StateGraph with checkpointer.

The LLM receives the FULL conversation history on every turn.
It decides when to call the `update_requirement_profile` tool to save/update
extracted fields, exactly like the hand-rolled agent loop in Lab 05 Task 02.

Key course patterns applied:
  - Lab 05 Task 02: ReAct loop (invoke → tool_calls → execute → append ToolMessage → repeat)
  - Lab 05 Task 03: create_agent / bind_tools with system prompt
  - Lab 06 TODO 1:  State with `messages: Annotated[list, add_messages]`
  - Lab 06 TODO 5:  StateGraph compiled with InMemorySaver checkpointer
  - Lecture 07:     Context isolation, least-privilege boundaries, iteration cap
"""

import json
from typing import Annotated, Any, Dict, List, Optional, TypedDict

from langchain_core.messages import AIMessage, HumanMessage, SystemMessage, ToolMessage
from langchain_core.tools import tool
from langgraph.checkpoint.memory import InMemorySaver
from langgraph.graph import END, START, StateGraph
from langgraph.graph.message import add_messages
from pydantic import BaseModel, Field

from ai_service.agents.requirement_agent.models import RequirementProfile
from ai_service.config import get_llm
from ai_service.guardrails import SYSTEM_SECURITY_RULES, sanitize_and_delimit, validate_runtime_safety


# ------------------------------------------------------------------------------
# 1. State Definition (Lab 06 TODO 1 — add_messages reducer)
# ------------------------------------------------------------------------------
class RequirementState(TypedDict):
    """Shared state for the requirement discovery graph.
    `messages` uses add_messages so every node APPENDS to the conversation
    rather than replacing it — the exact pattern from Lab 06 TODO 1.
    """
    messages: Annotated[list, add_messages]   # Full conversation history
    profile: RequirementProfile               # Semantic memory: extracted requirements
    is_complete: bool                         # True when profile is confirmed
    iteration_count: int                      # Hard loop limiter (Lecture 07)


# ------------------------------------------------------------------------------
# 2. System Prompt (Lecture 05 Persona + Lecture 07 Guardrails)
# ------------------------------------------------------------------------------
REQUIREMENT_SYSTEM_PROMPT = """\
You are the Requirement & Product Discovery Agent for PCForge, a friendly PC building consultant.

YOUR JOB:
Gather the customer's PC requirements through natural, warm conversation.
You must discover ALL of these before presenting a summary:
  1. Purpose / Workload (Gaming, Video Editing, 3D Rendering, Office, Software Development, etc.)
  2. Budget (amount and currency, e.g., Rs. 400,000 or 400,000 LKR)
  3. Target Display Resolution (1080p, 1440p, 4K)
  4. Monitor Requirement (need a new monitor included, or already own one / tower only)
  5. Any special preferences (RGB, silent build, white aesthetic, compact ITX, peripherals, etc.)

RULES:
- Ask at most ONE focused question per turn. Never overwhelm with multiple questions.
- NEVER repeat your opening greeting once the conversation is underway.
- Keep responses warm, concise — 1 to 3 sentences maximum.
- When you learn new requirement info from the customer's message, call `update_requirement_profile` with the fields you extracted.
- When you need to correct a previously set field (e.g. customer says "actually my budget is X"), call `update_requirement_profile` with the corrected value.
- Once ALL required fields are gathered, present a bullet-point summary and ask the customer to confirm. Call `confirm_requirements` once the customer agrees.

BOUNDARIES (Least-Privilege — Lecture 07):
- You have NO access to product catalogs, stock inventory, or component prices.
- Do NOT recommend specific parts (e.g., "RTX 4070", "Ryzen 9") — that is the Build Agent's job.
- If asked about specific parts or stock, politely explain you need their general requirements \
first, then the Build and Inventory teams will handle part selection.
""" + "\n\n" + SYSTEM_SECURITY_RULES

MAX_AGENT_ITERATIONS = 8  # Hard iteration cap (Lecture 07 Slide 122)


# ------------------------------------------------------------------------------
# 3. Tools — allow-listed functions the LLM can call (Lab 05 Task 02)
#    "The docstring is the interface" — Lab 05; Lecture 05 Slide 736
# ------------------------------------------------------------------------------
@tool
def update_requirement_profile(
    purpose: Optional[str] = None,
    budget_amount: Optional[float] = None,
    currency: Optional[str] = None,
    budget_raw: Optional[str] = None,
    target_resolution: Optional[str] = None,
    monitor_needed: Optional[bool] = None,
    preferences: Optional[List[str]] = None,
) -> str:
    """Update the customer's PC requirement profile with newly discovered or corrected fields.
    Call this whenever the customer mentions their purpose, budget, resolution, monitor needs,
    or preferences. Only include the fields that were mentioned or changed — omit the rest.
    For budget: set budget_amount as a plain number (e.g., 400000), currency as 'LKR',
    and budget_raw as the original text (e.g., 'Rs. 400,000' or '400k LKR').
    For resolution: use '1080p', '1440p', or '4K'.
    """
    # This function body is executed by our code (Lab 05 Task 02 pattern).
    # We return a confirmation string; the actual state update happens in
    # _execute_tool_calls() which reads the args.
    updates = []
    if purpose is not None:
        updates.append(f"purpose={purpose}")
    if budget_amount is not None:
        updates.append(f"budget={currency or 'LKR'} {budget_amount:,.0f}")
    if target_resolution is not None:
        updates.append(f"resolution={target_resolution}")
    if monitor_needed is not None:
        updates.append(f"monitor_needed={monitor_needed}")
    if preferences is not None:
        updates.append(f"preferences={preferences}")
    return f"Profile updated: {', '.join(updates)}" if updates else "No fields to update."


@tool
def confirm_requirements() -> str:
    """Mark the requirement profile as complete and confirmed by the customer.
    Call this ONLY after the customer has explicitly agreed to the summary
    (e.g., they said 'yes', 'looks good', 'correct', 'proceed').
    Do NOT call this if the customer wants changes.
    """
    return "Requirements confirmed. Profile is now locked and ready for the Build Agent."


# Tool registry — Lab 05 Task 02 pattern: TOOLS = {"name": func, ...}
TOOLS = {
    "update_requirement_profile": update_requirement_profile,
    "confirm_requirements": confirm_requirements,
}
TOOL_LIST = [update_requirement_profile, confirm_requirements]


# ------------------------------------------------------------------------------
# 4. Helper: safely extract text from Gemini responses
# ------------------------------------------------------------------------------
def _extract_text_content(content) -> str:
    """Gemini can return content as a string OR a list of content blocks.
    This helper handles both — same pattern as Lab 05 Task 01 `text_of()`.
    """
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict) and "text" in item:
                parts.append(item["text"])
            elif hasattr(item, "text"):
                parts.append(str(item.text))
            elif isinstance(item, str):
                parts.append(item)
        return " ".join(parts).strip() if parts else ""
    return str(content).strip()


# ------------------------------------------------------------------------------
# 5. Graph Node: the agent node (Lab 05 Task 02 ReAct loop, inside a StateGraph)
# ------------------------------------------------------------------------------
def agent_node(state: RequirementState) -> Dict[str, Any]:
    """The core ReAct agent node.
    On each invocation:
      1. Sends the FULL message history (with SystemMessage) to the LLM
      2. If the LLM requests tool calls → execute them, append ToolMessages, re-invoke
      3. If the LLM produces a plain text response → return it as the reply
    This is the exact Lab 05 Task 02 loop, but inside a LangGraph node.
    """
    llm = get_llm()
    if llm is None:
        return {
            "messages": [AIMessage(content="I'm sorry, the AI service is not configured. "
                                           "Please check the API key.")],
        }

    # Bind our tools to the LLM (Lab 05 Task 02: llm_with_tools = llm.bind_tools(tools))
    llm_with_tools = llm.bind_tools(TOOL_LIST)

    messages = list(state.get("messages", []))
    profile = state.get("profile", RequirementProfile())
    iteration_count = state.get("iteration_count", 0)

    # Ensure SystemMessage is at the front (Lab 05 Task 01 pattern)
    if not messages or not isinstance(messages[0], SystemMessage):
        messages.insert(0, SystemMessage(content=REQUIREMENT_SYSTEM_PROMPT))

    # --- ReAct Loop (Lab 05 Task 02): model proposes, THIS code disposes ---
    new_messages = []  # Messages generated in this turn (to append to state)
    for step in range(MAX_AGENT_ITERATIONS):
        try:
            response = llm_with_tools.invoke(messages)
        except Exception as e:
            print(f"[requirement_agent] Error: LLM invocation failed: {e}")
            last_human = ""
            for m in reversed(messages):
                if isinstance(m, HumanMessage) or getattr(m, "type", "") == "human":
                    last_human = _extract_text_content(m.content)
                    break
            profile = _heuristic_slot_extraction(last_human, profile)
            missing = profile.missing_fields
            if not missing or profile.is_complete:
                reply_txt = f"Requirements confirmed for your {profile.purpose or 'custom'} PC build with budget {profile.budget_raw or 'specified'}. Ready for the Build Agent."
            elif missing:
                reply_txt = f"Noted your {profile.purpose or 'custom'} requirements! What is your preference for {missing[0].replace('_', ' ')}?"
            else:
                reply_txt = "Could you tell me more about your requirements?"
            err_msg = AIMessage(content=reply_txt)
            messages.append(err_msg)
            new_messages.append(err_msg)
            break

        # Append the AIMessage to our working list AND to new_messages
        messages.append(response)
        new_messages.append(response)

        # If no tool calls → the model produced a final text reply. Done.
        if not response.tool_calls:
            break

        # Execute each requested tool (Lab 05 Task 02 pattern)
        for call in response.tool_calls:
            tool_name = call["name"]
            args = call["args"]

            if tool_name in TOOLS:
                result = TOOLS[tool_name].invoke(args)

                # Apply profile updates from the tool args
                if tool_name == "update_requirement_profile":
                    profile = _apply_profile_update(profile, args)
                elif tool_name == "confirm_requirements":
                    profile = _mark_confirmed(profile)
            else:
                result = f"Error: unknown tool '{tool_name}'"

            # Append ToolMessage with matching tool_call_id (Lab 05 Task 02 — CRITICAL)
            tool_msg = ToolMessage(
                content=str(result),
                tool_call_id=call["id"],
            )
            messages.append(tool_msg)
            new_messages.append(tool_msg)

    # Ensure mentioned fields in customer message are extracted if LLM responded in conversational text
    last_human = ""
    for m in reversed(messages):
        if isinstance(m, HumanMessage) or getattr(m, "type", "") == "human":
            last_human = _extract_text_content(m.content)
            break
    if last_human:
        profile = _heuristic_slot_extraction(last_human, profile)

    # Recalculate missing fields
    profile = _recalculate_missing(profile)

    return {
        "messages": new_messages,
        "profile": profile,
        "is_complete": profile.is_complete,
        "iteration_count": iteration_count + 1,
    }


def _heuristic_slot_extraction(text: str, profile: RequirementProfile) -> RequirementProfile:
    """Fallback rule-based slot extraction when LLM experiences transient network or quota failures."""
    import re
    clean = (text or "").lower()
    updates: Dict[str, Any] = {}

    # Purpose
    for p in ["gaming", "video editing", "3d rendering", "software development", "office", "streaming", "workstation"]:
        if p in clean:
            updates["purpose"] = p.title()
            break

    # Resolution
    if "4k" in clean:
        updates["target_resolution"] = "4K"
    elif "1440p" in clean or "2k" in clean:
        updates["target_resolution"] = "1440p"
    elif "1080p" in clean or "fhd" in clean:
        updates["target_resolution"] = "1080p"

    # Monitor
    monitor_negative = [
        "already have a monitor", "already have", "already own", "have a monitor",
        "own a monitor", "tower only", "no monitor", "without a monitor", "without monitor",
        "just need the tower", "just the tower", "only the tower", "already got a monitor",
        "don't need a monitor", "dont need a monitor", "got a monitor"
    ]
    monitor_positive = [
        "include a monitor", "need a monitor", "with a monitor", "with monitor",
        "want a monitor", "add a monitor", "include monitor", "buying a monitor",
        "get a monitor", "buy a monitor", "plus monitor"
    ]
    if any(m in clean for m in monitor_negative):
        updates["monitor_needed"] = False
    elif any(m in clean for m in monitor_positive):
        updates["monitor_needed"] = True

    # Budget
    match = re.search(r'(?:rs\.?|lkr|budget\s*(?:is|of|:)?\s*(?:rs\.?|lkr)?)\s*([\d,]+(?:\.\d+)?)', clean)
    if not match:
        match = re.search(r'\b(\d{1,3}(?:,\d{3})+|\d{5,8})\b', clean)
    if match:
        raw_num = match.group(1).replace(",", "")
        try:
            val = float(raw_num)
            if val >= 50000:
                updates["budget_amount"] = val
                updates["currency"] = "LKR"
                updates["budget_raw"] = f"Rs. {val:,.0f}"
        except Exception:
            pass

    # Confirmation
    if any(w in clean for w in ["yes", "proceed", "looks good", "confirm", "perfect", "that's right", "thats right", "go ahead", "ready"]):
        if profile.purpose or profile.budget_amount or profile.budget_raw:
            profile = _mark_confirmed(profile)

    if updates:
        profile = _apply_profile_update(profile, updates)
    return profile


def _apply_profile_update(profile: RequirementProfile, args: Dict[str, Any]) -> RequirementProfile:
    """Non-destructively merge tool call args into the existing profile.
    Only fields explicitly provided in args are updated.
    """
    data = profile.model_dump()

    if args.get("purpose") is not None:
        data["purpose"] = args["purpose"]
    if args.get("budget_amount") is not None:
        data["budget_amount"] = float(args["budget_amount"])
    if args.get("currency") is not None:
        data["currency"] = args["currency"]
    if args.get("budget_raw") is not None:
        data["budget_raw"] = args["budget_raw"]
    elif args.get("budget_amount") is not None:
        # Auto-generate budget_raw if not provided
        curr = args.get("currency") or data.get("currency", "LKR")
        amt = float(args["budget_amount"])
        data["budget_raw"] = f"{curr} {amt:,.0f}"
    if args.get("target_resolution") is not None:
        data["target_resolution"] = args["target_resolution"]
    if args.get("monitor_needed") is not None:
        data["monitor_needed"] = args["monitor_needed"]
    if args.get("preferences") is not None:
        existing = set(data.get("preferences", []))
        for p in args["preferences"]:
            if p and p not in existing:
                data.setdefault("preferences", []).append(p)

    return RequirementProfile(**data)


def _mark_confirmed(profile: RequirementProfile) -> RequirementProfile:
    """Mark the profile as confirmed and complete."""
    data = profile.model_dump()
    data["confirmed_by_user"] = True
    data["is_complete"] = True
    return RequirementProfile(**data)


def _recalculate_missing(profile: RequirementProfile) -> RequirementProfile:
    """Recalculate the missing_fields list based on current profile state."""
    missing = []
    if not profile.purpose:
        missing.append("purpose")
    if not profile.budget_amount:
        missing.append("budget")
    if not profile.target_resolution:
        missing.append("target_resolution")
    if profile.monitor_needed is None:
        missing.append("monitor_needed")

    data = profile.model_dump()
    data["missing_fields"] = missing
    return RequirementProfile(**data)


# ------------------------------------------------------------------------------
# 7. Build & Compile the StateGraph (Lab 06 TODO 5)
# ------------------------------------------------------------------------------
def build_requirement_graph(checkpointer=None):
    """Builds and compiles the Requirement Discovery StateGraph.
    Single-node graph: START → agent → END.
    The agent node internally runs the ReAct loop (Lab 05 Task 02).
    State persistence comes from the checkpointer (Lab 06 InMemorySaver).
    """
    if checkpointer is None:
        checkpointer = InMemorySaver()

    builder = StateGraph(RequirementState)
    builder.add_node("agent", agent_node)
    builder.add_edge(START, "agent")
    builder.add_edge("agent", END)

    return builder.compile(checkpointer=checkpointer)


# Global persistent checkpointer across requests (Lab 06 pattern)
CHECKPOINTER = InMemorySaver()
REQUIREMENT_GRAPH = build_requirement_graph(CHECKPOINTER)


def create_requirement_agent(llm=None, checkpointer=None):
    """Factory alias matching Lab 05/06/07 conventions."""
    return build_requirement_graph(checkpointer=checkpointer or CHECKPOINTER)


# ------------------------------------------------------------------------------
# 8. Public Service Function (Called by FastAPI main.py)
# ------------------------------------------------------------------------------
def run_requirement_chat(session_id: str, message: str) -> Dict[str, Any]:
    """Executes one conversational turn on the Requirement Agent graph.

    The user's message is wrapped in a HumanMessage and passed into the graph.
    The graph's checkpointer (keyed by session_id as thread_id) ensures the full
    conversation history is automatically restored and extended — Lab 06 pattern.
    """
    config = {"configurable": {"thread_id": session_id}}

    # Defense Layer 2: Delimit untrusted input & neutralize delimiter breakouts (Lab 07 Part 5)
    delimited_message = sanitize_and_delimit(message, tag="user_input")

    # Input: delimited HumanMessage. The checkpointer restores prior messages.
    inputs = {
        "messages": [HumanMessage(content=delimited_message)],
    }

    final_state = REQUIREMENT_GRAPH.invoke(inputs, config)

    profile = final_state.get("profile", RequirementProfile())
    messages = final_state.get("messages", [])

    # Extract the last AI message as the reply (skip ToolMessages)
    last_ai_msg = "How can I help with your PC build today?"
    for m in reversed(messages):
        if isinstance(m, AIMessage) or getattr(m, "type", "") == "ai":
            text = _extract_text_content(m.content)
            # Skip empty AI messages (tool-call-only messages have empty content)
            if text and len(text) > 5:
                last_ai_msg = text
                break

    # Defense Layer 1: Deterministic runtime safety filter (Lab 07 Part 5)
    is_safe, validated_reply = validate_runtime_safety(last_ai_msg)
    if not is_safe:
        last_ai_msg = validated_reply

    return {
        "session_id": session_id,
        "reply": last_ai_msg,
        "profile": profile,
        "is_complete": profile.is_complete,
        "status": "ready_for_build" if profile.is_complete else "gathering",
    }

