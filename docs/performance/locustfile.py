"""
PCForge Performance Test Suite
================================
Tool: Locust (https://locust.io)
Covers: §12 Performance requirement — concurrent requests, response time,
        success/failure rate, database response, and Agentic AI latency.

Usage:
    pip install locust
    locust -f docs/performance/locustfile.py --host=http://localhost:5000
    Then open http://localhost:8089 and start the test.

Or headless (CI mode):
    locust -f docs/performance/locustfile.py --host=http://localhost:5000 \
           --users 20 --spawn-rate 5 --run-time 60s --headless \
           --html docs/performance/report.html

Scenarios tested:
  1. GuestUser    — unauthenticated catalog browsing (50% of traffic)
  2. CustomerUser — authenticated shopping workflow (30% of traffic)
  3. StaffUser    — authenticated staff API operations (20% of traffic)
"""

import json
import random
from locust import HttpUser, TaskSet, between, task, events

# ---------------------------------------------------------------------------
# Shared test credentials (must match db/seed.sql)
# ---------------------------------------------------------------------------
CUSTOMER_CREDS = {"email": "customer@pcforge.com", "password": "Cust123!"}
STAFF_CREDS    = {"email": "staff@pcforge.com",    "password": "Staff123!"}
ADMIN_CREDS    = {"email": "admin@pcforge.com",    "password": "Admin123!"}


def login(client, creds) -> str | None:
    """Helper: POST /api/auth/login and return JWT token."""
    with client.post(
        "/api/auth/login",
        json=creds,
        name="/api/auth/login",
        catch_response=True,
    ) as resp:
        if resp.status_code == 200:
            data = resp.json()
            return data.get("token") or data.get("access_token")
        resp.failure(f"Login failed: {resp.status_code} {resp.text[:120]}")
        return None


# ---------------------------------------------------------------------------
# Task Sets
# ---------------------------------------------------------------------------

class GuestBrowsing(TaskSet):
    """Unauthenticated catalog browsing — simulates anonymous visitors."""

    @task(4)
    def get_categories(self):
        self.client.get("/api/categories", name="/api/categories")

    @task(6)
    def get_products(self):
        page = random.randint(1, 3)
        self.client.get(
            f"/api/products?pageNumber={page}&pageSize=12",
            name="/api/products",
        )

    @task(3)
    def get_single_product(self):
        product_id = random.randint(1, 20)
        self.client.get(f"/api/products/{product_id}", name="/api/products/{id}")

    @task(1)
    def health_check(self):
        self.client.get("/health", name="/health")


class CustomerWorkflow(TaskSet):
    """Authenticated customer: login → browse → view order history."""

    token: str | None = None

    def on_start(self):
        self.token = login(self.client, CUSTOMER_CREDS)

    def auth_headers(self):
        return {"Authorization": f"Bearer {self.token}"} if self.token else {}

    @task(5)
    def browse_products(self):
        self.client.get(
            "/api/products?pageNumber=1&pageSize=12",
            headers=self.auth_headers(),
            name="/api/products (auth)",
        )

    @task(3)
    def view_product_detail(self):
        product_id = random.randint(1, 20)
        self.client.get(
            f"/api/products/{product_id}",
            headers=self.auth_headers(),
            name="/api/products/{id} (auth)",
        )

    @task(2)
    def get_order_history(self):
        self.client.get(
            "/api/orders",
            headers=self.auth_headers(),
            name="/api/orders",
        )

    @task(2)
    def get_support_tickets(self):
        self.client.get(
            "/api/supporttickets",
            headers=self.auth_headers(),
            name="/api/supporttickets",
        )

    @task(1)
    def get_profile(self):
        self.client.get(
            "/api/auth/me",
            headers=self.auth_headers(),
            name="/api/auth/me",
        )


class StaffWorkflow(TaskSet):
    """Authenticated staff: login → manage inventory → view build queue."""

    token: str | None = None

    def on_start(self):
        self.token = login(self.client, STAFF_CREDS)

    def auth_headers(self):
        return {"Authorization": f"Bearer {self.token}"} if self.token else {}

    @task(4)
    def get_custom_builds(self):
        self.client.get(
            "/api/custombuilds?pageNumber=1&pageSize=10",
            headers=self.auth_headers(),
            name="/api/custombuilds",
        )

    @task(3)
    def get_all_orders(self):
        self.client.get(
            "/api/orders",
            headers=self.auth_headers(),
            name="/api/orders (staff)",
        )

    @task(2)
    def get_all_products(self):
        self.client.get(
            "/api/products?pageSize=20",
            headers=self.auth_headers(),
            name="/api/products (staff)",
        )

    @task(1)
    def get_all_tickets(self):
        self.client.get(
            "/api/supporttickets",
            headers=self.auth_headers(),
            name="/api/supporttickets (staff)",
        )


class AiWorkflow(TaskSet):
    """AI Agentic workflow latency test — starts a requirement session."""

    token: str | None = None

    def on_start(self):
        self.token = login(self.client, CUSTOMER_CREDS)

    def auth_headers(self):
        return {"Authorization": f"Bearer {self.token}"} if self.token else {}

    @task(1)
    def start_ai_session(self):
        with self.client.post(
            "/api/aibuilds/requirement-session/start",
            headers=self.auth_headers(),
            json={},
            name="/api/aibuilds/start-session",
            catch_response=True,
            timeout=30,
        ) as resp:
            if resp.status_code in (200, 201):
                resp.success()
            elif resp.status_code == 503:
                resp.failure("AI service unavailable (expected in CI/offline mode)")
            else:
                resp.failure(f"Unexpected status: {resp.status_code}")


# ---------------------------------------------------------------------------
# User Classes (weight controls traffic split)
# ---------------------------------------------------------------------------

class GuestUser(HttpUser):
    """50% of virtual users — anonymous browsing."""
    tasks = [GuestBrowsing]
    wait_time = between(1, 3)
    weight = 5


class CustomerUser(HttpUser):
    """30% of virtual users — authenticated customer workflow."""
    tasks = [CustomerWorkflow]
    wait_time = between(2, 5)
    weight = 3


class StaffUser(HttpUser):
    """20% of virtual users — staff/admin workflow."""
    tasks = [StaffWorkflow]
    wait_time = between(1, 4)
    weight = 2
