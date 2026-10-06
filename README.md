<p align="center">
  <img src="logo.png" alt="PCForge Logo" width="160" />
</p>

# PCForge — Computer Shop & Custom PC Builder Platform

[![CI](https://github.com/thisal-d/pc-forge/actions/workflows/ci.yml/badge.svg)](https://github.com/thisal-d/pc-forge/actions/workflows/ci.yml)

A full-stack, cross-platform e-commerce and custom PC building ecosystem engineered for **SE3090 — Software Engineering Frameworks (2026)**.

Modeled on the Sri Lankan enthusiast computer retail industry (Nanotek, Redline Technologies): customers design custom PCs via the Flutter mobile app, autonomous LangGraph AI agents check hardware tolerances and reserve parts, store technicians stage builds in workshop assembly bays via the React portal, and customers inspect benchmark stress tests and pay upon in-store collection.

| Component | Technology | Live URL / Deployment Target |
|---|---|---|
| ASP.NET Core Web API | .NET 8, EF Core, PostgreSQL | `https://pc-forge.onrender.com` |
| Swagger / OpenAPI | Swashbuckle | `https://pc-forge.onrender.com/swagger` |
| Health Check | ASP.NET Core health endpoint | `https://pc-forge.onrender.com/health` |
| React Web Portal | Vite + React 19 | `https://pc-forge-admin.pages.dev` |
| Flutter Mobile App | Flutter 3.x (Material 3) | Release APK — see §Flutter APK below |
| PostgreSQL Database | Neon Serverless Postgres (16 tables) | Managed — connection string via `DATABASE_URL` |
| Python AI Microservice | FastAPI + LangGraph + Gemini 2.5 Flash | Local `:5050` / internal worker |
| Git Push & File Tracker | Markdown Audit Manifest | [`contributions.md`](contributions.md) |

> ⚠️ **Render free-tier cold-start:** If the API has not received traffic in 15 minutes, Render will sleep the container. Visit `https://pc-forge.onrender.com/health` first and wait ~30 s for it to wake up before beginning the demonstration.

---

## 5-Member Team Architecture & Component Ownership

As approved under **SE3090 Specification Section 3 & Section 4.1**, the 5-member team architecture partitions the platform into **5 distinct business components and 5 specialized LangGraph AI agents**. Each member owns a complete vertical slice across Backend API, PostgreSQL database, React web portal, Flutter mobile app, automated tests, and AI orchestration.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              PCFORGE 5-MEMBER VERTICAL SLICES                          │
├──────────┬──────────────────────────────────────────┬──────────────────────────────────┤
│ Member   │ Primary Business Component Slice         │ Specialized LangGraph Agent      │
├──────────┼──────────────────────────────────────────┼──────────────────────────────────┤
│ Member 01│ User Auth, Profile Reactivity & Staff    │ 🤖 Requirement Discovery Agent   │
│ Member 02│ Product Catalog, Nanotek Filters & Stock │ 🤖 Inventory Stock Agent         │
│ Member 03│ Custom PC Builder & Tolerance Reviews    │ 🤖 PC Build & Compatibility Agent│
│ Member 04│ Cart, Orders, Coupons & Fulfillment      │ 🤖 Order Planning & Pricing Agent│
│ Member 05│ Support Tickets, RMA Claims & Warranty   │ 🤖 After-Sales Service Agent     │
└──────────┴──────────────────────────────────────────┴──────────────────────────────────┘
```

### Detailed Member Breakdown

#### 🧑 Member 01: User Auth, Profile Reactivity & Requirement Discovery Agent
- **Backend API:** `AuthController.cs` (`POST /register`, `POST /login`, `GET /me`, `PUT /profile`), `StaffController.cs` (Admin CRUD, password reset, status toggle), `RequirementSessions` state tracking.
- **Database:** `Users`, `Roles`, `Staff`, `RequirementSessions`.
- **React Web:** Staff Management workbench (`/staff` data table, telemetry, add/edit modal, reset password).
- **Flutter App:** Login, Register, Profile view/edit modal with instant reactive updates via `AuthSession` (`ChangeNotifier`), and Conversational AI Requirement Chat screen.
- **Agentic AI:** **Requirement Discovery Agent** (`ai_service/agents/requirement_agent/`) — LangGraph multi-turn conversational agent extracting budget, use-case, and target resolution without hardware leakage.
- **Tests:** 10 Pytest agent evaluation tests, xUnit security tests, Flutter auth tests.

#### 🧩 Member 02: Product Catalog, Nanotek Filters & Inventory Stock Agent
- **Backend API:** `ProductsController.cs` (search, faceted filter, CRUD, quick stock updates `PATCH /stock`), `CategoriesController.cs` (categories and dynamic facets).
- **Database:** `Categories`, `Products`, `CategoryFilters`, `FilterOptions`, `ProductFilterValues`, views `v_category_filters` and `v_product_details`.
- **React Web:** Live Inventory workbench (`/inventory` with inline ±1 steppers and audit adjustment modal), Products catalog CRUD (`/products`), and Categories & dynamic facet filters (`/categories`).
- **Flutter App:** Product catalog 2-column grid, Nanotek dynamic faceted filter bottom sheet, instant debounced search, product specifications view, and **In-Store Barcode Scanner** (Device Feature).
- **Agentic AI:** **Inventory Stock Agent** (`ai_service/agents/inventory_agent/`) — LangGraph state machine querying live shelf stock, suggesting compatible in-stock alternatives, and creating 15-minute temporary reservation holds.
- **Tests:** 6 Pytest inventory evaluation tests, Flutter scanner and catalog widget tests.

#### 🖥️ Member 03: Custom PC Builder, Hardware Compatibility & Clearance Review
- **Backend API:** `CustomBuildsController.cs` (build submission, tolerance inspection, review queue, status transitions `PATCH /review`), `POST /api/aibuilds/generate-build`.
- **Database:** `CustomBuilds`, `CustomBuildItems`.
- **React Web:** Build Reviews workbench (`/build-reviews` queue with KPI statistics, search, filter, and detailed inspection modal with **Automated Compatibility Diagnostics**: CPU socket match, RAM DDR match, and PSU transient headroom meter).
- **Flutter App:** Build PC Hub (toggling Auto AI vs Manual Mode), 8-slot Manual PC Builder with live wattage summation and socket/DDR mismatch warnings, Build Status tracker with 1-tap **"Modify & Resubmit"**.
- **Agentic AI:** **PC Build & Compatibility Agent** (`ai_service/agents/build_agent/`) — LangGraph state machine enforcing deterministic hardware rules (Socket AM5/LGA1700, DDR4/DDR5, PSU Wattage headroom $+150\text{W}$, case form factor) with auto-substitution loop.
- **Tests:** 12 Pytest build agent evaluation tests, xUnit AI build integration tests, Flutter build widget tests.

#### 🛒 Member 04: Cart, Orders, Coupons & Checkout Fulfillment
- **Backend API:** `OrdersController.cs` (transactional order placement, order history, fulfillment `PATCH /status` with **automatic inventory restocking on cancellation**), `CouponsController.cs` (discount rules, percentage/fixed caps).
- **Database:** `Orders`, `OrderItems`, `Coupons`, `Carts`, `CartItems`.
- **React Web:** Order Fulfillment workbench (`/orders` status tabs, customer search, BOM inspection, status update) and Coupon Management workbench (`/coupons`).
- **Flutter App:** Reactive shopping cart, checkout screen with promo code validation and delivery address, order history with status pills, and itemized receipt screen.
- **Agentic AI:** **Order Planning Agent** (`ai_service/agents/order_planning_agent/`) — LangGraph state machine computing bundle pricing in LKR, coupon discount validation, delivery fees, and draft proposals held for customer approval.
- **Tests:** 7 Pytest order planning evaluation tests, Flutter checkout and order placement tests.

#### 🛠️ Member 05: Customer Support, Warranty Claims, RMA & After-Sales Agent
- **Backend API:** `SupportTicketsController.cs` (ticket creation, customer history, technician resolution), `ServiceRequestsController.cs` (warranty verification, appointment scheduling), `UploadController.cs` (Cloudinary CDN image upload).
- **Database:** `SupportTickets`, `ServiceRequests`.
- **React Web:** Support & RMA workbench (`/support` ticket queue, photo proof inspector, warranty badge, timeline messaging, and RMA resolution) and Service Requests workbench (`/service-requests`).
- **Flutter App:** Support dashboard, ticket submission with **Camera / Photo proof attachment** (Device Feature), and Conversational AI After-Sales Support Chat screen.
- **Agentic AI:** **After-Sales Service Agent** (`ai_service/agents/after_sales_agent/`) — LangGraph troubleshooting decision tree, warranty lookup, and automated RMA ticket drafting.
- **Tests:** 6 Pytest after-sales evaluation tests, Flutter support widget tests.

---

## Default Login Credentials

| Role | Email | Password | Primary Client Application |
|---|---|---|---|
| **Admin** | `admin@pcforge.com` | `Admin123!` | React Web Portal (`/staff`, full platform) |
| **Staff** | `staff@pcforge.com` | `Staff123!` | React Web Portal (Orders, Inventory, Reviews, Support) |
| **Customer** | `customer@pcforge.com` | `Cust123!` | Flutter Mobile App |

> **Role Hierarchy & Access Control:** **Admin** $\supset$ **Staff** $\supset$ **Customer**. Staff has full operational access across store fulfillment. Admin has root authority and exclusively manages staff onboarding.
>
> 🇱🇰 **Currency Standard:** All pricing, subtotals, custom build estimates, and receipts strictly operate in Sri Lankan Rupees (**LKR**).

---

## Architecture Overview

```text
┌─────────────────────────┐         ┌─────────────────────────┐
│     React Web Portal    │         │    Flutter Mobile App   │
│   (Store Staff & Admin) │         │    (Customer Client)    │
└────────────┬────────────┘         └────────────┬────────────┘
             │  JWT Bearer REST /api             │  JWT Bearer REST /api
             ▼                                   ▼
┌─────────────────────────────────────────────────────────────┐
│                 ASP.NET Core Web API (:5000)                │
│    Controllers ──► Services ──► EF Core ──► PostgreSQL      │
│    AiAgentService.cs ────► (Internal gateway bridge)        │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTP (:5050) Internal only
                               ▼
                ┌──────────────────────────────┐
                │    Python AI Microservice    │
                │     FastAPI + LangGraph      │
                │    Google Gemini 2.5 Flash   │
                │     5 Specialized Agents     │
                │    Allow-listed Tools        │
                └──────────────────────────────┘
```

**Mandatory Architecture Rule (§2):** React and Flutter communicate **only** with the ASP.NET Core Web API. The Python AI service is an internal service called exclusively by `AiAgentService.cs` and is never exposed directly to clients.

See [`docs/ADR.md`](docs/ADR.md) for all 6 Architecture Decision Records.

---

## Database ER Diagram

```
Roles ──< Users ──< Staff
                │
                ├──< Orders ──< OrderItems ──> Products
                ├──< Carts  ──< CartItems  ──> Products
                ├──< SupportTickets
                └──< ServiceRequests

Categories ──< CategoryFilters ──< FilterOptions
           ──< Products ──< ProductFilterValues ──> FilterOptions
                       ──< CustomBuildItems ──> CustomBuilds ──> Users
```

**Tables (16 total):** `Roles`, `Users`, `Staff`, `Categories`, `Products`, `CategoryFilters`, `FilterOptions`, `ProductFilterValues`, `Carts`, `CartItems`, `Orders`, `OrderItems`, `ServiceRequests`, `SupportTickets`, `CustomBuilds`, `CustomBuildItems`.

Full SQL Schema: [`db/schema.sql`](db/schema.sql) | Seed Data: [`db/seed.sql`](db/seed.sql)

---

## Project Structure & File Layout

```text
pc-forge/
├── contributions.md           # 5-member file breakdown & Git push tracker (§3, §13)
├── runner.py                  # One-command runner for all 4 system tiers
├── .github/workflows/ci.yml   # GitHub Actions CI (Backend, AI, React, Flutter)
├── docs/
│   ├── ADR.md                 # 6 Architecture Decision Records (§14.2)
│   ├── CONSOLIDATED_REPORT.md # Comprehensive 15-section project report (§15)
│   └── performance/
│       └── locustfile.py      # Locust performance & load test script (§12)
├── db/
│   ├── schema.sql             # 16 relational tables, views, constraints
│   └── seed.sql               # Hardware catalog, demo users, orders
├── backend/                   # ASP.NET Core .NET 8 Web API
│   ├── Controllers/           # Auth, Products, Categories, Orders, CustomBuilds,
│   │                          #   SupportTickets, AiBuilds, ServiceRequests, Coupons, Staff, Upload
│   ├── Services/              # AiAgentService, AuthService, CloudinaryImageUploadService
│   ├── Data/                  # AppDbContext, DbInitializer
│   ├── Models/                # 14 Entity Framework Core domain models
│   └── DTOs/                  # Strongly typed request/response contracts
├── backend.Tests/             # xUnit integration tests (InMemory EF Core)
│   ├── AiBuildsControllerTests.cs
│   └── SecurityTests.cs
├── ai_service/                # Python FastAPI Agentic AI Microservice (:5050)
│   ├── agents/
│   │   ├── requirement_agent/ # Member 01 — Conversational requirement gathering
│   │   ├── inventory_agent/   # Member 02 — Stock verification & 15-min hold
│   │   ├── build_agent/       # Member 03 — LangGraph PC build & compatibility
│   │   ├── order_planning_agent/ # Member 04 — Bundle pricing, coupons, shipping
│   │   └── after_sales_agent/ # Member 05 — Troubleshooting & RMA scheduling
│   └── tests/                 # Pytest agent evaluation tests (6 files)
├── app/                       # Flutter 3.x Customer Mobile App
│   ├── lib/core/              # Routes, theme, widgets, auth session
│   ├── lib/features/          # auth, catalog, cart, checkout, orders, support, build_pc, scanner
│   └── test/                  # 9 test files, 49 automated tests
└── web/                       # React 19 + Vite Staff & Admin Portal
    ├── src/pages/             # Staff, Inventory, BuildReviews, Orders, Support, Products, Categories
    ├── src/components/        # Modular workbench tables, modals, diagnostics
    ├── src/context/           # AuthContext (React Context API)
    ├── src/services/          # REST service layer (Axios)
    └── src/__tests__/         # Vitest unit tests (services.test.js)
```

---

## Quick-Start Guide

### ⚡ One-Command Runner (All 4 Tiers)

```powershell
python runner.py
```

Simultaneously boots the ASP.NET Core Backend (:5000), Python AI Service (:5050), React Web Portal (:5173), and Flutter Mobile App.

**Hotkeys:** `r` Hot Reload · `R` Hot Restart · `b` Restart Backend · `w` Restart Web · `q` Quit

---

### Step-by-Step Manual Setup

#### 1. Environment Configuration

Copy `.env.example` to `.env` in the root directory:

```env
# Google Gemini API Keys (automatic fallback rotation)
GOOGLE_API_KEY_1=your_gemini_api_key_1
GOOGLE_API_KEY_2=your_gemini_api_key_2
GOOGLE_API_KEY=your_gemini_api_key_1

DATABASE_URL=postgresql://user:password@host/pcforge_db
JWT_SECRET=your_super_secret_jwt_key_at_least_32_characters_long
CLOUDINARY_URL=cloudinary://api_key:api_secret@cloud_name
```

#### 2. Database Setup (PostgreSQL)

```powershell
python update-db.py --seed          # Apply schema + seed data
python update-db.py --status        # Verify 16 tables
```

#### 3. ASP.NET Core Web API (.NET 8)

```powershell
cd backend
dotnet restore
dotnet run
# Swagger UI: http://localhost:5000/swagger
# Health Check: http://localhost:5000/health
```

#### 4. Python Agentic AI Microservice

```powershell
cd ai_service
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 5050 --reload
# Interactive Docs: http://localhost:5050/docs
```

#### 5. React Web Portal (Vite + React 19)

```powershell
cd web
npm install
npm run dev
# Portal: http://localhost:5173
```

#### 6. Flutter Customer Mobile App

```powershell
cd app
flutter pub get
flutter run
```

For Android physical devices connected via USB:
```powershell
adb reverse tcp:5000 tcp:5000
flutter run
```

---

## Flutter Android Release APK

Generate the production Android APK:
```powershell
cd app
flutter build apk --release
# Output binary: app/build/app/outputs/flutter-apk/app-release.apk
```

Install directly onto a connected physical Android device:
```powershell
adb install app/build/app/outputs/flutter-apk/app-release.apk
```

---

## Automated Testing Suite (139 Tests, 100% Passing)

```powershell
# 1. Backend Integration Tests (28 tests)
cd backend.Tests
dotnet test --verbosity normal

# 2. React Web Tests (17 tests)
cd web
npm test

# 3. Flutter Mobile Tests (49 tests)
cd app
flutter test
flutter analyze

# 4. Python Agent Evaluation Tests (45 tests)
cd ai_service
pytest tests/ -v --tb=short
```

| Subsystem | Framework / Tool | Test Files | Tests Passing | Focus Area |
|---|---|:---:|:---:|---|
| **Backend API** | xUnit + InMemory EF Core | 2 | **28** | Security, JWT claims, custom builds review, AI bridge |
| **React Web** | Vitest + jsdom | 1 | **17** | Auth, REST services, protected routing, workbenches |
| **Flutter Mobile** | Flutter Test (Unit & Widget) | 9 | **49** | Reactive state, cart, checkout, scanner, custom builder |
| **Agentic AI** | Pytest (LangGraph Golden Cases) | 6 | **45** | Deterministic formulas, tools, memory, prompt injection |
| **TOTAL** | **Enterprise Test Automation** | **18** | **139 / 139** | **100% Pass Rate** |

### Performance Testing (Locust)

```powershell
pip install locust
locust -f docs/performance/locustfile.py --host=http://localhost:5000
```
Measures concurrent virtual users, response latency, database response, and AI latency (§12).

---

## CI/CD Pipeline

The GitHub Actions CI workflow ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) triggers on every push and pull request to `main`:

| Job Name | Environment | Key Pipeline Steps |
|---|---|---|
| **backend** | `ubuntu-latest` (.NET 8) | `dotnet restore` $\rightarrow$ `dotnet build` $\rightarrow$ `dotnet test` |
| **ai-service**| `ubuntu-latest` (Python 3.11) | `pip install` $\rightarrow$ `py_compile` $\rightarrow$ `pytest tests/` |
| **react** | `ubuntu-latest` (Node 20) | `npm ci` $\rightarrow$ `npm run build` $\rightarrow$ `npm test` |
| **flutter** | `ubuntu-latest` (Flutter 3.x) | `flutter pub get` $\rightarrow$ `flutter analyze` $\rightarrow$ `flutter test` |

---

## Architecture Decision Records (ADRs)

Detailed architectural justifications located in [`docs/ADR.md`](docs/ADR.md):
- **ADR-001:** React State Management (React Context API)
- **ADR-002:** Flutter State Management (Provider + ChangeNotifier)
- **ADR-003:** Agentic AI Framework (LangGraph + Google Gemini)
- **ADR-004:** Database Schema Strategy for AI Workflow State
- **ADR-005:** Deployment Strategy (Render + Neon)
- **ADR-006:** Python AI Boundary (Stateless Internal Microservice)

---

## Security & Academic Integrity Compliance

- **Role-Based Authorization:** Strict token claims with `ClockSkew = Zero` preventing token replay attacks.
- **Data Protection:** BCrypt hashing (12 work rounds) for all user credentials.
- **Zero Hallucination Writes:** Python agents never write directly to PostgreSQL; mutations must pass through ASP.NET Core validation and human-in-the-loop review.
- **Level 1 Viva Readiness:** AI assistance was used exclusively during development under Level 4 guidelines with full disclosure in [`docs/CONSOLIDATED_REPORT.md`](docs/CONSOLIDATED_REPORT.md). No external AI tools will be used during the demonstration or viva.
- **Git File Tracking:** See [`contributions.md`](contributions.md) for individual file ownership and Git push progress.
