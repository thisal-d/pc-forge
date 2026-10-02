from typing import Annotated, List, Optional
from pydantic import BaseModel, Field
from langgraph.graph.message import add_messages


class RequirementProfile(BaseModel):
    """Structured customer PC requirement profile."""
    purpose: Optional[str] = Field(
        default=None,
        description="Primary purpose of the PC (e.g., Gaming, Video Editing, 3D Rendering, Office, Software Development)."
    )
    budget_raw: Optional[str] = Field(
        default=None,
        description="Raw budget string stated by user (e.g., 'Rs. 400,000', '$2500', '400k LKR')."
    )
    budget_amount: Optional[float] = Field(
        default=None,
        description="Parsed numerical budget value without symbols or commas (e.g., 400000)."
    )
    currency: str = Field(
        default="LKR",
        description="Currency code (LKR, USD, etc.). Default is LKR for PCForge."
    )
    target_resolution: Optional[str] = Field(
        default=None,
        description="Gaming or display target resolution (e.g., '1080p', '1440p', '4K', 'Not Applicable')."
    )
    monitor_needed: Optional[bool] = Field(
        default=None,
        description="True if customer needs a monitor included, False if they already own one or only want the tower."
    )
    preferences: List[str] = Field(
        default_factory=list,
        description="Specific preferences (e.g., 'White aesthetic', 'Silent', 'RGB lighting', 'Compact ITX')."
    )
    missing_fields: List[str] = Field(
        default_factory=list,
        description="List of fields still required before the build can be handed to the Build Agent."
    )
    is_complete: bool = Field(
        default=False,
        description="True if purpose and budget are known, and resolution/monitor preferences are resolved."
    )
    confirmed_by_user: bool = Field(
        default=False,
        description="True if customer has explicitly reviewed and confirmed the summarized requirements."
    )


class RequirementChatRequest(BaseModel):
    session_id: str = Field(description="Unique conversation session or thread ID.")
    message: str = Field(description="Customer's plain text input.")


class RequirementChatResponse(BaseModel):
    session_id: str
    reply: str
    profile: RequirementProfile
    is_complete: bool
    status: str = Field(description="'gathering' or 'ready_for_build'")
