import api from '../api/axiosInstance.js';

// Global pool of standard component filters that can be assigned to categories
export const STANDARD_FILTERS_CATALOG = [
  { filterKey: 'brand', displayName: 'Brand / Manufacturer', filterType: 'multiselect', unit: null },
  { filterKey: 'socket', displayName: 'Socket Type', filterType: 'multiselect', unit: null },
  { filterKey: 'chipset', displayName: 'Chipset', filterType: 'multiselect', unit: null },
  { filterKey: 'form_factor', displayName: 'Form Factor', filterType: 'multiselect', unit: null },
  { filterKey: 'vram', displayName: 'VRAM Capacity', filterType: 'multiselect', unit: 'GB' },
  { filterKey: 'memory_type', displayName: 'Memory Type', filterType: 'multiselect', unit: null },
  { filterKey: 'ddr_type', displayName: 'DDR Type', filterType: 'multiselect', unit: null },
  { filterKey: 'speed', displayName: 'Memory Speed / Bus', filterType: 'multiselect', unit: 'MHz' },
  { filterKey: 'capacity', displayName: 'Capacity', filterType: 'multiselect', unit: 'GB' },
  { filterKey: 'efficiency', displayName: 'Efficiency Rating', filterType: 'multiselect', unit: null },
  { filterKey: 'wattage', displayName: 'Power Wattage', filterType: 'singleselect', unit: 'W' },
  { filterKey: 'modular_type', displayName: 'Modular Type', filterType: 'singleselect', unit: null },
  { filterKey: 'tdp', displayName: 'Thermal Design Power (TDP)', filterType: 'singleselect', unit: 'W' },
  { filterKey: 'cores', displayName: 'Core Count', filterType: 'singleselect', unit: null },
  { filterKey: 'threads', displayName: 'Thread Count', filterType: 'singleselect', unit: null },
  { filterKey: 'clock_speed', displayName: 'Clock Speed', filterType: 'singleselect', unit: 'GHz' },
  { filterKey: 'price_tier', displayName: 'Price Range', filterType: 'range', unit: 'LKR' },
  { filterKey: 'rgb_lighting', displayName: 'RGB Lighting', filterType: 'boolean', unit: null },
];

const mapApiCategory = (cat) => {
  if (!cat) return null;
  const id = cat.categoryId || cat.id;
  return {
    categoryId: id,
    id: id,
    name: cat.name,
    description: cat.description || '',
    status: cat.status || 'Active',
    productCount: cat.productCount ?? 0,
    filterCount: cat.filterCount ?? 0,
    createdAt: cat.createdAt || new Date().toISOString(),
    createdDate: cat.createdAt ? cat.createdAt.split('T')[0] : new Date().toISOString().split('T')[0],
  };
};

export const categoryService = {
  // Legacy synchronous getter returns empty array — components must fetch asynchronously
  getAllCategories() {
    return [];
  },

  // Fetch all categories from backend API (GET /api/categories)
  async getCategories() {
    try {
      const response = await api.get('/categories');
      if (Array.isArray(response.data)) {
        return response.data.map(mapApiCategory);
      }
      return [];
    } catch (err) {
      console.error('Failed to fetch categories from backend API:', err?.response?.data || err.message);
      throw err;
    }
  },

  // Fetch live categories from backend API
  async fetchCategoriesFromApi() {
    return this.getCategories();
  },

  // Fetch single category by ID
  async getCategoryById(categoryId) {
    const id = Number(categoryId);
    const response = await api.get(`/categories/${id}`);
    return mapApiCategory(response.data);
  },

  // Filter categories by search string and status (Pure utility function)
  filterCategories(categoryList, { search = '', status = 'all' } = {}) {
    if (!Array.isArray(categoryList)) return [];

    return categoryList.filter((category) => {
      // 1. Search filter: Category Name, Description, or ID
      if (search.trim()) {
        const q = search.trim().toLowerCase();
        const nameMatches = (category.name || '').toLowerCase().includes(q);
        const descMatches = (category.description || '').toLowerCase().includes(q);
        const idMatches = String(category.categoryId || category.id).includes(q);

        if (!nameMatches && !descMatches && !idMatches) {
          return false;
        }
      }

      // 2. Status filter: 'all', 'Active', 'Inactive'
      if (status !== 'all' && (category.status || 'Active').toLowerCase() !== status.toLowerCase()) {
        return false;
      }

      return true;
    });
  },

  // Calculate high-level summary KPIs (Pure utility function)
  calculateStats(categories) {
    if (!Array.isArray(categories)) {
      return { total: 0, active: 0, inactive: 0, totalAssignedFilters: 0 };
    }
    const total = categories.length;
    const active = categories.filter((c) => (c.status || 'Active').toLowerCase() === 'active').length;
    const inactive = categories.filter((c) => (c.status || 'Active').toLowerCase() === 'inactive').length;
    const totalAssignedFilters = categories.reduce((sum, c) => sum + (c.filterCount || 0), 0);

    return { total, active, inactive, totalAssignedFilters };
  },

  // Add a new Category in PostgreSQL categories table (POST /api/categories)
  async addCategory({ name, description = '', status = 'Active' }) {
    const cleanName = (name || '').trim();
    if (!cleanName) {
      throw new Error('Category name is required.');
    }

    try {
      const response = await api.post('/categories', {
        name: cleanName,
        description: (description || '').trim(),
        status: status || 'Active',
      });
      return mapApiCategory(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Staff or Admin account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Staff and Admin accounts can manage categories.'
          : err.response?.status === 400
          ? (err.response?.data?.message || 'Invalid category data provided.')
          : err.response?.data && typeof err.response.data === 'string'
          ? err.response.data
          : err.message || 'Failed to create category in database.');
      throw new Error(backendMessage);
    }
  },

  // Update Category Details (PUT /api/categories/{id})
  async updateCategory(categoryId, { name, description = '', status = 'Active' }) {
    const id = Number(categoryId);
    const cleanName = (name || '').trim();
    if (!cleanName) {
      throw new Error('Category name is required.');
    }

    try {
      const response = await api.put(`/categories/${id}`, {
        name: cleanName,
        description: (description || '').trim(),
        status: status || 'Active',
      });
      return mapApiCategory(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Staff or Admin account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Staff and Admin accounts can update categories.'
          : err.response?.status === 400
          ? (err.response?.data?.message || 'Invalid category update payload.')
          : err.response?.data && typeof err.response.data === 'string'
          ? err.response.data
          : err.message || 'Failed to update category in database.');
      throw new Error(backendMessage);
    }
  },

  // Toggle Category Active / Inactive status
  async toggleCategoryStatus(categoryId, currentCategory = {}) {
    const id = Number(categoryId);
    const nextStatus = (currentCategory.status || 'Active').toLowerCase() === 'active' ? 'Inactive' : 'Active';

    try {
      const response = await api.put(`/categories/${id}`, {
        name: currentCategory.name,
        description: currentCategory.description,
        status: nextStatus,
      });
      return mapApiCategory(response.data);
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to toggle category status.';
      throw new Error(backendMessage);
    }
  },

  // Delete Category (DELETE /api/categories/{id})
  async deleteCategory(categoryId) {
    const id = Number(categoryId);
    try {
      const response = await api.delete(`/categories/${id}`);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        (err.response?.status === 401
          ? 'Authentication required (401). Please log in with a valid Staff or Admin account.'
          : err.response?.status === 403
          ? 'Forbidden (403). Only Staff and Admin accounts can delete categories.'
          : err.response?.data && typeof err.response.data === 'string'
          ? err.response.data
          : err.message || 'Cannot delete category due to database constraints.');
      throw new Error(backendMessage);
    }
  },

  // ==========================================
  // CATEGORY FILTER MANAGEMENT OPERATIONS
  // ==========================================

  // Legacy sync getter
  getFiltersForCategory() {
    return [];
  },

  // Fetch live filters from backend API for a category (GET /api/categories/{id}/filters)
  async fetchFiltersForCategoryFromApi(categoryId) {
    const id = Number(categoryId);
    if (!id || isNaN(id)) return [];

    try {
      const response = await api.get(`/categories/${id}/filters`);
      if (Array.isArray(response.data)) {
        return response.data.map((f, index) => ({
          filterId: f.filterId || index + 1,
          categoryId: id,
          filterKey: f.filterKey,
          displayName: f.displayName,
          filterType: f.filterType || 'multiselect',
          unit: f.unit || null,
          displayOrder: f.displayOrder || index + 1,
          isFilterable: f.isFilterable !== false,
          optionsCount: Array.isArray(f.options) ? f.options.length : 0,
          options: Array.isArray(f.options) ? f.options : [],
        }));
      }
      return [];
    } catch (err) {
      console.warn(`Category filters API fetch note for category #${id}:`, err?.message);
      return [];
    }
  },

  // Get distinct pool of available filters that can be assigned
  getAvailableFiltersPool() {
    return [...STANDARD_FILTERS_CATALOG].sort((a, b) => a.displayName.localeCompare(b.displayName));
  },

  // Assign an existing or new filter to a category (POST /api/categories/{id}/filters)
  async addFilterToCategory(categoryId, { filterKey, displayName, filterType = 'multiselect', unit = null }) {
    const id = Number(categoryId);
    const cleanKey = (filterKey || '').trim().toLowerCase().replace(/\s+/g, '_');
    const cleanName = (displayName || '').trim();

    if (!cleanKey) {
      throw new Error('Filter key is required (e.g., "socket", "vram").');
    }
    if (!cleanName) {
      throw new Error('Filter display name is required (e.g., "Socket Type").');
    }

    try {
      const response = await api.post(`/categories/${id}/filters`, {
        filterKey: cleanKey,
        displayName: cleanName,
        filterType: filterType || 'multiselect',
        unit: unit ? unit.trim() : null,
        isFilterable: true,
      });
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to add filter to category.';
      throw new Error(backendMessage);
    }
  },

  // Remove a filter assignment from a category (DELETE /api/categories/{id}/filters/{filterId})
  async removeFilterFromCategory(categoryId, filterId) {
    const catId = Number(categoryId);
    const fId = Number(filterId);

    try {
      const response = await api.delete(`/categories/${catId}/filters/${fId}`);
      return response.data;
    } catch (err) {
      const backendMessage =
        err.response?.data?.message ||
        err.response?.data?.title ||
        err.message ||
        'Failed to remove filter from category.';
      throw new Error(backendMessage);
    }
  },

  // Reorder filter up or down
  async reorderFilter(categoryId, filterId, direction, currentFilters = []) {
    let list = [...currentFilters];
    if (list.length === 0) {
      list = await this.fetchFiltersForCategoryFromApi(categoryId);
    }
    list.sort((a, b) => (a.displayOrder || 0) - (b.displayOrder || 0));
    const index = list.findIndex((f) => f.filterId === filterId);
    if (index === -1) return list;

    if (direction === 'up' && index > 0) {
      const temp = list[index];
      list[index] = list[index - 1];
      list[index - 1] = temp;
    } else if (direction === 'down' && index < list.length - 1) {
      const temp = list[index];
      list[index] = list[index + 1];
      list[index + 1] = temp;
    } else {
      return list;
    }

    const reordered = list.map((f, idx) => ({
      ...f,
      displayOrder: idx + 1,
    }));

    try {
      await api.put(`/categories/${categoryId}/filters/reorder`, {
        order: reordered.map((f) => ({ filterId: f.filterId, displayOrder: f.displayOrder })),
      });
    } catch (err) {
      console.warn('Reorder API sync note:', err.message);
    }

    return reordered;
  },

  // Enable or disable a filter for a category (isFilterable)
  async toggleFilterActive(categoryId, filterId, currentFilters = []) {
    const target = currentFilters.find((f) => f.filterId === filterId);
    const newActiveState = target ? !target.isFilterable : false;

    const response = await api.put(`/categories/${categoryId}/filters/${filterId}`, {
      isFilterable: newActiveState,
    });

    return {
      ...(target || {}),
      filterId,
      ...(response.data || {}),
      isFilterable: response.data?.isFilterable !== undefined ? response.data.isFilterable : newActiveState,
    };
  },
};

export default categoryService;
