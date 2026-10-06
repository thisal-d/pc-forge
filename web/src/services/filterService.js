import api from '../api/axiosInstance.js';

export const filterService = {
  // Fetch all master filters from backend API (GET /api/filters)
  async getFilters() {
    try {
      const response = await api.get('/filters');
      if (Array.isArray(response.data)) {
        return response.data.map((f) => ({
          filterId: f.filterId,
          filterKey: f.filterKey,
          displayName: f.displayName,
          filterType: f.filterType || 'multiselect',
          unit: f.unit || null,
          createdAt: f.createdAt,
          updatedAt: f.updatedAt,
          assignedCategoriesCount: f.assignedCategoriesCount ?? 0,
          assignedCategoryNames: Array.isArray(f.assignedCategoryNames) ? f.assignedCategoryNames : [],
          options: Array.isArray(f.options)
            ? f.options.map((o) => ({
                optionId: o.optionId,
                value: o.value,
                optionValue: o.value,
                displayOrder: o.displayOrder,
              }))
            : [],
        }));
      }
      return [];
    } catch (err) {
      console.error('Failed to fetch master filters from backend API:', err?.response?.data || err.message);
      throw err;
    }
  },

  // Fetch a single master filter by ID (GET /api/filters/{id})
  async getFilterById(filterId) {
    const id = Number(filterId);
    const response = await api.get(`/filters/${id}`);
    const f = response.data;
    return {
      filterId: f.filterId,
      filterKey: f.filterKey,
      displayName: f.displayName,
      filterType: f.filterType || 'multiselect',
      unit: f.unit || null,
      createdAt: f.createdAt,
      updatedAt: f.updatedAt,
      assignedCategoriesCount: f.assignedCategoriesCount ?? 0,
      assignedCategoryNames: Array.isArray(f.assignedCategoryNames) ? f.assignedCategoryNames : [],
      options: Array.isArray(f.options)
        ? f.options.map((o) => ({
            optionId: o.optionId,
            value: o.value,
            optionValue: o.value,
            displayOrder: o.displayOrder,
          }))
        : [],
    };
  },

  // Create a new master filter in DB (POST /api/filters)
  async createFilter({ filterKey, displayName, filterType = 'multiselect', unit = null, options = [] }) {
    const cleanKey = (filterKey || '').trim().toLowerCase().replace(/\s+/g, '_');
    const cleanName = (displayName || '').trim();

    if (!cleanKey) {
      throw new Error('Filter key is required (e.g. "cuda_cores", "socket").');
    }
    if (!cleanName) {
      throw new Error('Filter display name is required (e.g. "CUDA Cores", "Socket Type").');
    }

    try {
      const response = await api.post('/filters', {
        filterKey: cleanKey,
        displayName: cleanName,
        filterType: filterType || 'multiselect',
        unit: unit && unit.trim() ? unit.trim() : null,
        options: Array.isArray(options) ? options.filter((o) => o && o.trim()) : [],
      });
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Staff or Admin account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Staff and Admin accounts can manage filters.'
          : err.response?.status === 400
          ? (err.response?.data?.message || 'Invalid filter data provided.')
          : err.message || 'Failed to create filter in database.');
      throw new Error(backendMessage);
    }
  },

  // Update a master filter in DB (PUT /api/filters/{id})
  async updateFilter(filterId, { displayName, filterType = 'multiselect', unit = null, options = [] }) {
    const id = Number(filterId);
    const cleanName = (displayName || '').trim();

    if (!cleanName) {
      throw new Error('Filter display name is required.');
    }

    try {
      const response = await api.put(`/filters/${id}`, {
        displayName: cleanName,
        filterType: filterType || 'multiselect',
        unit: unit && unit.trim() ? unit.trim() : null,
        options: Array.isArray(options) ? options.filter((o) => o && o.trim()) : [],
      });
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Staff or Admin account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Staff and Admin accounts can update filters.'
          : err.response?.status === 400
          ? (err.response?.data?.message || 'Invalid filter update data.')
          : err.message || 'Failed to update filter in database.');
      throw new Error(backendMessage);
    }
  },

  // Delete a master filter from DB (DELETE /api/filters/{id})
  async deleteFilter(filterId) {
    const id = Number(filterId);
    try {
      const response = await api.delete(`/filters/${id}`);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Staff or Admin account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Staff and Admin accounts can delete filters.'
          : err.response?.status === 400
          ? (err.response?.data?.message || 'Cannot delete filter due to existing dependencies.')
          : err.message || 'Failed to delete filter.');
      throw new Error(backendMessage);
    }
  },

  // Filter master filters list by search query and filter type (pure utility)
  filterFilters(filtersList, { search = '', filterType = 'all' } = {}) {
    if (!Array.isArray(filtersList)) return [];

    return filtersList.filter((f) => {
      // 1. Search filter: Display Name or Filter Key
      if (search.trim()) {
        const q = search.trim().toLowerCase();
        const nameMatches = (f.displayName || '').toLowerCase().includes(q);
        const keyMatches = (f.filterKey || '').toLowerCase().includes(q);
        const unitMatches = (f.unit || '').toLowerCase().includes(q);

        if (!nameMatches && !keyMatches && !unitMatches) {
          return false;
        }
      }

      // 2. Type filter
      if (filterType !== 'all' && (f.filterType || '').toLowerCase() !== filterType.toLowerCase()) {
        return false;
      }

      return true;
    });
  },

  // Calculate statistics for filter metrics cards (pure utility)
  calculateStats(filtersList) {
    if (!Array.isArray(filtersList)) {
      return { total: 0, multiselect: 0, singleselect: 0, range: 0, boolean: 0, totalOptions: 0 };
    }
    const total = filtersList.length;
    const multiselect = filtersList.filter((f) => (f.filterType || '').toLowerCase() === 'multiselect').length;
    const singleselect = filtersList.filter((f) => (f.filterType || '').toLowerCase() === 'singleselect').length;
    const range = filtersList.filter((f) => (f.filterType || '').toLowerCase() === 'range').length;
    const boolean = filtersList.filter((f) => (f.filterType || '').toLowerCase() === 'boolean').length;
    const totalOptions = filtersList.reduce((sum, f) => sum + (Array.isArray(f.options) ? f.options.length : 0), 0);

    return { total, multiselect, singleselect, range, boolean, totalOptions };
  },
};

export default filterService;
