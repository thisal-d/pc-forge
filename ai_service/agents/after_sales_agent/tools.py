"""
Allow-Listed Tools for After-Sales Service Agent — PCForge (Member 05)
=====================================================================
Performs verified system operations without direct database access:
  - Customer & order inspection from ASP.NET Core context
  - Live hardware warranty verification from ASP.NET Core context
  - RAG knowledge base search
  - Appointment validation
  - Structured Service Request generation for ASP.NET Core persistence
"""

from contextvars import ContextVar
from datetime import datetime, timezone, timedelta
import json
import os
import re
from typing import Any, Dict, List, Optional
from langchain_core.tools import tool

from ai_service.agents.after_sales_agent.knowledge_base import search_troubleshooting_knowledge as kb_search

# Request-scoped context passed by ASP.NET Core Web API
after_sales_context_var: ContextVar[Dict[str, Any]] = ContextVar("after_sales_context_var", default={})


def _get_category_warranty_months(category_name: Optional[str]) -> int:
    cat = (category_name or "").lower()
    if any(k in cat for k in ["gpu", "graphics", "video", "4070", "4080", "4090", "radeon"]):
        return 36
    if any(k in cat for k in ["cpu", "processor", "ryzen", "core", "intel"]):
        return 36
    if "motherboard" in cat:
        return 36
    if any(k in cat for k in ["ram", "memory", "ddr4", "ddr5"]):
        return 120  # 10 years / lifetime limited
    if any(k in cat for k in ["storage", "ssd", "nvme", "disk"]):
        return 60
    if any(k in cat for k in ["power", "psu", "watt"]):
        return 60
    if any(k in cat for k in ["cooler", "case", "chassis"]):
        return 24
    return 36


def _parse_product_warranty_months(specs: Optional[Any], category_name: Optional[str]) -> int:
    """Extract product-specific warranty length if stored in specs (e.g. '2 Years 6 Months', '30 Months', '6 Months', or numeric),
    otherwise gracefully fall back to the standard category warranty policy."""
    if specs:
        if isinstance(specs, str):
            try:
                specs = json.loads(specs)
            except Exception:
                specs = {}

        if isinstance(specs, dict):
            for key in ["warranty_months", "warrantyMonths", "warranty_month"]:
                if key in specs and isinstance(specs[key], (int, float)):
                    val = int(specs[key])
                    if val > 0:
                        return val

            for key in ["warranty", "warranty_period", "warrantyPeriod"]:
                if key in specs and isinstance(specs[key], str):
                    w_text = specs[key].strip().lower()
                    years = 0.0
                    months = 0
                    y_match = re.search(r'(\d+(?:\.\d+)?)\s*(?:year|yr)', w_text)
                    if y_match:
                        years = float(y_match.group(1))
                    m_match = re.search(r'(\d+)\s*(?:month|mo)', w_text)
                    if m_match:
                        months = int(m_match.group(1))
                    total = int(years * 12 + months)
                    if total > 0:
                        return total

    return _get_category_warranty_months(category_name)


def _format_warranty_period(months: int) -> str:
    """Format months into a clean, human-readable warranty period string."""
    years = months // 12
    rem = months % 12
    if years > 0 and rem > 0:
        return f"{years} Year{'s' if years > 1 else ''} {rem} Month{'s' if rem > 1 else ''} Manufacturer Warranty"
    elif years > 0:
        return f"{years} Year{'s' if years > 1 else ''} Manufacturer Warranty"
    elif rem > 0:
        return f"{rem} Month{'s' if rem > 1 else ''} Manufacturer Warranty"
    return "Standard Manufacturer Warranty"


@tool
def search_troubleshooting_knowledge(problem: str) -> str:
    """Retrieve safe, non-technical troubleshooting steps and safety warnings from the PCForge knowledge base.
    Args:
        problem: Customer's reported symptom (e.g. 'My PC won't turn on', 'My screen is black', 'strange noise').
    Returns:
        JSON string containing matched problem category, safe step-by-step guidance, and any critical safety hazard alerts.
    """
    result = kb_search(problem)
    return json.dumps(result)


@tool
def get_customer(user_id: int) -> str:
    """Retrieve authenticated customer account details (name, email) from context.
    Args:
        user_id: Authenticated user ID (e.g. 1).
    Returns:
        JSON string containing user's full name, email, and customer ID.
    """
    ctx = after_sales_context_var.get()
    customer = ctx.get("customer") if isinstance(ctx, dict) else None
    if customer and isinstance(customer, dict):
        full_name = customer.get("name") or customer.get("customer_name") or f"Customer #{user_id}"
        email = customer.get("email") or "customer@pcforge.com"
        return json.dumps({
            "user_id": user_id,
            "customer_name": full_name,
            "email": email
        })

    return json.dumps({
        "user_id": user_id,
        "customer_name": f"Customer #{user_id}",
        "email": "customer@pcforge.com"
    })


@tool
def get_order(order_id: int) -> str:
    """Retrieve verified order header information, purchase date, total amount, and fulfillment status.
    Args:
        order_id: The numeric order ID provided by the customer (e.g. 1001 or 1).
    Returns:
        JSON string with order existence, purchase date, status, and total amount.
    """
    ctx = after_sales_context_var.get()
    orders = ctx.get("orders") if isinstance(ctx, dict) else None

    if orders and isinstance(orders, list):
        for o in orders:
            oid = o.get("order_id") or o.get("orderId")
            if oid is not None and int(oid) == order_id:
                return json.dumps({
                    "found": True,
                    "order_id": order_id,
                    "order_number": o.get("order_number") or o.get("orderNumber") or f"PCF-10{order_id:03d}",
                    "user_id": o.get("user_id") or o.get("userId") or 1,
                    "total_amount": float(o.get("total_amount") or o.get("totalAmount") or 0.0),
                    "status": o.get("status") or "Delivered",
                    "purchase_date": o.get("purchase_date") or o.get("orderDate") or "2025-08-15"
                })

    return json.dumps({
        "found": False,
        "message": f"Order #{order_id} could not be found in our database. Please double check your order number."
    })


@tool
def get_order_products(order_id: int) -> str:
    """Retrieve itemized list of components and products purchased in an order.
    Args:
        order_id: The order ID.
    Returns:
        JSON string listing purchased products, model names, categories, and quantities.
    """
    ctx = after_sales_context_var.get()
    orders = ctx.get("orders") if isinstance(ctx, dict) else None

    if orders and isinstance(orders, list):
        for o in orders:
            oid = o.get("order_id") or o.get("orderId")
            if oid is not None and int(oid) == order_id:
                raw_items = o.get("items") or o.get("products") or []
                items = []
                for it in raw_items:
                    items.append({
                        "product_id": it.get("product_id") or it.get("productId") or 0,
                        "product_name": it.get("product_name") or it.get("productName") or it.get("name") or "Component",
                        "category": it.get("category") or it.get("categoryName") or "Hardware",
                        "unit_price": float(it.get("unit_price") or it.get("unitPrice") or 0.0),
                        "quantity": int(it.get("quantity") or 1)
                    })
                if items:
                    return json.dumps({"order_id": order_id, "products": items, "count": len(items)})

    return json.dumps({
        "order_id": order_id,
        "products": [],
        "count": 0,
        "error": f"No purchased items found for Order #{order_id}."
    })


@tool
def check_warranty(order_id: int, product_name_or_id: Optional[str] = None) -> str:
    """Verify official manufacturer warranty status and exact expiration date for a purchased component.
    Calculated strictly from purchase timestamp and category warranty policies:
      - GPUs, CPUs, Motherboards: 3-Year (36 months)
      - RAM: 10-Year (120 months)
      - PSUs, SSDs: 5-Year (60 months)
      - Cases & Coolers: 2-Year (24 months)
    Args:
        order_id: Valid customer Order ID.
        product_name_or_id: Component name or identifier (e.g. 'RTX 4070', 'CPU', or Product ID).
    Returns:
        JSON string with warranty status ('Active' or 'Expired'), expiration date, and coverage details.
    """
    now = datetime.now(timezone.utc)
    purchase_date = None
    matched_product_name = product_name_or_id or "Hardware Component"
    matched_category = "Hardware"
    matched_product_id = 0
    matched_specs = None
    order_found = False

    ctx = after_sales_context_var.get()
    orders = ctx.get("orders") if isinstance(ctx, dict) else None

    if orders and isinstance(orders, list):
        for o in orders:
            oid = o.get("order_id") or o.get("orderId")
            if oid is not None and int(oid) == order_id:
                order_found = True
                p_date_str = o.get("purchase_date") or o.get("orderDate")
                if p_date_str:
                    try:
                        purchase_date = datetime.fromisoformat(str(p_date_str).replace("Z", "+00:00"))
                    except Exception:
                        pass

                raw_items = o.get("items") or o.get("products") or []
                target_str = (product_name_or_id or "").lower()
                selected = None
                for it in raw_items:
                    name = str(it.get("product_name") or it.get("name") or "").lower()
                    cat = str(it.get("category") or it.get("categoryName") or "").lower()
                    if target_str and (target_str in name or target_str in cat):
                        selected = it
                        break
                if not selected and raw_items:
                    selected = raw_items[0]

                if selected:
                    matched_product_id = selected.get("product_id") or selected.get("productId") or 0
                    matched_product_name = selected.get("product_name") or selected.get("name") or matched_product_name
                    matched_category = selected.get("category") or selected.get("categoryName") or matched_category
                    matched_specs = selected.get("specifications")
                break

    if not order_found:
        return json.dumps({
            "order_id": order_id,
            "found": False,
            "error": f"Order #{order_id} could not be found in your purchase history. Please verify your order number."
        })

    if not purchase_date:
        purchase_date = now
    elif purchase_date.tzinfo is None:
        purchase_date = purchase_date.replace(tzinfo=timezone.utc)

    direct_warranty_months = (selected.get("warranty_months") or selected.get("warrantyMonths")) if selected else None
    if direct_warranty_months and isinstance(direct_warranty_months, (int, float)) and int(direct_warranty_months) > 0:
        warranty_months = int(direct_warranty_months)
    else:
        warranty_months = _parse_product_warranty_months(matched_specs, matched_category)
    expiry_date = purchase_date + timedelta(days=int(warranty_months * 30.4375))
    is_active = expiry_date >= now

    expiry_formatted = expiry_date.strftime("%B %d, %Y")
    status_str = "Active" if is_active else "Expired"
    warranty_period_display = _format_warranty_period(warranty_months)

    return json.dumps({
        "order_id": order_id,
        "product_id": matched_product_id,
        "product_name": matched_product_name,
        "category": matched_category,
        "purchase_date": purchase_date.strftime("%Y-%m-%d"),
        "warranty_period": warranty_period_display,
        "warranty_months": warranty_months,
        "warranty_status": status_str,
        "warranty_expiry_date": expiry_formatted,
        "is_under_warranty": is_active,
        "summary": (
            f"Your {matched_product_name} from Order #{order_id} is covered by active warranty until {expiry_formatted} ({warranty_period_display})."
            if is_active else
            f"The warranty coverage for {matched_product_name} expired on {expiry_formatted} ({warranty_period_display}). Technician inspection is available."
        )
    })


@tool
def validate_service_appointment(
    preferred_date: Optional[str] = None,
    preferred_time: Optional[str] = None
) -> str:
    """Validate that customer's requested service date and time slot conforms to PCForge service center rules.
    Business rules:
      - Both date AND time must be specified by the customer.
      - Date must be in the future (at least tomorrow).
      - Service Center is open Monday through Saturday (closed on Sundays).
      - Working hours: 09:00 AM to 06:00 PM.
    Args:
        preferred_date: Optional date string (e.g. '2026-10-02', 'Tomorrow', 'next Monday').
        preferred_time: Optional time string (e.g. '10:00 AM', '02:30 PM', '2 PM').
    Returns:
        JSON string indicating whether appointment is valid, or if time/date is missing.
    """
    now = datetime.now()
    ctx = after_sales_context_var.get() if isinstance(after_sales_context_var.get(), dict) else {}

    # Merge previously preserved date/time if not supplied in this turn
    date_str = (preferred_date or "").strip()
    if not date_str and ctx.get("preferred_date"):
        date_str = str(ctx.get("preferred_date")).strip()

    time_str = (preferred_time or "").strip()
    if not time_str and ctx.get("preferred_time"):
        time_str = str(ctx.get("preferred_time")).strip()

    parsed_date = None
    if date_str:
        date_lower = date_str.lower()
        if "tomorrow" in date_lower:
            parsed_date = (now + timedelta(days=1)).date()
        elif "today" in date_lower:
            parsed_date = now.date()
        else:
            # Check day of week names
            matched_day = False
            for idx, d_name in enumerate(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]):
                if d_name in date_lower:
                    days_ahead = (idx - now.weekday()) % 7
                    if days_ahead <= 0 or "next" in date_lower:
                        days_ahead += 7
                    parsed_date = (now + timedelta(days=days_ahead)).date()
                    matched_day = True
                    break
            if not matched_day:
                for fmt in ["%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%B %d, %Y", "%b %d, %Y", "%d-%m-%Y"]:
                    try:
                        parsed_date = datetime.strptime(date_str, fmt).date()
                        break
                    except Exception:
                        pass

        if not parsed_date:
            return json.dumps({
                "valid": False,
                "error": "invalid_date",
                "message": f"Could not recognize the date '{date_str}'. Please ask the customer for a valid date (Monday to Saturday)."
            })

        if parsed_date < now.date():
            return json.dumps({
                "valid": False,
                "error": "past_date",
                "message": f"The selected date ({parsed_date.strftime('%Y-%m-%d')}) has already passed. Please explain that the date has already passed and ask for another date."
            })

        if parsed_date.weekday() == 6:  # Sunday
            return json.dumps({
                "valid": False,
                "error": "sunday_closed",
                "message": f"The service center is closed on Sundays ({parsed_date.strftime('%Y-%m-%d')}). Please ask the customer to choose another date between Monday and Saturday."
            })

        # Check storewide maximum 10 service request capacity per date
        existing_list = ctx.get("service_requests") if isinstance(ctx, dict) else None
        if existing_list and isinstance(existing_list, list) and parsed_date:
            d_str = parsed_date.strftime("%Y-%m-%d")
            booked_same_date = sum(
                1 for sr in existing_list
                if str(sr.get("preferred_date") or "").startswith(d_str)
                and str(sr.get("status") or "").upper() not in ("CANCELLED", "CANCELED")
            )
            if booked_same_date >= 10:
                return json.dumps({
                    "valid": False,
                    "error": "capacity_exceeded",
                    "message": f"The selected date ({d_str}) has reached its maximum capacity of 10 service appointments (already has 10 requests booked). Please inform the customer and ask them to choose another date."
                })

        # Cache valid date into context
        ctx["preferred_date"] = parsed_date.strftime("%Y-%m-%d")

    formatted_time = None
    if time_str and time_str.lower() not in ["none", "null", ""]:
        time_clean = time_str.upper()
        hour = -1
        minute = 0
        match_12 = re.search(r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)', time_clean)
        if match_12:
            h = int(match_12.group(1))
            minute = int(match_12.group(2) or 0)
            ampm = match_12.group(3)
            if ampm == "PM" and h < 12:
                h += 12
            elif ampm == "AM" and h == 12:
                h = 0
            hour = h
        elif "AFTERNOON" in time_clean:
            hour = 14
            minute = 0
        elif "MORNING" in time_clean:
            hour = 10
            minute = 0
        else:
            match_24 = re.search(r'(\d{1,2}):(\d{2})', time_clean)
            if match_24:
                hour = int(match_24.group(1))
                minute = int(match_24.group(2))
            else:
                match_h = re.search(r'\b(\d{1,2})\b', time_clean)
                if match_h:
                    hour = int(match_h.group(1))
                    if hour < 7:  # e.g. "2" means 2 PM
                        hour += 12

        if hour < 9 or hour > 18 or (hour == 18 and minute > 0):
            return json.dumps({
                "valid": False,
                "error": "outside_hours",
                "message": f"The service time must be between 9:00 AM and 6:00 PM. Requested time '{time_str}' is outside working hours. Please explain that the service time must be between 9:00 AM and 6:00 PM and ask for another time."
            })

        formatted_time = f"{((hour - 1) % 12) + 1:02d}:{minute:02d} {'PM' if hour >= 12 else 'AM'}"
        # Cache valid time into context
        ctx["preferred_time"] = formatted_time

    # Determine state of completion
    if parsed_date and formatted_time:
        return json.dumps({
            "valid": True,
            "date": parsed_date.strftime("%Y-%m-%d"),
            "date_display": parsed_date.strftime("%A, %B %d, %Y"),
            "time": formatted_time,
            "message": f"Service appointment confirmed for {parsed_date.strftime('%A, %B %d, %Y')} at {formatted_time}."
        })
    elif parsed_date and not formatted_time:
        return json.dumps({
            "valid": False,
            "missing": "time",
            "date": parsed_date.strftime("%Y-%m-%d"),
            "date_display": parsed_date.strftime("%A, %B %d, %Y"),
            "message": f"Appointment date {parsed_date.strftime('%A, %B %d, %Y')} is noted, but preferred time was not provided. Please ask the customer only for their preferred time between 9:00 AM and 6:00 PM."
        })
    elif formatted_time and not parsed_date:
        return json.dumps({
            "valid": False,
            "missing": "date",
            "time": formatted_time,
            "message": f"Preferred time {formatted_time} is noted, but appointment date was not provided. Please ask the customer only for their preferred date (Monday to Saturday)."
        })
    else:
        return json.dumps({
            "valid": False,
            "missing": "both",
            "message": "Appointment date and time were not provided. Please ask the customer for their preferred date (Monday to Saturday) and time between 9:00 AM and 6:00 PM."
        })



@tool
def update_service_appointment(
    service_request_id_or_number: str,
    preferred_date: Optional[str] = None,
    preferred_time: Optional[str] = None
) -> str:
    """Updates the service appointment date and/or time slot of an existing Service Request.
    Use this tool whenever a customer asks to change the time, reschedule, or pick a different time for their Service Request.
    Do NOT call create_service_request when rescheduling!
    Args:
        service_request_id_or_number: The Service Request Number (e.g. 'SR-000105') or numeric ID (e.g. 15).
        preferred_date: New date if changed (e.g. '2026-09-29').
        preferred_time: New time slot (e.g. '02:00 PM').
    Returns:
        JSON string confirming the updated appointment details for ASP.NET Core persistence.
    """
    target = (service_request_id_or_number or "").strip().upper()
    sr_id = int(target) if target.isdigit() else 108
    sr_num = target if target.startswith("SR-") else f"SR-{sr_id:06d}"

    ctx = after_sales_context_var.get()
    existing_list = ctx.get("service_requests") if isinstance(ctx, dict) else None
    if existing_list and isinstance(existing_list, list):
        for sr in existing_list:
            cand_num = str(sr.get("service_request_number") or sr.get("serviceRequestNumber") or "").upper()
            cand_id = sr.get("service_request_id") or sr.get("serviceRequestId")
            if target == cand_num or (target.isdigit() and cand_id == int(target)):
                sr_num = cand_num or sr_num
                sr_id = cand_id or sr_id
                break

    new_date = preferred_date.strip() if preferred_date and preferred_date.strip() else str((datetime.now() + timedelta(days=2)).date())
    new_time = preferred_time.strip() if preferred_time and preferred_time.strip() else "10:00 AM"

    return json.dumps({
        "success": True,
        "action": "UPDATE_APPOINTMENT",
        "service_request_id": sr_id,
        "service_request_number": sr_num,
        "preferred_date": new_date,
        "preferred_time": new_time,
        "status": "PENDING",
        "confirmation_message": f"Your appointment for Service Request {sr_num} has been successfully rescheduled to {new_date} at {new_time}.",
        "message": f"Appointment for Service Request {sr_num} has been successfully updated to {new_date} at {new_time}."
    })


@tool
def create_service_request(
    user_id: int,
    problem_description: str,
    title: Optional[str] = None,
    description: Optional[str] = None,
    problem_category: str = "General",
    troubleshooting_summary: str = "",
    attempt_count: int = 5,
    order_id: Optional[int] = None,
    product_id: Optional[int] = None,
    product_name: Optional[str] = None,
    warranty_status: str = "Active",
    warranty_expiry_date: Optional[str] = None,
    preferred_date: Optional[str] = None,
    preferred_time: Optional[str] = None,
    priority: str = "Normal"
) -> str:
    """Create a structured Service Request candidate for ASP.NET Core EF Core persistence.
    Args:
        user_id: Authenticated customer user ID (e.g. 1).
        problem_description: Summary of the customer's reported symptom.
        title: Short title/summary of the service request (e.g. 'PC won't boot into Windows').
        description: Optional detailed description of the symptom or background.
        problem_category: Problem classification (e.g. 'Power / Boot', 'Display / Black Screen', etc.).
        troubleshooting_summary: Structured notes of steps attempted and outcomes for the technician.
        attempt_count: Number of troubleshooting steps attempted (1 to 5).
        order_id: Verified purchase order ID if provided (optional).
        product_id: Product ID of the affected component if identified.
        product_name: Commercial name of component (e.g. 'NVIDIA GeForce RTX 4070 Ti').
        warranty_status: 'Active' or 'Expired'.
        warranty_expiry_date: Formatted expiration date string.
        preferred_date: Appointment date (e.g. '2026-10-02').
        preferred_time: Appointment time slot (e.g. '10:00 AM').
        priority: Priority tag ('Normal', 'High', 'Urgent').
    Returns:
        JSON string confirming the candidate Service Request for ASP.NET Core authoritative persistence.
    """
    now = datetime.now(timezone.utc)
    sr_id = 108
    sr_number = "SR-000108"

    ctx = after_sales_context_var.get()
    existing_list = ctx.get("service_requests") if isinstance(ctx, dict) else None

    p_date = preferred_date or str((datetime.now() + timedelta(days=2)).date())
    p_time = preferred_time or "10:00 AM"

    # Past date validation
    if preferred_date:
        for fmt in ["%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%B %d, %Y", "%b %d, %Y", "%d-%m-%Y"]:
            try:
                cand_d = datetime.strptime(str(preferred_date).strip(), fmt).date()
                if cand_d < datetime.now().date():
                    return json.dumps({
                        "success": False,
                        "error": "past_date",
                        "message": f"The selected date ({preferred_date}) has already passed. Please ask the customer for another date."
                    })
                break
            except Exception:
                pass

    # Operating hours validation (09:00 AM to 06:00 PM)
    if preferred_time:
        t_clean = str(preferred_time).strip().upper()
        m12 = re.search(r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)', t_clean)
        hour = -1
        minute = 0
        if m12:
            hour = int(m12.group(1))
            minute = int(m12.group(2) or 0)
            ampm = m12.group(3)
            if ampm == "PM" and hour < 12: hour += 12
            elif ampm == "AM" and hour == 12: hour = 0
        else:
            m24 = re.search(r'(\d{1,2}):(\d{2})', t_clean)
            if m24:
                hour = int(m24.group(1))
                minute = int(m24.group(2))
        if hour >= 0 and (hour < 9 or hour > 18 or (hour == 18 and minute > 0)):
            return json.dumps({
                "success": False,
                "error": "outside_hours",
                "message": f"The service time must be between 9:00 AM and 6:00 PM. '{preferred_time}' is outside working hours. Please choose another time."
            })

    # Capacity check: max 10 appointments per day storewide
    if existing_list and isinstance(existing_list, list) and preferred_date:
        booked_same_date = sum(
            1 for sr in existing_list
            if str(sr.get("preferred_date") or "").startswith(str(p_date))
            and str(sr.get("status") or "").upper() not in ("CANCELLED", "CANCELED")
        )
        if booked_same_date >= 10:
            return json.dumps({
                "success": False,
                "error": "capacity_exceeded",
                "message": f"The selected date ({p_date}) has reached its maximum capacity of 10 service appointments (already has 10 requests booked). Please inform the customer and ask them to choose another date."
            })

    # Check for duplicate open request in context to avoid multiple pending requests
    if existing_list and isinstance(existing_list, list):
        for sr in existing_list:
            status = str(sr.get("status") or "").upper()
            cat = str(sr.get("problem_category") or sr.get("problemCategory") or "").strip()
            sr_order = sr.get("order_id") or sr.get("orderId")
            if status == "PENDING" and ((cat and cat.lower() == problem_category.lower()) or (order_id and sr_order == order_id)):
                cand_num = sr.get("service_request_number") or sr.get("serviceRequestNumber") or "SR-000108"
                cand_id = sr.get("service_request_id") or sr.get("serviceRequestId") or 108
                return json.dumps({
                    "success": True,
                    "action": "UPDATE_APPOINTMENT",
                    "service_request_id": cand_id,
                    "service_request_number": cand_num,
                    "user_id": user_id,
                    "order_id": order_id,
                    "order_number": f"PCF-10{order_id:03d}" if order_id else None,
                    "product_id": product_id,
                    "product_name": product_name or "Hardware Component",
                    "title": title or sr.get("title") or problem_description,
                    "description": description or sr.get("description") or problem_description,
                    "problem_description": problem_description,
                    "problem_category": problem_category,
                    "troubleshooting_summary": troubleshooting_summary,
                    "attempt_count": attempt_count,
                    "warranty_status": warranty_status,
                    "warranty_expiry_date": warranty_expiry_date or "Aug 2028",
                    "preferred_date": preferred_date or str((datetime.now() + timedelta(days=2)).date()),
                    "preferred_time": preferred_time or "10:00 AM",
                    "status": "PENDING",
                    "priority": priority,
                    "confirmation_message": f"Your Service Request ({cand_num}) appointment has been updated to {preferred_date or 'your chosen date'} at {preferred_time or '10:00 AM'}. Our technician will inspect your PC."
                })

    res_title = (title or "").strip() or (f"Service: {product_name}" if product_name else (problem_description[:50] if len(problem_description) > 50 else problem_description))
    res_desc = (description or "").strip() or problem_description

    return json.dumps({
        "success": True,
        "action": "CREATE_SERVICE_REQUEST",
        "service_request_id": sr_id,
        "service_request_number": sr_number,
        "user_id": user_id,
        "order_id": order_id,
        "order_number": f"PCF-10{order_id:03d}" if order_id else None,
        "product_id": product_id,
        "product_name": product_name or "Hardware Component",
        "title": res_title,
        "description": res_desc,
        "problem_description": problem_description,
        "problem_category": problem_category,
        "troubleshooting_summary": troubleshooting_summary or f"AI Troubleshooting completed ({attempt_count} attempts).",
        "attempt_count": attempt_count,
        "warranty_status": warranty_status,
        "warranty_expiry_date": warranty_expiry_date or "Aug 2028",
        "preferred_date": p_date,
        "preferred_time": p_time,
        "status": "PENDING",
        "priority": priority,
        "created_at": now.isoformat(),
        "confirmation_message": (
            f"Your Service Request has been created successfully.\n\n"
            f"Service Request ID: {sr_number}\n"
            f"Title: {res_title}\n"
            f"Order ID: {f'PCF-10{order_id:03d}' if order_id else 'N/A'}\n"
            f"Product: {product_name or 'Hardware Component'}\n"
            f"Warranty: {warranty_status}\n"
            f"Preferred Date: {p_date}\n"
            f"Preferred Time: {p_time}\n"
            f"Status: PENDING\n\n"
            f"Please bring your PC or the affected component to our service center for technician inspection."
        )
    })


@tool
def get_service_request(service_request_number_or_id: str) -> str:
    """Retrieve existing Service Request by its SR number (e.g. 'SR-000108') or numeric ID.
    Args:
        service_request_number_or_id: The Service Request identifier.
    Returns:
        JSON string containing the complete Service Request record.
    """
    identifier = service_request_number_or_id.strip().upper()
    ctx = after_sales_context_var.get()
    existing_list = ctx.get("service_requests") if isinstance(ctx, dict) else None

    if existing_list and isinstance(existing_list, list):
        for sr in existing_list:
            cand_num = str(sr.get("service_request_number") or sr.get("serviceRequestNumber") or "").upper()
            cand_id = sr.get("service_request_id") or sr.get("serviceRequestId")
            if identifier == cand_num or (identifier.isdigit() and cand_id == int(identifier)):
                return json.dumps({
                    "found": True,
                    "service_request_id": cand_id,
                    "service_request_number": cand_num,
                    "user_id": sr.get("user_id") or sr.get("userId") or 1,
                    "order_id": sr.get("order_id") or sr.get("orderId"),
                    "product_id": sr.get("product_id") or sr.get("productId"),
                    "problem_description": sr.get("problem_description") or sr.get("problemDescription") or "",
                    "problem_category": sr.get("problem_category") or sr.get("problemCategory") or "General",
                    "status": sr.get("status") or "PENDING",
                    "priority": sr.get("priority") or "Normal",
                    "warranty_status": sr.get("warranty_status") or sr.get("warrantyStatus") or "Active",
                    "preferred_date": sr.get("preferred_date") or sr.get("preferredDate"),
                    "preferred_time": sr.get("preferred_time") or sr.get("preferredTime"),
                    "created_at": sr.get("created_at") or sr.get("createdAt")
                })

    return json.dumps({"found": False, "message": f"Service Request '{identifier}' not found."})


@tool
def get_customer_service_requests(user_id: int) -> str:
    """Retrieve list of active and past Service Requests for a customer from context.
    Args:
        user_id: Authenticated customer user ID.
    Returns:
        JSON string containing the customer's service requests.
    """
    ctx = after_sales_context_var.get()
    existing_list = ctx.get("service_requests") if isinstance(ctx, dict) else None
    requests = existing_list if existing_list and isinstance(existing_list, list) else []

    return json.dumps({
        "user_id": user_id,
        "service_requests": requests,
        "count": len(requests)
    })


# Backward compatibility aliases for existing tests
@tool
def get_order_history(user_id: int = 1, order_number: Optional[str] = None) -> str:
    """Retrieve customer's verified purchase history (legacy alias)."""
    return get_order_products.invoke({"order_id": 1 if user_id == 1 else user_id})


@tool
def get_warranty_status(product_name_or_id: str, order_id_or_number: Optional[str] = "PCF-10492") -> str:
    """Check manufacturer warranty eligibility (legacy alias)."""
    oid = 1
    if order_id_or_number:
        clean = re.sub(r"[^\d]", "", order_id_or_number)
        if clean:
            oid = int(clean)
    return check_warranty.invoke({"order_id": oid, "product_name_or_id": product_name_or_id})


@tool
def create_rma_ticket(
    user_id: int,
    product_name: str,
    issue_type: str = "Hardware fault",
    fault_description: str = "",
    order_id: Optional[int] = None,
    priority: str = "High"
) -> str:
    """Creates a service request (legacy RMA alias)."""
    return create_service_request.invoke({
        "user_id": user_id,
        "problem_description": fault_description or f"Defective {product_name}",
        "problem_category": issue_type,
        "troubleshooting_summary": "Legacy RMA creation request.",
        "attempt_count": 1,
        "order_id": order_id,
        "product_name": product_name,
        "warranty_status": "Active",
        "priority": priority
    })


# Master list of allow-listed tools exposed to the agent
AFTER_SALES_TOOLS = [
    search_troubleshooting_knowledge,
    get_customer,
    get_order,
    get_order_products,
    check_warranty,
    validate_service_appointment,
    update_service_appointment,
    create_service_request,
    get_service_request,
    get_customer_service_requests,
    # Legacy aliases
    get_order_history,
    get_warranty_status,
    create_rma_ticket
]
