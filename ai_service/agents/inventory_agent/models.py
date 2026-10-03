"""
Data Contracts for Inventory Agent (Member 02)
==============================================
Pydantic contracts strictly corresponding to project.md §7.2:
  - get_stock_level(product_id)
  - find_compatible_substitute(...)
  - reserve_stock(product_ids, session_id, hold_minutes)
"""

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class InventoryCheckRequest(BaseModel):
    """Input payload to Member 02 Inventory Agent."""
    session_id: Optional[str] = Field(None, description="Active requirement gathering session ID")
    build_name: str = Field("PCForge Custom Build", description="Name of the validated build")
    target_resolution: str = Field("1440p", description="Resolution target")
    component_ids: Dict[str, int] = Field(
        ...,
        description="Map of slot type ('cpu', 'gpu', etc.) to Product ID from live catalog"
    )
    hold_minutes: int = Field(15, description="Duration in minutes to hold temporary stock reservation")
    catalog: Optional[List[Dict[str, Any]]] = Field(default=None, description="Warehouse catalog context passed from ASP.NET Core")


class ComponentStockStatus(BaseModel):
    """Real-time inventory evaluation for a single hardware component."""
    slot_type: str = Field(..., description="Component slot: cpu, gpu, motherboard, ram, etc.")
    product_id: int = Field(..., description="Database Product ID")
    name: str = Field(..., description="Product name")
    category: str = Field(..., description="Component category")
    brand: str = Field("", description="Manufacturer brand")
    price: float = Field(0.0, description="Unit price in USD/LKR")
    stock_quantity: int = Field(..., description="Current warehouse shelf count in PostgreSQL")
    status: str = Field(
        ...,
        description="'IN_STOCK' (qty > 5), 'LOW_STOCK' (1 <= qty <= 5), 'OUT_OF_STOCK' (qty == 0), or 'SUBSTITUTED'"
    )
    status_label: str = Field("In stock", description="Human-friendly label matching UI 3 (e.g. 'In stock', 'Low — 2 left')")
    was_substituted: bool = Field(False, description="True if this part was swapped due to out-of-stock")
    original_product_name: Optional[str] = Field(None, description="Original out-of-stock product name if substituted")


class ReservationHold(BaseModel):
    """Temporary reservation hold guaranteeing parts for customer checkout."""
    reservation_id: str = Field(..., description="Unique reservation identifier")
    held_minutes: int = Field(15, description="Hold window in minutes")
    expires_at: str = Field(..., description="ISO 8601 expiration timestamp")
    status: str = Field("Reserved", description="Reservation status label matching UI 3")
    reserved_product_ids: List[int] = Field(default_factory=list, description="IDs of locked hardware items")


class StockVerificationResult(BaseModel):
    """Final output from Member 02 Inventory Agent."""
    success: bool = Field(True, description="True if all 8 slots are confirmed in stock or substituted")
    all_in_stock: bool = Field(True, description="True if no out-of-stock items remain")
    total_price: float = Field(0.0, description="Total updated price of the stock-confirmed build")
    components: Dict[str, ComponentStockStatus] = Field(
        ...,
        description="All 8 components with confirmed shelf stock status"
    )
    reservation: ReservationHold = Field(..., description="15-minute reservation hold details")
    substitutions_made: List[str] = Field(
        default_factory=list,
        description="Human-readable log of any out-of-stock substitutions performed"
    )
    summary: str = Field("", description="Architectural summary from the Inventory Agent")
    trace_steps: List[str] = Field(
        default_factory=list,
        description="Trace of agent reasoning and tool executions"
    )
    error: Optional[str] = Field(None, description="Error message if inventory check could not complete")
