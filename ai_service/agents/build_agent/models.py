"""
PC Build & Compatibility Agent Models — PCForge (Member 03)
===========================================================
Defines structured data contracts for:
  - Hardware components (CPU, Motherboard, RAM, GPU, PSU, Storage, Case, Cooler)
  - Deterministic compatibility clearance checklist (Socket, Memory, Wattage, Case-fit)
  - Validated build proposals
  - API request & response schemas
"""

from typing import Dict, List, Optional, Any
from pydantic import BaseModel, Field


class ComponentItem(BaseModel):
    """A single hardware component in the PC build."""
    product_id: int = Field(default=0, description="Unique product ID from PCForge catalog")
    name: str = Field(description="Commercial name of the part")
    category: str = Field(description="Hardware category: CPU, Motherboard, RAM, GPU, PSU, Storage, Case, Cooler")
    brand: str = Field(default="", description="Manufacturer brand (e.g. AMD, Intel, ASUS, Corsair)")
    model: Optional[str] = Field(default=None, description="Model number/designation")
    price: float = Field(default=0.0, description="Current unit price")
    socket: Optional[str] = Field(default=None, description="Socket standard (e.g. AM5, LGA1700)")
    memory_type: Optional[str] = Field(default=None, description="Memory technology (e.g. DDR5, DDR4)")
    power_wattage: Optional[int] = Field(default=None, description="TDP wattage draw or PSU rated output wattage")
    form_factor: Optional[str] = Field(default=None, description="Form factor (e.g. ATX, Micro-ATX, Mini-ITX)")


class CompatibilityChecklist(BaseModel):
    """Clearance proof checklist matching UI Screen 2 in PCForge AI Workflow."""
    socket_match: bool = Field(default=True, description="True if CPU socket matches Motherboard socket")
    socket_details: str = Field(default="", description="Human-readable socket validation verdict")
    
    memory_match: bool = Field(default=True, description="True if RAM DDR generation matches Motherboard")
    memory_details: str = Field(default="", description="Human-readable memory compatibility verdict")
    
    wattage_ok: bool = Field(default=True, description="True if PSU provides adequate wattage + headroom")
    estimated_wattage: int = Field(default=0, description="Estimated peak system consumption (W)")
    psu_wattage: int = Field(default=0, description="PSU rated power delivery (W)")
    headroom_watts: int = Field(default=0, description="Net transient headroom above peak consumption (W)")
    
    case_fit_ok: bool = Field(default=True, description="True if Motherboard form factor fits within the chassis")
    case_fit_details: str = Field(default="", description="Human-readable form factor fit verdict")
    
    all_passed: bool = Field(default=True, description="True only if every individual hardware check passes")


class ValidatedBuild(BaseModel):
    """The complete technical proposal produced by Member 03."""
    build_name: str = Field(default="Custom PCForge Rig", description="Descriptive title for this configuration")
    purpose: str = Field(default="Gaming", description="Target workload (Gaming, Workstation, Office)")
    target_resolution: str = Field(default="1440p", description="Display target (1080p, 1440p, 4K)")
    components: Dict[str, ComponentItem] = Field(
        default_factory=dict,
        description="Slot dictionary: cpu, motherboard, ram, gpu, psu, storage, case, cooler"
    )
    total_price: float = Field(default=0.0, description="Sum of component prices")
    estimated_wattage: int = Field(default=0, description="Total estimated peak draw (W)")
    compatibility: CompatibilityChecklist = Field(
        default_factory=CompatibilityChecklist,
        description="Detailed clearance checks"
    )
    is_valid: bool = Field(default=False, description="True if 100% compatible and validated")
    status: str = Field(
        default="VALIDATED_PENDING_STOCK",
        description="Pipeline state ready for Member 02 Inventory verification"
    )


class BuildGenerationRequest(BaseModel):
    """Input payload to request an AI custom PC build."""
    session_id: Optional[str] = Field(default=None, description="Optional requirement session ID")
    purpose: str = Field(default="Gaming", description="Customer's primary PC workload")
    budget_amount: float = Field(default=400000.0, description="Target budget amount")
    currency: str = Field(default="LKR", description="Budget currency (e.g. LKR or USD)")
    target_resolution: str = Field(default="1440p", description="Target resolution")
    preferences: List[str] = Field(default_factory=list, description="Customer preferences (e.g. RGB, WiFi, Silent)")
    catalog: Optional[List[Dict[str, Any]]] = Field(default=None, description="Catalog products passed as context from ASP.NET Core")


class BuildGenerationResponse(BaseModel):
    """Output payload from Member 03 Build Agent."""
    success: bool = Field(default=True, description="True if build was generated and validated")
    build: Optional[ValidatedBuild] = Field(default=None, description="The validated 8-component build")
    summary: str = Field(default="", description="Architectural summary of component selection")
    trace_steps: List[str] = Field(default_factory=list, description="Reasoning and substitution audit trace")
    error: Optional[str] = Field(default=None, description="Error explanation if safe failure triggered")
