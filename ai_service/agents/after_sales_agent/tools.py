"""
After-sales support tools for PCForge.
Provides customer order lookup, hardware warranty inspection, RAG troubleshooting
search, and service appointment scheduling.
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





def _parse_date_string(date_str: Optional[str]) -> Optional[Any]:
    """Helper to parse relative terms like 'Tomorrow', day of week names, or formatted dates to a date object."""
    if not date_str or not str(date_str).strip():
        return None
    clean = str(date_str).strip().lower()
    now = datetime.now()
    if "tomorrow" in clean:
        cand = (now + timedelta(days=1)).date()
        if cand.weekday() == 6:  # Skip Sunday to Monday
            cand = cand + timedelta(days=1)
        return cand
    if "today" in clean:
        return now.date()
    for idx, d_name in enumerate(["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]):
        if d_name in clean:
            days_ahead = (idx - now.weekday()) % 7
            if days_ahead <= 0 or "next" in clean:
                days_ahead += 7
            cand = (now + timedelta(days=days_ahead)).date()
            if cand.weekday() == 6:
                cand = cand + timedelta(days=1)
            return cand
    for fmt in ["%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%B %d, %Y", "%b %d, %Y", "%d-%m-%Y", "%Y/%m/%d"]:
        try:
            return datetime.strptime(str(date_str).strip(), fmt).date()
        except Exception:
            pass
    return None


DEFAULT_SERVICE_TIME_SLOTS: List[Dict[str, Any]] = [
    {"slot_id": 1, "start_time": "09:00", "end_time": "11:00", "label": "09:00 AM - 11:00 AM", "default_capacity": 5},
    {"slot_id": 2, "start_time": "11:00", "end_time": "13:00", "label": "11:00 AM - 01:00 PM", "default_capacity": 5},
    {"slot_id": 6, "start_time": "12:30", "end_time": "14:30", "label": "12:30 PM - 02:30 PM", "default_capacity": 5},
    {"slot_id": 3, "start_time": "14:00", "end_time": "16:00", "label": "02:00 PM - 04:00 PM", "default_capacity": 5},
    {"slot_id": 4, "start_time": "16:00", "end_time": "18:00", "label": "04:00 PM - 06:00 PM", "default_capacity": 5},
]


def _get_active_time_slots() -> List[Dict[str, Any]]:
    """Returns active service time slots from request context (live DB), falling back to defaults."""
    ctx = after_sales_context_var.get() if isinstance(after_sales_context_var.get(), dict) else {}
    raw_slots = ctx.get("time_slots")
    if raw_slots and isinstance(raw_slots, list):
        active_list = []
        for s in raw_slots:
            is_active = s.get("is_active") if "is_active" in s else s.get("isActive", True)
            if is_active:
                s_id = s.get("slot_id") or s.get("slotId") or 0
                s_start = s.get("start_time") or s.get("startTime") or "09:00"
                s_end = s.get("end_time") or s.get("endTime") or "11:00"
                s_label = s.get("label") or f"{s_start} - {s_end}"
                active_list.append({
                    "slot_id": int(s_id),
                    "start_time": str(s_start),
                    "end_time": str(s_end),
                    "label": str(s_label),
                    "default_capacity": int(s.get("default_capacity") or s.get("defaultCapacity") or 5)
                })
        if active_list:
            active_list.sort(key=lambda x: x.get("start_time", ""))
            return active_list

    return DEFAULT_SERVICE_TIME_SLOTS


def _resolve_slot(time_str: Optional[str] = None, slot_id: Optional[int] = None) -> Optional[Dict[str, Any]]:
    """Resolves matching service time slot from numeric ID or customer time string."""
    slots = _get_active_time_slots()

    if slot_id is not None:
        try:
            s_id = int(slot_id)
            for s in slots:
                if s["slot_id"] == s_id:
                    return s
        except (ValueError, TypeError):
            pass

    if not time_str:
        return None

    clean = str(time_str).strip().lower()

    # Exact slot number or label matching
    for s in slots:
        if s["label"].lower() in clean or clean in s["label"].lower():
            return s
        if f"slot {s['slot_id']}" in clean:
            return s



    # Parse 12-hour or 24-hour time to total minutes from midnight
    minutes_val = -1
    m12 = re.search(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)', clean)
    if m12:
        h = int(m12.group(1))
        m = int(m12.group(2)) if m12.group(2) else 0
        ampm = m12.group(3).upper()
        if ampm == "PM" and h < 12:
            h += 12
        elif ampm == "AM" and h == 12:
            h = 0
        minutes_val = h * 60 + m
    else:
        m24 = re.search(r'(\d{1,2}):(\d{2})', clean)
        if m24:
            minutes_val = int(m24.group(1)) * 60 + int(m24.group(2))
        else:
            mh = re.search(r'\b(\d{1,2})\b', clean)
            if mh:
                h = int(mh.group(1))
                if h < 7:  # e.g. "2" means 2 PM
                    h += 12
                minutes_val = h * 60

    if minutes_val >= 0:
        # Match slot covering this minute
        for s in slots:
            try:
                sh, sm = map(int, s["start_time"].split(":"))
                eh, em = map(int, s["end_time"].split(":"))
                s_min = sh * 60 + sm
                e_min = eh * 60 + em
                if s_min <= minutes_val < e_min:
                    return s
            except Exception:
                pass

        # Fallback to closest slot start time
        best_slot = None
        min_diff = 999999
        for s in slots:
            try:
                sh, sm = map(int, s["start_time"].split(":"))
                s_min = sh * 60 + sm
                diff = abs(s_min - minutes_val)
                if diff < min_diff:
                    min_diff = diff
                    best_slot = s
            except Exception:
                pass
        if best_slot:
            return best_slot

    return None


@tool
def get_available_time_slots(preferred_date: Optional[str] = None) -> str:
    """Retrieve list of active service time slots and remaining booking capacity for a given date.
    Operating days: Monday through Saturday (Sunday closed).
    Working hours: 09:00 AM - 06:00 PM across configured slots.
    Args:
        preferred_date: Appointment date to check (e.g. '2026-10-20' or 'Tomorrow').
    Returns:
        JSON string listing the available time slots with availability status.
    """
    ctx = after_sales_context_var.get() if isinstance(after_sales_context_var.get(), dict) else {}
    target_date = preferred_date or ctx.get("preferred_date") or str((datetime.now() + timedelta(days=1)).date())

    existing_list = ctx.get("service_requests") if isinstance(ctx, dict) else None
    configured_slots = _get_active_time_slots()

    slots_output = []
    for s in configured_slots:
        booked = 0
        if existing_list and isinstance(existing_list, list):
            for sr in existing_list:
                sr_d = str(sr.get("preferred_date") or "")
                sr_status = str(sr.get("status") or "").upper()
                sr_slot = sr.get("slot_id")
                if target_date in sr_d and sr_status not in ("CANCELLED", "CANCELED", "REJECTED"):
                    if sr_slot == s["slot_id"] or s["label"].lower() in str(sr.get("preferred_time") or "").lower():
                        booked += 1

        capacity = s.get("default_capacity", 5)
        remaining = max(0, capacity - booked)
        slots_output.append({
            "slot_id": s["slot_id"],
            "label": s["label"],
            "start_time": s["start_time"],
            "end_time": s["end_time"],
            "max_capacity": capacity,
            "booked_count": booked,
            "remaining_slots": remaining,
            "is_available": remaining > 0
        })

    return json.dumps({
        "date": target_date,
        "operating_days": "Monday to Saturday (Closed Sunday)",
        "slots": slots_output
    })


@tool
def validate_service_appointment(
    preferred_date: Optional[str] = None,
    preferred_time: Optional[str] = None,
    slot_id: Optional[int] = None
) -> str:
    """Validate that customer's requested service date and time slot conforms to PCForge service center rules.
    Business rules:
      - Both date AND time/slot must be specified by the customer.
      - Date must be in the future (at least tomorrow).
      - Service Center is open Monday through Saturday (closed on Sundays).
      - Working hours: 09:00 AM to 06:00 PM across active configured service time slots.
    Args:
        preferred_date: Optional date string (e.g. '2026-10-02', 'Tomorrow', 'next Monday').
        preferred_time: Optional time string or slot label (e.g. '10:00 AM', 'Slot 1', '02:00 PM - 04:00 PM').
        slot_id: Optional slot ID from active time slots (e.g. 1, 2, 6, 3, 4).
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

    parsed_date = _parse_date_string(date_str) if date_str else None

    if date_str:
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
    matched_slot = _resolve_slot(time_str, slot_id)

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

        if hour >= 0:
            if hour < 9 or hour > 18 or (hour == 18 and minute > 0):
                return json.dumps({
                    "valid": False,
                    "error": "outside_hours",
                    "message": f"The service time must be between 9:00 AM and 6:00 PM. Requested time '{time_str}' is outside working hours. Please explain that the service time must be between 9:00 AM and 6:00 PM and ask for another time."
                })

            formatted_time = f"{((hour - 1) % 12) + 1:02d}:{minute:02d} {'PM' if hour >= 12 else 'AM'}"
        elif matched_slot:
            formatted_time = matched_slot["label"]

        if matched_slot:
            ctx["slot_id"] = matched_slot["slot_id"]
            ctx["slot_label"] = matched_slot["label"]

        # Cache valid time into context
        if formatted_time:
            ctx["preferred_time"] = formatted_time
    elif slot_id is not None and matched_slot:
        formatted_time = matched_slot["label"]
        ctx["slot_id"] = matched_slot["slot_id"]
        ctx["slot_label"] = matched_slot["label"]
        ctx["preferred_time"] = formatted_time

    # Determine state of completion
    if parsed_date and formatted_time:
        res_slot_id = matched_slot["slot_id"] if matched_slot else slot_id
        res_slot_label = matched_slot["label"] if matched_slot else formatted_time
        return json.dumps({
            "valid": True,
            "date": parsed_date.strftime("%Y-%m-%d"),
            "date_display": parsed_date.strftime("%A, %B %d, %Y"),
            "time": formatted_time,
            "slot_id": res_slot_id,
            "slot_label": res_slot_label,
            "message": f"Service appointment confirmed for {parsed_date.strftime('%A, %B %d, %Y')} during {res_slot_label}."
        })
    elif parsed_date and not formatted_time:
        active_slots_list = _get_active_time_slots()
        slot_options = ", ".join(f"Slot {s['slot_id']} ({s['label']})" for s in active_slots_list) if active_slots_list else "contact support for slots"
        return json.dumps({
            "valid": False,
            "missing": "time",
            "date": parsed_date.strftime("%Y-%m-%d"),
            "date_display": parsed_date.strftime("%A, %B %d, %Y"),
            "message": f"Appointment date {parsed_date.strftime('%A, %B %d, %Y')} is noted, but preferred time was not provided. Please choose from our available slots: {slot_options}."
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
            "message": "Appointment date and time were not provided. Our service center is open Monday through Saturday with slots from 09:00 AM to 06:00 PM."
        })



@tool
def update_service_appointment(
    service_request_id_or_number: str,
    preferred_date: Optional[str] = None,
    preferred_time: Optional[str] = None,
    slot_id: Optional[int] = None
) -> str:
    """Updates the service appointment date and/or time slot of an existing Service Request.
    Use this tool whenever a customer asks to change the time, reschedule, or pick a different time for their Service Request.
    Do NOT call create_service_request when rescheduling!
    Args:
        service_request_id_or_number: The Service Request Number (e.g. 'SR-000105') or numeric ID (e.g. 15).
        preferred_date: New date if changed (e.g. '2026-09-29').
        preferred_time: New time slot (e.g. '02:00 PM', 'Slot 3', '02:00 PM - 04:00 PM').
        slot_id: Optional new slot ID from active slots (e.g. 1, 2, 6, 3, 4).
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

    parsed_new_d = _parse_date_string(preferred_date) or (datetime.now() + timedelta(days=2)).date()
    new_date = parsed_new_d.strftime("%Y-%m-%d")
    new_time = preferred_time.strip() if preferred_time and preferred_time.strip() else "10:00 AM"

    matched_slot = _resolve_slot(new_time, slot_id)
    res_slot_id = matched_slot["slot_id"] if matched_slot else slot_id
    res_slot_label = matched_slot["label"] if matched_slot else new_time

    return json.dumps({
        "success": True,
        "action": "update",
        "service_request_id": sr_id,
        "service_request_number": sr_num,
        "preferred_date": new_date,
        "preferred_time": new_time,
        "slot_id": res_slot_id,
        "slot_label": res_slot_label,
        "status": "BOOKED",
        "confirmation_message": f"Your appointment for Service Request {sr_num} has been successfully rescheduled to {new_date} at {new_time} ({res_slot_label}).",
        "message": f"Appointment for Service Request {sr_num} has been successfully updated to {new_date} at {new_time} ({res_slot_label})."
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
    preferred_date: Optional[str] = None,
    preferred_time: Optional[str] = None,
    slot_id: Optional[int] = None,
    priority: str = "Normal",
    order_id: Optional[int] = None,
    product_id: Optional[int] = None,
    product_name: Optional[str] = None,
    warranty_status: Optional[str] = None,
    warranty_expiry_date: Optional[str] = None
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
        preferred_date: Appointment date (e.g. '2026-10-02').
        preferred_time: Appointment time slot (e.g. '10:00 AM' or '09:00 AM - 11:00 AM').
        slot_id: Optional slot ID from active slots (e.g. 1, 2, 6, 3, 4).
        priority: Priority tag ('Normal', 'High', 'Urgent').
    Returns:
        JSON string confirming the candidate Service Request for ASP.NET Core authoritative persistence.
    """
    now = datetime.now(timezone.utc)
    sr_id = 108
    sr_number = "SR-000108"

    ctx = after_sales_context_var.get()
    existing_list = ctx.get("service_requests") if isinstance(ctx, dict) else None

    parsed_d = _parse_date_string(preferred_date) or _parse_date_string(ctx.get("preferred_date"))
    if not parsed_d:
        cand = (datetime.now() + timedelta(days=1)).date()
        if cand.weekday() == 6:
            cand = cand + timedelta(days=1)
        parsed_d = cand
    p_date = parsed_d.strftime("%Y-%m-%d")
    p_time = preferred_time or "10:00 AM"

    # Past date validation
    if parsed_d < datetime.now().date():
        return json.dumps({
            "success": False,
            "error": "past_date",
            "message": f"The selected date ({p_date}) has already passed. Please ask the customer for another date."
        })

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

    matched_slot = _resolve_slot(p_time, slot_id)
    res_slot_id = matched_slot["slot_id"] if matched_slot else (slot_id or 1)
    res_slot_label = matched_slot["label"] if matched_slot else p_time

    # Check for duplicate open request in context to avoid multiple pending requests
    if existing_list and isinstance(existing_list, list):
        for sr in existing_list:
            status = str(sr.get("status") or "").upper()
            cat = str(sr.get("problem_category") or sr.get("problemCategory") or "").strip()
            if (status == "BOOKED" or status == "PENDING") and (cat and cat.lower() == problem_category.lower()):
                cand_num = sr.get("service_request_number") or sr.get("serviceRequestNumber") or "SR-000108"
                cand_id = sr.get("service_request_id") or sr.get("serviceRequestId") or 108
                return json.dumps({
                    "success": True,
                    "action": "update",
                    "service_request_id": cand_id,
                    "service_request_number": cand_num,
                    "user_id": user_id,
                    "title": title or sr.get("title") or problem_description,
                    "description": description or sr.get("description") or problem_description,
                    "problem_description": problem_description,
                    "problem_category": problem_category,
                    "troubleshooting_summary": troubleshooting_summary,
                    "attempt_count": attempt_count,
                    "preferred_date": p_date,
                    "preferred_time": p_time,
                    "slot_id": res_slot_id,
                    "slot_label": res_slot_label,
                    "status": "BOOKED",
                    "priority": priority,
                    "confirmation_message": f"Your Service Request ({cand_num}) appointment has been updated to {p_date} at {p_time} ({res_slot_label}). Our technician will inspect your PC."
                })

    res_title = (title or "").strip() or (problem_description[:50] if len(problem_description) > 50 else problem_description)
    res_desc = (description or "").strip() or problem_description

    return json.dumps({
        "success": True,
        "action": "create",
        "service_request_id": sr_id,
        "service_request_number": sr_number,
        "user_id": user_id,
        "title": res_title,
        "description": res_desc,
        "problem_description": problem_description,
        "problem_category": problem_category,
        "troubleshooting_summary": troubleshooting_summary or f"AI Troubleshooting completed ({attempt_count} attempts).",
        "attempt_count": attempt_count,
        "preferred_date": p_date,
        "preferred_time": p_time,
        "slot_id": res_slot_id,
        "slot_label": res_slot_label,
        "status": "BOOKED",
        "priority": priority,
        "created_at": now.isoformat(),
        "confirmation_message": (
            f"Your Service Request has been created successfully.\n\n"
            f"Service Request ID: {sr_number}\n"
            f"Title: {res_title}\n"
            f"Description: {res_desc}\n"
            f"Preferred Date: {p_date}\n"
            f"Time Slot: {res_slot_label}\n"
            f"Status: BOOKED\n\n"
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
                    "title": sr.get("title") or "Service Request",
                    "description": sr.get("description") or "",
                    "problem_description": sr.get("problem_description") or sr.get("problemDescription") or "",
                    "problem_category": sr.get("problem_category") or sr.get("problemCategory") or "General",
                    "status": sr.get("status") or "BOOKED",
                    "priority": sr.get("priority") or "Normal",
                    "preferred_date": sr.get("preferred_date") or sr.get("preferredDate"),
                    "preferred_time": sr.get("preferred_time") or sr.get("preferredTime"),
                    "slot_id": sr.get("slot_id") or sr.get("slotId"),
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





# Master list of allow-listed tools exposed to the agent
AFTER_SALES_TOOLS = [
    search_troubleshooting_knowledge,
    get_customer,
    get_available_time_slots,
    validate_service_appointment,
    update_service_appointment,
    create_service_request,
    get_service_request,
    get_customer_service_requests,
]
