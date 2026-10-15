"""
Order planning tools for PCForge.
Provides subtotal calculation, discount validation, delivery estimation,
and formal proposal generation.
"""

from contextvars import ContextVar
import json
import os
import random
from typing import Dict, List, Optional, Any
import urllib.parse
import urllib.request
from langchain_core.tools import tool

BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:5000")

order_planning_context_var: ContextVar[Dict[str, Any]] = ContextVar("order_planning_context_var", default={})


def _format_currency(amount: float, currency: str = "LKR") -> str:
    """Helper to format currency strings cleanly."""
    curr = currency if currency else "LKR"
    return f"{curr} {int(round(amount)):,}"


@tool
def calculate_pricing(
    components_json: str,
    currency: str = "LKR"
) -> str:
    """Calculate the subtotal and itemized pricing for all 8 components of the stock-confirmed build.
    Args:
        components_json: JSON string or dictionary of components with unit prices.
        currency: Store currency code ('LKR' or 'Rs.').
    Returns:
        JSON string containing itemized line items, component count, and calculated subtotal.
    """
    try:
        if isinstance(components_json, str):
            raw_comps = json.loads(components_json)
        else:
            raw_comps = components_json

        items = []
        raw_subtotal = 0.0

        # Handle dictionary of slots or array of items
        if isinstance(raw_comps, dict):
            iterable = raw_comps.items()
        elif isinstance(raw_comps, list):
            iterable = [(f"item_{i}", c) for i, c in enumerate(raw_comps)]
        else:
            iterable = []

        for slot, comp in iterable:
            if not isinstance(comp, dict):
                continue
            pid = int(comp.get("product_id") or comp.get("productId") or 0)
            name = str(comp.get("name") or comp.get("product_name") or f"Component {slot}")
            price = float(comp.get("price") or comp.get("unit_price") or 0.0)
            qty = int(comp.get("quantity") or 1)
            line_total = price * qty

            items.append({
                "product_id": pid,
                "slot": slot,
                "name": name,
                "unit_price": price,
                "quantity": qty,
                "total_price": line_total
            })
            raw_subtotal += line_total

        subtotal = raw_subtotal

        return json.dumps({
            "currency": currency,
            "components_count": len(items),
            "subtotal": subtotal,
            "formatted_subtotal": _format_currency(subtotal, currency),
            "items": items
        })
    except Exception as e:
        return json.dumps({"error": f"Failed calculating pricing: {e}"})


@tool
def apply_discount(
    promo_code: str,
    subtotal: float,
    currency: str = "LKR"
) -> str:
    """Validate and apply promotional vouchers to the build subtotal by querying the live PostgreSQL database.
    Queries the store `coupons` table for active campaigns (e.g. WELCOME5, FORGE10, GAMER2026, SLIITVIP),
    verifies eligibility against minimum subtotal, calculates exact deductions, and enforces maximum discount caps.
    Args:
        promo_code: Promotional code string provided by customer.
        subtotal: Current subtotal before discount.
        currency: Store currency code ('LKR' or 'Rs.').
    Returns:
        JSON string indicating voucher validity, discount amount, and updated net subtotal.
    """
    code_clean = (promo_code or "").strip().upper()
    subtotal_val = float(subtotal) if subtotal else 0.0

    if not code_clean:
        return json.dumps({
            "valid": False,
            "promo_code": "",
            "discount_amount": 0.0,
            "discount_percentage": 0.0,
            "formatted_discount": _format_currency(0.0, currency),
            "net_subtotal": subtotal_val,
            "message": "No promo code provided."
        })

    # Retrieve coupon details from request context or live backend API connected to PostgreSQL
    matched_coupon = None
    ctx = order_planning_context_var.get()
    ctx_coupons = ctx.get("coupons") if isinstance(ctx, dict) else None
    if ctx_coupons and isinstance(ctx_coupons, list):
        for c in ctx_coupons:
            if str(c.get("code") or "").strip().upper() == code_clean and c.get("is_active", True):
                matched_coupon = c
                break

    # If not in request-scoped context, validate against PostgreSQL via live backend API
    if not matched_coupon:
        try:
            url = f"{BACKEND_URL.rstrip('/')}/api/coupons/validate/{urllib.parse.quote(code_clean)}"
            req = urllib.request.Request(url, headers={"User-Agent": "PCForgeAi/1.0"})
            with urllib.request.urlopen(req, timeout=3.0) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if isinstance(data, dict) and data.get("code"):
                    matched_coupon = {
                        "code": data.get("code"),
                        "description": data.get("description", "Promotion applied"),
                        "discount_type": data.get("discountType") or data.get("discount_type") or "PERCENTAGE",
                        "discount_value": float(data.get("discountValue") or data.get("discount_value") or 0.0),
                        "min_subtotal": float(data.get("minSubtotal") or data.get("min_subtotal") or 0.0),
                        "max_discount": float(data.get("maxDiscount") or data.get("max_discount")) if (data.get("maxDiscount") or data.get("max_discount")) else None,
                        "is_active": data.get("isActive", True)
                    }
        except Exception:
            matched_coupon = None

    if not matched_coupon:
        return json.dumps({
            "valid": False,
            "promo_code": code_clean,
            "discount_amount": 0.0,
            "discount_percentage": 0.0,
            "formatted_discount": f"- {_format_currency(0.0, currency)}",
            "net_subtotal": subtotal_val,
            "message": f"Promo code '{code_clean}' is expired or invalid."
        })

    code_db = matched_coupon.get("code", code_clean)
    desc = matched_coupon.get("description", "Promotion applied")
    dtype = matched_coupon.get("discount_type") or matched_coupon.get("discountType") or "PERCENTAGE"
    val = matched_coupon.get("discount_value") or matched_coupon.get("discountValue") or 0.0
    min_sub = matched_coupon.get("min_subtotal") or matched_coupon.get("minSubtotal")
    max_disc = matched_coupon.get("max_discount") or matched_coupon.get("maxDiscount")

    min_subtotal_val = float(min_sub) if min_sub is not None else 0.0
    discount_val = float(val) if val is not None else 0.0
    max_disc_val = float(max_disc) if max_disc is not None else None

    # Check minimum spend requirement
    if subtotal_val < min_subtotal_val:
        return json.dumps({
            "valid": False,
            "promo_code": code_db,
            "discount_amount": 0.0,
            "discount_percentage": 0.0,
            "formatted_discount": f"- {_format_currency(0.0, currency)}",
            "net_subtotal": subtotal_val,
            "message": f"Promo code '{code_db}' requires a minimum subtotal of {_format_currency(min_subtotal_val, currency)}. Your current subtotal is {_format_currency(subtotal_val, currency)}."
        })

    # Calculate discount amount based on discount type
    if str(dtype).upper() == "PERCENTAGE":
        pct = discount_val
        discount = round(subtotal_val * (pct / 100.0), 0 if currency in ["Rs.", "LKR", "Rs"] else 2)
        if max_disc_val and max_disc_val > 0:
            discount = min(discount, max_disc_val)
    elif str(dtype).upper() == "FLAT":
        discount = discount_val
        pct = round((discount / subtotal_val * 100), 1) if subtotal_val > 0 else 0.0
    else:
        discount = 0.0
        pct = 0.0

    net_subtotal = max(0.0, subtotal_val - discount)
    formatted_disc = f"- {_format_currency(discount, currency)}"
    label = f"Discount ({code_db})"

    return json.dumps({
        "valid": True,
        "promo_code": code_db,
        "discount_amount": discount,
        "discount_percentage": pct,
        "discount_label": label,
        "formatted_discount": formatted_disc,
        "net_subtotal": net_subtotal,
        "message": f"{desc} verified and applied."
    })


@tool
def calculate_delivery(
    shipping_method: str = "standard",
    address_zone: str = "colombo",
    currency: str = "LKR"
) -> str:
    """Calculate shipping fee and arrival timeframe for physical PC delivery.
    Tiers:
      - standard: Rs. 2,500 — 3 to 5 business days (Matches UI 4)
      - express:  Rs. 5,000 — 1 to 2 business days
      - pickup:   Rs. 0 — Same-day in-store pickup
    Args:
        shipping_method: 'standard', 'express', or 'pickup'.
        address_zone: Delivery destination district or province.
        currency: Store currency code ('LKR' or 'Rs.').
    Returns:
        JSON string with delivery fee, estimated delivery days, and method title.
    """
    method_clean = (shipping_method or "standard").lower().strip()

    if method_clean in ["express", "priority", "fast"]:
        fee = 5000.0
        days = "1-2 business days"
        title = "Express Priority Courier"
    elif method_clean in ["pickup", "store_pickup", "collection"]:
        fee = 0.0
        days = "Same-day in-store collection"
        title = "Store Pickup (Colombo HQ)"
    else:  # Standard
        # Matches ui4.png: "Delivery Rs. 2,500"
        fee = 2500.0
        days = "3-5 business days"
        title = "Standard Insured Delivery"

    return json.dumps({
        "shipping_method": title,
        "delivery_fee": fee,
        "formatted_delivery": _format_currency(fee, currency),
        "estimated_delivery_days": days,
        "address_zone": address_zone
    })


@tool
def create_order_proposal(
    build_name: str,
    reservation_id: str,
    subtotal: float,
    discount_amount: float,
    delivery_fee: float = 0.0,
    total_price: Optional[float] = None,
    promo_code: str = "",
    currency: str = "LKR",
    order_number: Optional[str] = None
) -> str:
    """Create the formal Order Proposal holding status 'WAITING_FOR_APPROVAL'.
    Matches UI 4 in PCForge Agentic Workflow specifications.
    Args:
        build_name: Name of the proposed PC build.
        reservation_id: Valid 15-minute warehouse reservation hold ID.
        subtotal: Sum of component prices before discount.
        discount_amount: Deducted discount amount.
        delivery_fee: Delivery fee (0.0 for build proposals; selected at checkout).
        total_price: Net total price to be proposed to customer.
        promo_code: Applied coupon code.
        currency: Store currency code ('LKR' or 'Rs.').
        order_number: Optional order reference (e.g. PCF-10492).
    Returns:
        JSON string confirming proposal creation with status WAITING_FOR_APPROVAL.
    """
    # Matches ui4.png and ui5.png order format: "Order #PCF-10492"
    if not order_number or order_number == "None":
        rand_suffix = random.randint(10400, 10999)
        ord_num = f"PCF-{rand_suffix}"
    else:
        ord_num = order_number

    prop_id = f"PROP-{ord_num.replace('-', '')}"
    disc_label = f"Discount ({promo_code.strip().upper()})" if promo_code else "Discount"

    delivery_val = float(delivery_fee or 0.0)
    calculated_total = float(total_price) if total_price is not None else max(0.0, float(subtotal) - float(discount_amount) + delivery_val)

    return json.dumps({
        "proposal_id": prop_id,
        "order_number": ord_num,
        "build_name": build_name or "Custom PCForge Rig",
        "reservation_id": reservation_id,
        "status": "WAITING_FOR_APPROVAL",
        "status_label": "Waiting for your approval",
        "pricing": {
            "currency": currency,
            "subtotal": float(subtotal),
            "discount_code": promo_code or None,
            "discount_amount": float(discount_amount),
            "discount_label": disc_label,
            "delivery_fee": delivery_val,
            "total_price": calculated_total,
            "formatted_subtotal": _format_currency(subtotal, currency),
            "formatted_discount": f"- {_format_currency(discount_amount, currency)}" if discount_amount > 0 else _format_currency(0, currency),
            "formatted_delivery": _format_currency(delivery_val, currency) if delivery_val > 0 else "Rs. 0 (Calculated at checkout)",
            "formatted_total": _format_currency(calculated_total, currency),
        },
        "technician_notice": "We'll notify you once a technician has checked your build — usually within a few hours."
    })


# Export allow-listed tools list for LangGraph registration
ORDER_PLANNING_TOOLS = [
    calculate_pricing,
    apply_discount,
    calculate_delivery,
    create_order_proposal
]
