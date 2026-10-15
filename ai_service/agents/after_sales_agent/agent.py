"""
After-Sales Service Agent for PCForge.
Guides customers through safe troubleshooting, checks warranty eligibility,
and creates or reschedules in-store service appointments.
"""

from datetime import datetime, timezone
import json
import re
from typing import Annotated, Any, Dict, List, Optional, TypedDict

from langchain_core.messages import AIMessage, BaseMessage, HumanMessage, SystemMessage, ToolMessage
from langgraph.checkpoint.memory import InMemorySaver
from langgraph.graph import END, START, StateGraph
from langgraph.graph.message import add_messages

from ai_service.config import get_llm
from ai_service.guardrails import SYSTEM_SECURITY_RULES, sanitize_and_delimit, validate_runtime_safety
from ai_service.agents.after_sales_agent.models import (
    AfterSalesChatRequest,
    AfterSalesChatResponse,
    ServiceRequestDetails,
)
from ai_service.agents.after_sales_agent.tools import (
    AFTER_SALES_TOOLS,
    after_sales_context_var,
    create_service_request,
    get_available_time_slots,
    get_customer,
    get_customer_service_requests,
    get_service_request,
    search_troubleshooting_knowledge,
    update_service_appointment,
    validate_service_appointment,
)

TOOLS_BY_NAME = {t.name: t for t in AFTER_SALES_TOOLS}

AFTER_SALES_SYSTEM_PROMPT = """\
You are the PCForge AI After-Sales Service Agent, an empathetic and patient customer support representative.
Your mission is to help customers who have issues with a PC or computer hardware.

CORE PRINCIPLE:
The customer is a regular person and does NOT have technical knowledge.
Never ask for technical metrics like CPU voltages, BIOS settings, GPU junction temperatures, or RAM timings.
Keep instructions simple, clear, and one step at a time.

SAFETY PROTOCOL (CRITICAL):
- Never instruct customers to open a Power Supply Unit (PSU), touch exposed electrical wires, or perform dangerous internal electrical modifications.
- If the customer reports burning smells, smoke, sparks, liquid spills, or electrical shocks, STOP troubleshooting immediately.
  Instruct them to disconnect the power cable immediately for safety, and switch to Service Request Mode for technician inspection.

TWO MODES OF OPERATION:
1. TROUBLESHOOTING MODE (Initial Chat)
2. SERVICE REQUEST MODE (Technician Intake)

--- MODE 1: TROUBLESHOOTING MODE ---
- Understand the customer's problem and consult the troubleshooting knowledge base.
- Provide exactly ONE safe, non-technical instruction per turn (Step 1 through Step 5).
- At each step, invite the customer to report progress or choose to stop troubleshooting and book a technician inspection.
- After 5 unsuccessful attempts, or if the customer at any point asks to create a service request or request a technician:
  Stop troubleshooting immediately and transition to Service Request Mode.

--- MODE 2: SERVICE REQUEST MODE ---
- Collect the customer's appointment preference:
  * Operating Days: Monday through Saturday (Closed on Sundays).
  * Available Time Slots: ALWAYS use `get_available_time_slots` with the requested date to retrieve active slots and remaining capacity directly from the store database, and present the active slots to the customer.
- Formulate a clear, concise Title (e.g. "PC won't boot into Windows" or "Display Artifacting") and problem Description based on the conversation so far.
- Service requests are general service appointments. Do NOT ask for or require an Order ID, Order Number, Product ID, Product Name, serial number, or warranty proof.
- Photos/images are not used in PCForge service requests. NEVER ask or instruct the customer to take, upload, or attach photos, images, or screenshots of the PC, components, or screens.
- Never re-ask for details already provided by the customer.
- Use `validate_service_appointment` to verify date and slot availability.
- Present a clear summary (Title, Description, Date, Time Slot) and ask the customer to confirm before booking.
- Once confirmed by the customer, create the Service Request using `create_service_request`.
- If the customer wishes to reschedule an existing appointment, use `update_service_appointment` without creating duplicates.

STYLE & FORMATTING:
- Write in a clean, natural conversational style.
- Do NOT use Markdown bold (**text**), italics (*text*), stray asterisks (*), or raw markdown headers (###).
- Output must be clean, readable plain text for a conversational chat UI.
""" + "\n\n" + SYSTEM_SECURITY_RULES


class AfterSalesState(TypedDict):
    """LangGraph conversation state for Member 05 After-Sales Service Agent."""
    messages: Annotated[List[BaseMessage], add_messages]
    customer_id: int
    session_id: str
    problem_description: str
    problem_category: str
    troubleshooting_attempt: int
    attempted_steps: List[str]
    issue_resolved: bool
    preferred_date: Optional[str]
    preferred_time: Optional[str]
    slot_id: Optional[int]
    slot_label: Optional[str]
    service_request_required: bool
    service_request_mode: bool
    service_request_data: Optional[Dict]
    agent_trace: List[str]
    iteration_count: int


def clean_chat_formatting(text: str) -> str:
    """Removes raw Markdown symbols (**bold**, *italics*, stray *, headers)
    to produce clean, natural conversational chat text.
    """
    if not text:
        return ""
    # Strip markdown headers (e.g. "### Step 1" -> "Step 1")
    cleaned = re.sub(r'^#{1,6}\s*', '', text, flags=re.MULTILINE)
    # Strip bold markdown (**word** -> word or __word__ -> word)
    cleaned = re.sub(r'\*\*(.*?)\*\*', r'\1', cleaned)
    cleaned = re.sub(r'__(.*?)__', r'\1', cleaned)
    # Strip italic markdown (*word* -> word or _word_ -> word)
    cleaned = re.sub(r'(?<!\w)\*([^\*\n]+)\*(?!\w)', r'\1', cleaned)
    cleaned = re.sub(r'(?<!\w)_([^_\n]+)_(?!\w)', r'\1', cleaned)
    # Remove any stray asterisks
    cleaned = re.sub(r'\*', '', cleaned)
    # Remove markdown link formatting [text](url) -> text
    cleaned = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', cleaned)
    # Clean up double spaces or excessive newlines
    cleaned = re.sub(r'[ \t]+', ' ', cleaned)
    cleaned = re.sub(r'\n{3,}', '\n\n', cleaned)
    return cleaned.strip()


def _extract_text(content: Any) -> str:
    """Helper to safely extract string text from message content."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and "text" in block:
                parts.append(block["text"])
            elif isinstance(block, str):
                parts.append(block)
        return "".join(parts)
    return str(content or "")


def agent_node(state: AfterSalesState) -> Dict:
    """Executes Gemini LLM with allow-listed after-sales tools bound."""
    messages = list(state.get("messages", []))
    trace = list(state.get("agent_trace", []))
    iteration = state.get("iteration_count", 0) + 1
    sr_mode = state.get("service_request_mode", False)

    trace.append(f"[After-Sales Node Turn #{iteration}] Processing customer message (SR Mode: {sr_mode})...")

    llm = get_llm()
    if llm is None:
        err = "Google Gemini LLM is not configured or failed to initialize. Please check GOOGLE_API_KEY in .env."
        trace.append(f"[Error] {err}")
        return {
            "messages": [AIMessage(content=f"Error: {err}")],
            "agent_trace": trace,
            "iteration_count": iteration,
            "service_request_mode": sr_mode
        }

    agent_llm = llm.bind_tools(AFTER_SALES_TOOLS)

    # If Service Request mode is active, inject a directive so the LLM stops troubleshooting and focuses on intake
    invocation_messages = messages
    if sr_mode:
        ctx = after_sales_context_var.get() if isinstance(after_sales_context_var.get(), dict) else {}
        known_date = state.get("preferred_date") or ctx.get("preferred_date")
        known_time = state.get("preferred_time") or ctx.get("preferred_time")
        known_slot = state.get("slot_label") or ctx.get("slot_label")

        date_info = f"Already collected preferred date: {known_date}." if known_date else "Preferred date: not yet provided."
        time_info = f"Already collected time slot: {known_slot or known_time}." if (known_slot or known_time) else "Time slot: not yet provided."

        directive = SystemMessage(
            content=(
                f"[Service Request Mode is ACTIVE. Do not troubleshoot.\n"
                f"- No Order ID is needed.\n"
                f"- Standard Slots: Slot 1 (09:00 AM - 11:00 AM), Slot 2 (11:00 AM - 01:00 PM), Slot 3 (02:00 PM - 04:00 PM), Slot 4 (04:00 PM - 06:00 PM).\n"
                f"- Current Appointment State: {date_info} | {time_info}\n"
                f"- If date or time slot is missing, ask only for the missing detail.\n"
                f"- When date and time slot are provided, validate the appointment, summarize the details (Title, Description, Date, Slot), and ask for confirmation.\n"
                f"- Once confirmed, book the service request using create_service_request.\n"
                f"- Use clean plain text without markdown asterisks.]"
            )
        )
        invocation_messages = messages + [directive]

    response = agent_llm.invoke(invocation_messages)

    if getattr(response, "tool_calls", None):
        for tc in response.tool_calls:
            trace.append(f"[Tool Call] {tc['name']} with args: {tc['args']}")

    return {
        "messages": [response],
        "agent_trace": trace,
        "iteration_count": iteration,
        "service_request_mode": sr_mode
    }


def tools_node(state: AfterSalesState) -> Dict:
    """Executes allow-listed tools requested by Gemini and updates state."""
    messages = state.get("messages", [])
    last_msg = messages[-1]
    trace = list(state.get("agent_trace", []))

    sr_data = state.get("service_request_data")
    attempt_count = state.get("troubleshooting_attempt", 0)
    attempted_steps = list(state.get("attempted_steps", []))
    problem_cat = state.get("problem_category", "General")
    pref_date = state.get("preferred_date")
    pref_time = state.get("preferred_time")
    pref_slot_id = state.get("slot_id")
    pref_slot_label = state.get("slot_label")
    sr_required = state.get("service_request_required", False)

    tool_messages = []
    for tool_call in getattr(last_msg, "tool_calls", []):
        t_name = tool_call["name"]
        t_args = tool_call["args"]
        call_id = tool_call["id"]

        if t_name not in TOOLS_BY_NAME:
            res_str = json.dumps({"error": f"Tool '{t_name}' is not allow-listed."})
        else:
            try:
                target_tool = TOOLS_BY_NAME[t_name]
                res_str = target_tool.invoke(t_args)

                # Parse tool response to maintain state
                try:
                    parsed = json.loads(res_str)
                    if t_name == "search_troubleshooting_knowledge":
                        problem_cat = parsed.get("matched_category", problem_cat)
                        if parsed.get("is_safety_hazard"):
                            sr_required = True
                    elif t_name == "validate_service_appointment":
                        if parsed.get("valid") is True:
                            pref_date = parsed.get("date") or pref_date
                            pref_time = parsed.get("time") or pref_time
                            pref_slot_id = parsed.get("slot_id") or pref_slot_id
                            pref_slot_label = parsed.get("slot_label") or pref_slot_label
                        elif parsed.get("missing") == "time":
                            pref_date = parsed.get("date") or pref_date
                        elif parsed.get("missing") == "date":
                            pref_time = parsed.get("time") or pref_time
                            pref_slot_id = parsed.get("slot_id") or pref_slot_id
                            pref_slot_label = parsed.get("slot_label") or pref_slot_label
                        ctx = after_sales_context_var.get()
                        if isinstance(ctx, dict):
                            if pref_date:
                                ctx["preferred_date"] = pref_date
                            if pref_time:
                                ctx["preferred_time"] = pref_time
                            if pref_slot_id:
                                ctx["slot_id"] = pref_slot_id
                            if pref_slot_label:
                                ctx["slot_label"] = pref_slot_label
                    elif t_name == "update_service_appointment":
                        pref_date = parsed.get("preferred_date", pref_date)
                        pref_time = parsed.get("preferred_time", pref_time)
                        pref_slot_id = parsed.get("slot_id", pref_slot_id)
                        pref_slot_label = parsed.get("slot_label", pref_slot_label)
                        if sr_data:
                            sr_data["preferred_date"] = pref_date
                            sr_data["preferred_time"] = pref_time
                            sr_data["slot_id"] = pref_slot_id
                            sr_data["slot_label"] = pref_slot_label
                        else:
                            sr_data = parsed
                    elif t_name == "create_service_request":
                        sr_data = parsed
                        sr_required = True
                        if parsed.get("slot_id"):
                            pref_slot_id = parsed.get("slot_id")
                        if parsed.get("slot_label"):
                            pref_slot_label = parsed.get("slot_label")
                except Exception:
                    pass
            except Exception as ex:
                res_str = json.dumps({"error": f"Error executing {t_name}: {str(ex)}"})

        trace.append(f"[Tool Response] {t_name} -> {res_str[:120]}...")
        tool_messages.append(
            ToolMessage(
                content=res_str,
                name=t_name,
                tool_call_id=call_id
            )
        )

    sr_mode = state.get("service_request_mode", False)

    return {
        "messages": tool_messages,
        "agent_trace": trace,
        "service_request_data": sr_data,
        "troubleshooting_attempt": attempt_count,
        "attempted_steps": attempted_steps,
        "problem_category": problem_cat,
        "preferred_date": pref_date,
        "preferred_time": pref_time,
        "slot_id": pref_slot_id,
        "slot_label": pref_slot_label,
        "service_request_required": sr_required,
        "service_request_mode": sr_mode or (sr_data is not None)
    }


def should_continue(state: AfterSalesState) -> str:
    """Routes to tools node if tool calls were generated, or terminates turn."""
    last_msg = state["messages"][-1]
    iteration = state.get("iteration_count", 0)

    if getattr(last_msg, "tool_calls", None) and len(last_msg.tool_calls) > 0:
        if iteration >= 5:  # Safety circuit breaker per-turn
            return END
        return "tools"
    return END


def build_after_sales_graph(checkpointer=None):
    """Assembles and compiles the After-Sales LangGraph StateGraph."""
    if checkpointer is None:
        checkpointer = InMemorySaver()

    builder = StateGraph(AfterSalesState)
    builder.add_node("agent", agent_node)
    builder.add_node("tools", tools_node)

    builder.set_entry_point("agent")
    builder.add_conditional_edges(
        "agent",
        should_continue,
        {
            "tools": "tools",
            END: END
        }
    )
    builder.add_edge("tools", "agent")

    return builder.compile(checkpointer=checkpointer)


# Shared persistent checkpointer across requests
CHECKPOINTER = InMemorySaver()
AFTER_SALES_GRAPH = build_after_sales_graph(CHECKPOINTER)


def run_after_sales_chat(request: AfterSalesChatRequest) -> AfterSalesChatResponse:
    """Public execution entry point for Member 05 After-Sales Service Agent."""
    after_sales_context_var.set({
        "customer": request.customer,
        "orders": request.orders,
        "service_requests": request.service_requests,
        "time_slots": request.time_slots,
    })
    session_id = request.session_id or f"after_sales_{request.user_id}"
    config = {"configurable": {"thread_id": session_id}}

    user_msg_clean = request.message.strip()

    # Pre-check for resolved signals
    resolved_triggers = ["it worked", "it works", "it turned on", "fixed now", "all good now", "it's working", "problem solved"]
    is_resolved = any(t in user_msg_clean.lower() for t in resolved_triggers)

    # Detect if user asks to stop chatting / create a service request / book technician
    sr_triggers = [
        "service request",
        "create service request",
        "open service request",
        "create a service request",
        "open a service request",
        "stop chatting",
        "stop troubleshooting",
        "stop chat",
        "technician",
        "book service",
        "book appointment",
        "open ticket",
        "rma ticket",
        "create ticket",
        "request service",
        "send technician",
        "want a technician",
        "talk to technician"
    ]
    user_requested_sr = any(t in user_msg_clean.lower() for t in sr_triggers)

    # Check previous session state
    state_history = CHECKPOINTER.get(config)
    prev_sr_mode = False
    prev_pref_date = None
    prev_pref_time = None
    prev_slot_id = None
    prev_slot_label = None
    if state_history and state_history.get("channel_values"):
        vals = state_history.get("channel_values", {})
        prev_sr_mode = vals.get("service_request_mode", False)
        prev_pref_date = vals.get("preferred_date")
        prev_pref_time = vals.get("preferred_time")
        prev_slot_id = vals.get("slot_id")
        prev_slot_label = vals.get("slot_label")

    is_sr_mode = prev_sr_mode or user_requested_sr

    after_sales_context_var.set({
        "customer": request.customer,
        "orders": request.orders,
        "service_requests": request.service_requests,
        "time_slots": request.time_slots,
        "preferred_date": prev_pref_date,
        "preferred_time": prev_pref_time,
        "slot_id": prev_slot_id,
        "slot_label": prev_slot_label
    })

    # Delimit untrusted input & neutralize delimiter breakouts
    delimited_user_msg = sanitize_and_delimit(user_msg_clean, tag="customer_input")

    # Input message with iteration_count explicitly reset to 0 for this user turn
    inputs = {
        "messages": [HumanMessage(content=delimited_user_msg)],
        "customer_id": request.user_id,
        "session_id": session_id,
        "order_id": None,
        "preferred_date": prev_pref_date,
        "preferred_time": prev_pref_time,
        "slot_id": prev_slot_id,
        "slot_label": prev_slot_label,
        "service_request_mode": is_sr_mode,
        "iteration_count": 0
    }

    # If first turn in this session, ensure System Prompt is seeded
    if not state_history or not state_history.get("channel_values", {}).get("messages"):
        inputs["messages"] = [
            SystemMessage(content=AFTER_SALES_SYSTEM_PROMPT),
            HumanMessage(content=delimited_user_msg)
        ]


    try:
        final_state = AFTER_SALES_GRAPH.invoke(inputs, config)
        trace = final_state.get("agent_trace", [])
        sr_raw = final_state.get("service_request_data")
        attempt_count = final_state.get("troubleshooting_attempt", 0)
        attempted_steps = list(final_state.get("attempted_steps", []))
        problem_category = final_state.get("problem_category", "General")
        sr_required = final_state.get("service_request_required", False)
        is_sr_mode = final_state.get("service_request_mode", is_sr_mode)

        all_msgs = final_state.get("messages", [])

        # Extract reply text ONLY from the AI messages generated in THIS turn (after the last HumanMessage)
        reply_text = ""
        last_human_idx = -1
        for i in range(len(all_msgs) - 1, -1, -1):
            if isinstance(all_msgs[i], HumanMessage) or getattr(all_msgs[i], "type", "") == "human":
                last_human_idx = i
                break

        if last_human_idx >= 0:
            for m in reversed(all_msgs[last_human_idx + 1:]):
                if isinstance(m, AIMessage) or getattr(m, "type", "") == "ai":
                    content = _extract_text(m.content)
                    if content and len(content.strip()) > 5:
                        reply_text = content.strip()
                        break

        # If current turn produced only tool calls without final text, generate reply using LLM
        if not reply_text:
            llm = get_llm()
            if llm:
                try:
                    followup = llm.invoke(all_msgs)
                    reply_text = _extract_text(followup.content).strip()
                except Exception:
                    pass

        # Step count and attempted steps tracking from user message and agent reply
        user_step_match = re.search(r'\b(?:step|part)\s*(\d+)\b', user_msg_clean, re.IGNORECASE)
        if user_step_match:
            u_step = int(user_step_match.group(1))
            attempt_count = max(attempt_count, u_step)
            u_desc = f"Step {u_step}"
            if u_desc not in attempted_steps:
                attempted_steps.append(u_desc)

        step_match = re.search(r'\b(?:step|part)\s*(\d+)\b', reply_text, re.IGNORECASE)
        if step_match:
            step_num = int(step_match.group(1))
            attempt_count = max(attempt_count, step_num)
            step_desc = f"Step {step_num}"
            if step_desc not in attempted_steps:
                attempted_steps.append(step_desc)

        # Detect completion of 5 steps or customer saying step 5
        if (
            attempt_count >= 5
            or re.search(r'\b(?:five|5)\s*(?:troubleshooting\s*)?steps?\b', user_msg_clean, re.IGNORECASE)
            or re.search(r'\bstep\s*5\b', user_msg_clean, re.IGNORECASE)
            or re.search(r'\ball\s*five\s*steps\b', reply_text, re.IGNORECASE)
            or re.search(r'\ball\s*5\s*steps\b', reply_text, re.IGNORECASE)
        ):
            attempt_count = max(attempt_count, 5)
            is_sr_mode = True
            sr_required = True
        elif "service request" in reply_text.lower() and "technician" in reply_text.lower():
            is_sr_mode = True

        # Check if create_service_request, update_service_appointment, or create_rma_ticket tool was called in conversation
        if not sr_raw:
            for m in reversed(all_msgs):
                if isinstance(m, ToolMessage) and m.name in ("create_service_request", "create_rma_ticket", "update_service_appointment"):
                    try:
                        sr_raw = json.loads(m.content)
                        break
                    except Exception:
                        pass

        # Build ServiceRequestDetails if Service Request was created
        sr_model = None

        if sr_raw and (sr_raw.get("service_request_number") or sr_raw.get("service_request_id")):
            num_id = sr_raw.get("service_request_id") or 108
            sr_num = sr_raw.get("service_request_number") or f"SR-{num_id:06d}"
            raw_act = str(sr_raw.get("action") or "create").lower()
            action_type = "update" if ("update" in raw_act or "reschedule" in raw_act) else "create"

            sr_model = ServiceRequestDetails(
                action=action_type,
                id=num_id,
                service_request_id=num_id,
                service_request_number=sr_num,
                user_id=request.user_id,
                title=sr_raw.get("title") or f"Service: {problem_category}",
                description=sr_raw.get("description") or sr_raw.get("problem_description") or user_msg_clean,
                problem_description=sr_raw.get("problem_description") or user_msg_clean,
                problem_category=problem_category,
                troubleshooting_summary=sr_raw.get("troubleshooting_summary") or f"Troubleshooting completed ({attempt_count} attempts).",
                attempt_count=attempt_count or 1,
                preferred_date=sr_raw.get("preferred_date"),
                preferred_time=sr_raw.get("preferred_time") or "10:00 AM",
                slot_id=sr_raw.get("slot_id"),
                slot_label=sr_raw.get("slot_label") or sr_raw.get("preferred_time"),
                status=sr_raw.get("status", "BOOKED"),
                priority=sr_raw.get("priority", "Normal"),
                created_at=datetime.now(timezone.utc).isoformat()
            )
            sr_required = True
            is_sr_mode = True

        # If user explicitly requested service request on this turn and the LLM response is generic/step
        if user_requested_sr and not sr_model and not any(k in reply_text.lower() for k in ["appointment", "preferred date", "preferred time", "schedule", "monday", "tomorrow"]):
            if not reply_text or "step" in reply_text.lower():
                reply_text = (
                    "Understood. We will stop troubleshooting here and set up a Service Request "
                    "for our technicians to inspect your system in person.\n\n"
                    "What date and time slot would you prefer for the service appointment? "
                    "Our service center is open Monday through Saturday between 9:00 AM and 6:00 PM."
                )

        # Suggest Service Request after 5 unsuccessful troubleshooting attempts
        if attempt_count >= 5 and not is_resolved and not sr_model:
            is_sr_mode = True
            sr_required = True
            if "service request" not in reply_text.lower():
                reply_text += (
                    "\n\nWe have completed 5 troubleshooting steps and your PC issue is not resolved. "
                    "I suggest creating a Service Request so one of our service center technicians can inspect and repair your PC in person.\n\n"
                    "What date and time slot would you prefer for the appointment? "
                    "Our service center is open Monday through Saturday with slots between 9:00 AM and 6:00 PM."
                )

        # While chatting during troubleshooting, prompt user to create a service request and stop chatting
        if not is_sr_mode and not is_resolved and not sr_model:
            if "service request" not in reply_text.lower():
                reply_text += (
                    "\n\nIf you prefer to have a technician inspect it in person, "
                    "just let me know or say 'Create Service Request' at any time."
                )

        if not reply_text:
            if sr_model:
                reply_text = sr_raw.get("confirmation_message") or f"Your Service Request ({sr_model.service_request_number}) has been created successfully. Our technician will inspect your PC."
            elif is_resolved:
                reply_text = "That is wonderful to hear! I'm glad your issue is resolved. Please feel free to reach out if you have any other questions about your PC."
            else:
                reply_text = "Let's check your PC setup. Please make sure all external cables are firmly connected, and let me know what happens."

        # Persist updated state into checkpointer
        is_sr_mode = is_sr_mode or (sr_model is not None) or (sr_raw is not None)
        ctx = after_sales_context_var.get() if isinstance(after_sales_context_var.get(), dict) else {}
        final_pref_date = final_state.get("preferred_date") or ctx.get("preferred_date") or prev_pref_date
        final_pref_time = final_state.get("preferred_time") or ctx.get("preferred_time") or prev_pref_time
        final_slot_id = final_state.get("slot_id") or ctx.get("slot_id") or prev_slot_id
        final_slot_label = final_state.get("slot_label") or ctx.get("slot_label") or prev_slot_label

        try:
            AFTER_SALES_GRAPH.update_state(
                config,
                {
                    "troubleshooting_attempt": attempt_count,
                    "attempted_steps": attempted_steps,
                    "problem_category": problem_category,
                    "preferred_date": final_pref_date,
                    "preferred_time": final_pref_time,
                    "slot_id": final_slot_id,
                    "slot_label": final_slot_label,
                    "service_request_required": sr_required or is_sr_mode,
                    "service_request_mode": is_sr_mode
                }
            )
        except Exception:
            pass

        # Runtime validation filter
        is_safe, validated_reply = validate_runtime_safety(reply_text)
        if not is_safe:
            reply_text = validated_reply

        return AfterSalesChatResponse(
            success=True,
            reply=clean_chat_formatting(reply_text),
            attempt_count=attempt_count,
            attempted_steps=attempted_steps,
            problem_category=problem_category,
            is_resolved=is_resolved,
            service_request_required=sr_required or is_sr_mode,
            service_request_mode=is_sr_mode,
            service_request=sr_model,
            agent_trace=trace
        )


    except Exception as e:
        print(f"[run_after_sales_chat] Error: {e}")
        return AfterSalesChatResponse(
            success=False,
            reply="The AI service is currently experiencing high demand or quota limits. Please try again shortly.",
            attempt_count=0,
            attempted_steps=[],
            service_request_mode=False,
            service_request_required=False,
            agent_trace=[f"[Error - External LLM Error: {str(e)}"]
        )
