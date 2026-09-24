import api from '../api/axiosInstance.js';

const mapApiStaff = (s) => {
  if (!s) return null;
  const staffId = s.staffId || s.id;
  return {
    id: `STF-${staffId}`,
    staffId: staffId,
    userId: s.userId || staffId,
    firstName: s.firstName || '',
    lastName: s.lastName || '',
    email: s.email || '',
    phone: s.phone || '',
    role: s.role || 'Staff',
    department: s.department || 'Hardware Diagnostics & Repair',
    specialization: s.specialization || '',
    status: s.status || 'Active',
    joinedDate: s.joinedDate || (s.createdAt ? s.createdAt.split('T')[0] : '2025-01-10'),
    createdDate: s.createdDate || (s.createdAt ? s.createdAt.split('T')[0] : '2025-01-10'),
    lastLogin: s.lastLogin || 'Never',
    notes: s.notes || '',
  };
};

export const staffService = {
  // Legacy synchronous getter returns empty array
  getAllStaff() {
    return [];
  },

  // Fetch live staff records from backend database API
  async fetchStaffFromApi() {
    try {
      const response = await api.get('/staff');
      if (Array.isArray(response.data)) {
        return response.data.map(mapApiStaff);
      }
      return [];
    } catch (err) {
      console.error('Failed to fetch staff from API:', err?.response?.data || err.message);
      throw err;
    }
  },

  // Pure filter function for a list of staff members
  filterStaff(staffList, { search = '', status = 'all' } = {}) {
    if (!Array.isArray(staffList)) return [];

    return staffList.filter((member) => {
      // 1. Search filter: name, email, or phone
      if (search.trim()) {
        const q = search.trim().toLowerCase();
        const fullName = `${member.firstName} ${member.lastName}`.toLowerCase();
        const email = (member.email || '').toLowerCase();
        const phone = (member.phone || '').replace(/[\s()+-]/g, '');
        const cleanQuery = q.replace(/[\s()+-]/g, '');

        const matchesName = fullName.includes(q);
        const matchesEmail = email.includes(q);
        const matchesPhone = phone.includes(cleanQuery) || (member.phone || '').toLowerCase().includes(q);

        if (!matchesName && !matchesEmail && !matchesPhone) {
          return false;
        }
      }

      // 2. Status filter: 'all', 'Active', 'Inactive'
      if (status !== 'all' && member.status.toLowerCase() !== status.toLowerCase()) {
        return false;
      }

      return true;
    });
  },

  // Calculate statistics from a given staff list (Pure utility function)
  calculateStats(staffList) {
    if (!Array.isArray(staffList)) {
      return { total: 0, active: 0, inactive: 0, departments: 0 };
    }
    const total = staffList.length;
    const active = staffList.filter((s) => s.status === 'Active').length;
    const inactive = staffList.filter((s) => s.status === 'Inactive').length;
    const departments = new Set(staffList.map((s) => s.department).filter(Boolean)).size;

    return { total, active, inactive, departments };
  },

  // Add a new technician staff account (POST /api/staff)
  async addStaff(staffData) {
    const cleanEmail = (staffData.email || '').trim().toLowerCase();
    const cleanFirst = (staffData.firstName || '').trim();
    const cleanLast = (staffData.lastName || '').trim();

    if (!cleanFirst) throw new Error('First name is required.');
    if (!cleanLast) throw new Error('Last name is required.');
    if (!cleanEmail) throw new Error('Email is required.');

    try {
      const response = await api.post('/staff', {
        firstName: cleanFirst,
        lastName: cleanLast,
        email: cleanEmail,
        password: staffData.password || undefined,
        department: staffData.department || 'Hardware Diagnostics & Repair',
        phone: staffData.phone ? staffData.phone.trim() : '+94 77 000 0000',
        specialization: staffData.specialization || staffData.notes,
        status: staffData.status || 'Active',
        notes: staffData.notes,
      });

      return mapApiStaff(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with an Admin account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Admin accounts can add staff.'
          : err.message || 'Failed to add staff member.');
      throw new Error(backendMessage);
    }
  },

  // Reset staff account password (POST /api/staff/{id}/reset-password)
  async resetStaffPassword(id, newPassword) {
    if (!newPassword || newPassword.length < 6) {
      throw new Error('New password must be at least 6 characters long.');
    }

    try {
      const response = await api.post(`/staff/${id}/reset-password`, { newPassword });
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to reset staff password.';
      throw new Error(backendMessage);
    }
  },

  // Update staff member (PUT /api/staff/{id})
  async updateStaff(id, fields) {
    try {
      const response = await api.put(`/staff/${id}`, fields);
      return mapApiStaff(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to update staff member.';
      throw new Error(backendMessage);
    }
  },

  // Toggle active/inactive status (PATCH /api/staff/{id}/status)
  async toggleStaffStatus(id) {
    try {
      const response = await api.patch(`/staff/${id}/status`);
      return mapApiStaff(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to toggle staff status.';
      throw new Error(backendMessage);
    }
  },

  // Delete staff member (DELETE /api/staff/{id})
  async deleteStaff(id) {
    try {
      const response = await api.delete(`/staff/${id}`);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to delete staff member.';
      throw new Error(backendMessage);
    }
  },
};

export default staffService;
