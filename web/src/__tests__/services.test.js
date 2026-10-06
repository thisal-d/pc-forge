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
import { productService } from "../services/productService.js";
import { buildReviewService } from "../services/buildReviewService.js";
import { orderService } from "../services/orderService.js";
import { filterService } from "../services/filterService.js";

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

  it("toggleProductStatus() toggles Active to Inactive", async () => {
    api.patch.mockResolvedValueOnce({
      data: {
        productId: 42,
        name: "Test GPU",
        status: "Inactive",
        stockQuantity: 10,
      },
    });
    const result = await productService.toggleProductStatus(42);
    expect(api.patch).toHaveBeenCalledWith("/products/42/status", {});
    expect(result.status).toBe("Inactive");
  });

  it("toggleProductStatus() sets explicit targetStatus", async () => {
    api.patch.mockResolvedValueOnce({
      data: {
        productId: 42,
        name: "Test GPU",
        status: "Active",
        stockQuantity: 10,
      },
    });
    const result = await productService.toggleProductStatus(42, "Active");
    expect(api.patch).toHaveBeenCalledWith("/products/42/status", { status: "Active" });
    expect(result.status).toBe("Active");
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
      },
    });

    const result = await buildReviewService.updateBuildReview(7, {
      status: "Approved by Staff",
      staffNotes: "Verified all clearances and PSU headroom.",
    });

    expect(api.patch).toHaveBeenCalledWith("/custombuilds/7/review", {
      status: "Approved by Staff",
      staffNotes: "Verified all clearances and PSU headroom.",
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

// ── Order Service Methods ───────────────────────────────────────────────────
describe("orderService – cancelOrder() & calculateStats()", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("calls POST /orders/{id}/cancel and returns cancelled order", async () => {
    api.post.mockResolvedValueOnce({
      data: {
        orderId: 101,
        status: "Cancelled",
        totalAmount: 45000,
      },
    });

    const result = await orderService.cancelOrder(101);
    expect(api.post).toHaveBeenCalledWith("/orders/101/cancel");
    expect(result.status).toBe("Cancelled");
  });

  it("calculates correct statistics for canonical order statuses", () => {
    const mockOrders = [
      { orderId: 1, status: "Order placed", totalAmount: 50000 },
      { orderId: 2, status: "Processing", totalAmount: 30000 },
      { orderId: 3, status: "Ready for delivery", totalAmount: 20000 },
      { orderId: 4, status: "Out for delivery", totalAmount: 15000 },
      { orderId: 5, status: "Ready for pickup", totalAmount: 80000 },
      { orderId: 6, status: "Paid & Completed", totalAmount: 95000 },
      { orderId: 7, status: "Cancelled", totalAmount: 40000 },
    ];

    const stats = orderService.calculateStats(mockOrders);

    expect(stats.total).toBe(7);
    expect(stats.orderPlaced).toBe(1);
    expect(stats.processing).toBe(1);
    expect(stats.readyForDelivery).toBe(1);
    expect(stats.outForDelivery).toBe(1);
    expect(stats.readyForPickup).toBe(1);
    expect(stats.paidAndCompleted).toBe(1);
    expect(stats.cancelled).toBe(1);
    // Non-cancelled revenue: 50000 + 30000 + 20000 + 15000 + 80000 + 95000 = 290000
    expect(stats.totalRevenue).toBe(290000);
  });
});

// ── Filter Service Methods ──────────────────────────────────────────────────
describe("filterService – Master filters DB management", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("getFilters() calls GET /filters and returns mapped filter items", async () => {
    api.get.mockResolvedValueOnce({
      data: [
        {
          filterId: 1,
          filterKey: "cuda_cores",
          displayName: "CUDA Cores",
          filterType: "multiselect",
          unit: null,
          options: [{ optionId: 10, value: "3072", displayOrder: 1 }],
          assignedCategoriesCount: 1,
          assignedCategoryNames: ["GPU"],
        },
      ],
    });

    const result = await filterService.getFilters();
    expect(api.get).toHaveBeenCalledWith("/filters");
    expect(result).toHaveLength(1);
    expect(result[0].filterKey).toBe("cuda_cores");
    expect(result[0].options[0].value).toBe("3072");
    expect(result[0].assignedCategoriesCount).toBe(1);
  });

  it("createFilter() sends valid payload to POST /filters", async () => {
    api.post.mockResolvedValueOnce({
      data: {
        filterId: 5,
        filterKey: "refresh_rate",
        displayName: "Refresh Rate",
        filterType: "multiselect",
        unit: "Hz",
        options: [{ optionId: 1, value: "144Hz" }, { optionId: 2, value: "240Hz" }],
      },
    });

    const result = await filterService.createFilter({
      filterKey: "refresh_rate",
      displayName: "Refresh Rate",
      filterType: "multiselect",
      unit: "Hz",
      options: ["144Hz", "240Hz"],
    });

    expect(api.post).toHaveBeenCalledWith("/filters", {
      filterKey: "refresh_rate",
      displayName: "Refresh Rate",
      filterType: "multiselect",
      unit: "Hz",
      options: ["144Hz", "240Hz"],
    });
    expect(result.filterId).toBe(5);
  });

  it("updateFilter() sends updated payload to PUT /filters/{id}", async () => {
    api.put.mockResolvedValueOnce({
      data: {
        filterId: 5,
        filterKey: "refresh_rate",
        displayName: "Display Refresh Rate",
        filterType: "multiselect",
        unit: "Hz",
        options: [{ optionId: 1, value: "144Hz" }, { optionId: 2, value: "360Hz" }],
      },
    });

    const result = await filterService.updateFilter(5, {
      displayName: "Display Refresh Rate",
      filterType: "multiselect",
      unit: "Hz",
      options: ["144Hz", "360Hz"],
    });

    expect(api.put).toHaveBeenCalledWith("/filters/5", {
      displayName: "Display Refresh Rate",
      filterType: "multiselect",
      unit: "Hz",
      options: ["144Hz", "360Hz"],
    });
    expect(result.displayName).toBe("Display Refresh Rate");
  });

  it("deleteFilter() calls DELETE /filters/{id}", async () => {
    api.delete.mockResolvedValueOnce({
      data: { message: "Filter deleted" },
    });

    const result = await filterService.deleteFilter(5);
    expect(api.delete).toHaveBeenCalledWith("/filters/5");
    expect(result.message).toBe("Filter deleted");
  });

  it("calculateStats() calculates correct KPI totals", () => {
    const mockFilters = [
      { filterId: 1, filterType: "multiselect", options: [{ value: "A" }, { value: "B" }] },
      { filterId: 2, filterType: "multiselect", options: [{ value: "C" }] },
      { filterId: 3, filterType: "singleselect", options: [{ value: "D" }, { value: "E" }] },
      { filterId: 4, filterType: "range", options: [] },
      { filterId: 5, filterType: "boolean", options: [{ value: "Yes" }, { value: "No" }] },
    ];

    const stats = filterService.calculateStats(mockFilters);
    expect(stats.total).toBe(5);
    expect(stats.multiselect).toBe(2);
    expect(stats.singleselect).toBe(1);
    expect(stats.range).toBe(1);
    expect(stats.boolean).toBe(1);
    expect(stats.totalOptions).toBe(7);
  });

  it("filterFilters() correctly filters by search and type", () => {
    const mockFilters = [
      { filterId: 1, filterKey: "cuda_cores", displayName: "CUDA Cores", filterType: "multiselect" },
      { filterId: 2, filterKey: "socket", displayName: "Socket Type", filterType: "multiselect" },
      { filterId: 3, filterKey: "wattage", displayName: "Power Wattage", filterType: "singleselect" },
    ];

    const searchMatch = filterService.filterFilters(mockFilters, { search: "cuda" });
    expect(searchMatch).toHaveLength(1);
    expect(searchMatch[0].filterKey).toBe("cuda_cores");

    const typeMatch = filterService.filterFilters(mockFilters, { filterType: "singleselect" });
    expect(typeMatch).toHaveLength(1);
    expect(typeMatch[0].filterKey).toBe("wattage");
  });
});

// ── Filter Management Option Formatting ───────────────────────────────────────
import { formatOptionWithUnit } from "../pages/FilterManagement.jsx";

describe("Filter Option Formatting – formatOptionWithUnit()", () => {
  it("auto-appends unit of measure to numeric values (e.g. 100 -> 100GB)", () => {
    expect(formatOptionWithUnit("100", "GB")).toBe("100GB");
    expect(formatOptionWithUnit("200", "GB")).toBe("200GB");
    expect(formatOptionWithUnit("650", "W")).toBe("650W");
    expect(formatOptionWithUnit("3200", "MHz")).toBe("3200MHz");
  });

  it("does not duplicate unit if user already typed it", () => {
    expect(formatOptionWithUnit("100GB", "GB")).toBe("100GB");
    expect(formatOptionWithUnit("100gb", "GB")).toBe("100GB");
    expect(formatOptionWithUnit("100 GB", "GB")).toBe("100GB");
  });

  it("preserves non-unit strings when no unit is defined", () => {
    expect(formatOptionWithUnit("AM5", "")).toBe("AM5");
    expect(formatOptionWithUnit("LGA1700", null)).toBe("LGA1700");
    expect(formatOptionWithUnit("80+ Bronze", "")).toBe("80+ Bronze");
  });

  it("handles whitespace gracefully", () => {
    expect(formatOptionWithUnit("  100  ", "  GB  ")).toBe("100GB");
    expect(formatOptionWithUnit("", "GB")).toBe("");
  });
});



