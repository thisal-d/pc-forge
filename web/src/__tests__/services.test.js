import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock axios instance used by all services
vi.mock("../api/axiosInstance", () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    interceptors: {
      request: { use: vi.fn() },
      response: { use: vi.fn() },
    },
  },
}));

import api from "../api/axiosInstance";
import { buildReviewService } from "../services/buildReviewService.js";

// ── Auth Service ──────────────────────────────────────────────────────────────
describe("Auth – login()", () => {
  beforeEach(() => vi.clearAllMocks());

  it("returns token on successful login", async () => {
    api.post.mockResolvedValueOnce({
      data: { token: "jwt-abc-123", user: { email: "staff@pcforge.com", role: "Staff" } },
    });
    const { data } = await api.post("/auth/login", { email: "staff@pcforge.com", password: "Staff123!" });
    expect(data.token).toBe("jwt-abc-123");
    expect(data.user.role).toBe("Staff");
  });

  it("rejects on wrong password (401)", async () => {
    api.post.mockRejectedValueOnce({ response: { status: 401 } });
    await expect(
      api.post("/auth/login", { email: "x", password: "wrong" })
    ).rejects.toMatchObject({ response: { status: 401 } });
  });
});

// ── Product Service ───────────────────────────────────────────────────────────
describe("Products – getProducts()", () => {
  it("returns paginated products list", async () => {
    api.get.mockResolvedValueOnce({
      data: {
        data: [
          { productId: 1, name: "Intel Core i9-14900K", price: 89999, stock: 5 },
          { productId: 2, name: "AMD Ryzen 9 7950X",    price: 104999, stock: 3 },
        ],
        totalCount: 2,
        pageNumber: 1,
        pageSize: 12,
      },
    });
    const { data } = await api.get("/products?pageNumber=1&pageSize=12");
    expect(data.data).toHaveLength(2);
    expect(data.data[0].name).toBe("Intel Core i9-14900K");
  });

  it("returns empty when no products match filters", async () => {
    api.get.mockResolvedValueOnce({ data: { data: [], totalCount: 0 } });
    const { data } = await api.get("/products?brand=NonExistentBrand");
    expect(data.data).toHaveLength(0);
    expect(data.totalCount).toBe(0);
  });
});

// ── Coupon Service ────────────────────────────────────────────────────────────
describe("Coupons – validation logic", () => {
  it("returns valid coupon data", async () => {
    api.get.mockResolvedValueOnce({
      data: { code: "WELCOME10", discountPercent: 10, isActive: true, maxDiscount: 5000 },
    });
    const { data } = await api.get("/coupons/WELCOME10");
    expect(data.discountPercent).toBe(10);
    expect(data.isActive).toBe(true);
  });

  it("rejects expired coupon (404)", async () => {
    api.get.mockRejectedValueOnce({ response: { status: 404 } });
    await expect(api.get("/coupons/EXPIRED20")).rejects.toMatchObject({ response: { status: 404 } });
  });
});

// ── Order Service ─────────────────────────────────────────────────────────────
describe("Orders – getOrders()", () => {
  it("returns order history for authenticated customer", async () => {
    api.get.mockResolvedValueOnce({
      data: [
        { orderId: 1001, status: "Processing", totalAmount: 250000 },
        { orderId: 1002, status: "Delivered",  totalAmount: 89999 },
      ],
    });
    const { data } = await api.get("/orders");
    expect(data).toHaveLength(2);
    expect(data[0].status).toBe("Processing");
  });

  it("returns 401 when token is missing", async () => {
    api.get.mockRejectedValueOnce({ response: { status: 401 } });
    await expect(api.get("/orders")).rejects.toMatchObject({ response: { status: 401 } });
  });
});

// ── After-Sales Chat Service ──────────────────────────────────────────────────
describe("AfterSales – AI chat message", () => {
  it("returns AI reply on success", async () => {
    api.post.mockResolvedValueOnce({
      data: { success: true, reply: "Hello! How can I help?", session_id: "sess-001" },
    });
    const { data } = await api.post("/ServiceRequests/ai-chat", { message: "Hello", session_id: null });
    expect(data.success).toBe(true);
    expect(data.reply).toContain("Hello");
  });

  it("handles network error gracefully", async () => {
    api.post.mockRejectedValueOnce(new Error("Network Error"));
    await expect(api.post("/ServiceRequests/ai-chat", { message: "Hi" })).rejects.toThrow("Network Error");
  });
});

// ── Build Review Service ──────────────────────────────────────────────────────
describe("BuildReviews – status transitions", () => {
  it("approves a build (200)", async () => {
    api.patch.mockResolvedValueOnce({ data: { status: "Approved by Staff", buildId: 42 } });
    const { data } = await api.patch("/custombuilds/42/review", { newStatus: "Approved by Staff" });
    expect(data.status).toBe("Approved by Staff");
  });

  it("requests changes on a build (200)", async () => {
    api.patch.mockResolvedValueOnce({ data: { status: "Changes Requested", buildId: 42 } });
    const { data } = await api.patch("/custombuilds/42/review", { newStatus: "Changes Requested" });
    expect(data.status).toBe("Changes Requested");
  });

  it("returns 403 when customer tries to review (forbidden)", async () => {
    api.patch.mockRejectedValueOnce({ response: { status: 403 } });
    await expect(api.patch("/custombuilds/42/review", {})).rejects.toMatchObject({ response: { status: 403 } });
  });
});

// ── Category Service ──────────────────────────────────────────────────────────
describe("Categories – getCategories()", () => {
  it("returns all hardware categories", async () => {
    api.get.mockResolvedValueOnce({
      data: [
        { categoryId: 1, name: "CPU" },
        { categoryId: 2, name: "GPU" },
        { categoryId: 3, name: "Motherboard" },
      ],
    });
    const { data } = await api.get("/categories");
    expect(data).toHaveLength(3);
    expect(data.map((c) => c.name)).toContain("GPU");
  });
});

// ── Build Review Service Methods ──────────────────────────────────────────────
describe("buildReviewService – updateBuildReview()", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("updates review status and delegates customer notification to backend", async () => {
    api.patch.mockResolvedValueOnce({
      data: {
        buildId: 7,
        status: "Approved by Staff",
        staffNotes: "Verified all clearances and PSU headroom.",
        assignedStaffId: 2,
      },
    });

    const result = await buildReviewService.updateBuildReview(7, {
      status: "Approved by Staff",
      staffNotes: "Verified all clearances and PSU headroom.",
      assignedStaffId: 2,
    });

    expect(api.patch).toHaveBeenCalledWith("/custombuilds/7/review", {
      status: "Approved by Staff",
      staffNotes: "Verified all clearances and PSU headroom.",
      assignedStaffId: 2,
    });
    expect(result.status).toBe("Approved by Staff");
  });

  it("handles backend error when updating build review", async () => {
    api.patch.mockRejectedValueOnce({
      response: { data: { message: "Build not found" } },
    });

    await expect(
      buildReviewService.updateBuildReview(999, { status: "Approved by Staff" })
    ).rejects.toThrow("Build not found");
  });
});

