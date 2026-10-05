import api from '../api/axiosInstance.js';

export const ORDER_STATUSES = [
  'Order placed',
  'Processing',
  'Ready for delivery',
  'Out for delivery',
  'Ready for pickup',
  'Paid & Completed',
  'Cancelled',
];

export const orderService = {
  // Fetch orders with optional status filter and search term
  async getOrders({ status = 'all', search = '' } = {}) {
    const params = {};
    if (status && status !== 'all') {
      params.status = status;
    }
    if (search && search.trim()) {
      params.search = search.trim();
    }

    try {
      const response = await api.get('/orders', { params });
      return Array.isArray(response.data) ? response.data : [];
    } catch (err) {
      console.error('Failed to fetch orders from backend:', err?.response?.data || err.message);
      throw err;
    }
  },

  // Fetch full details of a specific order
  async getOrderById(orderId) {
    const id = Number(orderId);
    if (!id || isNaN(id)) throw new Error('Invalid order ID.');

    try {
      const response = await api.get(`/orders/${id}`);
      return response.data;
    } catch (err) {
      console.error(`Failed to fetch order #${id}:`, err?.response?.data || err.message);
      throw err;
    }
  },

  // Update order status (with automatic backend inventory restock on cancellation)
  async updateOrderStatus(orderId, status, notes = '') {
    const id = Number(orderId);
    if (!id || isNaN(id)) throw new Error('Invalid order ID.');
    if (!status) throw new Error('Status is required.');

    try {
      const response = await api.patch(`/orders/${id}/status`, {
        status,
        notes: notes || undefined,
      });
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Admin or Staff account.'
          : err.response?.status === 403
            ? 'Forbidden (403). Only Admin and Staff accounts can update order statuses.'
            : err.message || 'Failed to update order status.');
      throw new Error(backendMessage);
    }
  },

  // Cancel order (with automatic backend inventory restock)
  async cancelOrder(orderId) {
    const id = Number(orderId);
    if (!id || isNaN(id)) throw new Error('Invalid order ID.');

    try {
      const response = await api.post(`/orders/${id}/cancel`);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message || 'Failed to cancel order.';
      throw new Error(backendMessage);
    }
  },

  // Calculate high-level order metrics
  calculateStats(orders = []) {
    if (!Array.isArray(orders)) {
      return {
        total: 0,
        orderPlaced: 0,
        processing: 0,
        readyForDelivery: 0,
        outForDelivery: 0,
        readyForPickup: 0,
        paidAndCompleted: 0,
        cancelled: 0,
        totalRevenue: 0,
      };
    }

    const total = orders.length;
    let orderPlaced = 0;
    let processing = 0;
    let readyForDelivery = 0;
    let outForDelivery = 0;
    let readyForPickup = 0;
    let paidAndCompleted = 0;
    let cancelled = 0;
    let totalRevenue = 0;

    orders.forEach((o) => {
      const s = (o.status || '').toLowerCase();
      if (s === 'order placed') orderPlaced++;
      else if (s === 'processing') processing++;
      else if (s === 'ready for delivery') readyForDelivery++;
      else if (s === 'out for delivery') outForDelivery++;
      else if (s === 'ready for pickup') readyForPickup++;
      else if (s === 'paid & completed' || s === 'paid and completed') paidAndCompleted++;
      else if (s === 'cancelled') cancelled++;

      // Count revenue from non-cancelled orders
      if (s !== 'cancelled') {
        totalRevenue += Number(o.TotalAmount || o.totalAmount) || 0;
      }
    });

    return {
      total,
      orderPlaced,
      processing,
      readyForDelivery,
      outForDelivery,
      readyForPickup,
      paidAndCompleted,
      cancelled,
      totalRevenue,
    };
  },

  // Format currency
  formatCurrency(amount) {
    const val = Number(amount) || 0;
    return `LKR ${val.toLocaleString('en-US', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })}`;
  },

  // Format date & time
  formatDateTime(isoDate) {
    if (!isoDate) return 'N/A';
    try {
      const d = new Date(isoDate);
      return d.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return isoDate;
    }
  },
};

export default orderService;
