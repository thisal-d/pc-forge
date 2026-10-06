"""
After-Sales Service Agent Implementation — PCForge (Member 05)
===============================================================
Autonomous LangGraph StateGraph agent utilizing Google Gemini and RAG knowledge.
Guides customers through safe, non-technical troubleshooting (max 5 attempts),
verifies real purchase and warranty from PostgreSQL, and creates Service Requests.
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
from ai_service.agents.after_sales_agent.models import (
    AfterSalesChatRequest,
    AfterSalesChatResponse,
    RmaTicketDetails,
    ServiceRequestDetails,
)
from ai_service.agents.after_sales_agent.tools import (
    AFTER_SALES_TOOLS,
    after_sales_context_var,
    check_warranty,
    create_service_request,
    get_customer,
    get_order,
    get_order_products,
    search_troubleshooting_knowledge,
    update_service_appointment,
    validate_service_appointment,
)

TOOLS_BY_NAME = {t.name: t for t in AFTER_SALES_TOOLS}

AFTER_SALES_SYSTEM_PROMPT = """\
You are the PCForge AI After-Sales Service Agent, an empathetic and patient customer support representative.
Your mission is to help customers who have issues with a PC or computer component purchased from PCForge.

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
1. Symptom Understanding:
   - Understand the customer's problem (e.g., "PC won't turn on", "screen is black", "PC keeps restarting", "PC is very slow", "strange noise").
   - Call `search_troubleshooting_knowledge` with their symptom ONCE at the start of the issue to retrieve the matched category and procedure steps.
   - CRITICAL: Once `search_troubleshooting_knowledge` has been called, DO NOT call it again for subsequent checks in the same session. You already have all steps in the conversation history!

2. One Step at a Time with Service Request Option:
   - Provide exactly ONE simple, safe troubleshooting instruction per turn (Step 1, Step 2, etc.).
   - Follow the numbered sequence in order: Step 1 → Step 2 → Step 3 → Step 4 → Step 5.
   - At each step, invite the customer to choose: they can either report if the step worked, OR they can choose to stop troubleshooting right now and create a Service Request for technician inspection.

3. Suggesting Service Request after 5 Attempts:
   - If troubleshooting reaches 5 unsuccessful attempts without resolution (or after completing Step 5):
     * You MUST proactively suggest creating a Service Request:
       "We have tried 5 troubleshooting steps and your PC issue is not resolved. I suggest creating a Service Request so one of our service center technicians can inspect and repair your PC in person."
     * Promptly switch to SERVICE REQUEST MODE!
   - If the customer at ANY point asks or confirms to create a service request, stop troubleshooting, or requests a technician:
     * IMMEDIATELY STOP TROUBLESHOOTING. Do not provide any more troubleshooting steps.
     * Switch directly to SERVICE REQUEST MODE!

--- MODE 2: SERVICE REQUEST MODE ---
Once in Service Request Mode, stop troubleshooting and follow these exact steps:

1. Request Appointment Information:
   - Ask the customer for their preferred appointment date and time (between 9:00 AM and 6:00 PM, Monday through Saturday).
   - Do NOT ask for an Order ID under any circumstances. There is no Order ID requirement.
   - Understand the customer's natural language for dates and times (e.g., "Tomorrow at 2 PM", "2 PM", "Tomorrow", "Next Monday at 10", "Friday afternoon").
   - NEVER ask for information that the customer has already provided!
     * If the customer provides both date and time: recognize that both are available and proceed to validate and summarize.
     * If the customer provides only the date: remember the date, do NOT ask for the date again, and ask ONLY for the missing time (e.g. "What time would you prefer?").
     * If the customer provides only the time: remember the time, do NOT ask for the time again, and ask ONLY for the missing date (e.g. "What date would you prefer?").
     * If the customer provides neither: ask for their preferred date and time.

2. Validate Date and Time:
   - Call `validate_service_appointment(preferred_date=..., preferred_time=...)`.
   - The date must NOT be in the past.
   - Operating hours are 9:00 AM to 6:00 PM. Closed on Sundays.
   - Storewide booking limit: Maximum 10 Service Requests per date.
   - Do NOT create the Service Request until both date and time are valid!

3. Generate Title & Description and Request Customer Confirmation:
   - Synthesize a concise Title and detailed Description from the conversation.
   - Show the generated details to the customer and ask for confirmation:
     "Here are the details for your Service Request:

     Title: [Generated Title]
     Description: [Generated Description]
     Preferred Date: [Date]
     Preferred Time: [Time]

     Please confirm if you would like to submit this Service Request, or let me know if you would like to edit anything."
   - Do NOT call `create_service_request` until the customer confirms (e.g., "confirm", "yes", "looks good", "submit", "proceed")!

4. Service Request Creation:
   - Once confirmed by the customer, create the Service Request using `create_service_request`.
   - New requests start in Pending status.
   - Display the confirmation with Service Request Number, title, date, time, and Pending status.

5. Rescheduling (Duplicate Prevention):
   - If the customer wants to change date/time after creation, call `update_service_appointment`.

STYLE & FORMATTING (CRITICAL):
- Write in a clean, natural conversational style.
- Do NOT use Markdown bold (**text**), italics (*text*), stray asterisks (*), or raw markdown headers (###).
- Output must be clean, readable plain text for a conversational chat UI.
"""


class AfterSalesState(TypedDict):
    """LangGraph conversation state for Member 05 After-Sales Service Agent."""
    messages: Annotated[List[BaseMessage], add_messages]
    customer_id: int
    session_id: str
    problem_description: str
    problem_category: str
    product_name: str
    product_id: Optional[int]
    order_id: Optional[int]
    troubleshooting_attempt: int
    attempted_steps: List[str]
    issue_resolved: bool
    warranty_status: str
    warranty_expiry_date: Optional[str]
    preferred_date: Optional[str]
    preferred_time: Optional[str]
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

        date_info = f"Already collected preferred date: {known_date}." if known_date else "Preferred date: not yet provided."
        time_info = f"Already collected preferred time: {known_time}." if known_time else "Preferred time: not yet provided."

        directive = SystemMessage(
            content=(
                f"[DIRECTIVE: Service Request Mode is ACTIVE. Do NOT provide troubleshooting steps.\n"
                f"RULES:\n"
                f"1. No Order ID is needed - NEVER ask for an Order ID.\n"
                f"2. Current Appointment State: {date_info} | {time_info}\n"
                f"3. NEVER ask for information that the user has already provided!\n"
                f"   - If the user provided only the date: remember the date and ask ONLY for the missing time (e.g. 'What time would you prefer?').\n"
                f"   - If the user provided only the time: remember the time and ask ONLY for the missing date (e.g. 'What date would you prefer?').\n"
                f"   - If both date and time are provided or known: validate using validate_service_appointment, show the summary, and ask for confirmation.\n"
                f"   - If neither date nor time is known: ask for preferred date and time.\n"
                f"4. Once the user confirms, call create_service_request.\n"
                f"5. Write clean natural text without markdown symbols or bold asterisks.]"
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
    warranty_st = state.get("warranty_status", "Active")
    warranty_exp = state.get("warranty_expiry_date")
    order_id = state.get("order_id")
    pref_date = state.get("preferred_date")
    pref_time = state.get("preferred_time")
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
                    elif t_name == "check_warranty":
                        warranty_st = parsed.get("warranty_status", warranty_st)
                        warranty_exp = parsed.get("warranty_expiry_date", warranty_exp)
                        if parsed.get("order_id"):
                            order_id = parsed.get("order_id")
                    elif t_name == "validate_service_appointment":
                        if parsed.get("valid") is True:
                            pref_date = parsed.get("date") or pref_date
                            pref_time = parsed.get("time") or pref_time
                        elif parsed.get("missing") == "time":
                            pref_date = parsed.get("date") or pref_date
                        elif parsed.get("missing") == "date":
                            pref_time = parsed.get("time") or pref_time
                        ctx = after_sales_context_var.get()
                        if isinstance(ctx, dict):
                            if pref_date:
                                ctx["preferred_date"] = pref_date
                            if pref_time:
                                ctx["preferred_time"] = pref_time
                    elif t_name == "update_service_appointment":
                        pref_date = parsed.get("preferred_date", pref_date)
                        pref_time = parsed.get("preferred_time", pref_time)
                        if sr_data:
                            sr_data["preferred_date"] = pref_date
                            sr_data["preferred_time"] = pref_time
                        else:
                            sr_data = parsed
                    elif t_name in ("create_service_request", "create_rma_ticket"):
                        sr_data = parsed
                        sr_required = True
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
        "warranty_status": warranty_st,
        "warranty_expiry_date": warranty_exp,
        "order_id": order_id,
        "preferred_date": pref_date,
        "preferred_time": pref_time,
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
        "service_requests": request.service_requests
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
    if state_history and state_history.get("channel_values"):
        vals = state_history.get("channel_values", {})
        prev_sr_mode = vals.get("service_request_mode", False)
        prev_pref_date = vals.get("preferred_date")
        prev_pref_time = vals.get("preferred_time")

    is_sr_mode = prev_sr_mode or user_requested_sr

    after_sales_context_var.set({
        "customer": request.customer,
        "orders": request.orders,
        "service_requests": request.service_requests,
        "preferred_date": prev_pref_date,
        "preferred_time": prev_pref_time
    })

    # Input message with iteration_count explicitly reset to 0 for this user turn
    inputs = {
        "messages": [HumanMessage(content=user_msg_clean)],
        "customer_id": request.user_id,
        "session_id": session_id,
        "order_id": None,
        "preferred_date": prev_pref_date,
        "preferred_time": prev_pref_time,
        "service_request_mode": is_sr_mode,
        "iteration_count": 0
    }

    # If first turn in this session, ensure System Prompt is seeded
    if not state_history or not state_history.get("channel_values", {}).get("messages"):
        inputs["messages"] = [
            SystemMessage(content=AFTER_SALES_SYSTEM_PROMPT),
            HumanMessage(content=user_msg_clean)
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

        # Step count and attempted steps tracking from reply
        step_match = re.search(r'\b(?:step|part)\s*(\d+)\b', reply_text, re.IGNORECASE)
        if step_match:
            step_num = int(step_match.group(1))
            attempt_count = max(attempt_count, step_num)
            step_desc = f"Step {step_num}"
            if step_desc not in attempted_steps:
                attempted_steps.append(step_desc)
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
        rma_legacy_model = None

        if sr_raw and (sr_raw.get("service_request_number") or sr_raw.get("service_request_id") or sr_raw.get("ticket_id")):
            num_id = sr_raw.get("service_request_id") or sr_raw.get("ticket_id") or 108
            sr_num = sr_raw.get("service_request_number") or sr_raw.get("rma_number") or f"SR-{num_id:06d}"

            sr_model = ServiceRequestDetails(
                id=num_id,
                service_request_id=num_id,
                service_request_number=sr_num,
                user_id=request.user_id,
                order_id=None,
                order_number=None,
                product_id=sr_raw.get("product_id") or 8,
                product_name=sr_raw.get("product_name") or sr_raw.get("component") or "Hardware Component",
                title=sr_raw.get("title") or (f"Service - {sr_raw.get('product_name')}" if sr_raw.get("product_name") else f"Service: {problem_category}"),
                description=sr_raw.get("description") or sr_raw.get("problem_description") or user_msg_clean,
                problem_description=sr_raw.get("problem_description") or user_msg_clean,
                problem_category=problem_category,
                troubleshooting_summary=sr_raw.get("troubleshooting_summary") or f"Troubleshooting completed ({attempt_count} attempts).",
                attempt_count=attempt_count or 1,
                warranty_status=sr_raw.get("warranty_status", "Active"),
                warranty_expiry_date=sr_raw.get("warranty_expiry_date", "Aug 2028"),
                preferred_date=sr_raw.get("preferred_date"),
                preferred_time=sr_raw.get("preferred_time") or "10:00 AM",
                status=sr_raw.get("status", "PENDING"),
                priority=sr_raw.get("priority", "Normal"),
                created_at=datetime.now(timezone.utc).isoformat()
            )

            rma_legacy_model = RmaTicketDetails(
                ticket_id=num_id,
                rma_number=sr_num,
                order_id=None,
                order_number=None,
                product_id=sr_model.product_id,
                component_name=sr_model.product_name,
                issue_type=problem_category,
                status=sr_model.status,
                priority=sr_model.priority,
                description=user_msg_clean,
                created_at=sr_model.created_at
            )
            sr_required = True
            is_sr_mode = True

        # If user explicitly requested service request on this turn and the LLM response is generic/step
        if user_requested_sr and not sr_model and not any(k in reply_text.lower() for k in ["appointment", "preferred date", "preferred time", "schedule", "monday", "tomorrow"]):
            if not reply_text or "step" in reply_text.lower():
                reply_text = (
                    "Understood. We will stop troubleshooting here and set up a Service Request "
                    "for our technicians to inspect your system in person.\n\n"
                    "What date and time would you prefer for the service appointment? "
                    "Our service center is open Monday through Saturday between 9:00 AM and 6:00 PM."
                )

        # Suggest Service Request after 5 unsuccessful troubleshooting attempts
        if attempt_count >= 5 and not is_resolved and not is_sr_mode and not sr_model:
            is_sr_mode = True
            if "service request" not in reply_text.lower() or "suggest" not in reply_text.lower():
                reply_text += (
                    "\n\nWe have completed 5 troubleshooting steps and your PC issue is not resolved. "
                    "I suggest creating a Service Request so one of our service center technicians can inspect and repair your PC in person.\n\n"
                    "What date and time would you prefer for the appointment? "
                    "Our service center is open Monday through Saturday between 9:00 AM and 6:00 PM."
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

        try:
            AFTER_SALES_GRAPH.update_state(
                config,
                {
                    "troubleshooting_attempt": attempt_count,
                    "attempted_steps": attempted_steps,
                    "problem_category": problem_category,
                    "preferred_date": final_pref_date,
                    "preferred_time": final_pref_time,
                    "service_request_required": sr_required or is_sr_mode,
                    "service_request_mode": is_sr_mode
                }
            )
        except Exception:
            pass

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
            ticket=rma_legacy_model,
            agent_trace=trace
        )

    except Exception as e:
        print(f"[run_after_sales_chat] Error: {e}")
        user_msg = (request.message or "").lower()
        if "step 5" in user_msg or "5 attempts" in user_msg or "5th attempt" in user_msg:
            return AfterSalesChatResponse(
                success=True,
                reply=clean_chat_formatting(
                    "We have completed 5 troubleshooting steps and your PC issue is not resolved. "
                    "I suggest creating a Service Request so one of our service center technicians can inspect and repair your PC in person.\n\n"
                    "What date and time would you prefer for the service appointment (Monday to Saturday, 9:00 AM to 6:00 PM)?"
                ),
                attempt_count=5,
                service_request_mode=True,
                service_request_required=True,
                agent_trace=[f"[Fallback Mode - External LLM Error: {str(e)}"]
            )
        if user_requested_sr or "service request" in user_msg or "appointment" in user_msg or "stop chatting" in user_msg:
            return AfterSalesChatResponse(
                success=True,
                reply=clean_chat_formatting(
                    "Understood. We will stop troubleshooting here and set up a Service Request for our technicians to inspect your system.\n\n"
                    "What date and time would you prefer for the service appointment (Monday to Saturday, 9:00 AM to 6:00 PM)?"
                ),
                service_request_mode=True,
                service_request_required=True,
                agent_trace=[f"[Fallback Mode - External LLM Error: {str(e)}"]
            )
        return AfterSalesChatResponse(
            success=True,
            reply=clean_chat_formatting(
                "I am here to help troubleshoot your PC. Please check that all cables and power connections are securely seated.\n\n"
                "If you would like to schedule an in-person technician appointment instead, just let me know or say 'Create Service Request'."
            ),
            agent_trace=[f"[Fallback Mode - External LLM Error: {str(e)}"]
        )
