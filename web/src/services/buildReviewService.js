import api from '../api/axiosInstance.js';

export const buildReviewService = {
  // Fetch all custom builds from backend API with optional search, status, and staff filters
  async fetchBuilds({ status = 'all', search = '', staffId = 'all' } = {}) {
    try {
      const params = {};
      if (status !== 'all') params.status = status;
      if (search.trim()) params.search = search.trim();
      if (staffId !== 'all') params.staffId = staffId;

      const response = await api.get('/custombuilds', { params });
      if (Array.isArray(response.data)) {
        return response.data;
      }
      return [];
    } catch (err) {
      console.error('Failed to fetch custom builds from backend API:', err?.response?.data || err.message);
      throw err;
    }
  },

  // Get single build details with technical clearance & BOM from backend API
  async getBuildById(buildId) {
    const id = Number(buildId);
    if (!id || isNaN(id)) return null;

    try {
      const response = await api.get(`/custombuilds/${id}`);
      return response.data;
    } catch (err) {
      console.error(`Failed to fetch build #${id}:`, err?.response?.data || err.message);
      return null;
    }
  },

  // Update build review status and technician notes (PATCH /api/custombuilds/{id}/review)
  async updateBuildReview(buildId, { status, staffNotes, assignedStaffId }) {
    const id = Number(buildId);
    try {
      const response = await api.patch(`/custombuilds/${id}/review`, {
        status,
        staffNotes,
        assignedStaffId,
      });
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to update custom build review.';
      throw new Error(backendMessage);
    }
  },

  // Customer resubmission after modifying components based on feedback (PUT /api/custombuilds/{id})
  async resubmitBuild(buildId, buildData) {
    const id = Number(buildId);
    try {
      const response = await api.put(`/custombuilds/${id}`, buildData);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to resubmit custom build.';
      throw new Error(backendMessage);
    }
  },
};

export default buildReviewService;
