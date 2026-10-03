import api from '../api/axiosInstance.js';

export const couponService = {
  // Fetch coupons with optional search query and activeOnly filter
  async getCoupons({ search = '', activeOnly = false } = {}) {
    const params = {};
    if (search && search.trim()) {
      params.search = search.trim();
    }
    if (activeOnly) {
      params.activeOnly = true;
    }

    try {
      const response = await api.get('/coupons', { params });
      return Array.isArray(response.data) ? response.data : [];
    } catch (err) {
      console.error('Failed to fetch coupons from backend:', err?.response?.data || err.message);
      throw err;
    }
  },

  // Get single coupon
  async getCouponById(couponId) {
    try {
      const response = await api.get(`/coupons/${couponId}`);
      return response.data;
    } catch (err) {
      console.error(`Failed to fetch coupon #${couponId}:`, err?.response?.data || err.message);
      throw err;
    }
  },

  // Create new coupon
  async createCoupon(data) {
    try {
      const response = await api.post('/coupons', data);
      return response.data;
    } catch (err) {
      const msg = err.response?.data?.message || 'Failed to create coupon.';
      throw new Error(msg);
    }
  },

  // Update existing coupon
  async updateCoupon(couponId, data) {
    try {
      const response = await api.put(`/coupons/${couponId}`, data);
      return response.data;
    } catch (err) {
      const msg = err.response?.data?.message || 'Failed to update coupon.';
      throw new Error(msg);
    }
  },

  // Toggle active/inactive
  async toggleStatus(couponId) {
    try {
      const response = await api.patch(`/coupons/${couponId}/toggle-status`);
      return response.data;
    } catch (err) {
      const msg = err.response?.data?.message || 'Failed to toggle coupon status.';
      throw new Error(msg);
    }
  },

  // Delete coupon
  async deleteCoupon(couponId) {
    try {
      const response = await api.delete(`/coupons/${couponId}`);
      return response.data;
    } catch (err) {
      const msg = err.response?.data?.message || 'Failed to delete coupon.';
      throw new Error(msg);
    }
  },
};
