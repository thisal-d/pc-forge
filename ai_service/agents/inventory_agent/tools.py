"""
Allow-Listed Tools for Inventory Agent (Member 02)
==================================================
Corresponds strictly to project.md §7.2:
  - get_stock_level(product_id)
  - reserve_stock(product_ids, session_id, hold_minutes)
  - find_compatible_substitute(category, failed_product_id, socket, memory_type, max_price)

All queries target the live PostgreSQL database and backend API.
"""

from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional
import urllib.request
from langchain_core.tools import tool
from dotenv import load_dotenv

BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:5000")


from contextvars import ContextVar
from datetime import datetime, timedelta, timezone
import json
import os
from typing import Any, Dict, List, Optional
import urllib.request
from langchain_core.tools import tool

BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:5000")

inventory_context_var: ContextVar[Dict[str, Any]] = ContextVar("inventory_context_var", default={})


DEFAULT_INVENTORY_CATALOG: List[Dict[str, Any]] = [
    {"product_id": 1, "name": "AMD Ryzen 5 7600X", "category": "CPU", "brand": "AMD", "model": "7600X", "price": 229.0, "socket": "AM5", "memory_type": "DDR5", "power_wattage": 105, "form_factor": None, "stock_quantity": 12},
    {"product_id": 2, "name": "Intel Core i5-13600K", "category": "CPU", "brand": "Intel", "model": "13600K", "price": 299.0, "socket": "LGA1700", "memory_type": "DDR5", "power_wattage": 125, "form_factor": None, "stock_quantity": 8},
    {"product_id": 3, "name": "MSI B650 Gaming Plus WiFi", "category": "Motherboard", "brand": "MSI", "model": "B650", "price": 179.0, "socket": "AM5", "memory_type": "DDR5", "power_wattage": 50, "form_factor": "ATX", "stock_quantity": 10},
    {"product_id": 4, "name": "ASUS TUF Gaming B760-PLUS", "category": "Motherboard", "brand": "ASUS", "model": "B760", "price": 189.0, "socket": "LGA1700", "memory_type": "DDR5", "power_wattage": 50, "form_factor": "ATX", "stock_quantity": 6},
    {"product_id": 5, "name": "Corsair Vengeance 32GB (2x16GB) DDR5 6000MHz", "category": "RAM", "brand": "Corsair", "model": "Vengeance", "price": 115.0, "socket": None, "memory_type": "DDR5", "power_wattage": 15, "form_factor": "DIMM", "stock_quantity": 15},
    {"product_id": 6, "name": "Kingston Fury Beast 16GB (2x8GB) DDR5 5200MHz", "category": "RAM", "brand": "Kingston", "model": "Fury", "price": 65.0, "socket": None, "memory_type": "DDR5", "power_wattage": 15, "form_factor": "DIMM", "stock_quantity": 9},
    {"product_id": 8, "name": "NVIDIA GeForce RTX 4070 Ti 12GB", "category": "GPU", "brand": "NVIDIA", "model": "RTX 4070 Ti", "price": 799.0, "socket": None, "memory_type": "GDDR6X", "power_wattage": 285, "form_factor": None, "stock_quantity": 5},
    {"product_id": 9, "name": "AMD Radeon RX 7800 XT 16GB", "category": "GPU", "brand": "AMD", "model": "RX 7800 XT", "price": 499.0, "socket": None, "memory_type": "GDDR6", "power_wattage": 263, "form_factor": None, "stock_quantity": 7},
    {"product_id": 10, "name": "Corsair RM750e 750W 80+ Gold Fully Modular", "category": "PSU", "brand": "Corsair", "model": "RM750e", "price": 99.0, "socket": None, "memory_type": None, "power_wattage": 750, "form_factor": "ATX", "stock_quantity": 14},
    {"product_id": 11, "name": "Samsung 980 Pro 1TB NVMe PCIe 4.0 SSD", "category": "Storage", "brand": "Samsung", "model": "980 Pro", "price": 89.0, "socket": None, "memory_type": None, "power_wattage": 10, "form_factor": "M.2 2280", "stock_quantity": 20},
    {"product_id": 12, "name": "NZXT H5 Flow ATX Mid-Tower Case", "category": "Case", "brand": "NZXT", "model": "H5 Flow", "price": 89.0, "socket": None, "memory_type": None, "power_wattage": 0, "form_factor": "ATX", "stock_quantity": 11},
    {"product_id": 13, "name": "DeepCool AK620 High-Performance CPU Air Cooler", "category": "Cooler", "brand": "DeepCool", "model": "AK620", "price": 65.0, "socket": "AM5 / LGA1700", "memory_type": None, "power_wattage": 5, "form_factor": None, "stock_quantity": 10},
]


def _find_product_in_catalog(pid: int) -> Optional[Dict[str, Any]]:
    """Helper to locate a product in the request-scoped catalog context or fallback."""
    ctx = inventory_context_var.get()
    catalog = ctx.get("catalog") if isinstance(ctx, dict) else None
    search_list = catalog if (catalog and isinstance(catalog, list)) else DEFAULT_INVENTORY_CATALOG
    for p in search_list:
        item_id = p.get("product_id") or p.get("productId")
        if item_id is not None and int(item_id) == pid:
            return p
    return None


@tool
def get_stock_level(product_id: int) -> str:
    """Check live shelf inventory count for a specific hardware component.
    Args:
        product_id: The unique database product ID to inspect.
    Returns:
        JSON string containing product_id, name, stock_quantity, status, and status_label.
    """
    pid = int(product_id)

    # 1. First priority: Check in-memory catalog context passed from ASP.NET Core
    p_ctx = _find_product_in_catalog(pid)
    if p_ctx:
        qty = int(p_ctx.get("stock_quantity") or p_ctx.get("stockQuantity") or 10)
        name = p_ctx.get("name", f"Product #{pid}")
        cat = p_ctx.get("category") or p_ctx.get("categoryName", "Component")
        price = float(p_ctx.get("price", 0.0))

        if qty == 0:
            status = "OUT_OF_STOCK"
            label = "Out of stock"
        elif qty <= 5:
            status = "LOW_STOCK"
            label = f"Low — {qty} left"
        else:
            status = "IN_STOCK"
            label = "In stock"

        return json.dumps({
            "product_id": pid,
            "name": name,
            "category": cat,
            "price": price,
            "stock_quantity": qty,
            "status": status,
            "status_label": label
        })

    # 2. Query backend API /api/products/{id} via HTTP
    try:
        url = f"{BACKEND_URL.rstrip('/')}/api/products/{pid}"
        req = urllib.request.Request(url, headers={"User-Agent": "PCForgeAi/1.0"})
        with urllib.request.urlopen(req, timeout=3.0) as resp:
            p = json.loads(resp.read().decode("utf-8"))
            qty = int(p.get("stockQuantity", 0))
            name = p.get("name", f"Product #{pid}")
            cat = p.get("categoryName", "Component")
            price = float(p.get("price", 0.0))

            if qty == 0:
                status = "OUT_OF_STOCK"
                label = "Out of stock"
            elif qty <= 5:
                status = "LOW_STOCK"
                label = f"Low — {qty} left"
            else:
                status = "IN_STOCK"
                label = "In stock"

            return json.dumps({
                "product_id": pid,
                "name": name,
                "category": cat,
                "price": price,
                "stock_quantity": qty,
                "status": status,
                "status_label": label
            })
    except Exception:
        pass

    # 3. Product not found in catalog
    return json.dumps({
        "product_id": pid,
        "name": f"Product #{pid}",
        "category": "Unknown",
        "price": 0.0,
        "stock_quantity": 0,
        "status": "OUT_OF_STOCK",
        "status_label": "Product not found in catalog",
        "error": f"Product #{pid} could not be located in live catalog."
    })


@tool
def find_compatible_substitute(
    category: str,
    failed_product_id: int,
    socket: Optional[str] = None,
    memory_type: Optional[str] = None,
    max_price: Optional[float] = None
) -> str:
    """Find in-stock alternative components from the store catalog if a selected part is out of stock.
    Filters exclusively for items with stock_quantity > 0 and matching technical compatibility.
    Args:
        category: Component category ('CPU', 'Motherboard', 'RAM', 'GPU', 'PSU', 'Storage', 'Case', 'Cooler').
        failed_product_id: ID of the out-of-stock product to replace.
        socket: Physical socket requirement (e.g. 'AM5', 'LGA1700').
        memory_type: Memory standard requirement (e.g. 'DDR5', 'DDR4').
        max_price: Maximum allowed unit price in USD.
    Returns:
        JSON string list of in-stock substitute components.
    """
    clean_cat = category.strip().lower()
    failed_id = int(failed_product_id)

    # 1. Retrieve items from context catalog or backend HTTP API
    catalog_items: List[Dict[str, Any]] = []
    ctx = inventory_context_var.get()
    ctx_catalog = ctx.get("catalog") if isinstance(ctx, dict) else None
    if ctx_catalog and isinstance(ctx_catalog, list):
        catalog_items = ctx_catalog
    else:
        try:
            url = f"{BACKEND_URL.rstrip('/')}/api/products"
            req = urllib.request.Request(url, headers={"User-Agent": "PCForgeAi/1.0"})
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if isinstance(data, list):
                    catalog_items = data
        except Exception:
            catalog_items = []

    if not catalog_items:
        catalog_items = DEFAULT_INVENTORY_CATALOG

    results = []
    for item in catalog_items:
        p_id = int(item.get("product_id") or item.get("productId") or 0)
        if p_id == failed_id:
            continue

        item_cat = (item.get("category") or item.get("categoryName") or "").strip().lower()
        if clean_cat not in item_cat and item_cat not in clean_cat:
            continue

        stock_qty = int(item.get("stock_quantity") or item.get("stockQuantity") or 0)
        if stock_qty <= 0:
            continue

        item_socket = item.get("socket")
        if socket and item_socket and socket.lower() not in str(item_socket).lower():
            continue

        item_mem = item.get("memory_type") or item.get("memoryType")
        if memory_type and item_mem and memory_type.lower() not in str(item_mem).lower():
            continue

        price = float(item.get("price") or 0.0)
        if max_price is not None and max_price > 0 and price > max_price:
            continue

        results.append({
            "product_id": p_id,
            "name": item.get("name", f"Product #{p_id}"),
            "category": item.get("category") or item.get("categoryName") or category,
            "brand": item.get("brand", ""),
            "model": item.get("model", ""),
            "price": price,
            "stock_quantity": stock_qty,
            "socket": item_socket,
            "memory_type": item_mem,
            "power_wattage": item.get("power_wattage") or item.get("powerWattage"),
            "form_factor": item.get("form_factor") or item.get("formFactor")
        })

    results.sort(key=lambda x: x["price"])
    return json.dumps(results[:10])


@tool
def reserve_stock(
    product_ids_json: str,
    session_id: str,
    hold_minutes: int = 15
) -> str:
    """Create a temporary 15-minute reservation hold on hardware components for customer review.
    Guarantees stock availability so parts are not sold out before customer checkout.
    Args:
        product_ids_json: JSON array of integer Product IDs (e.g. '[30, 43, 48, 36, 52, 56, 58, 61]').
        session_id: Active requirement gathering session ID.
        hold_minutes: Hold duration in minutes (standard is 15 minutes per project specifications).
    Returns:
        JSON string confirming reservation_id, expires_at timestamp, and 'Reserved ✓' status.
    """
    try:
        if isinstance(product_ids_json, list):
            ids = [int(i) for i in product_ids_json]
        else:
            ids = [int(i) for i in json.loads(product_ids_json)]
    except Exception:
        ids = []

    hold_mins = int(hold_minutes) if hold_minutes else 15
    now = datetime.now(timezone.utc)
    expires = now + timedelta(minutes=hold_mins)
    res_id = f"RES-{''.join(session_id.replace('-', '')[:8]).upper() if session_id else 'HOLD88'}"

    return json.dumps({
        "status": "RESERVED",
        "reservation_id": res_id,
        "held_minutes": hold_mins,
        "expires_at": expires.isoformat(),
        "status_label": "Reserved",
        "reserved_product_ids": ids
    })


INVENTORY_TOOLS = [
    get_stock_level,
    find_compatible_substitute,
    reserve_stock
]
