"""
Data schemas for after-sales troubleshooting conversations
and service request creation.
"""

from typing import Dict, List, Optional, Any
from pydantic import BaseModel, Field


class ServiceRequestDetails(BaseModel):
    """Structured service request details for persistence and customer communication."""
    action: str = Field(default="create", description="Action to perform: create or update")
    id: Optional[int] = Field(default=None, description="Primary database ID")
    service_request_id: Optional[int] = Field(default=None, description="Service Request primary key")
    service_request_number: str = Field(default="", description="Generated Service Request Number, e.g. SR-000108")
    user_id: int = Field(default=1, description="Authenticated customer ID")
    customer_name: Optional[str] = Field(default=None, description="Customer full name")
    title: Optional[str] = Field(default=None, description="Brief title/summary of the service request")
    description: Optional[str] = Field(default=None, description="Detailed problem description (optional)")
    problem_description: str = Field(default="", description="Customer-reported symptom")
    problem_category: str = Field(default="General", description="Troubleshooting category")
    troubleshooting_summary: Optional[str] = Field(default=None, description="Steps attempted and AI assessment")
    attempt_count: int = Field(default=0, description="Number of troubleshooting attempts made (0-5)")
    preferred_date: Optional[str] = Field(default=None, description="Preferred appointment date")
    preferred_time: Optional[str] = Field(default=None, description="Preferred appointment time slot")
    slot_id: Optional[int] = Field(default=None, description="Service time slot ID configured in store database")
    slot_label: Optional[str] = Field(default=None, description="Time slot label, e.g. 09:00 AM - 11:00 AM")
    status: str = Field(default="BOOKED", description="Status: BOOKED, IN_PROGRESS, SCHEDULED, IN_SERVICE, RESOLVED")
    priority: str = Field(default="Normal", description="Priority: Low, Normal, High, Urgent")
    created_at: str = Field(default="", description="ISO timestamp")
    # Optional legacy fields for backward compatibility
    order_id: Optional[int] = Field(default=None, description="Legacy field")
    order_number: Optional[str] = Field(default=None, description="Legacy field")
    product_id: Optional[int] = Field(default=None, description="Legacy field")
    product_name: Optional[str] = Field(default=None, description="Legacy field")
    warranty_status: Optional[str] = Field(default=None, description="Legacy field")
    warranty_expiry_date: Optional[str] = Field(default=None, description="Legacy field")


class RmaTicketDetails(BaseModel):
    """Backward-compatible RMA ticket model for legacy components."""
    ticket_id: int = Field(default=108, description="Primary ticket ID")
    rma_number: str = Field(default="SR-000108", description="Formatted reference number")
    order_id: Optional[int] = Field(default=None, description="Linked order ID")
    order_number: Optional[str] = Field(default=None, description="Linked order reference")
    product_id: Optional[int] = Field(default=None, description="Target product ID")
    component_name: str = Field(default="PC System", description="Commercial component name")
    issue_type: str = Field(default="Hardware fault", description="Issue category")
    status: str = Field(default="BOOKED", description="Status pill")
    priority: str = Field(default="Normal", description="Ticket priority")
    description: str = Field(default="", description="Customer-reported symptom")
    attachment_url: Optional[str] = Field(default=None, description="Photo proof URL")
    created_at: str = Field(default="", description="ISO timestamp")


class AfterSalesChatRequest(BaseModel):
    """Customer chat message submitted to Member 05 After-Sales Service Agent."""
    user_id: int = Field(default=1, description="Authenticated customer User ID")
    message: str = Field(description="Customer question or symptom report")
    session_id: Optional[str] = Field(default=None, description="Conversational thread ID")
    problem_category: Optional[str] = Field(default=None, description="Optional problem category")
    customer: Optional[Dict[str, Any]] = Field(default=None, description="Authenticated customer profile context")
    service_requests: Optional[List[Dict[str, Any]]] = Field(default=None, description="Customer active and past service requests")
    time_slots: Optional[List[Dict[str, Any]]] = Field(default=None, description="Active Service Time Slots configured in database")
    # Legacy optional context
    order_id: Optional[int] = Field(default=None, description="Legacy field")
    orders: Optional[List[Dict[str, Any]]] = Field(default=None, description="Legacy field")


class AfterSalesChatResponse(BaseModel):
    """Response returned by Member 05 After-Sales Service Agent."""
    success: bool = Field(default=True, description="True if response generated successfully")
    reply: str = Field(description="Conversational response message")
    attempt_count: int = Field(default=0, description="Current troubleshooting attempt count (0 to 5)")
    attempted_steps: List[str] = Field(default_factory=list, description="Titles of steps attempted so far")
    problem_category: Optional[str] = Field(default=None, description="Detected category")
    is_resolved: bool = Field(default=False, description="True if customer reported issue was fixed")
    service_request_required: bool = Field(default=False, description="True if Service Request process triggered")
    service_request_mode: bool = Field(default=False, description="True when troubleshooting chat has stopped and agent is in Service Request intake mode")
    service_request: Optional[ServiceRequestDetails] = Field(default=None, description="Populated when Service Request is created")
    ticket: Optional[RmaTicketDetails] = Field(default=None, description="Legacy ticket view for backward compatibility")
    agent_trace: List[str] = Field(default_factory=list, description="Reasoning and tool execution log")
    error: Optional[str] = Field(default=None, description="Error message if failed")
