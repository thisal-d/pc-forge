# PCForge EmailJS Notification Templates & Integration Guide

This directory contains production-ready, responsive HTML email templates designed for PCForge customer notifications via EmailJS.

---

## 1. How Many Templates Should You Create in EmailJS?

You have **two architectural options** depending on your EmailJS plan and workflow preference:

### ⭐ Recommended Option: Master Templates (Fastest & Free-Tier Friendly)
EmailJS free accounts allow up to 2 active templates (or 3 on some accounts). Because the PCForge backend dynamically populates the `{{headline}}`, `{{status_badge}}`, `{{summary_text}}`, and context notes for every status transition, you only need **2 Master Templates** (or 3 if you have an allowance for a dedicated service request template):

| # | Master Template Name | Purpose | Target .env Variable | Source File in This Folder |
|---|----------------------|---------|----------------------|----------------------------|
| 1 | **PCForge Custom Builds** | Covers all custom build events (Submitted, In Review, Approved, Modifications Requested, Cancelled) + Service Requests fallback | `EMAILJS_PC_BUILD_REVIEW_TEMPLATE_ID` | `01_master_custom_builds_template.html` |
| 2 | **PCForge Orders & Fulfillment** | Covers all order events (Placed, Processing/Assembly, Ready for Pickup, Out for Delivery, Completed, Cancelled) | `EMAILJS_ORDER_STATUS_TEMPLATE_ID` | `02_master_order_status_template.html` |
| 3 | **PCForge Service Requests** *(Optional 3rd)* | Covers all after-sales service events (Received, In Progress, Completed, Rejected, Cancelled). Automatically falls back to Template #1 if omitted. | `EMAILJS_SERVICE_REQUEST_TEMPLATE_ID` | `03_master_service_requests_template.html` |

> [!TIP]
> If your EmailJS free tier allows a maximum of 2 templates, simply create Templates #1 and #2. The backend is designed to route after-sales service notifications through Template #1 with zero errors.

---

### Alternative Option: Create 16 Granular Event Templates
If you prefer dedicated, static templates in EmailJS for every granular event, the backend supports individual template overrides:

#### Custom Build Events:
- `EMAILJS_BUILD_SUBMITTED_TEMPLATE_ID` — Build configuration submitted
- `EMAILJS_BUILD_IN_REVIEW_TEMPLATE_ID` — Technician review started
- `EMAILJS_BUILD_APPROVED_TEMPLATE_ID` — Build approved & cleared for assembly
- `EMAILJS_BUILD_CHANGES_REQUESTED_TEMPLATE_ID` — Build rejected / changes requested
- `EMAILJS_BUILD_CANCELLED_TEMPLATE_ID` — Build request cancelled

#### Order Fulfillment Events:
- `EMAILJS_ORDER_PLACED_TEMPLATE_ID` — Order confirmed & placed
- `EMAILJS_ORDER_PROCESSING_TEMPLATE_ID` — PC assembly & staging started
- `EMAILJS_ORDER_READY_PICKUP_TEMPLATE_ID` — Ready for pickup (with verified pickup details)
- `EMAILJS_ORDER_OUT_FOR_DELIVERY_TEMPLATE_ID` — Courier dispatched / out for delivery
- `EMAILJS_ORDER_COMPLETED_TEMPLATE_ID` — Order paid & completed
- `EMAILJS_ORDER_CANCELLED_TEMPLATE_ID` — Order cancelled

#### After-Sales Service Request Events:
- `EMAILJS_SERVICE_RECEIVED_TEMPLATE_ID` — Service request ticket received
- `EMAILJS_SERVICE_IN_PROGRESS_TEMPLATE_ID` — Technician assigned & in progress
- `EMAILJS_SERVICE_COMPLETED_TEMPLATE_ID` — Hardware repaired / completed
- `EMAILJS_SERVICE_REJECTED_TEMPLATE_ID` — Service request rejected
- `EMAILJS_SERVICE_CANCELLED_TEMPLATE_ID` — Service appointment cancelled

---

## 2. Updated `backend/.env` Configuration

Your `backend/.env` has been updated. The previous variable `EMAILJS_TEMPLATE_ID` has been renamed to `EMAILJS_PC_BUILD_REVIEW_TEMPLATE_ID`:

```env
# ==============================================================================
# Email Notification Service (EmailJS REST API)
# ==============================================================================
EMAILJS_SERVICE_ID=service_nedjkjj
EMAILJS_PUBLIC_KEY=7obE5oGCUOnm9zKwx
EMAILJS_PRIVATE_KEY=your_optional_emailjs_private_key

# Master Workflow Template IDs
EMAILJS_PC_BUILD_REVIEW_TEMPLATE_ID=template_j4yxcad
EMAILJS_ORDER_STATUS_TEMPLATE_ID=template_order_status
EMAILJS_SERVICE_REQUEST_TEMPLATE_ID=template_service_request

# Legacy Fallback (Preserves backwards compatibility)
EMAILJS_TEMPLATE_ID=template_j4yxcad
```

---

## 3. Verified Store Pickup Details

When an order moves to **"Ready for pickup"**, the backend automatically injects the verified physical pickup coordinates:

- **Pickup Store:** `PCForge Store & Technical Support Hub`
- **Address:** `100 Innovation Drive, Colombo 03, Sri Lanka`
- **Hours:** `Monday – Saturday: 09:00 AM – 06:00 PM (Closed Sundays & Public Holidays)`
- **Instructions:** `Please present your Order ID (#{{order_id}}) and a valid government photo ID (NIC / Driving License / Passport) at the support counter.`

---

## 4. Template Variable Reference

All templates utilize the following parameters sent by the backend:

### Common Parameters
- `{{to_name}}` & `{{customer_name}}`: Customer full name
- `{{to_email}}` & `{{customer_email}}`: Customer email address
- `{{subject}}`: Event-specific email subject line
- `{{headline}}`: Visual header text
- `{{status_badge}}`: Colored pill badge text (e.g. `APPROVED`, `PROCESSING`, `READY FOR PICKUP`)
- `{{summary_text}}`: Explanatory paragraph tailored to the event
- `{{action_url}}`: Link to order/build/service page in customer portal
- `{{action_label}}`: CTA button text (e.g. `Track Order Details`, `View Custom Build`)
- `{{logo_url}}`: `https://pc-forge-admin.pages.dev/logo.png`
- `{{support_email}}`: `support@pcforge.com`
- `{{current_year}}`: Current year (e.g. `2026`)

### Custom Build Parameters
- `{{build_id}}`: Numeric build ID
- `{{build_name}}`: Custom build title / configuration name
- `{{status}}`: Build status string
- `{{technician_notes}}`: Staff inspection findings and clearance notes
- `{{total_price}}`: Formatted currency total (`LKR ...`)

### Order Parameters
- `{{order_id}}`: Numeric order ID
- `{{status}}`: Fulfillment status string
- `{{payment_method}}`: `Cash on Delivery` or `Store Pickup`
- `{{shipping_address}}`: Delivery street address or store hub
- `{{total_amount}}`: Formatted order total (`LKR ...`)
- `{{item_count}}`: Total hardware units in order
- `{{pickup_store_name}}`, `{{pickup_address}}`, `{{pickup_hours}}`, `{{pickup_instructions}}`

### Service Request Parameters
- `{{service_request_number}}`: Service ticket number (e.g. `SR-1001`)
- `{{title}}`: Hardware fault or maintenance topic
- `{{appointment_date}}`: Formatted appointment date (e.g. `Wednesday, October 21, 2026`)
- `{{appointment_time}}`: Time slot window (e.g. `09:00 AM - 11:00 AM`)
- `{{service_notes}}`: Technician instructions and diagnostic updates

---

## 5. How to Deploy to EmailJS Dashboard

1. Log into your [EmailJS Dashboard](https://dashboard.emailjs.com/admin/templates).
2. Go to **Email Templates** &rarr; click **Create New Template**.
3. Open the relevant file from this directory:
   - For PC Builds: copy all HTML from `01_master_custom_builds_template.html`.
   - For Orders: copy all HTML from `02_master_order_status_template.html`.
   - For Service Requests: copy all HTML from `03_master_service_requests_template.html`.
4. In the EmailJS template editor:
   - Click the **Source Code** (`<>`) icon.
   - Paste the copied HTML and click **OK**.
   - Set the **Subject** field to `{{subject}}`.
   - Set the **To Email** field to `{{to_email}}`.
   - Set the **From Name** to `PCForge Notifications`.
5. Click **Save** and copy the generated **Template ID** (e.g., `template_abc123`).
6. Paste the Template ID into your `backend/.env` file under the corresponding variable name.
