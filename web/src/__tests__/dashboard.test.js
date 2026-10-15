import { describe, it, expect } from 'vitest';
import { orderService } from '../services/orderService.js';
import { serviceRequestService } from '../services/serviceRequestService.js';

describe('Dashboard Telemetry & KPI Calculations', () => {
  it('correctly aggregates order stats and revenues', () => {
    const mockOrders = [
      { orderId: 1, status: 'Order placed', totalAmount: 150000, createdAt: '2026-03-01T10:00:00' },
      { orderId: 2, status: 'Processing', totalAmount: 250000, createdAt: '2026-03-05T12:00:00' },
      { orderId: 3, status: 'Paid & Completed', totalAmount: 400000, createdAt: '2026-03-10T14:00:00' },
      { orderId: 4, status: 'Cancelled', totalAmount: 80000, createdAt: '2026-03-12T16:00:00' },
    ];

    const stats = orderService.calculateStats(mockOrders);
    expect(stats.total).toBe(4);
    expect(stats.orderPlaced).toBe(1);
    expect(stats.processing).toBe(1);
    expect(stats.paidAndCompleted).toBe(1);
    expect(stats.cancelled).toBe(1);
    // Non-cancelled orders revenue: 150000 + 250000 + 400000 = 800000
    expect(stats.totalRevenue).toBe(800000);
  });

  it('correctly calculates service request KPIs', () => {
    const mockServices = [
      { serviceRequestId: 101, status: 'Booked' },
      { serviceRequestId: 102, status: 'Pending' },
      { serviceRequestId: 103, status: 'In Progress' },
      { serviceRequestId: 104, status: 'Completed' },
      { serviceRequestId: 105, status: 'Cancelled' },
    ];

    const stats = serviceRequestService.getStats(mockServices);
    expect(stats.total).toBe(5);
    expect(stats.booked).toBe(2);
    expect(stats.inProgress).toBe(1);
    expect(stats.completed).toBe(1);
    expect(stats.cancelled).toBe(1);
  });
});
