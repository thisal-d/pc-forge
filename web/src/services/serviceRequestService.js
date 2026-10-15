import api from '../api/axiosInstance.js';

export const serviceRequestService = {
  // Fetch live service requests from backend API (GET /api/ServiceRequests)
  async fetchServiceRequests({ status, search, startDate, endDate } = {}) {
    try {
      const params = {};
      if (status && status !== 'all') params.status = status;
      if (search && search.trim()) params.search = search.trim();
      if (startDate) params.startDate = startDate;
      if (endDate) params.endDate = endDate;

      const response = await api.get('/ServiceRequests', { params });
      return Array.isArray(response.data) ? response.data : [];
    } catch (err) {
      console.error('Failed to fetch service requests from API:', err?.response?.data || err.message);
      return [];
    }
  },

  // Get single service request by ID or SR-Number (GET /api/ServiceRequests/{id})
  async getServiceRequestById(id) {
    try {
      const response = await api.get(`/ServiceRequests/${id}`);
      return response.data;
    } catch (err) {
      console.error(`Failed to get service request #${id}:`, err?.response?.data || err.message);
      throw new Error(err.response?.data?.message || `Service Request #${id} not found.`);
    }
  },

  // Check appointment availability and slots for a date (GET /api/ServiceRequests/availability?date=YYYY-MM-DD)
  async checkAvailability(date) {
    try {
      const dateStr = typeof date === 'string' ? date : date.toISOString().split('T')[0];
      const response = await api.get('/ServiceRequests/availability', { params: { date: dateStr } });
      return response.data;
    } catch (err) {
      console.error('Failed to check availability:', err?.response?.data || err.message);
      return { isAvailable: true, remainingSlots: 20, bookedCount: 0, slots: [] };
    }
  },

  // Fetch slots availability for a specific date (GET /api/ServiceRequests/slots?date=YYYY-MM-DD)
  async fetchTimeSlotsForDate(date) {
    try {
      const dateStr = typeof date === 'string' ? date : date.toISOString().split('T')[0];
      const response = await api.get('/ServiceRequests/slots', { params: { date: dateStr } });
      return Array.isArray(response.data) ? response.data : [];
    } catch (err) {
      console.error('Failed to fetch time slots for date:', err?.response?.data || err.message);
      return [];
    }
  },

  // Fetch all time slots for management (GET /api/ServiceRequests/admin/slots)
  async fetchAdminSlots() {
    try {
      const response = await api.get('/ServiceRequests/admin/slots');
      return Array.isArray(response.data) ? response.data : [];
    } catch (err) {
      console.error('Failed to fetch admin slots:', err?.response?.data || err.message);
      throw new Error(err.response?.data?.message || 'Failed to load time slots.');
    }
  },

  // Create new time slot (POST /api/ServiceRequests/admin/slots)
  async createSlot(slotData) {
    try {
      const response = await api.post('/ServiceRequests/admin/slots', slotData);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to create time slot.';
      throw new Error(backendMessage);
    }
  },

  // Update existing time slot (PUT /api/ServiceRequests/admin/slots/{id})
  async updateSlot(id, slotData) {
    try {
      const response = await api.put(`/ServiceRequests/admin/slots/${id}`, slotData);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to update time slot.';
      throw new Error(backendMessage);
    }
  },

  // Delete time slot (DELETE /api/ServiceRequests/admin/slots/{id})
  async deleteSlot(id) {
    try {
      const response = await api.delete(`/ServiceRequests/admin/slots/${id}`);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to delete time slot.';
      throw new Error(backendMessage);
    }
  },

  // Toggle time slot active/inactive (PATCH /api/ServiceRequests/admin/slots/{id}/toggle-active)
  async toggleSlotActive(id) {
    try {
      const response = await api.patch(`/ServiceRequests/admin/slots/${id}/toggle-active`);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to toggle slot active status.';
      throw new Error(backendMessage);
    }
  },

  // Set date override for a slot (capacity override or close slot) (POST /api/ServiceRequests/admin/slots/{id}/override)
  async setSlotOverride(slotId, overrideData) {
    try {
      const response = await api.post(`/ServiceRequests/admin/slots/${slotId}/override`, overrideData);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to set time slot override.';
      throw new Error(backendMessage);
    }
  },

  // Remove date override for a slot (DELETE /api/ServiceRequests/admin/slots/{id}/override?date=YYYY-MM-DD)
  async removeSlotOverride(slotId, date) {
    try {
      const dateStr = typeof date === 'string' ? date : date.toISOString().split('T')[0];
      const response = await api.delete(`/ServiceRequests/admin/slots/${slotId}/override`, { params: { date: dateStr } });
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to remove slot override.';
      throw new Error(backendMessage);
    }
  },

  // Cancel service request (POST /api/ServiceRequests/{id}/cancel)
  async cancelServiceRequest(id) {
    try {
      const response = await api.post(`/ServiceRequests/${id}/cancel`);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to cancel service request.';
      throw new Error(backendMessage);
    }
  },

  // Compute live KPI analytics
  getStats(requestsList = []) {
    if (!Array.isArray(requestsList)) {
      return { total: 0, pending: 0, inProgress: 0, completed: 0, noShow: 0, cancelled: 0 };
    }

    const norm = (s) => (s || '').toUpperCase().replace(/_/g, ' ');
    const total = requestsList.length;
    const pending = requestsList.filter((r) => norm(r.status) === 'PENDING').length;
    const inProgress = requestsList.filter((r) => {
      const s = norm(r.status);
      return s === 'IN PROGRESS' || s === 'IN SERVICE' || s === 'UNDER REVIEW' || s === 'SCHEDULED';
    }).length;
    const completed = requestsList.filter((r) => {
      const s = norm(r.status);
      return s === 'COMPLETED' || s === 'RESOLVED';
    }).length;
    const noShow = requestsList.filter((r) => norm(r.status) === 'NO SHOW').length;
    const cancelled = requestsList.filter((r) => norm(r.status) === 'CANCELLED' || norm(r.status) === 'CANCELED' || norm(r.status) === 'REJECTED').length;

    return { total, pending, inProgress, completed, noShow, cancelled };
  },

  // Update service request status and optional appointment date/time/slot (PUT /api/ServiceRequests/{id})
  async updateServiceRequestStatus(id, newStatus, preferredDate = null, preferredTime = null, slotId = null) {
    try {
      const payload = { status: newStatus };
      if (preferredDate) payload.preferredDate = preferredDate;
      if (preferredTime) payload.preferredTime = preferredTime;
      if (slotId) payload.slotId = Number(slotId);

      const response = await api.put(`/ServiceRequests/${id}`, payload);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to update service request.';
      throw new Error(backendMessage);
    }
  },

  // Create new service request (POST /api/ServiceRequests)
  async createServiceRequest(requestData) {
    try {
      const response = await api.post('/ServiceRequests', {
        title: requestData.title?.trim() || null,
        description: requestData.description?.trim() || null,
        slotId: requestData.slotId ? Number(requestData.slotId) : null,
        preferredDate: requestData.preferredDate || null,
        preferredTime: requestData.preferredTime || null,
      });
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to create service request.';
      throw new Error(backendMessage);
    }
  },

  // Fetch verified order items and warranty info (GET /api/ServiceRequests/orders/{orderId}/warranty)
  async fetchOrderWarranty(orderId) {
    try {
      const response = await api.get(`/ServiceRequests/orders/${orderId}/warranty`);
      return response.data;
    } catch (err) {
      console.error(`Failed to fetch order #${orderId} warranty:`, err?.response?.data || err.message);
      return null;
    }
  },

  // Send conversational message to After-Sales Service Agent (POST /api/ServiceRequests/ai-chat)
  async sendAfterSalesChatMessage(message, sessionId = null, orderId = null) {
    try {
      const response = await api.post('/ServiceRequests/ai-chat', {
        message,
        session_id: sessionId,
        order_id: orderId,
      });
      return response.data;
    } catch (err) {
      console.error('Failed to chat with AI Service Agent:', err?.response?.data || err.message);
      return {
        success: false,
        reply: 'Our After-Sales Service Agent is currently offline. Please retry shortly.',
        error: err.message,
      };
    }
  },
};

export default serviceRequestService;
