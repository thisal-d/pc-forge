import React, { useState, useMemo, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { categoryService } from '../services/categoryService';
import {
  CategoryStats,
  CategoryToolbar,
  CategoryTable,
  AddCategoryModal,
  EditCategoryModal,
  ViewCategoryModal,
  ManageFiltersModal,
  DeleteCategoryModal,
} from '../components/categories/index.js';
import { CloseIcon, AlertTriangleIcon, CheckCircleIcon } from '../components/icons/index.js';

export const CategoryManagement = () => {
  // Master category list
  const [rawCategories, setRawCategories] = useState([]);
  const [loading, setLoading] = useState(true);

  // Load categories from backend API
  const loadCategories = async () => {
    setLoading(true);
    try {
      const list = await categoryService.fetchCategoriesFromApi();
      if (Array.isArray(list)) {
        setRawCategories(list);
      }
    } catch {
      showNotification('error', 'Failed to load categories from server.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadCategories();
  }, []);

  // Filter & Search states
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  // Flash notification state
  const [notification, setNotification] = useState(null);

  const showNotification = (type, message) => {
    setNotification({ type, message });
    setTimeout(() => {
      setNotification(null);
    }, 4500);
  };

  // Add Category Modal state
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [addFormData, setAddFormData] = useState({
    name: '',
    description: '',
    status: 'Active',
  });
  const [addErrors, setAddErrors] = useState({});
  const [addSubmitting, setAddSubmitting] = useState(false);

  // Edit Category Modal state
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [currentEditingCategory, setCurrentEditingCategory] = useState(null);
  const [editFormData, setEditFormData] = useState({
    name: '',
    description: '',
    status: 'Active',
  });
  const [editErrors, setEditErrors] = useState({});
  const [editSubmitting, setEditSubmitting] = useState(false);

  // View Category Details Modal state
  const [viewingCategory, setViewingCategory] = useState(null);
  const [viewingCategoryFilters, setViewingCategoryFilters] = useState([]);

  // Manage Filters Modal state
  const [managingCategory, setManagingCategory] = useState(null);
  const [assignedFilters, setAssignedFilters] = useState([]);
  const [filtersLoading, setFiltersLoading] = useState(false);

  // Filter Assignment Sub-form state
  const [filterMode, setFilterMode] = useState('select'); // 'select' | 'custom'
  const [selectedPoolFilterKey, setSelectedPoolFilterKey] = useState('');
  const [customFilterData, setCustomFilterData] = useState({
    filterKey: '',
    displayName: '',
    filterType: 'multiselect',
    unit: '',
  });
  const [filterActionError, setFilterActionError] = useState('');
  const [filterActionSuccess, setFilterActionSuccess] = useState('');

  // Delete Category Confirmation Modal state
  const [deleteCandidate, setDeleteCandidate] = useState(null);
  const [deleteError, setDeleteError] = useState('');

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // Filtered categories
  const filteredCategories = useMemo(() => {
    return categoryService.filterCategories(rawCategories, {
      search: searchQuery,
      status: statusFilter,
    });
  }, [rawCategories, searchQuery, statusFilter]);

  // Paginated categories slice
  const totalPages = Math.max(1, Math.ceil(filteredCategories.length / pageSize));
  const paginatedCategories = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredCategories.slice(start, start + pageSize);
  }, [filteredCategories, currentPage, pageSize]);

  // Derived KPI statistics
  const stats = useMemo(() => {
    return categoryService.calculateStats(rawCategories);
  }, [rawCategories]);

  // Available filter pool
  const availableFiltersPool = useMemo(() => {
    return categoryService.getAvailableFiltersPool();
  }, []);

  const handleSearchChange = (e) => {
    setSearchQuery(e.target.value);
    setCurrentPage(1);
  };

  const handleClearSearch = () => {
    setSearchQuery('');
    setCurrentPage(1);
  };

  const handleResetFilters = () => {
    setSearchQuery('');
    setStatusFilter('all');
    setCurrentPage(1);
  };

  // ==========================================
  // ADD CATEGORY HANDLERS
  // ==========================================
  const handleOpenAddModal = () => {
    setAddFormData({
      name: '',
      description: '',
      status: 'Active',
    });
    setAddErrors({});
    setIsAddModalOpen(true);
  };

  const handleCloseAddModal = () => {
    setIsAddModalOpen(false);
    setAddErrors({});
  };

  const handleAddFormChange = (e) => {
    const { name, value } = e.target;
    setAddFormData((prev) => ({ ...prev, [name]: value }));
    if (addErrors[name]) {
      setAddErrors((prev) => ({ ...prev, [name]: '' }));
    }
  };

  const handleAddSubmit = async (e) => {
    e.preventDefault();
    const errors = {};

    if (!addFormData.name.trim()) {
      errors.name = 'Category name is required.';
    } else {
      const exists = rawCategories.some(
        (c) => c.name.trim().toLowerCase() === addFormData.name.trim().toLowerCase()
      );
      if (exists) {
        errors.name = `A category named "${addFormData.name.trim()}" already exists.`;
      }
    }

    if (Object.keys(errors).length > 0) {
      setAddErrors(errors);
      return;
    }

    setAddSubmitting(true);
    try {
      const created = await categoryService.addCategory({
        name: addFormData.name,
        description: addFormData.description,
        status: addFormData.status,
      });

      setRawCategories((prev) => {
        const id = created.categoryId || created.id;
        const exists = prev.some((c) => (c.categoryId === id || c.id === id));
        return exists ? prev : [...prev, created];
      });
      setIsAddModalOpen(false);
      showNotification('success', `Category "${created.name}" created successfully.`);
    } catch (err) {
      setAddErrors({ general: err.message || 'Failed to create category.' });
      // Re-fetch in background in case server created it or state was out of sync
      categoryService.fetchCategoriesFromApi().then((list) => {
        if (Array.isArray(list)) setRawCategories(list);
      }).catch(() => {});
    } finally {
      setAddSubmitting(false);
    }
  };

  // ==========================================
  // EDIT CATEGORY HANDLERS
  // ==========================================
  const handleOpenEditModal = (category) => {
    setCurrentEditingCategory(category);
    setEditFormData({
      name: category.name,
      description: category.description || '',
      status: category.status || 'Active',
    });
    setEditErrors({});
    setIsEditModalOpen(true);
  };

  const handleCloseEditModal = () => {
    setIsEditModalOpen(false);
    setCurrentEditingCategory(null);
    setEditErrors({});
  };

  const handleEditFormChange = (e) => {
    const { name, value } = e.target;
    setEditFormData((prev) => ({ ...prev, [name]: value }));
    if (editErrors[name]) {
      setEditErrors((prev) => ({ ...prev, [name]: '' }));
    }
  };

  const handleEditSubmit = async (e) => {
    e.preventDefault();
    if (!currentEditingCategory) return;

    const errors = {};
    if (!editFormData.name.trim()) {
      errors.name = 'Category name is required.';
    } else {
      const catId = currentEditingCategory.categoryId || currentEditingCategory.id;
      const exists = rawCategories.some(
        (c) => (c.categoryId !== catId && c.id !== catId) &&
               c.name.trim().toLowerCase() === editFormData.name.trim().toLowerCase()
      );
      if (exists) {
        errors.name = `Another category named "${editFormData.name.trim()}" already exists.`;
      }
    }

    if (Object.keys(errors).length > 0) {
      setEditErrors(errors);
      return;
    }

    setEditSubmitting(true);
    try {
      const catId = currentEditingCategory.categoryId || currentEditingCategory.id;
      const updated = await categoryService.updateCategory(catId, {
        name: editFormData.name,
        description: editFormData.description,
        status: editFormData.status,
      });

      setRawCategories((prev) =>
        prev.map((c) => ((c.categoryId === catId || c.id === catId) ? { ...c, ...updated } : c))
      );
      setIsEditModalOpen(false);
      showNotification('success', `Category "${updated.name}" updated successfully.`);
    } catch (err) {
      setEditErrors({ general: err.message || 'Failed to update category.' });
    } finally {
      setEditSubmitting(false);
    }
  };

  // ==========================================
  // STATUS TOGGLE & DELETE HANDLERS
  // ==========================================
  const handleToggleStatus = async (category) => {
    const catId = category.categoryId || category.id;
    try {
      const updated = await categoryService.toggleCategoryStatus(catId);
      setRawCategories((prev) =>
        prev.map((c) => ((c.categoryId === catId || c.id === catId) ? { ...c, status: updated.status } : c))
      );
      showNotification(
        'success',
        `Category "${category.name}" is now ${updated.status}.`
      );
    } catch (err) {
      showNotification('error', err.message || 'Failed to update status.');
    }
  };

  const handleOpenDeleteModal = (category) => {
    setDeleteCandidate(category);
    setDeleteError('');
  };

  const handleConfirmDelete = async () => {
    if (!deleteCandidate) return;
    const catId = deleteCandidate.categoryId || deleteCandidate.id;

    try {
      await categoryService.deleteCategory(catId);
      setRawCategories((prev) => prev.filter((c) => c.categoryId !== catId && c.id !== catId));
      showNotification('success', `Category "${deleteCandidate.name}" was removed.`);
      setDeleteCandidate(null);
    } catch (err) {
      setDeleteError(err.message || 'Failed to delete category.');
    }
  };

  // ==========================================
  // VIEW CATEGORY DETAILS
  // ==========================================
  const handleOpenViewModal = async (category) => {
    setViewingCategory(category);
    const catId = category.categoryId || category.id;
    const filters = await categoryService.fetchFiltersForCategoryFromApi(catId);
    setViewingCategoryFilters(filters || []);
  };

  const handleCloseViewModal = () => {
    setViewingCategory(null);
    setViewingCategoryFilters([]);
  };

  // ==========================================
  // MANAGE FILTERS MODAL HANDLERS
  // ==========================================
  const handleOpenManageFilters = async (category) => {
    setManagingCategory(category);
    setFilterActionError('');
    setFilterActionSuccess('');
    setSelectedPoolFilterKey('');
    setCustomFilterData({
      filterKey: '',
      displayName: '',
      filterType: 'multiselect',
      unit: '',
    });
    setFiltersLoading(true);

    const catId = category.categoryId || category.id;
    try {
      const filters = await categoryService.fetchFiltersForCategoryFromApi(catId);
      setAssignedFilters(filters);
    } catch {
      const localFilters = categoryService.getFiltersForCategory(catId);
      setAssignedFilters(localFilters);
    } finally {
      setFiltersLoading(false);
    }
  };

  const handleCloseManageFilters = () => {
    setManagingCategory(null);
    setAssignedFilters([]);
    setFilterActionError('');
    setFilterActionSuccess('');
  };

  const handleReorderFilter = async (filterId, direction) => {
    if (!managingCategory) return;
    const catId = managingCategory.categoryId || managingCategory.id;

    try {
      const reordered = await categoryService.reorderFilter(catId, filterId, direction, assignedFilters);
      setAssignedFilters(reordered);
    } catch (err) {
      setFilterActionError(err.message || 'Failed to reorder filters.');
    }
  };

  const handleToggleFilterActive = async (filterId) => {
    if (!managingCategory) return;
    const catId = managingCategory.categoryId || managingCategory.id;

    try {
      const toggled = await categoryService.toggleFilterActive(catId, filterId, assignedFilters);
      setAssignedFilters((prev) =>
        prev.map((f) => (f.filterId === filterId ? { ...f, isFilterable: toggled.isFilterable } : f))
      );
      setFilterActionSuccess(`Filter "${toggled.displayName || 'Selected filter'}" is now ${toggled.isFilterable ? 'Enabled' : 'Disabled'}.`);
      setTimeout(() => setFilterActionSuccess(''), 3000);
    } catch (err) {
      setFilterActionError(err.message || 'Failed to toggle filter status.');
    }
  };

  const handleRemoveFilter = async (filterId, filterName) => {
    if (!managingCategory) return;
    const catId = managingCategory.categoryId || managingCategory.id;

    try {
      await categoryService.removeFilterFromCategory(catId, filterId);
      const updatedList = await categoryService.fetchFiltersForCategoryFromApi(catId);
      setAssignedFilters(updatedList);

      setRawCategories((prev) =>
        prev.map((c) => ((c.categoryId === catId || c.id === catId) ? { ...c, filterCount: updatedList.length } : c))
      );

      setFilterActionSuccess(`Removed filter "${filterName}".`);
      setTimeout(() => setFilterActionSuccess(''), 3000);
    } catch (err) {
      setFilterActionError(err.message || 'Failed to remove filter.');
    }
  };

  const handleAddFilterAssignment = async (e) => {
    e.preventDefault();
    if (!managingCategory) return;
    setFilterActionError('');
    setFilterActionSuccess('');

    const catId = managingCategory.categoryId || managingCategory.id;
    let targetFilter = null;

    if (filterMode === 'select') {
      if (!selectedPoolFilterKey) {
        setFilterActionError('Please select a filter from the list.');
        return;
      }
      const poolMatch = availableFiltersPool.find(
        (f) => f.filterKey.toLowerCase() === selectedPoolFilterKey.toLowerCase()
      );
      if (!poolMatch) {
        setFilterActionError('Selected filter definition not found.');
        return;
      }
      targetFilter = {
        filterKey: poolMatch.filterKey,
        displayName: poolMatch.displayName,
        filterType: poolMatch.filterType,
        unit: poolMatch.unit,
      };
    } else {
      if (!customFilterData.displayName.trim()) {
        setFilterActionError('Display name is required (e.g., "Memory Speed").');
        return;
      }
      const autoKey =
        customFilterData.filterKey.trim() ||
        customFilterData.displayName.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_');

      targetFilter = {
        filterKey: autoKey,
        displayName: customFilterData.displayName.trim(),
        filterType: customFilterData.filterType || 'multiselect',
        unit: customFilterData.unit.trim() || null,
      };
    }

    try {
      const added = await categoryService.addFilterToCategory(catId, targetFilter);
      const updatedList = await categoryService.fetchFiltersForCategoryFromApi(catId);
      setAssignedFilters(updatedList);

      setRawCategories((prev) =>
        prev.map((c) => ((c.categoryId === catId || c.id === catId) ? { ...c, filterCount: updatedList.length } : c))
      );

      setFilterActionSuccess(`Filter "${added.displayName}" assigned successfully.`);
      setSelectedPoolFilterKey('');
      setCustomFilterData({
        filterKey: '',
        displayName: '',
        filterType: 'multiselect',
        unit: '',
      });
      setTimeout(() => setFilterActionSuccess(''), 3500);
    } catch (err) {
      setFilterActionError(err.message || 'Failed to assign filter.');
    }
  };

  return (
    <div className="page-container">
      {/* Toast Notification Banner */}
      {notification && (
        <div
          className={`notification-banner alert-${notification.type === 'error' ? 'error' : 'success'}`}
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: '1rem',
          }}
        >
          <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            {notification.type === 'error' ? <AlertTriangleIcon size={16} /> : <CheckCircleIcon size={16} />}
            <span>{notification.message}</span>
          </span>
          <button
            onClick={() => setNotification(null)}
            className="clear-search-btn"
            style={{ position: 'static' }}
          >
            <CloseIcon size={14} />
          </button>
        </div>
      )}

      {/* Page Header */}
      <div className="dashboard-header">
        <div>
          <h1>Category Management</h1>
          <p className="subtitle">
            Manage product categories and assign dynamic specifications for hardware search filters.
          </p>
        </div>
        <div>
          <button
            onClick={handleOpenAddModal}
            className="btn btn-primary"
            id="add-category-btn"
          >
            + Add Category
          </button>
        </div>
      </div>

      {/* KPI Statistics Summary Cards */}
      <CategoryStats stats={stats} />

      {/* Toolbar: Search and Status Filters */}
      <CategoryToolbar
        searchQuery={searchQuery}
        onSearchChange={handleSearchChange}
        onClearSearch={handleClearSearch}
        statusFilter={statusFilter}
        onStatusFilterChange={setStatusFilter}
        onResetFilters={handleResetFilters}
        onRefresh={loadCategories}
      />

      {/* Category Table Card */}
      <CategoryTable
        filteredCategories={filteredCategories}
        paginatedCategories={paginatedCategories}
        totalCount={stats.total}
        loading={loading}
        currentPage={currentPage}
        totalPages={totalPages}
        pageSize={pageSize}
        onPageChange={setCurrentPage}
        onPageSizeChange={(newSize) => {
          setPageSize(newSize);
          setCurrentPage(1);
        }}
        onResetFilters={handleResetFilters}
        onOpenAddModal={handleOpenAddModal}
        onViewCategory={handleOpenViewModal}
        onEditCategory={handleOpenEditModal}
        onManageFilters={handleOpenManageFilters}
        onToggleStatus={handleToggleStatus}
        onDeleteCategory={handleOpenDeleteModal}
      />

      {/* Back to Dashboard Link */}
      <div style={{ marginTop: '1.5rem', textAlign: 'center' }}>
        <Link to="/dashboard" className="btn btn-outline-sm">
          ← Back to Dashboard
        </Link>
      </div>

      {/* 1. ADD CATEGORY MODAL */}
      <AddCategoryModal
        isOpen={isAddModalOpen}
        onClose={handleCloseAddModal}
        formData={addFormData}
        onFormChange={handleAddFormChange}
        errors={addErrors}
        submitting={addSubmitting}
        onSubmit={handleAddSubmit}
      />

      {/* 2. EDIT CATEGORY MODAL */}
      <EditCategoryModal
        isOpen={isEditModalOpen}
        onClose={handleCloseEditModal}
        category={currentEditingCategory}
        formData={editFormData}
        onFormChange={handleEditFormChange}
        errors={editErrors}
        submitting={editSubmitting}
        onSubmit={handleEditSubmit}
      />

      {/* 3. VIEW CATEGORY DETAILS MODAL */}
      <ViewCategoryModal
        category={viewingCategory}
        filters={viewingCategoryFilters}
        onClose={handleCloseViewModal}
        onManageFilters={(cat) => handleOpenManageFilters(cat)}
      />

      {/* 4. MANAGE FILTERS MODAL */}
      <ManageFiltersModal
        category={managingCategory}
        onClose={handleCloseManageFilters}
        assignedFilters={assignedFilters}
        filtersLoading={filtersLoading}
        onReorderFilter={handleReorderFilter}
        onToggleFilterActive={handleToggleFilterActive}
        onRemoveFilter={handleRemoveFilter}
        filterActionError={filterActionError}
        filterActionSuccess={filterActionSuccess}
        filterMode={filterMode}
        onFilterModeChange={setFilterMode}
        selectedPoolFilterKey={selectedPoolFilterKey}
        onSelectedPoolFilterKeyChange={setSelectedPoolFilterKey}
        availableFiltersPool={availableFiltersPool}
        customFilterData={customFilterData}
        onCustomFilterDataChange={setCustomFilterData}
        onAddFilterAssignment={handleAddFilterAssignment}
      />

      {/* 5. DELETE CONFIRMATION MODAL */}
      <DeleteCategoryModal
        category={deleteCandidate}
        onClose={() => setDeleteCandidate(null)}
        onConfirm={handleConfirmDelete}
        error={deleteError}
      />
    </div>
  );
};

export default CategoryManagement;
