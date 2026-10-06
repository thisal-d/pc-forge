<p align="center">
  <img src="logo.png" alt="PCForge Logo" width="160" />
</p>

# PCForge — Computer Shop & Custom PC Builder Platform

[![CI Pipeline](https://github.com/thisal-d/pc-forge/actions/workflows/ci.yml/badge.svg)](https://github.com/thisal-d/pc-forge/actions/workflows/ci.yml)
[![.NET 8](https://img.shields.io/badge/.NET-8.0-512BD4?logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/)
[![React 19](https://img.shields.io/badge/React-19.0-61DAFB?logo=react&logoColor=black)](https://react.dev/)
[![Flutter 3](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![LangGraph](https://img.shields.io/badge/LangGraph-Agentic%20AI-FF6F00?logo=langchain&logoColor=white)](https://langchain.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Neon%20Serverless-4169E1?logo=postgresql&logoColor=white)](https://neon.tech/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A full-stack, cross-platform e-commerce and custom PC building ecosystem modeled on the enthusiast computer retail industry. Customers design custom rigs with real-time hardware compatibility validation, autonomous LangGraph AI agents recommend specifications and reserve inventory, store technicians review builds in dedicated assembly workbenches, and after-sales service workflows provide seamless RMA and appointment scheduling.

---

## Live Deployments & Endpoints

| Tier / Component | Technology | Live URL / Deployment Target |
|---|---|---|
| **ASP.NET Core Web API** | .NET 8, EF Core, PostgreSQL | [`https://pc-forge.onrender.com`](https://pc-forge.onrender.com) |
| **Interactive API Documentation** | Swagger / OpenAPI (Swashbuckle) | [`https://pc-forge.onrender.com/swagger`](https://pc-forge.onrender.com/swagger) |
| **System Health Check** | ASP.NET Core Health Endpoint | [`https://pc-forge.onrender.com/health`](https://pc-forge.onrender.com/health) |
| **React Web Admin Portal** | Vite + React 19 + Tailwind/CSS | [`https://pc-forge-admin.pages.dev`](https://pc-forge-admin.pages.dev) |
| **Flutter Mobile Client** | Flutter 3.x (Material 3) | Release APK — see [Android Release APK](#flutter-android-release-apk) |
| **Relational Database** | Neon Serverless PostgreSQL | Managed Cloud PostgreSQL (15 relational tables) |
| **Python AI Microservice** | FastAPI + LangGraph + Google Gemini | Internal microservice gateway (`:5050`) |

> ⚠️ **Render Free-Tier Notice:** If the Web API container has been idle for 15 minutes, Render puts it into sleep mode. If visiting for the first time, allow ~30 seconds for the container to complete cold start by opening the [Health Endpoint](https://pc-forge.onrender.com/health).

---

## Platform Highlights & Core Capabilities

- **Interactive Custom PC Builder**: Live wattage summation, CPU-motherboard socket matching (AM5, AM4, LGA1700), RAM DDR generation verification, form factor clearance checks, and one-tap checkout with automatic component reservation.
- **Autonomous Multi-Agent AI (LangGraph)**: 5 specialized agents orchestrating customer requirement extraction, live stock lookups with alternative substitutions, deterministic hardware clearance, pricing proposals in LKR, and after-sales service appointment scheduling.
- **Multi-Key LLM Cascading Failover**: Enterprise key rotation mechanism supporting up to 6 Gemini API keys with automatic exponential backoff, health tracking, and zero downtime during quota exhaustion.
- **Store Operations & Staff Workbenches**: Dedicated React web portal for store managers and technicians, featuring real-time KPI metrics, custom build review queues with automated compatibility meters, inventory adjusters, order fulfillment tabs, and service request intake.
- **Reactive Mobile Client (Flutter)**: Material 3 mobile application featuring reactive state management (`Provider` + `ChangeNotifier`), faceted catalog search, hardware camera scanner, and customer appointment management.
- **Zero-Hallucination Database Isolation**: AI microservice operates statelessly; all database persistence and stock updates are authoritatively validated and committed exclusively through the ASP.NET Core backend.

---

## Autonomous AI Agent Ecosystem (LangGraph)

The platform integrates **5 specialized LangGraph AI agents**, each designed for a specific stage of the custom PC purchasing and support journey:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              PCFORGE MULTI-AGENT ARCHITECTURE                          │
├────────────────────────┬──────────────────────────────────┬────────────────────────────┤
│ Agent Name             │ Primary Domain / Responsibility  │ Key Tools & Safeguards     │
├────────────────────────┼──────────────────────────────────┼────────────────────────────┤
│ 🤖 Requirement Agent   │ Conversational Budget & Use-case │ RAG profile, no part leak  │
│ 🤖 Inventory Agent     │ Stock Verification & Holds       │ Live stock check, 15m hold │
│ 🤖 PC Build Agent      │ Compatibility & Tolerance Rules  │ Socket, DDR, PSU +150W     │
│ 🤖 Order Planning Agent│ LKR Pricing, Bundles & Coupons   │ Promo codes, delivery fee  │
│ 🤖 After-Sales Agent   │ Troubleshooting & RMA Scheduling │ Date capacity, RMA ticket  │
└────────────────────────┴──────────────────────────────────┴────────────────────────────┘
```

### 1. 🤖 Requirement Discovery Agent
* **Domain:** Multi-turn customer onboarding (`ai_service/agents/requirement_agent/`).
* **Functionality:** Extracts customer use-case (1440p gaming, 3D rendering, machine learning), budget constraints in LKR, and performance priorities without prematurely hallucinating component models.

### 2. 🤖 Inventory Stock Agent
* **Domain:** Shelf availability and reservation (`ai_service/agents/inventory_agent/`).
* **Functionality:** Queries live component inventory, recommends pin-compatible alternatives when parts are out of stock, and establishes temporary 15-minute reservation holds to prevent inventory race conditions.

### 3. 🤖 PC Build & Compatibility Agent
* **Domain:** Deterministic hardware compatibility validation (`ai_service/agents/build_agent/`).
* **Functionality:** Enforces strict hardware constraints:
  - CPU & Motherboard socket pairing (AM5, LGA1700, AM4).
  - Memory generation compatibility (DDR4 vs DDR5 DIMM).
  - Power supply headroom validation (System Total TDP $+ 150\text{W}$ minimum transient buffer).
  - Case clearance and motherboard form-factor compatibility (E-ATX, ATX, Micro-ATX, Mini-ITX).

### 4. 🤖 Order Planning & Pricing Agent
* **Domain:** Checkout planning and promotions (`ai_service/agents/order_planning_agent/`).
* **Functionality:** Calculates itemized bills in Sri Lankan Rupees (LKR), validates coupon codes with minimum order constraints, computes island-wide delivery tiers, and generates draft order proposals.

### 5. 🤖 After-Sales Service Agent
* **Domain:** Troubleshooting and service intake (`ai_service/agents/after_sales_agent/`).
* **Functionality:** Guides customers through safe hardware troubleshooting trees (power cables, PSU switches, display outputs), checks warranty periods based on purchase dates, and schedules in-store technician appointments (enforcing a daily maximum capacity of 10 appointments).

---

## System Architecture

```
┌────────────────────────────────────────────────┐     ┌────────────────────────────────────────────────┐
│             React Web Admin Portal             │     │               Flutter Mobile App               │
│            (Store Staff & Technicians)         │     │               (Customer Client)                │
└───────────────────────┬────────────────────────┘     └───────────────────────┬────────────────────────┘
                        │  HTTPS / JWT Bearer Tokens                           │  HTTPS / JWT Bearer Tokens
                        ▼                                                      ▼
┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                     ASP.NET Core 8 Web API (:5000)                                    │
│             Controllers  ──►  Services Layer  ──►  Entity Framework Core  ──►  PostgreSQL             │
│             AiAgentService.cs  ──►  Internal HTTP Gateway Bridge (:5050)                             │
└───────────────────────────────────────────────────┬───────────────────────────────────────────────────┘
                                                    │ Internal HTTP JSON RPC
                                                    ▼
                             ┌─────────────────────────────────────────────┐
                             │       Python AI Microservice (:5050)        │
                             │       FastAPI + LangGraph StateGraph        │
                             │   Google Gemini with Multi-Key Failover     │
                             │      5 Domain-Specific Tool Toolkits        │
                             └─────────────────────────────────────────────┘
```

### Architectural Principles
1. **Single Entry Gateway**: React and Flutter clients communicate exclusively with the ASP.NET Core Web API.
2. **Stateless AI Boundary**: The Python AI microservice is an internal service invoked exclusively by `AiAgentService.cs` and is never exposed directly to external networks.
3. **Database Consistency**: All write operations against PostgreSQL are transactional and managed by Entity Framework Core with row-level locking during inventory reservations.

For full architectural decision records, see [`docs/ADR.md`](docs/ADR.md).

---

## Default Demo Credentials

| Role | Email Address | Password | Intended Client Interface |
|---|---|---|---|
| **Admin** | `admin@pcforge.com` | `Admin123!` | React Web Portal (`/staff`, full administrative control) |
| **Staff / Technician** | `staff@pcforge.com` | `Staff123!` | React Web Portal (Orders, Inventory, Build Reviews, Support) |
| **Customer** | `customer@pcforge.com` | `Cust123!` | Flutter Mobile Application |

> **Role Hierarchy:** **Admin** $\supset$ **Staff** $\supset$ **Customer**.
> 
> 🇱🇰 **Currency Standard:** All pricing, subtotals, build estimates, and receipts strictly operate in Sri Lankan Rupees (**LKR**).

---

## Technology Stack

| Layer | Technologies & Frameworks |
|---|---|
| **Backend API** | ASP.NET Core (.NET 8), Entity Framework Core 8, Npgsql, Swashbuckle OpenAPI, BCrypt.Net |
| **Database** | Neon Serverless PostgreSQL, 15 normalized relational tables, SQL indexes, foreign key cascades |
| **AI Microservice** | Python 3.11, FastAPI, LangGraph, LangChain, Google Generative AI (Gemini 2.5 / 3.8 Flash), Uvicorn |
| **Web Portal** | React 19, Vite, React Router 7, Axios, Lucide Icons, Vanilla CSS Design System |
| **Mobile App** | Flutter 3.x, Dart 3.10+, Provider & ChangeNotifier, Material 3 Design System, Mobile Scanner |
| **DevOps & CI/CD** | GitHub Actions (Ubuntu multi-job pipeline), Python Runner Orchestrator, Cloudflare Pages, Render |

---

## Database Schema & Entities

The platform uses 15 normalized relational tables managed via PostgreSQL:

```
Roles ──────< Users ──────< Staff
                │
                ├───< Orders ─────< OrderItems ─────> Products
                ├───< Carts  ─────< CartItems  ─────> Products
                ├───< ServiceRequests
                └───< CustomBuilds ───< CustomBuildItems ───> Products

Categories ───< CategoryFilters ───< FilterOptions
           ───< Products ────────< ProductFilterValues ───> FilterOptions
```

- **Authentication & Staff:** `Roles`, `Users`, `Staff`
- **Catalog & Faceted Search:** `Categories`, `Products`, `CategoryFilters`, `FilterOptions`, `ProductFilterValues`
- **Cart & Orders:** `Carts`, `CartItems`, `Orders`, `OrderItems`, `Coupons`
- **Custom Rig Configuration:** `CustomBuilds`, `CustomBuildItems`
- **After-Sales Services:** `ServiceRequests`

Database Schema: [`db/schema.sql`](db/schema.sql) · Seed Data: [`db/seed.sql`](db/seed.sql)

---

## Project Structure

```text
pc-forge/
├── runner.py                  # Full-stack orchestrator for all 4 application tiers
├── .github/workflows/ci.yml   # Multi-job GitHub Actions CI/CD pipeline
├── docs/                      # Architecture Decision Records (ADRs) & documentation
│   ├── ADR.md                 # 6 Architectural Decision Records
│   └── performance/           # Locust load and stress testing scripts
├── db/                        # Database scripts
│   ├── schema.sql             # Relational DDL schema with indexes and constraints
│   ├── seed.sql               # Enthusiast component catalog, demo users, orders
│   └── cleanup_and_migration.sql # Migration and cleanup scripts
├── backend/                   # ASP.NET Core Web API (.NET 8)
│   ├── Controllers/           # Auth, Products, Categories, Orders, CustomBuilds, ServiceRequests, Staff
│   ├── Services/              # AiAgentService, AuthService, CloudinaryImageUploadService
│   ├── Data/                  # AppDbContext, DbInitializer
│   ├── Models/                # Entity Framework Core domain entities
│   └── DTOs/                  # Data transfer object contracts
├── backend.Tests/             # xUnit integration & unit test suite (.NET 8/9)
├── ai_service/                # Python FastAPI Agentic AI Microservice (:5050)
│   ├── agents/                # 5 LangGraph autonomous agent implementations
│   ├── test_gemini_keys.py    # Diagnostic tool for inspecting Gemini API keys
│   └── tests/                 # Pytest test suite for agent tools & workflows
├── app/                       # Flutter 3.x Customer Mobile Application
│   ├── lib/core/              # Routing, themes, auth session, common widgets
│   ├── lib/features/          # auth, catalog, cart, checkout, orders, support, build_pc, scanner
│   └── test/                  # Flutter unit & widget test suite
└── web/                       # React 19 + Vite Staff & Admin Portal
    ├── src/pages/             # Staff, BuildReviews, Orders, ServiceRequests, Products, Categories
    ├── src/components/        # Modular workbenches, inspection modals, tables
    ├── src/services/          # API client services
    └── src/__tests__/         # Vitest unit test suite
```

---

## Quick-Start Guide

### ⚡ One-Command Runner (Recommended)

Run all 4 application tiers simultaneously using the built-in orchestrator:

```powershell
python runner.py
```

The orchestrator initializes:
- **Backend API**: `http://localhost:5000`
- **AI Microservice**: `http://localhost:5050`
- **Web Admin Portal**: `http://localhost:5173`
- **Mobile Client**: Connected Android device, emulator, or Windows desktop target

**Orchestrator Hotkeys:**
- `b` — Restart Backend
- `w` — Restart Web Portal
- `m` — Restart Mobile Client
- `s` — Display service status overview
- `q` — Cleanly terminate all background services

---

### Step-by-Step Manual Setup

#### 1. Environment Configuration

Copy `.env.example` to `.env` in the project root:

```env
# Google Gemini API Keys (Multi-key cascading fallback 1 -> 6)
GEMINI_API_KEY_1=your_gemini_api_key_1
GEMINI_API_KEY_2=your_gemini_api_key_2
CHAT_MODEL=gemini-3.8-flash

# Database Connection (PostgreSQL)
DATABASE_URL=postgresql://user:password@host/pcforge_db

# Security & JWT Authentication
JWT_SECRET=your_super_secret_jwt_key_at_least_32_characters_long

# Cloud Storage (Optional for RMA image uploads)
CLOUDINARY_URL=cloudinary://api_key:api_secret@cloud_name
```

#### 2. Database Setup

```powershell
# Apply schema and initial seed data
python update-db.py --seed

# Verify table integrity
python update-db.py --status
```

#### 3. ASP.NET Core Web API (.NET 8)

```powershell
cd backend
dotnet restore
dotnet run
# Swagger UI available at: http://localhost:5000/swagger
```

#### 4. Python AI Microservice

```powershell
cd ai_service
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 5050 --reload
# Interactive API docs available at: http://localhost:5050/docs
```

#### 5. React Web Admin Portal

```powershell
cd web
npm install
npm run dev
# Portal accessible at: http://localhost:5173
```

#### 6. Flutter Customer Mobile App

```powershell
cd app
flutter pub get
flutter run
```

*For physical Android devices over USB:*
```powershell
adb reverse tcp:5000 tcp:5000
adb reverse tcp:5050 tcp:5050
flutter run
```

---

## Flutter Android Release APK

To build a standalone production release APK for Android devices:

```powershell
cd app
flutter build apk --release
# Generated binary location: app/build/app/outputs/flutter-apk/app-release.apk
```

Install directly via ADB:
```powershell
adb install app/build/app/outputs/flutter-apk/app-release.apk
```

---

## Automated Test Suites

The repository features comprehensive automated test coverage across all subsystems:

```powershell
# 1. Backend Integration Tests (.NET xUnit)
cd backend.Tests
dotnet test --configuration Release

# 2. React Web Portal Tests (Vitest)
cd web
npm test

# 3. Flutter Mobile Unit & Widget Tests
cd app
flutter test

# 4. Python AI Agent Evaluation Tests (Pytest)
cd ai_service
pytest tests/ -v --tb=short
```

| Subsystem | Framework | Focus Areas |
|---|---|---|
| **Backend API** | xUnit, InMemory EF Core, WebApplicationFactory | Role-based authorization, JWT validation, custom build approval transitions, service requests |
| **React Web** | Vitest, jsdom, React Testing Library | Authenticated routing, workbench tables, modals, API client service integration |
| **Flutter Mobile** | Flutter Test, Widget Tester | Cart state reactivity, custom PC builder rules, catalog search, barcode scanner integration |
| **Agentic AI** | Pytest, LangGraph Test Harness | Component clearance logic, prompt injection resistance, tool schema execution, multi-key rotation |

### Performance & Load Testing (Locust)

```powershell
pip install locust
locust -f docs/performance/locustfile.py --host=http://localhost:5000
```
Evaluates throughput, database connection pool resilience, and response latencies under concurrent user loads.

---

## CI/CD Pipeline

The GitHub Actions workflow ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) automatically runs on push and pull request events targeting `main` and `dev`:

1. **Security & Integrity Gate**: Scans git tree to prevent secret leaks (`.env` or credential tracking).
2. **Backend Job**: .NET 8 SDK setup $\rightarrow$ dependency restore $\rightarrow$ Release build $\rightarrow$ xUnit test execution $\rightarrow$ vulnerability scan.
3. **AI Service Job**: Python 3.11 $\rightarrow$ dependencies $\rightarrow$ bytecode compilation $\rightarrow$ Pytest suite.
4. **React Web Job**: Node 22 $\rightarrow$ clean install (`npm ci`) $\rightarrow$ static analysis (`oxlint`) $\rightarrow$ Vitest test suite $\rightarrow$ production bundle build.
5. **Flutter Mobile Job**: Flutter 3.38.5 $\rightarrow$ package resolution $\rightarrow$ static code analysis (`flutter analyze --no-fatal-infos`) $\rightarrow$ widget tests.

---

## Security & Architectural Governance

- **Zero-Trust Role Permissions**: Strict JWT claim verification with zero clock-skew tolerance to prevent token replay attacks.
- **Secure Password Hashing**: BCrypt hashing with work factor 12 for all stored credentials.
- **Deterministic AI Guardrails**: Tool-calling schemas restrict AI agents to verified, allow-listed internal endpoints. Unsafe operations require human-in-the-loop review.
- **Sanitized Logs**: Diagnostic and logging utilities automatically redact sensitive API keys and secrets from output streams.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
