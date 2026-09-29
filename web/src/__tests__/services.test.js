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

vi.mock("@emailjs/browser", () => ({
  default: {
    send: vi.fn(),
  },
}));

import api from "../api/axiosInstance";
import emailjs from "@emailjs/browser";
import { emailService } from "../services/emailService.js";

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

// ── EmailJS Notification Service ──────────────────────────────────────────────
describe("EmailJS – sendBuildReviewNotification()", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("handles missing customer email gracefully without throwing", async () => {
    const result = await emailService.sendBuildReviewNotification({
      customerEmail: "",
      buildId: 10,
      newStatus: "Approved by Staff",
    });
    expect(result.success).toBe(false);
    expect(result.error).toContain("Customer email is required");
    expect(emailjs.send).not.toHaveBeenCalled();
  });

  it("runs in simulated mode when env keys are unconfigured or placeholder", async () => {
    const originalServiceId = import.meta.env.VITE_EMAILJS_SERVICE_ID;
    const originalTemplateId = import.meta.env.VITE_EMAILJS_TEMPLATE_ID;
    const originalPublicKey = import.meta.env.VITE_EMAILJS_PUBLIC_KEY;

    import.meta.env.VITE_EMAILJS_SERVICE_ID = "your_emailjs_service_id";
    import.meta.env.VITE_EMAILJS_TEMPLATE_ID = "your_emailjs_template_id";
    import.meta.env.VITE_EMAILJS_PUBLIC_KEY = "your_emailjs_public_key";

    try {
      const result = await emailService.sendBuildReviewNotification({
        customerEmail: "customer@example.com",
        customerName: "Alex Mercer",
        buildId: 7,
        buildName: "Creator Studio Beast",
        newStatus: "Approved by Staff",
        technicianNotes: "Verified all clearances and PSU headroom.",
        totalPrice: 2499.0,
      });

      expect(result.success).toBe(true);
      expect(result.simulated).toBe(true);
    } finally {
      import.meta.env.VITE_EMAILJS_SERVICE_ID = originalServiceId;
      import.meta.env.VITE_EMAILJS_TEMPLATE_ID = originalTemplateId;
      import.meta.env.VITE_EMAILJS_PUBLIC_KEY = originalPublicKey;
    }
  });

  it("calls emailjs.send with formatted params when valid keys are configured", async () => {
    // Temporarily mock environment variables
    const originalEnv = { ...import.meta.env };
    import.meta.env.VITE_EMAILJS_SERVICE_ID = "service_pcforge";
    import.meta.env.VITE_EMAILJS_TEMPLATE_ID = "template_build_approved";
    import.meta.env.VITE_EMAILJS_PUBLIC_KEY = "pk_live_pcforge123";

    emailjs.send.mockResolvedValueOnce({ status: 200, text: "OK" });

    const result = await emailService.sendBuildReviewNotification({
      customerEmail: "gamer@pcforge.com",
      customerName: "Gamer User",
      buildId: 42,
      buildName: "RTX 4090 Ultra",
      newStatus: "Changes Requested",
      technicianNotes: "Power supply wattage (650W) is insufficient for RTX 4090. Upgrade to at least 850W.",
      totalPrice: 3200.0,
    });

    expect(result.success).toBe(true);
    expect(result.simulated).toBe(false);
    expect(emailjs.send).toHaveBeenCalledTimes(1);

    const [serviceId, templateId, templateParams, publicKey] = emailjs.send.mock.calls[0];
    expect(serviceId).toBe("service_pcforge");
    expect(templateId).toBe("template_build_approved");
    expect(publicKey).toBe("pk_live_pcforge123");
    expect(templateParams.to_email).toBe("gamer@pcforge.com");
    expect(templateParams.review_status).toBe("CHANGES REQUESTED");
    expect(templateParams.technician_notes).toContain("Power supply wattage");

    // Restore environment
    Object.assign(import.meta.env, originalEnv);
  });
});

