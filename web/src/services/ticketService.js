// Forwarding ticketService to serviceRequestService (Support tickets replaced by Service Requests)
import serviceRequestService from './serviceRequestService.js';

export const ticketService = {
  getAllTickets() {
    return [];
  },

  async getAllTicketsAsync(filters = {}) {
    return await serviceRequestService.getServiceRequests(filters);
  },

  async getTicketByIdAsync(ticketId) {
    return await serviceRequestService.getServiceRequestById(ticketId);
  },

  getTicketById(ticketId) {
    return null;
  },

  async updateTicketStatus(ticketId, newStatus) {
    return await serviceRequestService.updateServiceRequest(ticketId, { status: newStatus });
  },

  async createTicket(ticketData) {
    return await serviceRequestService.createServiceRequest({
      title: ticketData.title || ticketData.subject,
      description: ticketData.description,
    });
  },

  getMetrics(list = []) {
    return {
      total: list.length,
      open: list.filter((t) => t.status === 'Pending').length,
      inReview: list.filter((t) => t.status === 'In Progress').length,
      resolved: list.filter((t) => t.status === 'Completed').length,
    };
  },
};

export default ticketService;
