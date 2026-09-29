"""
Allow-Listed Tools for PC Build & Compatibility Agent (Member 03)
==================================================================
Corresponds strictly to project.md §7.2:
  - get_candidate_components(category, filters)
  - check_socket_compatibility(cpu, motherboard)
  - check_memory_compatibility(ram, motherboard)
  - check_psu_wattage(cpu, gpu, psu)
  - check_case_fit(motherboard, gpu, case)

"The docstring is the interface" — Lab 05; Lecture 05 Slide 736
All tools output structured JSON dictionaries, never unstructured prose.
"""

from contextvars import ContextVar
import json
import os
import urllib.request
from typing import Any, Dict, List, Optional
from langchain_core.tools import tool
from ai_service.config import BACKEND_URL

build_context_var: ContextVar[Dict[str, Any]] = ContextVar("build_context_var", default={})


def fetch_live_products() -> List[Dict[str, Any]]:
    """Fetches products from request context passed by ASP.NET Core,
    or queries the ASP.NET Core Web API at /api/products.
    Never connects directly to PostgreSQL.
    """
    # 1. First priority: Use catalog context passed in request payload from ASP.NET Core
    ctx = build_context_var.get()
    ctx_catalog = ctx.get("catalog") if isinstance(ctx, dict) else None
    if ctx_catalog and isinstance(ctx_catalog, list) and len(ctx_catalog) > 0:
        items = []
        for p in ctx_catalog:
            cat_name = p.get("category") or p.get("categoryName") or "Component"
            items.append({
                "product_id": p.get("product_id") or p.get("productId", 0),
                "name": p.get("name", "Unknown"),
                "category": cat_name,
                "brand": p.get("brand", ""),
                "model": p.get("model", ""),
                "price": float(p.get("price", 0.0)),
                "socket": p.get("socket"),
                "memory_type": p.get("memory_type") or p.get("memoryType"),
                "power_wattage": p.get("power_wattage") or p.get("powerWattage"),
                "form_factor": p.get("form_factor") or p.get("formFactor")
            })
        if items:
            return items

    # 2. Query ASP.NET Core Web API via HTTP
    try:
        url = f"{BACKEND_URL.rstrip('/')}/api/products"
        req = urllib.request.Request(url, headers={"User-Agent": "PCForgeAi/1.0"})
        with urllib.request.urlopen(req, timeout=3.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if isinstance(data, list) and len(data) > 0:
                items = []
                for p in data:
                    cat_name = p.get("categoryName")
                    if not cat_name:
                        cat_id = p.get("categoryId")
                        cat_map = {1: "CPU", 2: "GPU", 3: "Motherboard", 4: "RAM", 5: "PSU", 6: "Storage", 7: "Case", 8: "Cooler"}
                        cat_name = cat_map.get(cat_id, "Component")

                    items.append({
                        "product_id": p.get("productId", 0),
                        "name": p.get("name", "Unknown"),
                        "category": cat_name,
                        "brand": p.get("brand", ""),
                        "model": p.get("model", ""),
                        "price": float(p.get("price", 0.0)),
                        "socket": p.get("socket"),
                        "memory_type": p.get("memoryType"),
                        "power_wattage": p.get("powerWattage"),
                        "form_factor": p.get("formFactor")
                    })
                return items
    except Exception:
        pass

    # 3. Default fallback catalog for offline execution and isolated tests
    return list(DEFAULT_CATALOG)


DEFAULT_CATALOG: List[Dict[str, Any]] = [
    {"product_id": 1, "name": "AMD Ryzen 5 7600X", "category": "CPU", "brand": "AMD", "model": "7600X", "price": 229.0, "socket": "AM5", "memory_type": "DDR5", "power_wattage": 105, "form_factor": None},
    {"product_id": 2, "name": "Intel Core i5-13600K", "category": "CPU", "brand": "Intel", "model": "13600K", "price": 299.0, "socket": "LGA1700", "memory_type": "DDR5", "power_wattage": 125, "form_factor": None},
    {"product_id": 3, "name": "MSI B650 Gaming Plus WiFi", "category": "Motherboard", "brand": "MSI", "model": "B650", "price": 179.0, "socket": "AM5", "memory_type": "DDR5", "power_wattage": 50, "form_factor": "ATX"},
    {"product_id": 4, "name": "ASUS TUF Gaming B760-PLUS", "category": "Motherboard", "brand": "ASUS", "model": "B760", "price": 189.0, "socket": "LGA1700", "memory_type": "DDR5", "power_wattage": 50, "form_factor": "ATX"},
    {"product_id": 5, "name": "Corsair Vengeance 32GB (2x16GB) DDR5 6000MHz", "category": "RAM", "brand": "Corsair", "model": "Vengeance", "price": 115.0, "socket": None, "memory_type": "DDR5", "power_wattage": 15, "form_factor": "DIMM"},
    {"product_id": 6, "name": "Kingston Fury Beast 16GB (2x8GB) DDR5 5200MHz", "category": "RAM", "brand": "Kingston", "model": "Fury", "price": 65.0, "socket": None, "memory_type": "DDR5", "power_wattage": 15, "form_factor": "DIMM"},
    {"product_id": 8, "name": "NVIDIA GeForce RTX 4070 Ti 12GB", "category": "GPU", "brand": "NVIDIA", "model": "RTX 4070 Ti", "price": 799.0, "socket": None, "memory_type": "GDDR6X", "power_wattage": 285, "form_factor": None},
    {"product_id": 9, "name": "AMD Radeon RX 7800 XT 16GB", "category": "GPU", "brand": "AMD", "model": "RX 7800 XT", "price": 499.0, "socket": None, "memory_type": "GDDR6", "power_wattage": 263, "form_factor": None},
    {"product_id": 10, "name": "Corsair RM750e 750W 80+ Gold Fully Modular", "category": "PSU", "brand": "Corsair", "model": "RM750e", "price": 99.0, "socket": None, "memory_type": None, "power_wattage": 750, "form_factor": "ATX"},
    {"product_id": 11, "name": "Samsung 980 Pro 1TB NVMe PCIe 4.0 SSD", "category": "Storage", "brand": "Samsung", "model": "980 Pro", "price": 89.0, "socket": None, "memory_type": None, "power_wattage": 10, "form_factor": "M.2 2280"},
    {"product_id": 12, "name": "NZXT H5 Flow ATX Mid-Tower Case", "category": "Case", "brand": "NZXT", "model": "H5 Flow", "price": 89.0, "socket": None, "memory_type": None, "power_wattage": 0, "form_factor": "ATX"},
    {"product_id": 13, "name": "DeepCool AK620 High-Performance CPU Air Cooler", "category": "Cooler", "brand": "DeepCool", "model": "AK620", "price": 65.0, "socket": "AM5 / LGA1700", "memory_type": None, "power_wattage": 5, "form_factor": None},
    {"product_id": 14, "name": "AMD Ryzen 9 7950X", "category": "CPU", "brand": "AMD", "model": "7950X", "price": 699.0, "socket": "AM5", "memory_type": "DDR5", "power_wattage": 170, "form_factor": None},
    {"product_id": 15, "name": "ASUS ROG Strix RTX 4090 24GB", "category": "GPU", "brand": "ASUS", "model": "RTX 4090", "price": 1599.0, "socket": None, "memory_type": "GDDR6X", "power_wattage": 450, "form_factor": None},
    {"product_id": 16, "name": "Corsair RM850x 850W 80+ Gold Fully Modular", "category": "PSU", "brand": "Corsair", "model": "RM850x", "price": 139.0, "socket": None, "memory_type": None, "power_wattage": 850, "form_factor": "ATX"},
    {"product_id": 17, "name": "Corsair RM1000x 1000W 80+ Gold Fully Modular", "category": "PSU", "brand": "Corsair", "model": "RM1000x", "price": 189.0, "socket": None, "memory_type": None, "power_wattage": 1000, "form_factor": "ATX"},
]


_fetch_live_products = fetch_live_products



@tool
def get_candidate_components(
    category: str,
    max_price: Optional[float] = None,
    socket: Optional[str] = None,
    memory_type: Optional[str] = None,
) -> str:
    """Fetch matching hardware components from the PCForge store catalog.
    Use this tool to find options for CPU, Motherboard, RAM, GPU, PSU, Storage, Case, and Cooler.
    Args:
        category: Hardware category ('CPU', 'GPU', 'Motherboard', 'RAM', 'PSU', 'Storage', 'Case', 'Cooler').
        max_price: Maximum allowed unit price in USD/LKR equivalent.
        socket: Optional socket constraint (e.g. 'AM5' or 'LGA1700').
        memory_type: Optional memory standard (e.g. 'DDR5' or 'DDR4').
    Returns:
        JSON string list of component objects with prices, brands, and technical specs.
    """
    catalog = _fetch_live_products()
    clean_cat = category.strip().lower()
    matches = []

    for item in catalog:
        item_cat = (item.get("category") or "").strip().lower()
        if clean_cat not in item_cat and item_cat not in clean_cat:
            continue
        
        if max_price is not None and item.get("price", 0.0) > max_price:
            continue
            
        if socket:
            if not item.get("socket"):
                continue
            item_sock = str(item["socket"]).upper()
            req_sock = socket.strip().upper()
            if req_sock not in item_sock:
                continue

        if memory_type:
            if not item.get("memory_type"):
                continue
            item_mem = str(item["memory_type"]).upper()
            req_mem = memory_type.strip().upper()
            if req_mem != item_mem:
                continue

        matches.append(item)

    # Sort by price ascending
    matches.sort(key=lambda x: x.get("price", 0.0))
    return json.dumps(matches)


@tool
def check_socket_compatibility(cpu_socket: str, motherboard_socket: str) -> str:
    """Proves physical CPU socket match with Motherboard socket.
    Args:
        cpu_socket: Socket requirement of the CPU (e.g. 'AM5', 'LGA1700').
        motherboard_socket: Socket supported by Motherboard (e.g. 'AM5', 'LGA1700').
    Returns:
        JSON string with 'compatible' boolean and explanatory verdict.
    """
    c_sock = (cpu_socket or "").strip().upper()
    m_sock = (motherboard_socket or "").strip().upper()
    
    is_match = (c_sock == m_sock) and bool(c_sock)
    details = (
        f"Verified: CPU socket ({c_sock}) matches Motherboard socket ({m_sock})."
        if is_match else
        f"INCOMPATIBLE: CPU socket ({c_sock}) does NOT match Motherboard socket ({m_sock}). Physical installation impossible."
    )
    return json.dumps({
        "compatible": is_match,
        "cpu_socket": c_sock,
        "motherboard_socket": m_sock,
        "details": details
    })


@tool
def check_memory_compatibility(ram_type: str, motherboard_memory_type: str) -> str:
    """Proves DDR generation match between RAM module and Motherboard memory slots.
    Args:
        ram_type: RAM generation (e.g. 'DDR5', 'DDR4').
        motherboard_memory_type: Motherboard generation (e.g. 'DDR5', 'DDR4').
    Returns:
        JSON string with 'compatible' boolean and explanatory verdict.
    """
    r_type = (ram_type or "").strip().upper()
    m_type = (motherboard_memory_type or "").strip().upper()

    is_match = (r_type == m_type) and bool(r_type)
    details = (
        f"Verified: RAM generation ({r_type}) matches Motherboard slots ({m_type})."
        if is_match else
        f"INCOMPATIBLE: RAM ({r_type}) cannot be installed in Motherboard slot ({m_type})."
    )
    return json.dumps({
        "compatible": is_match,
        "ram_type": r_type,
        "motherboard_memory_type": m_type,
        "details": details
    })


@tool
def check_psu_wattage(
    cpu_tdp: int,
    gpu_tdp: int,
    psu_wattage: int,
    base_system_watts: int = 75,
    transient_headroom_watts: int = 150
) -> str:
    """Verifies power supply capacity and transient headroom for CPU and GPU loads.
    Formula: Total System Load = CPU TDP + GPU TDP + Base System (75W).
    Adequate when: PSU Wattage >= Total System Load + Headroom (150W).
    Args:
        cpu_tdp: Peak thermal design power of CPU in watts (e.g. 105).
        gpu_tdp: Peak power draw of GPU in watts (e.g. 285).
        psu_wattage: Continuous rated output of PSU in watts (e.g. 750).
        base_system_watts: Estimated overhead for motherboard, RAM, fans, and SSDs (default 75W).
        transient_headroom_watts: Safety headroom for transient spikes (default 150W).
    Returns:
        JSON string with 'compatible' boolean, estimated wattage, and net headroom.
    """
    total_load = int(cpu_tdp) + int(gpu_tdp) + int(base_system_watts)
    required_psu = total_load + int(transient_headroom_watts)
    headroom = int(psu_wattage) - total_load
    is_adequate = int(psu_wattage) >= required_psu

    if is_adequate:
        details = f"Verified: PSU ({psu_wattage}W) provides +{headroom}W safety headroom above peak load ({total_load}W)."
    else:
        details = (
            f"INSUFFICIENT: Total load ({total_load}W) requires at least {required_psu}W with safety headroom. "
            f"Selected PSU is only {psu_wattage}W (headroom: +{headroom}W is below the +{transient_headroom_watts}W minimum)."
        )

    return json.dumps({
        "compatible": is_adequate,
        "estimated_system_load_w": total_load,
        "psu_wattage_w": int(psu_wattage),
        "net_headroom_w": headroom,
        "minimum_recommended_psu_w": required_psu,
        "details": details
    })


@tool
def check_case_fit(motherboard_form_factor: str, case_form_factor: str) -> str:
    """Verifies that the chosen motherboard form factor physically fits into the chassis.
    ATX cases accommodate ATX, Micro-ATX, and Mini-ITX.
    Micro-ATX cases accommodate Micro-ATX and Mini-ITX.
    Mini-ITX cases accommodate Mini-ITX only.
    Args:
        motherboard_form_factor: Motherboard size ('ATX', 'Micro-ATX', 'Mini-ITX').
        case_form_factor: Chassis size ('ATX', 'Micro-ATX', 'Mini-ITX').
    Returns:
        JSON string with 'compatible' boolean and clearance details.
    """
    mb_ff = (motherboard_form_factor or "ATX").strip().upper()
    cs_ff = (case_form_factor or "ATX").strip().upper()

    hierarchy = {
        "MINI-ITX": 1,
        "MICRO-ATX": 2,
        "ATX": 3,
        "E-ATX": 4
    }

    mb_rank = hierarchy.get(mb_ff, 3)
    cs_rank = hierarchy.get(cs_ff, 3)

    is_fit = mb_rank <= cs_rank
    details = (
        f"Verified: {motherboard_form_factor} motherboard fits comfortably inside {case_form_factor} chassis."
        if is_fit else
        f"PHYSICAL CONFLICT: {motherboard_form_factor} motherboard is too large for {case_form_factor} chassis."
    )

    return json.dumps({
        "compatible": is_fit,
        "motherboard_form_factor": motherboard_form_factor,
        "case_form_factor": case_form_factor,
        "details": details
    })


@tool
def submit_validated_build(
    cpu_product_id: int,
    motherboard_product_id: int,
    ram_product_id: int,
    gpu_product_id: int,
    psu_product_id: int,
    storage_product_id: int,
    case_product_id: int,
    cooler_product_id: int,
    build_name: str,
    engineering_notes: str,
) -> str:
    """Finalize and submit the validated 8-component PC build proposal.
    Call this tool ONLY after you have verified socket match, memory generation,
    PSU wattage headroom, and chassis fit using the clearance tools.
    Args:
        cpu_product_id: ID of the selected CPU from get_candidate_components.
        motherboard_product_id: ID of the selected Motherboard.
        ram_product_id: ID of the selected RAM kit.
        gpu_product_id: ID of the selected GPU.
        psu_product_id: ID of the selected PSU.
        storage_product_id: ID of the selected SSD.
        case_product_id: ID of the selected Case.
        cooler_product_id: ID of the selected Cooler.
        build_name: Descriptive title for this build (e.g. 'Ryzen 5 7600X / RX 7800 XT Battlestation').
        engineering_notes: Architectural summary of the build and why components were chosen.
    Returns:
        JSON confirmation string with submitted component IDs.
    """
    return json.dumps({
        "status": "SUBMITTED",
        "cpu_product_id": cpu_product_id,
        "motherboard_product_id": motherboard_product_id,
        "ram_product_id": ram_product_id,
        "gpu_product_id": gpu_product_id,
        "psu_product_id": psu_product_id,
        "storage_product_id": storage_product_id,
        "case_product_id": case_product_id,
        "cooler_product_id": cooler_product_id,
        "build_name": build_name,
        "engineering_notes": engineering_notes
    })


BUILD_TOOLS = [
    get_candidate_components,
    check_socket_compatibility,
    check_memory_compatibility,
    check_psu_wattage,
    check_case_fit,
    submit_validated_build
]
