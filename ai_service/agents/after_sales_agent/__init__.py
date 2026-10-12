"""
After-Sales Service Agent Package — PCForge (Member 05)
"""

from ai_service.agents.after_sales_agent.models import (
    ServiceRequestDetails,
    RmaTicketDetails,
    AfterSalesChatRequest,
    AfterSalesChatResponse,
)
from ai_service.agents.after_sales_agent.tools import (
    AFTER_SALES_TOOLS,
    search_troubleshooting_knowledge,
    get_customer,
    get_order,
    get_order_products,
    check_warranty,
    validate_service_appointment,
    create_service_request,
    get_service_request,
    get_customer_service_requests,
    get_order_history,
    get_warranty_status,
    create_rma_ticket,
)
from ai_service.agents.after_sales_agent.agent import (
    run_after_sales_chat,
    AFTER_SALES_GRAPH,
)

__all__ = [
    "ServiceRequestDetails",
    "RmaTicketDetails",
    "AfterSalesChatRequest",
    "AfterSalesChatResponse",
    "AFTER_SALES_TOOLS",
    "search_troubleshooting_knowledge",
    "get_customer",
    "get_order",
    "get_order_products",
    "check_warranty",
    "validate_service_appointment",
    "create_service_request",
    "get_service_request",
    "get_customer_service_requests",
    "get_order_history",
    "get_warranty_status",
    "create_rma_ticket",
    "run_after_sales_chat",
    "AFTER_SALES_GRAPH",
]
