# Architecture Decision Records (ADR)
## PCForge — SE3090 Group Assignment 2026

> **Format:** Each ADR captures: Context → Options Considered → Decision → Consequences  
> **Scope:** Key technical decisions made during PCForge development  
> **Authors:** SE3090 Group (5 members)

---

## ADR-001: State Management in React Web Application

**Date:** August 2026  
**Status:** Accepted

### Context
The React staff/admin portal needs to share authenticated user state (JWT token, role, user profile) across protected routes, navigation, and all API service calls. We needed a solution that is lightweight, built-in to React, and avoids over-engineering a relatively simple auth-focused web portal.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| **React Context API + useReducer** | Built-in, no extra dependency, sufficient for auth-scoped state | Not suitable for high-frequency updates or large normalized stores |
| Redux Toolkit | Industry standard, DevTools, predictable | Significant boilerplate, overkill for a staff portal with limited global state |
| Zustand | Minimal boilerplate, performant | Extra dependency, less familiar to the team |

### Decision
**React Context API** (`AuthContext.jsx`) with `useState` for auth state. The portal's global state is limited to the authenticated user object and JWT token — both perfectly suited to Context. Per-page state is managed locally with `useState`/`useEffect` hooks.

### Consequences
- ✅ Zero extra dependencies; portable and understandable
- ✅ Role-based route protection implemented cleanly via `ProtectedRoute` wrapper
- ✅ All API service calls read the token from Context via `useContext(AuthContext)`
- ⚠️ If portal scope grows to complex shared non-auth state, migration to Zustand would be the next step

---

## ADR-002: State Management in Flutter Mobile Application

**Date:** August 2026  
**Status:** Accepted

### Context
The Flutter customer app has several stateful concerns: authentication session, shopping cart, AI build session (multi-step conversation), and real-time UI updates triggered by API responses. We needed a pattern that integrates naturally with Flutter's widget tree and supports reactive UI rebuilds.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| **Provider + ChangeNotifier** | Flutter-native, lightweight, excellent widget integration | Requires careful scoping to avoid unnecessary rebuilds |
| Riverpod | More modern, compile-safe | Steeper learning curve; team had Provider experience |
| BLoC/Cubit | Strict separation of events and states | Verbose; adds significant boilerplate for simpler flows |
| setState only | Simple for local state | Cannot share state across the widget tree |

### Decision
**Provider pattern with `ChangeNotifier`** singletons. Key services (`AiBuildService`, `AuthSession`, `CartService`) extend `ChangeNotifier` and are registered as top-level `ChangeNotifierProvider`s. Widgets subscribe via `Consumer<T>` or `context.watch<T>()`.

### Consequences
- ✅ Reactive UI: AI chat messages, cart totals, and session state update widgets instantly
- ✅ `AuthSession.instance` provides token access to API calls without threading it through constructors
- ✅ `AiBuildService` cleanly encapsulates the multi-turn requirement gathering session state
- ⚠️ Singleton providers require explicit `resetSession()` calls on logout to avoid state leakage

---

## ADR-003: Agentic AI Framework and Orchestration Method

**Date:** August–September 2026  
**Status:** Accepted

### Context
The PCForge Agentic AI subsystem must implement a multi-step workflow with 5 distinct agent roles, allow-listed tools, deterministic validation, shared persisted state, and human approval gates. The framework must integrate with the Google Gemini API, be deployable as a FastAPI microservice, and be callable by the ASP.NET Core backend.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| **LangGraph + LangChain (Google Gemini)** | Lab-taught framework; explicit StateGraph with typed state; ToolNode routing; iteration cap support | Requires careful design of state schemas per agent |
| Microsoft Semantic Kernel | Strong .NET integration | Python SDK less mature; less aligned with lab content |
| LlamaIndex Agents | Good RAG integration | Less suited for multi-agent orchestration workflows |
| Custom orchestration (raw prompts) | Full control | No built-in tool routing or state management |

### Decision
**LangGraph `StateGraph` + LangChain tool-calling + Google Gemini (`gemini-2.5-flash-lite`)** via `langchain-google-genai`. Each agent is a self-contained `StateGraph` with:
- `messages` channel using `add_messages` reducer
- `ToolNode` for allow-listed tool dispatch  
- Hard `MAX_AGENT_ITERATIONS = 8` cap to prevent runaway loops
- Structured Pydantic output models for every agent

The Python service runs as a **stateless FastAPI microservice on port 5050**, called exclusively by `AiAgentService.cs` in ASP.NET Core. All DB persistence happens in the ASP.NET layer after deterministic validation.

### Consequences
- ✅ Matches SE3090 lab and lecture content (Labs 05–06, Lectures 05–07)
- ✅ Clear agent boundaries: Requirement → Build → Inventory → Order Planning → After-Sales
- ✅ Tool inputs validated via Pydantic; outputs are structured JSON — never unstructured prose
- ✅ Python service has zero DB dependencies; `psycopg`/SQLAlchemy absent from codebase
- ⚠️ Gemini API rate limits (429) can trigger under heavy concurrent testing; fallback heuristics implemented in `AiAgentService.cs`

---

## ADR-004: Database Schema Strategy for Agentic AI Workflow State

**Date:** September 2026  
**Status:** Accepted

### Context
The spec requires persisting "workflow ID, objective, plan, completed steps, tool results, validation results, errors, approval status and final outcome in structured, durable storage." We needed to decide where and how AI workflow state is stored.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| **Persist in existing domain tables (Orders, ServiceRequests, CustomBuilds)** | No new tables; workflow state attached to domain entities; EF Core migrations trivial | Requires JSONB columns for agent traces |
| Dedicated `AgentWorkflowRun` table | Clean separation of concerns | Extra join complexity; duplicates domain data |
| In-memory session store (Redis) | Fast | Not durable; no audit trail |

### Decision
**Embed agent workflow state in existing domain tables** using dedicated columns:

- `CustomBuilds` / `Orders`: store `AgentSessionId`, `AgentTrace` (JSON), `ValidationResult`, `ApprovalStatus`, `ReservationId`
- `ServiceRequests`: store `SessionId`, `AgentTrace`, `DiagnosisResult`, `AppointmentStatus`
- **In-memory `RequirementSessions` dictionary** in ASP.NET Core for ephemeral chat state (non-durable by design — session ends when build completes)

This keeps the AI audit trail co-located with the domain record it produced, satisfying the observability requirement without a separate schema.

### Consequences
- ✅ Full audit trail: every AI decision, tool call, validation result, and approval decision is persisted in PostgreSQL via EF Core
- ✅ React admin portal can display agent traces directly from existing API endpoints
- ✅ EF Core migrations manage schema evolution; no raw SQL required for AI state
- ⚠️ JSONB agent trace columns can grow large for complex workflows; indexing on `SessionId` mitigates query performance concerns

---

## ADR-005: Cloud Deployment Platform

**Date:** September 2026  
**Status:** Accepted

### Context
We needed a no-cost, reliable cloud platform to deploy the ASP.NET Core Web API and React web application, with PostgreSQL hosted on a managed database service. The deployment must provide a stable public URL for evaluators and support environment variable injection for secrets.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| **Render.com (API) + Neon PostgreSQL + Cloudflare Pages (React)** | Free tier; supports .NET 8 Docker deployments; Neon has free Postgres with connection pooling | Cold-start latency on free tier (~30–50 s) |
| Railway | Simple .NET support | Free tier limits bandwidth |
| Azure App Service | Enterprise-grade | Requires credit card; costly beyond free tier |
| Heroku | Familiar | Eliminated free tier in 2022 |

### Decision
**Render.com** for the ASP.NET Core API (Docker-based deployment), **Neon PostgreSQL** for the managed database, and local / static hosting for the React web application. The Python AI service runs locally during evaluation (Agentic AI is resource-intensive and free-tier cloud limits make it impractical to deploy alongside the API).

### Consequences
- ✅ No cost; institution-provided free tier compliant
- ✅ Render's Docker support handles the .NET 8 Kestrel + Swagger setup cleanly
- ✅ Neon provides connection pooling and automatic scale-to-zero
- ✅ GitHub Actions CI deploys automatically on push to `main`
- ⚠️ Render free tier cold-starts after 15 minutes of inactivity — evaluators should ping the health URL (`/health`) before demo

---

## ADR-006: Python AI Service as Internal Microservice (Architectural Boundary)

**Date:** September 2026  
**Status:** Accepted

### Context
The SE3090 specification mandates: *"Where a Python Agentic AI service is used, it must operate as an internal service called by ASP.NET Core and must not be called directly by either client application."* We needed to enforce this boundary architecturally rather than by convention.

### Options Considered
| Option | Pros | Cons |
|---|---|---|
| **ASP.NET Core as sole gateway; Python service internal** | Spec compliant; single auth surface; deterministic validation before persistence | Adds one network hop; requires context hydration in AiAgentService |
| Python service exposed to clients directly | Simpler client code | Violates mandatory backend rule; no server-side validation gate |
| Embed Python in ASP.NET process (pythonnet) | No network hop | Brittle; version conflicts; violates separation of concerns |

### Decision
**ASP.NET Core `AiAgentService` is the exclusive caller of the Python FastAPI service.** The data flow is:

```
Client → ASP.NET Controller → AiAgentService (hydrate DB context)
       → Python AI Microservice (stateless compute)
       → AiAgentService (deterministic validation + EF Core persistence)
       → PostgreSQL
```

Python service has no DB credentials, no `psycopg`, no SQLAlchemy. Context (product catalog, coupons, customer history) is injected via HTTP payload from ASP.NET Core on every call.

### Consequences
- ✅ Architecture is provably compliant: grep for `5050` or `psycopg` in `web/` and `app/` returns zero results
- ✅ All business validation (budget limits, appointment windows, warranty eligibility) is deterministic C# code — not LLM output
- ✅ Single JWT auth surface; clients never need a second auth token for AI features
- ✅ Python service is horizontally scalable and independently replaceable
- ⚠️ Context hydration adds ~50–100 ms per AI call; acceptable for the use case
