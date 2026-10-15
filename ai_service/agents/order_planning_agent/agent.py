"""
Order Planning Agent for PCForge.
Computes itemized pricing, validates promotional discounts,
calculates delivery logistics, and generates order proposals for review.
"""

import json
from typing import Annotated, Dict, List, Optional, TypedDict
from langchain_core.messages import BaseMessage, HumanMessage, SystemMessage, ToolMessage
from langgraph.graph import END, StateGraph
from langgraph.graph.message import add_messages

from ai_service.config import get_llm
from ai_service.guardrails import SYSTEM_SECURITY_RULES, sanitize_and_delimit
from ai_service.agents.order_planning_agent.models import (
    OrderPlanningRequest,
    OrderPricingItem,
    OrderProposal,
    OrderProposalResponse,
    PricingBreakdown,
)
from ai_service.agents.order_planning_agent.tools import (
    ORDER_PLANNING_TOOLS,
    apply_discount,
    calculate_delivery,
    calculate_pricing,
    create_order_proposal,
    order_planning_context_var,
)

TOOLS_BY_NAME = {t.name: t for t in ORDER_PLANNING_TOOLS}

SYSTEM_PROMPT = """You are the Order Planning Agent for the PCForge Multi-Agent AI Subsystem.
Your mission is to take an approved, stock-verified PC build and produce a transparent custom build proposal.

YOUR RESPONSIBILITIES:
1. Examine the components provided in the customer's build.
2. Calculate itemized pricing and subtotal using your pricing calculation tools.
3. If a promo voucher is provided (e.g. 'WELCOME5'), evaluate the discount.
4. For custom rig build proposals, delivery fees are NOT charged at this stage (delivery_fee = 0.0) as the customer selects delivery or store pickup later during final order checkout.
5. Create the formal proposal holding status 'WAITING_FOR_APPROVAL' with total_price = subtotal - discount_amount (delivery_fee=0.0).

STRICT RULES & CONSTRAINTS:
- You CANNOT select, swap, or replace hardware components (handled during build assembly and inventory verification).
- You CANNOT process payments or charge customer credit cards.
- The proposal status MUST be 'WAITING_FOR_APPROVAL'.
- Ensure all numbers reconcile correctly before submitting the proposal.
""" + "\n\n" + SYSTEM_SECURITY_RULES


class OrderPlanningState(TypedDict):
    """Workflow state for Order Planning Agent."""
    messages: Annotated[List[BaseMessage], add_messages]
    request_data: Dict
    proposal_payload: Optional[Dict]
    agent_trace: List[str]
    iteration_count: int
    error_message: Optional[str]


def agent_reasoning_node(state: OrderPlanningState) -> Dict:
    """Invokes Google Gemini with the current message trajectory and allow-listed tools."""
    messages = state["messages"]
    trace = list(state.get("agent_trace", []))
    iteration = state.get("iteration_count", 0) + 1

    trace.append(f"[Agent Node Turn #{iteration}] Reasoning over build pricing and order parameters...")

    llm_instance = get_llm()
    if llm_instance is None:
        err = "Order Planning Agent requires an active LLM client. Please check GOOGLE_API_KEY in .env."
        trace.append(f"[Order Planning Error] {err}")
        return {
            "error_message": err,
            "agent_trace": trace,
            "iteration_count": iteration,
        }

    order_planner_llm = llm_instance.bind_tools(ORDER_PLANNING_TOOLS)
    try:
        response = order_planner_llm.invoke(messages)
    except Exception as e:
        err = f"Order Planning Agent encountered external LLM or quota error: {str(e)}"
        trace.append(f"[Order Planning Error] {err}")
        return {
            "error_message": err,
            "agent_trace": trace,
            "iteration_count": iteration,
        }

    if response.tool_calls:
        for tc in response.tool_calls:
            trace.append(f"[Tool Call] Invoking {tc['name']} with args: {tc['args']}")

    return {
        "messages": [response],
        "agent_trace": trace,
        "iteration_count": iteration,
    }


def tools_execution_node(state: OrderPlanningState) -> Dict:
    """Executes the specific tool invoked by Gemini and records results back into state."""
    messages = state["messages"]
    last_message = messages[-1]
    trace = list(state.get("agent_trace", []))
    proposal_data = state.get("proposal_payload")

    tool_messages = []
    for tool_call in last_message.tool_calls:
        tool_name = tool_call["name"]
        tool_args = tool_call["args"]
        call_id = tool_call["id"]

        if tool_name not in TOOLS_BY_NAME:
            result_str = json.dumps({"error": f"Tool '{tool_name}' is not in the allow-list."})
        else:
            try:
                target_tool = TOOLS_BY_NAME[tool_name]
                result_str = target_tool.invoke(tool_args)

                # Capture proposal result if create_order_proposal was invoked
                if tool_name == "create_order_proposal":
                    try:
                        proposal_data = json.loads(result_str)
                    except Exception:
                        pass
            except Exception as ex:
                result_str = json.dumps({"error": f"Execution error in {tool_name}: {str(ex)}"})

        trace.append(f"[Tool Response] {tool_name} returned: {result_str[:200]}...")
        tool_messages.append(
            ToolMessage(
                content=result_str,
                name=tool_name,
                tool_call_id=call_id
            )
        )

    return {
        "messages": tool_messages,
        "agent_trace": trace,
        "proposal_payload": proposal_data,
    }


def should_continue(state: OrderPlanningState) -> str:
    """Routes to tools node if Gemini issued tool calls, or terminates graph if done."""
    if state.get("error_message"):
        return END
    last_message = state["messages"][-1]
    iteration = state.get("iteration_count", 0)

    if getattr(last_message, "tool_calls", None) and len(last_message.tool_calls) > 0:
        if iteration >= 8:  # Safety circuit breaker
            return END
        return "tools"
    return END


def build_order_planning_graph():
    """Assembles and compiles the StateGraph for Order Planning."""
    workflow = StateGraph(OrderPlanningState)

    workflow.add_node("agent", agent_reasoning_node)
    workflow.add_node("tools", tools_execution_node)

    workflow.set_entry_point("agent")
    workflow.add_conditional_edges(
        "agent",
        should_continue,
        {
            "tools": "tools",
            END: END,
        }
    )
    workflow.add_edge("tools", "agent")

    return workflow.compile()


ORDER_PLANNING_GRAPH = build_order_planning_graph()


def generate_order_proposal(request: OrderPlanningRequest) -> OrderProposalResponse:
    """Computes order pricing, evaluates discounts, and generates a reviewable proposal."""
    order_planning_context_var.set({"coupons": request.coupons or []})
    components_payload = json.dumps(request.components, indent=2) if request.components else "{}"
    raw_order_details = (
        f"Build Name: {request.build_name}\n"
        f"Warehouse Reservation ID: {request.reservation_id}\n"
        f"Promo Code: {request.promo_code or 'WELCOME5'}\n"
        f"Shipping Method: {request.shipping_method or 'standard'}\n"
        f"Shipping Address: {request.shipping_address or 'Colombo, Western Province'}\n"
        f"Currency: {request.currency or 'Rs.'}\n\n"
        f"Components Data:\n{components_payload}"
    )
    delimited_details = sanitize_and_delimit(raw_order_details, tag="order_request")

    initial_user_prompt = f"""Please price and generate a customer custom build proposal for the following stock-confirmed PC build:
{delimited_details}

Please execute:
1. `calculate_pricing` to compute the subtotal.
2. `apply_discount` for promo code '{request.promo_code or 'WELCOME5'}'.
3. Calculate net total (subtotal - discount_amount). Note: Do NOT add delivery cost; delivery fee is 0.0 for custom build proposals since customer selects delivery or store pickup during final order checkout.
4. Call `create_order_proposal` with subtotal, discount_amount, delivery_fee=0.0, and total_price.
"""


    initial_messages = [
        SystemMessage(content=SYSTEM_PROMPT),
        HumanMessage(content=initial_user_prompt)
    ]

    initial_state: OrderPlanningState = {
        "messages": initial_messages,
        "request_data": request.model_dump(),
        "proposal_payload": None,
        "error_message": None,
        "agent_trace": [
            f"[Order Planning Agent Initialized] Processing build '{request.build_name}' (Reservation {request.reservation_id})."
        ],
        "iteration_count": 0,
    }

    try:
        final_state = ORDER_PLANNING_GRAPH.invoke(initial_state)
        proposal_dict = final_state.get("proposal_payload")
        trace = final_state.get("agent_trace", [])
        err_msg = final_state.get("error_message")

        if err_msg:
            return OrderProposalResponse(
                success=False,
                error=err_msg,
                agent_trace=trace
            )

        # Extraction from messages if create_order_proposal tool was called earlier
        if not proposal_dict:
            for msg in reversed(final_state["messages"]):
                if isinstance(msg, ToolMessage) and msg.name == "create_order_proposal":
                    try:
                        proposal_dict = json.loads(msg.content)
                        break
                    except Exception:
                        pass

        # If still no proposal
        if not proposal_dict:
            return OrderProposalResponse(
                success=False,
                error="Order Planning Agent did not generate a valid proposal.",
                agent_trace=trace
            )

        pricing_data = proposal_dict.get("pricing", {})
        breakdown = PricingBreakdown(
            currency=pricing_data.get("currency", request.currency or "Rs."),
            subtotal=pricing_data.get("subtotal", 0.0),
            discount_code=pricing_data.get("discount_code"),
            discount_amount=pricing_data.get("discount_amount", 0.0),
            discount_label=pricing_data.get("discount_label"),
            delivery_method=request.shipping_method or "Selected at Checkout",
            delivery_fee=pricing_data.get("delivery_fee", 0.0),
            total_price=pricing_data.get("total_price", 0.0),
            formatted_subtotal=pricing_data.get("formatted_subtotal", "Rs. 0"),
            formatted_discount=pricing_data.get("formatted_discount", "- Rs. 0"),
            formatted_delivery=pricing_data.get("formatted_delivery", "Rs. 0"),
            formatted_total=pricing_data.get("formatted_total", "Rs. 0"),
        )

        # Assemble component items list
        items_list = []
        for slot, c in request.components.items():
            if isinstance(c, dict):
                items_list.append(OrderPricingItem(
                    product_id=int(c.get("product_id") or c.get("productId") or 0),
                    slot=slot,
                    name=str(c.get("name") or c.get("product_name") or f"Component {slot}"),
                    unit_price=float(c.get("price") or c.get("unit_price") or 0.0),
                    quantity=1,
                    total_price=float(c.get("price") or c.get("unit_price") or 0.0)
                ))

        order_prop = OrderProposal(
            proposal_id=proposal_dict.get("proposal_id", "PROP-PCF10492"),
            order_number=proposal_dict.get("order_number", "PCF-10492"),
            build_name=request.build_name,
            reservation_id=request.reservation_id,
            status="WAITING_FOR_APPROVAL",
            status_label="Waiting for your approval",
            components_count=len(items_list) if items_list else 8,
            pricing=breakdown,
            components=items_list,
            estimated_delivery="3-5 business days",
            technician_notice="We'll notify you once a technician has checked your build — usually within a few hours."
        )

        trace.append(f"[Completed] Generated Order Proposal #{order_prop.order_number} (Total: {breakdown.formatted_total}).")

        return OrderProposalResponse(
            success=True,
            proposal=order_prop,
            agent_trace=trace
        )

    except Exception as e:
        return OrderProposalResponse(
            success=False,
            error=f"Order Planning Agent failed: {str(e)}",
            agent_trace=[f"[Error] {str(e)}"]
        )
