import api from '../api/axiosInstance.js';

export const serviceRequestService = {
  // Fetch live service requests from backend API (GET /api/ServiceRequests)
  async fetchServiceRequests({ status, search, priority, startDate, endDate } = {}) {
    try {
      const params = {};
      if (status && status !== 'all') params.status = status;
      if (search && search.trim()) params.search = search.trim();
      if (priority && priority !== 'all') params.priority = priority;
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

  // Check appointment availability for a date (GET /api/ServiceRequests/availability?date=YYYY-MM-DD)
  async checkAvailability(date) {
    try {
      const dateStr = typeof date === 'string' ? date : date.toISOString().split('T')[0];
      const response = await api.get('/ServiceRequests/availability', { params: { date: dateStr } });
      return response.data;
    } catch (err) {
      console.error('Failed to check availability:', err?.response?.data || err.message);
      return { isAvailable: true, remainingSlots: 10, bookedCount: 0 };
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
      return { total: 0, pending: 0, inProgress: 0, completed: 0, noShow: 0, cancelled: 0, urgentOrHigh: 0 };
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
    const cancelled = requestsList.filter((r) => norm(r.status) === 'CANCELLED' || norm(r.status) === 'CANCELED').length;
    const urgentOrHigh = requestsList.filter(
      (r) => (r.priority === 'High' || r.priority === 'Urgent') && norm(r.status) !== 'COMPLETED' && norm(r.status) !== 'RESOLVED' && norm(r.status) !== 'CANCELLED'
    ).length;

    return { total, pending, inProgress, completed, noShow, cancelled, urgentOrHigh };
  },

  // Update service request status, diagnosis, internal notes, and resolution (PUT /api/ServiceRequests/{id})
  async updateServiceRequestStatus(id, newStatus, technicianNotes = null, resolution = null, internalNotes = null) {
    try {
      const response = await api.put(`/ServiceRequests/${id}`, {
        status: newStatus,
        technicianNotes: technicianNotes !== null ? technicianNotes : undefined,
        resolution: resolution !== null ? resolution : undefined,
        internalNotes: internalNotes !== null ? internalNotes : undefined,
      });
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

  // Assign technician staff to service request (PUT /api/ServiceRequests/{id})
  async assignTechnician(id, staffId) {
    const parsedStaffId = staffId ? Number(String(staffId).replace(/^STF-/, '')) : null;

    try {
      const response = await api.put(`/ServiceRequests/${id}`, {
        assignedStaffId: parsedStaffId,
      });
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to assign technician.';
      throw new Error(backendMessage);
    }
  },

  // Update priority (PUT /api/ServiceRequests/{id})
  async updatePriority(id, newPriority) {
    try {
      const response = await api.put(`/ServiceRequests/${id}`, {
        priority: newPriority,
      });
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to update priority.';
      throw new Error(backendMessage);
    }
  },

  // Create new service request (POST /api/ServiceRequests)
  async createServiceRequest(requestData) {
    try {
      const response = await api.post('/ServiceRequests', {
        orderId: requestData.orderId ? Number(requestData.orderId) : null,
        productId: requestData.productId ? Number(requestData.productId) : null,
        problemDescription: requestData.problemDescription,
        problemCategory: requestData.problemCategory || 'General',
        troubleshootingSummary: requestData.troubleshootingSummary || null,
        attemptCount: Number(requestData.attemptCount || 0),
        warrantyStatus: requestData.warrantyStatus || 'Active',
        warrantyExpiryDate: requestData.warrantyExpiryDate || null,
        preferredDate: requestData.preferredDate || null,
        preferredTime: requestData.preferredTime || '10:00 AM',
        priority: requestData.priority || 'Normal',
        attachmentUrl: requestData.attachmentUrl || null,
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
