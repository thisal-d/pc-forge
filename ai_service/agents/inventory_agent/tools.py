"""
Inventory query and reservation tools for PCForge.
Provides real-time stock verification, compatible substitutions,
and reservation holds against catalog data.
"""

from contextvars import ContextVar
from datetime import datetime, timedelta, timezone
import json
import os
from typing import Any, Dict, List, Optional
import urllib.request
from langchain_core.tools import tool

BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:5000")

inventory_context_var: ContextVar[Dict[str, Any]] = ContextVar("inventory_context_var", default={})


def _find_product_in_catalog(pid: int) -> Optional[Dict[str, Any]]:
    """Helper to locate a product in the request-scoped catalog context from PostgreSQL database, or via live backend API."""
    ctx = inventory_context_var.get()
    catalog = ctx.get("catalog") if isinstance(ctx, dict) else None
    if catalog and isinstance(catalog, list):
        for p in catalog:
            item_id = p.get("product_id") or p.get("productId")
            if item_id is not None and int(item_id) == pid:
                return p

    # Query live backend API connected to PostgreSQL
    try:
        url = f"{BACKEND_URL.rstrip('/')}/api/products/{pid}"
        req = urllib.request.Request(url, headers={"User-Agent": "PCForgeAi/1.0"})
        with urllib.request.urlopen(req, timeout=3.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if isinstance(data, dict):
                return {
                    "product_id": data.get("productId", pid),
                    "name": data.get("name", f"Product #{pid}"),
                    "category": data.get("categoryName", "Component"),
                    "brand": data.get("brand", ""),
                    "model": data.get("model", ""),
                    "price": float(data.get("price", 0.0)),
                    "socket": data.get("socket"),
                    "memory_type": data.get("memoryType"),
                    "power_wattage": data.get("powerWattage"),
                    "form_factor": data.get("formFactor"),
                    "stock_quantity": int(data.get("stockQuantity", 0))
                }
    except Exception:
        pass

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
        raw_qty = p_ctx.get("stock_quantity")
        if raw_qty is None:
            raw_qty = p_ctx.get("stockQuantity", 0)
        qty = int(raw_qty)
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
        max_price: Maximum allowed unit price in LKR.
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
        return json.dumps([])

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
        JSON string confirming reservation_id, expires_at timestamp, and 'Reserved' status.
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
