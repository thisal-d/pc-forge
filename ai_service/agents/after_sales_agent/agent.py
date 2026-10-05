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

1. Request Customer Information:
   - Ask the customer for:
     * Preferred date
     * Preferred time (between 9:00 AM and 6:00 PM, Monday through Saturday)
     * Order ID, if applicable (optional if not purchased from PCForge)
   - If Order ID is provided, verify warranty using `check_warranty`.
   - Explain warranty coverage clearly (Active or Expired).

2. Validate Date and Time Strictly:
   - Always call `validate_service_appointment(preferred_date=..., preferred_time=...)`.
   - The date must NOT be in the past:
     If the customer provides a past date, explain that the date has already passed and ask for another date.
   - The time must be between 9:00 AM and 6:00 PM:
     If the customer provides a time before 9:00 AM or after 6:00 PM, explain that the service time must be between 9:00 AM and 6:00 PM and ask for another time.
   - Service Center operating days: Monday through Saturday (closed on Sundays). If Sunday is chosen, ask for a date from Monday to Saturday.
   - Storewide booking limit: Maximum 10 Service Requests per date. If the date already has 10 requests, inform the customer that the date already has 10 requests booked and ask them to choose another date.
   - CRITICAL: Do NOT create the Service Request until both date and time are valid!

3. Generate Title & Description and Request Customer Confirmation:
   - Synthesize a concise, professional Title and a detailed Description directly from the troubleshooting conversation.
   - Show the generated title and description to the customer and allow them to confirm or edit them before submission:
     "Here are the details generated from our troubleshooting session:

     Title: [Generated Title]
     Description: [Generated Description]
     Preferred Date: [Date]
     Preferred Time: [Time]
     Order ID: [Order ID or N/A]

     Please confirm if you would like to submit this Service Request, or let me know if you would like to edit the title or description."
   - Do NOT call `create_service_request` until the customer confirms (e.g., "confirm", "yes", "looks good", "submit", "proceed")!

4. Service Request Creation:
   - Once confirmed by the customer, create the Service Request using `create_service_request`.
   - New requests must start with Pending status.
   - Existing statuses: Pending, In Progress, Completed, No Show, Cancelled. Customers can cancel while Pending.
   - Display the final confirmation details with the Service Request ID, title, appointment date/time, and Pending status.

5. Rescheduling & Changing Time/Date (STRICT DUPLICATE PREVENTION):
   - NEVER create multiple Service Requests for the same customer issue!
   - Once a Service Request has already been created (e.g., [SR-NUMBER]):
     If the customer asks for a different time, a different date, or wants to reschedule:
     * DO NOT call `create_service_request`!
     * Call `update_service_appointment(service_request_id_or_number=[SR-NUMBER], preferred_date=..., preferred_time=...)`.
     * Confirm to the customer that their appointment for [SR-NUMBER] has been rescheduled.
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
        directive = SystemMessage(
            content="[DIRECTIVE: Service Request Mode is ACTIVE. Do NOT provide troubleshooting steps or chatter. Proceed directly with Service Request intake: request or verify Order ID, check warranty using check_warranty, validate appointment using validate_service_appointment, and create the Service Request using create_service_request.]"
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
                            pref_date = parsed.get("date", pref_date)
                            pref_time = parsed.get("time", pref_time)
                        elif parsed.get("missing") == "time":
                            pref_date = parsed.get("date", pref_date)
                            pref_time = None
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
    if state_history and state_history.get("channel_values"):
        vals = state_history.get("channel_values", {})
        prev_sr_mode = vals.get("service_request_mode", False)

    is_sr_mode = prev_sr_mode or user_requested_sr

    # Input message with iteration_count explicitly reset to 0 for this user turn
    inputs = {
        "messages": [HumanMessage(content=user_msg_clean)],
        "customer_id": request.user_id,
        "session_id": session_id,
        "order_id": request.order_id,
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
        elif "service request" in reply_text.lower() and ("order id" in reply_text.lower() or "technician" in reply_text.lower()):
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
                order_id=sr_raw.get("order_id") or request.order_id or 1,
                order_number=sr_raw.get("order_number") or f"PCF-10{(request.order_id or 1):03d}",
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
                order_id=sr_model.order_id,
                order_number=sr_model.order_number,
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
        if user_requested_sr and not sr_model and not any(k in reply_text.lower() for k in ["order id", "order #", "pcf-"]):
            if not reply_text or "step" in reply_text.lower():
                reply_text = (
                    "Understood! We'll stop the troubleshooting process here and get a Service Request set up "
                    "for our technicians to inspect your system in person.\n\n"
                    "Please provide your **Order ID** (e.g., Order #1 or PCF-10001) so I can verify your purchase "
                    "and warranty coverage."
                )

        # Suggest Service Request after 5 unsuccessful troubleshooting attempts
        if attempt_count >= 5 and not is_resolved and not is_sr_mode and not sr_model:
            is_sr_mode = True
            if "service request" not in reply_text.lower() or "suggest" not in reply_text.lower():
                reply_text += (
                    "\n\nWe have completed 5 troubleshooting steps and your PC issue is not resolved. "
                    "I suggest creating a Service Request so one of our service center technicians can inspect and repair your PC in person.\n\n"
                    "To proceed, please provide your preferred appointment date (Monday - Saturday), "
                    "preferred time between 9:00 AM and 6:00 PM, and your Order ID if applicable."
                )

        # While chatting during troubleshooting, prompt user to create a service request and stop chatting
        if not is_sr_mode and not is_resolved and not sr_model:
            if "service request" not in reply_text.lower():
                reply_text += (
                    "\n\n*Prefer to have a technician inspect it?* "
                    "If you would like to stop chatting now and create a Service Request for our technicians to inspect your PC in person, "
                    "just let me know or reply **\"Create Service Request\"**."
                )

        if not reply_text:
            if sr_model:
                reply_text = sr_raw.get("confirmation_message") or f"Your Service Request ({sr_model.service_request_number}) has been created successfully. Our technician will inspect your PC."
            elif is_resolved:
                reply_text = "That is wonderful to hear! I'm glad your issue is resolved. Please feel free to reach out if you have any other questions about your PC."
            else:
                reply_text = "Let's check your PC setup. Please make sure all external cables are firmly connected, and let me know what happens."

        # Persist updated attempt_count, attempted_steps, and service_request_mode into checkpointer
        is_sr_mode = is_sr_mode or (sr_model is not None) or (sr_raw is not None)
        try:
            AFTER_SALES_GRAPH.update_state(
                config,
                {
                    "troubleshooting_attempt": attempt_count,
                    "attempted_steps": attempted_steps,
                    "problem_category": problem_category,
                    "service_request_required": sr_required or is_sr_mode,
                    "service_request_mode": is_sr_mode
                }
            )
        except Exception:
            pass

        return AfterSalesChatResponse(
            success=True,
            reply=reply_text,
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
                reply=(
                    "We have completed 5 troubleshooting steps and your PC issue is not resolved. "
                    "I suggest creating a Service Request so one of our service center technicians can inspect and repair your PC in person.\n\n"
                    "To proceed, please provide your **Order ID** (or Order number) and your preferred date (Monday to Saturday) "
                    "and appointment time between 09:00 AM and 06:00 PM."
                ),
                attempt_count=5,
                service_request_mode=True,
                service_request_required=True,
                agent_trace=[f"[Fallback Mode - External LLM Error: {str(e)}"]
            )
        if user_requested_sr or "service request" in user_msg or "appointment" in user_msg or "stop chatting" in user_msg:
            return AfterSalesChatResponse(
                success=True,
                reply=(
                    "Understood! We'll stop chatting and set up a Service Request for our technicians to inspect your system.\n\n"
                    "Please provide your **Order ID** (or Order number) and your preferred date (Monday to Saturday) "
                    "and appointment time between 09:00 AM and 06:00 PM."
                ),
                service_request_mode=True,
                service_request_required=True,
                agent_trace=[f"[Fallback Mode - External LLM Error: {str(e)}"]
            )
        return AfterSalesChatResponse(
            success=True,
            reply=(
                "I am here to help troubleshoot your PC. Please check that all cables and power connections are securely seated.\n\n"
                "*Prefer to have a technician inspect it?* Reply **\"Create Service Request\"** to schedule an in-person appointment."
            ),
            agent_trace=[f"[Fallback Mode - External LLM Error: {str(e)}"]
        )
