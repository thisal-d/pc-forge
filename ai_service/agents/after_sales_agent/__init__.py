"""
After-Sales Service Agent Package — PCForge (Member 05)
"""

from ai_service.agents.after_sales_agent.models import (
    ServiceRequestDetails,
    AfterSalesChatRequest,
    AfterSalesChatResponse,
)
from ai_service.agents.after_sales_agent.tools import (
    AFTER_SALES_TOOLS,
    search_troubleshooting_knowledge,
    get_customer,
    get_available_time_slots,
    validate_service_appointment,
    update_service_appointment,
    create_service_request,
    get_service_request,
    get_customer_service_requests,
)
from ai_service.agents.after_sales_agent.agent import (
    run_after_sales_chat,
    AFTER_SALES_GRAPH,
)

__all__ = [
    "ServiceRequestDetails",
    "AfterSalesChatRequest",
    "AfterSalesChatResponse",
    "AFTER_SALES_TOOLS",
    "search_troubleshooting_knowledge",
    "get_customer",
    "get_available_time_slots",
    "validate_service_appointment",
    "update_service_appointment",
    "create_service_request",
    "get_service_request",
    "get_customer_service_requests",
    "run_after_sales_chat",
    "AFTER_SALES_GRAPH",
]
