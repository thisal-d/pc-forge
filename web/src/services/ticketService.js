import api from '../api/axiosInstance.js';

const mapApiTicket = (t) => {
  if (!t) return null;
  return {
    ticketId: t.ticketId,
    id: t.ticketId,
    userId: t.userId,
    customerName: t.customerName || (t.userId ? `Customer #${t.userId}` : 'Customer'),
    customerEmail: t.customerEmail || 'customer@pcforge.com',
    customerPhone: '+94 77 000 0000',
    orderId: t.orderId,
    orderDate: t.createdAt ? t.createdAt.split('T')[0] : '2025-01-10',
    productId: t.productId,
    productName: t.productName || 'Hardware Component',
    productCategory: 'Hardware',
    warrantyStatus: 'Active',
    warrantyExpiresDate: '2028-12-31',
    issueType: t.issueType || 'General',
    subject: t.subject || 'Support Ticket',
    description: t.description || '',
    attachmentUrl: t.attachmentUrl || null,
    status: t.status || 'Open',
    priority: t.priority || 'Normal',
    assignedStaffId: t.assignedStaffId ?? null,
    assignedStaffName: t.assignedStaffName || 'Unassigned',
    assignedStaffDepartment: null,
    rmaNumber: t.status === 'RMA Approved' ? `RMA-2025-${t.ticketId}` : null,
    resolutionNotes: t.resolutionNotes || null,
    timeline: [
      {
        id: `t-${t.ticketId}-1`,
        sender: 'Customer',
        senderName: t.customerName || `Customer #${t.userId}`,
        isInternal: false,
        message: t.description || 'Support ticket opened.',
        attachmentUrl: t.attachmentUrl || null,
        timestamp: t.createdAt || new Date().toISOString(),
      },
      ...(t.resolutionNotes
        ? [
            {
              id: `t-${t.ticketId}-2`,
              sender: 'Technician',
              senderName: t.assignedStaffName || 'Staff Technician',
              isInternal: false,
              message: `Resolution: ${t.resolutionNotes}`,
              timestamp: t.updatedAt || new Date().toISOString(),
            },
          ]
        : []),
    ],
    createdAt: t.createdAt || new Date().toISOString(),
    updatedAt: t.updatedAt || new Date().toISOString(),
  };
};

export const ticketService = {
  // Legacy synchronous getter returns empty array
  getAllTickets() {
    return [];
  },

  // Fetch live tickets from backend API (GET /api/SupportTickets)
  async fetchTicketsFromApi() {
    try {
      const response = await api.get('/SupportTickets');
      if (Array.isArray(response.data)) {
        return response.data.map(mapApiTicket);
      }
      return [];
    } catch (err) {
      console.error('Failed to fetch support tickets from API:', err?.response?.data || err.message);
      throw err;
    }
  },

  // Get single ticket by ID (GET /api/SupportTickets/{id})
  async getTicketById(ticketId) {
    const id = Number(ticketId);
    if (!id || isNaN(id)) return null;

    try {
      const response = await api.get(`/SupportTickets/${id}`);
      return mapApiTicket(response.data);
    } catch (err) {
      console.error(`Failed to fetch ticket #${id}:`, err?.response?.data || err.message);
      return null;
    }
  },

  // Filter tickets by search query, status, priority, category/issueType, and assigned technician
  filterTickets(
    ticketList,
    { search = '', status = 'all', priority = 'all', issueType = 'all', staffId = 'all' } = {}
  ) {
    if (!Array.isArray(ticketList)) return [];

    return ticketList.filter((ticket) => {
      // 1. Search filter: Ticket ID (#505), Customer Name, Email, Order ID, Subject, Product
      if (search.trim()) {
        const q = search.trim().toLowerCase();
        const cleanQuery = q.replace(/^#/, '');

        const matchesId = String(ticket.ticketId).includes(cleanQuery);
        const matchesOrderId = ticket.orderId && String(ticket.orderId).includes(cleanQuery);
        const matchesCustomer = (ticket.customerName || '').toLowerCase().includes(q);
        const matchesEmail = (ticket.customerEmail || '').toLowerCase().includes(q);
        const matchesSubject = (ticket.subject || '').toLowerCase().includes(q);
        const matchesProduct = (ticket.productName || '').toLowerCase().includes(q);

        if (!matchesId && !matchesOrderId && !matchesCustomer && !matchesEmail && !matchesSubject && !matchesProduct) {
          return false;
        }
      }

      // 2. Status filter
      if (status !== 'all' && (ticket.status || '').toLowerCase() !== status.toLowerCase()) {
        return false;
      }

      // 3. Priority filter
      if (priority !== 'all' && (ticket.priority || '').toLowerCase() !== priority.toLowerCase()) {
        return false;
      }

      // 4. Issue Type filter
      if (issueType !== 'all' && (ticket.issueType || '').toLowerCase() !== issueType.toLowerCase()) {
        return false;
      }

      // 5. Assigned Staff filter
      if (staffId !== 'all') {
        if (staffId === 'unassigned') {
          if (ticket.assignedStaffId != null) return false;
        } else if (String(ticket.assignedStaffId) !== String(staffId)) {
          return false;
        }
      }

      return true;
    });
  },

  // Calculate statistics for KPI cards (Pure utility function)
  calculateStats(ticketList) {
    if (!Array.isArray(ticketList)) {
      return { total: 0, open: 0, inReview: 0, rmaApproved: 0, resolved: 0, urgentOrHigh: 0 };
    }

    const total = ticketList.length;
    const open = ticketList.filter((t) => t.status === 'Open').length;
    const inReview = ticketList.filter((t) => t.status === 'In Review').length;
    const rmaApproved = ticketList.filter((t) => t.status === 'RMA Approved').length;
    const resolved = ticketList.filter((t) => t.status === 'Resolved' || t.status === 'Closed').length;
    const urgentOrHigh = ticketList.filter(
      (t) => (t.priority === 'High' || t.priority === 'Urgent') && t.status !== 'Closed' && t.status !== 'Resolved'
    ).length;

    return { total, open, inReview, rmaApproved, resolved, urgentOrHigh };
  },

  // Update ticket status & optional resolution notes (PUT /api/SupportTickets/{id})
  async updateTicketStatus(ticketId, newStatus, resolutionNotes = null) {
    const id = Number(ticketId);
    try {
      const response = await api.put(`/SupportTickets/${id}`, {
        status: newStatus,
        resolutionNotes: resolutionNotes || undefined,
      });
      return mapApiTicket(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to update ticket status.';
      throw new Error(backendMessage);
    }
  },

  // Assign technician staff to ticket (PUT /api/SupportTickets/{id})
  async assignTechnician(ticketId, staffId) {
    const id = Number(ticketId);
    const parsedStaffId = staffId ? Number(String(staffId).replace(/^STF-/, '')) : null;

    try {
      const response = await api.put(`/SupportTickets/${id}`, {
        assignedStaffId: parsedStaffId,
      });
      return mapApiTicket(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to assign technician.';
      throw new Error(backendMessage);
    }
  },

  // Update ticket priority (PUT /api/SupportTickets/{id})
  async updatePriority(ticketId, newPriority) {
    const id = Number(ticketId);
    try {
      const response = await api.put(`/SupportTickets/${id}`, {
        priority: newPriority,
      });
      return mapApiTicket(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to update ticket priority.';
      throw new Error(backendMessage);
    }
  },

  // Add timeline entry
  async addTimelineEntry(ticketId, { message, isInternal = false, senderName = 'Staff' }) {
    // Return updated ticket with resolution notes if resolution
    return this.getTicketById(ticketId);
  },

  // Approve RMA for replacement or return
  async createRma(ticketId, { rmaType = 'Replacement', returnTracking = null, notes = '' }) {
    return this.updateTicketStatus(ticketId, 'RMA Approved', notes);
  },

  // Create new ticket (POST /api/SupportTickets)
  async createTicket(ticketData) {
    try {
      const response = await api.post('/SupportTickets', {
        orderId: ticketData.orderId ? Number(ticketData.orderId) : null,
        productId: ticketData.productId ? Number(ticketData.productId) : null,
        issueType: ticketData.issueType || 'General',
        subject: ticketData.subject,
        description: ticketData.description,
        attachmentUrl: ticketData.attachmentUrl || null,
      });
      return mapApiTicket(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to create support ticket.';
      throw new Error(backendMessage);
    }
  },
};

export default ticketService;
