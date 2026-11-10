import React, { useState, useMemo, useEffect } from 'react';
import { filterService } from '../services/filterService.js';
import { Pagination } from '../components/common/Pagination.jsx';
import { CloseIcon, AlertTriangleIcon, CheckCircleIcon, InfoIcon } from '../components/icons/index.js';
import '../styles/pages/filters.css';

// Slug generator
export const slugify = (text) => {
  return (text || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
};

// Auto-format option value with unit of measure if appropriate
export const formatOptionWithUnit = (rawOpt, unit) => {
  const trimmed = (rawOpt || '').trim();
  const cleanUnit = (unit || '').trim();
  if (!trimmed) return '';
  if (!cleanUnit) return trimmed;

  const unitLower = cleanUnit.toLowerCase();
  const trimmedLower = trimmed.toLowerCase();

  // If it already ends with unit (case-insensitive)
  if (trimmedLower.endsWith(unitLower)) {
    const withoutUnit = trimmed.slice(0, trimmed.length - cleanUnit.length).trimEnd();
    return withoutUnit ? `${withoutUnit}${cleanUnit}` : cleanUnit;
  }

  // Auto-append unit if value doesn't already have it
  return `${trimmed}${cleanUnit}`;
};

export const FilterManagement = () => {
  const [filters, setFilters] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [notification, setNotification] = useState(null);

  // Modal States
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [createForm, setCreateForm] = useState({
    displayName: '',
    filterKey: '',
    filterType: 'multiselect',
    unit: '',
    options: [],
  });
  const [createOptionInput, setCreateOptionInput] = useState('');
  const [createErrors, setCreateErrors] = useState({});
  const [createSubmitting, setCreateSubmitting] = useState(false);

  // Edit Modal State
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [editingFilter, setEditingFilter] = useState(null);
  const [editForm, setEditForm] = useState({
    displayName: '',
    filterType: 'multiselect',
    unit: '',
    options: [],
  });
  const [editOptionInput, setEditOptionInput] = useState('');
  const [editErrors, setEditErrors] = useState({});
  const [editSubmitting, setEditSubmitting] = useState(false);

  // Delete Modal State
  const [deleteCandidate, setDeleteCandidate] = useState(null);
  const [deleteSubmitting, setDeleteSubmitting] = useState(false);
  const [deleteError, setDeleteError] = useState('');

  // Load Filters from backend API
  const loadFilters = async () => {
    setLoading(true);
    try {
      const data = await filterService.getFilters();
      setFilters(data || []);
    } catch {
      showNotification('error', 'Failed to load filters from database.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadFilters();
  }, []);

  const showNotification = (type, message) => {
    setNotification({ type, message });
    setTimeout(() => {
      setNotification(null);
    }, 4500);
  };

  // Filter & Search
  const filteredFilters = useMemo(() => {
    return filterService.filterFilters(filters, {
      search: searchQuery,
      filterType: typeFilter,
    });
  }, [filters, searchQuery, typeFilter]);

  // Pagination State
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, typeFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredFilters.length / pageSize));
  const paginatedFilters = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredFilters.slice(start, start + pageSize);
  }, [filteredFilters, currentPage, pageSize]);

  // Derived Stats
  const stats = useMemo(() => {
    return filterService.calculateStats(filters);
  }, [filters]);

  // ----------------------------------------------------
  // CREATE FILTER HANDLERS
  // ----------------------------------------------------
  const handleOpenCreateModal = () => {
    setCreateForm({
      displayName: '',
      filterKey: '',
      filterType: 'multiselect',
      unit: '',
      options: [],
    });
    setCreateOptionInput('');
    setCreateErrors({});
    setIsCreateModalOpen(true);
  };

  const handleCloseCreateModal = () => {
    setIsCreateModalOpen(false);
    setCreateErrors({});
  };

  const handleCreateDisplayNameChange = (e) => {
    const val = e.target.value;
    setCreateForm((prev) => ({
      ...prev,
      displayName: val,
      filterKey: slugify(val),
    }));
    if (createErrors.displayName || createErrors.filterKey) {
      setCreateErrors((prev) => ({ ...prev, displayName: '', filterKey: '' }));
    }
  };

  const handleAddCreateOption = (e) => {
    if (e && e.preventDefault) e.preventDefault();
    const raw = (createOptionInput || '').trim();
    if (!raw) return;

    // Support comma-separated batch input if user enters "100, 200"
    const rawList = raw.includes(',')
      ? raw.split(',').map((s) => s.trim()).filter(Boolean)
      : [raw];

    const newOptionsToAdd = [];
    let duplicateMsg = '';

    for (const item of rawList) {
      const formatted = formatOptionWithUnit(item, createForm.unit);
      if (!formatted) continue;

      const alreadyExists =
        createForm.options.some((o) => o.toLowerCase() === formatted.toLowerCase()) ||
        newOptionsToAdd.some((o) => o.toLowerCase() === formatted.toLowerCase());

      if (alreadyExists) {
        duplicateMsg = `Option "${formatted}" is already added.`;
      } else {
        newOptionsToAdd.push(formatted);
      }
    }

    if (newOptionsToAdd.length > 0) {
      setCreateForm((prev) => ({
        ...prev,
        options: [...prev.options, ...newOptionsToAdd],
      }));
      setCreateOptionInput('');
      setCreateErrors((prev) => ({ ...prev, option: duplicateMsg || '' }));
    } else if (duplicateMsg) {
      setCreateErrors((prev) => ({ ...prev, option: duplicateMsg }));
    }
  };

  const handleRemoveCreateOption = (indexToRemove) => {
    setCreateForm((prev) => ({
      ...prev,
      options: prev.options.filter((_, idx) => idx !== indexToRemove),
    }));
  };

  const handleCreateSubmit = async (e) => {
    e.preventDefault();
    const errors = {};

    if (!createForm.displayName.trim()) {
      errors.displayName = 'Display label is required.';
    }
    if (!createForm.filterKey.trim()) {
      errors.filterKey = 'System key is required.';
    } else {
      const exists = filters.some(
        (f) => f.filterKey.toLowerCase() === createForm.filterKey.trim().toLowerCase()
      );
      if (exists) {
        errors.filterKey = `Filter key "${createForm.filterKey.trim()}" already exists in the database.`;
      }
    }

    if (Object.keys(errors).length > 0) {
      setCreateErrors(errors);
      return;
    }

    setCreateSubmitting(true);
    try {
      await filterService.createFilter({
        filterKey: createForm.filterKey.trim(),
        displayName: createForm.displayName.trim(),
        filterType: createForm.filterType,
        unit: createForm.unit ? createForm.unit.trim() : null,
        options: createForm.options,
      });

      await loadFilters();
      setIsCreateModalOpen(false);
      showNotification('success', `Filter "${createForm.displayName.trim()}" created successfully in database.`);
    } catch (err) {
      setCreateErrors({ general: err.message || 'Failed to create filter in database.' });
    } finally {
      setCreateSubmitting(false);
    }
  };

  // ----------------------------------------------------
  // EDIT FILTER HANDLERS
  // ----------------------------------------------------
  const handleOpenEditModal = (filter) => {
    setEditingFilter(filter);
    setEditForm({
      displayName: filter.displayName,
      filterType: filter.filterType || 'multiselect',
      unit: filter.unit || '',
      options: Array.isArray(filter.options)
        ? filter.options.map((o) => (typeof o === 'object' ? (o.value ?? o.optionValue ?? '') : String(o)))
        : [],
    });
    setEditOptionInput('');
    setEditErrors({});
    setIsEditModalOpen(true);
  };

  const handleCloseEditModal = () => {
    setIsEditModalOpen(false);
    setEditingFilter(null);
    setEditErrors({});
  };

  const handleAddEditOption = (e) => {
    if (e && e.preventDefault) e.preventDefault();
    const raw = (editOptionInput || '').trim();
    if (!raw) return;

    // Support comma-separated batch input if user enters "100, 200"
    const rawList = raw.includes(',')
      ? raw.split(',').map((s) => s.trim()).filter(Boolean)
      : [raw];

    const newOptionsToAdd = [];
    let duplicateMsg = '';

    for (const item of rawList) {
      const formatted = formatOptionWithUnit(item, editForm.unit);
      if (!formatted) continue;

      const alreadyExists =
        editForm.options.some((o) => o.toLowerCase() === formatted.toLowerCase()) ||
        newOptionsToAdd.some((o) => o.toLowerCase() === formatted.toLowerCase());

      if (alreadyExists) {
        duplicateMsg = `Option "${formatted}" is already added.`;
      } else {
        newOptionsToAdd.push(formatted);
      }
    }

    if (newOptionsToAdd.length > 0) {
      setEditForm((prev) => ({
        ...prev,
        options: [...prev.options, ...newOptionsToAdd],
      }));
      setEditOptionInput('');
      setEditErrors((prev) => ({ ...prev, option: duplicateMsg || '' }));
    } else if (duplicateMsg) {
      setEditErrors((prev) => ({ ...prev, option: duplicateMsg }));
    }
  };

  const handleRemoveEditOption = (indexToRemove) => {
    setEditForm((prev) => ({
      ...prev,
      options: prev.options.filter((_, idx) => idx !== indexToRemove),
    }));
  };

  const handleEditSubmit = async (e) => {
    e.preventDefault();
    if (!editingFilter) return;

    if (!editForm.displayName.trim()) {
      setEditErrors({ displayName: 'Display label is required.' });
      return;
    }

    setEditSubmitting(true);
    try {
      await filterService.updateFilter(editingFilter.filterId, {
        displayName: editForm.displayName.trim(),
        filterType: editForm.filterType,
        unit: editForm.unit ? editForm.unit.trim() : null,
        options: editForm.options,
      });

      await loadFilters();
      setIsEditModalOpen(false);
      showNotification('success', `Filter "${editForm.displayName.trim()}" updated successfully.`);
    } catch (err) {
      setEditErrors({ general: err.message || 'Failed to update filter.' });
    } finally {
      setEditSubmitting(false);
    }
  };

  // ----------------------------------------------------
  // DELETE FILTER HANDLERS
  // ----------------------------------------------------
  const handleOpenDeleteModal = (filter) => {
    setDeleteCandidate(filter);
    setDeleteError('');
  };

  const handleCloseDeleteModal = () => {
    setDeleteCandidate(null);
    setDeleteError('');
  };

  const handleConfirmDelete = async () => {
    if (!deleteCandidate) return;

    setDeleteSubmitting(true);
    setDeleteError('');
    try {
      await filterService.deleteFilter(deleteCandidate.filterId);
      await loadFilters();
      showNotification('success', `Filter "${deleteCandidate.displayName}" was deleted from database.`);
      setDeleteCandidate(null);
    } catch (err) {
      setDeleteError(err.message || 'Failed to delete filter.');
    } finally {
      setDeleteSubmitting(false);
    }
  };

  const getTypeBadge = (type) => {
    const t = (type || 'multiselect').toLowerCase();
    switch (t) {
      case 'multiselect':
        return <span className="filter-type-badge filter-type-multiselect">Multi-Select</span>;
      case 'singleselect':
        return <span className="filter-type-badge filter-type-singleselect">Single-Select</span>;
      case 'range':
        return <span className="filter-type-badge filter-type-range">Numeric Range</span>;
      case 'boolean':
        return <span className="filter-type-badge filter-type-boolean">Boolean Switch</span>;
      default:
        return <span className="badge badge-secondary">{type}</span>;
    }
  };

  return (
    <div className="page-container">
      {/* Toast Notification */}
      {notification && (
        <div className={`notification-banner alert alert-${notification.type === 'error' ? 'error' : 'success'}`}>
          <span>{notification.message}</span>
          <button
            type="button"
            onClick={() => setNotification(null)}
            className="clear-search-btn"
            style={{ position: 'static', marginLeft: 'auto' }}
            aria-label="Dismiss notification"
          >
            <CloseIcon size={14} />
          </button>
        </div>
      )}

      {/* Header Banner */}
      <div className="dashboard-header">
        <div>
          <h1>Filter Management</h1>
          <p className="subtitle">
            Manage master hardware specifications and dynamic filter options stored in the database.
          </p>
        </div>
        <div className="header-actions">
          <button
            id="create-filter-btn"
            className="btn btn-primary"
            onClick={handleOpenCreateModal}
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <line x1="12" y1="5" x2="12" y2="19"></line>
              <line x1="5" y1="12" x2="19" y2="12"></line>
            </svg>
            <span>Create Filter</span>
          </button>
        </div>
      </div>

      {/* KPI Stats Cards */}
      <div className="stats-grid">
        <div className="stat-card stat-card-total">
          <div className="metric-card-top">
            <div className="metric-icon-circle icon-circle-blue">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"></polygon>
              </svg>
            </div>
            <div className="metric-details">
              <span className="stat-label">Total Filters</span>
              <span className="stat-value">{stats.total}</span>
              <span className="stat-subtext">Hardware specifications</span>
            </div>
          </div>
        </div>

        <div className="stat-card stat-card-active">
          <div className="metric-card-top">
            <div className="metric-icon-circle icon-circle-blue">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M9 11l3 3L22 4" />
                <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" />
              </svg>
            </div>
            <div className="metric-details">
              <span className="stat-label">Multi-Select</span>
              <span className="stat-value">{stats.multiselect}</span>
              <span className="stat-subtext">Checkbox attributes</span>
            </div>
          </div>
        </div>

        <div className="stat-card stat-card-tech">
          <div className="metric-card-top">
            <div className="metric-icon-circle icon-circle-purple">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <circle cx="12" cy="12" r="4" />
              </svg>
            </div>
            <div className="metric-details">
              <span className="stat-label">Single-Select</span>
              <span className="stat-value">{stats.singleselect}</span>
              <span className="stat-subtext">Radio attributes</span>
            </div>
          </div>
        </div>

        <div className="stat-card stat-card-active">
          <div className="metric-card-top">
            <div className="metric-icon-circle icon-circle-green">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </div>
            <div className="metric-details">
              <span className="stat-label">Option Values</span>
              <span className="stat-value">{stats.totalOptions}</span>
              <span className="stat-subtext">Predefined filter options</span>
            </div>
          </div>
        </div>
      </div>

      {/* Search & Filter Toolbar */}
      <div className="toolbar-card">
        <div className="search-filter-row">
          <div className="toolbar-search-wrapper">
            <span className="toolbar-search-icon">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="11" cy="11" r="8"></circle>
                <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
              </svg>
            </span>
            <input
              id="filter-search-input"
              type="text"
              className="toolbar-search-input"
              placeholder="Search by filter name, key (e.g. cuda_cores), or unit..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
            {searchQuery && (
              <button
                type="button"
                className="toolbar-clear-btn"
                onClick={() => setSearchQuery('')}
                title="Clear search"
              >
                ✕
              </button>
            )}
          </div>

          <div className="toolbar-filters-group">
            <div className="toolbar-select-item">
              <select
                id="filter-type-select"
                className="toolbar-select"
                value={typeFilter}
                onChange={(e) => setTypeFilter(e.target.value)}
              >
                <option value="all">All Filter Types</option>
                <option value="multiselect">Multi-Select</option>
                <option value="singleselect">Single-Select</option>
                <option value="range">Numeric Range</option>
                <option value="boolean">Boolean Switch</option>
              </select>
            </div>

            {(searchQuery || typeFilter !== 'all') && (
              <button
                type="button"
                onClick={() => {
                  setSearchQuery('');
                  setTypeFilter('all');
                }}
                className="btn btn-outline-sm"
              >
                Reset Filters
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Main Table */}
      <div className="data-table-card">
        <div className="table-header-banner">
          <h3>Specifications & Filter Keys ({filteredFilters.length})</h3>
          <span className="table-header-subtitle">
            Showing {paginatedFilters.length} of {filters.length} master filter specifications
          </span>
        </div>

        {loading ? (
          <div style={{ padding: '3rem', textAlign: 'center', color: 'var(--text-muted)' }}>
            Loading database filters...
          </div>
        ) : filteredFilters.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon">
              <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"></polygon>
              </svg>
            </div>
            <h4>No Filters Found</h4>
            <p>
              {searchQuery || typeFilter !== 'all'
                ? 'No filters matched your search criteria.'
                : 'No master filters have been created yet. Click "Create Filter" to add one.'}
            </p>
            {(searchQuery || typeFilter !== 'all') && (
              <button
                type="button"
                className="btn btn-outline-sm"
                onClick={() => {
                  setSearchQuery('');
                  setTypeFilter('all');
                }}
              >
                Clear Filters
              </button>
            )}
          </div>
        ) : (
          <div className="table-responsive">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Filter Name & Key</th>
                  <th>UI Type</th>
                  <th>Unit</th>
                  <th>Predefined Options</th>
                  <th>Assigned Categories</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {paginatedFilters.map((f) => (
                  <tr key={f.filterId}>
                    <td>
                      <div style={{ fontWeight: 700, fontSize: '0.925rem', color: 'var(--text-main)' }}>
                        {f.displayName}
                      </div>
                      <code className="filter-key-code">
                        {f.filterKey}
                      </code>
                    </td>

                    <td>{getTypeBadge(f.filterType)}</td>

                    <td>
                      {f.unit ? (
                        <span className="filter-unit-pill">
                          {f.unit}
                        </span>
                      ) : (
                        <span style={{ color: 'var(--text-subtle)', fontSize: '0.85rem' }}>—</span>
                      )}
                    </td>

                    <td>
                      {f.options && f.options.length > 0 ? (
                        <div className="filter-options-wrap">
                          {f.options.slice(0, 4).map((opt) => (
                            <span
                              key={opt.optionId || opt.value}
                              className="filter-option-chip"
                            >
                              {opt.value}
                            </span>
                          ))}
                          {f.options.length > 4 && (
                            <span className="filter-option-more">
                              +{f.options.length - 4} more
                            </span>
                          )}
                        </div>
                      ) : (
                        <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontStyle: 'italic' }}>
                          (Harvested from products)
                        </span>
                      )}
                    </td>

                    <td>
                      {f.assignedCategoryNames && f.assignedCategoryNames.length > 0 ? (
                        <div className="filter-cat-wrap">
                          {f.assignedCategoryNames.map((catName) => (
                            <span
                              key={catName}
                              className="filter-cat-pill"
                            >
                              {catName}
                            </span>
                          ))}
                        </div>
                      ) : (
                        <span className="filter-cat-empty">
                          Not assigned
                        </span>
                      )}
                    </td>

                    <td style={{ textAlign: 'right' }}>
                      <div style={{ display: 'inline-flex', gap: '0.4rem', justifyContent: 'flex-end' }}>
                        <button
                          type="button"
                          className="btn btn-outline-sm"
                          onClick={() => handleOpenEditModal(f)}
                        >
                          Edit
                        </button>
                        <button
                          type="button"
                          className="btn btn-danger-sm"
                          onClick={() => handleOpenDeleteModal(f)}
                        >
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          totalItems={filteredFilters.length}
          pageSize={pageSize}
          onPageChange={setCurrentPage}
          onPageSizeChange={(newSize) => {
            setPageSize(newSize);
            setCurrentPage(1);
          }}
          itemLabel="filters"
        />
      </div>

      {/* ==================================================== */}
      {/* CREATE FILTER MODAL */}
      {/* ==================================================== */}
      {isCreateModalOpen && (
        <div className="modal-overlay" onClick={handleCloseCreateModal}>
          <div className="modal-dialog" style={{ maxWidth: '600px' }} onClick={(e) => e.stopPropagation()} id="create-filter-modal">
            <div className="modal-header">
              <div>
                <h3 className="modal-title">Create Master Filter</h3>
                <span className="modal-subtitle">
                  New technical specification attribute stored in the database
                </span>
              </div>
              <button onClick={handleCloseCreateModal} className="modal-close-btn" aria-label="Close modal">
                <CloseIcon size={16} />
              </button>
            </div>

            <form onSubmit={handleCreateSubmit}>
              <div className="modal-body">
                {createErrors.general && (
                  <div className="alert alert-error">
                    {createErrors.general}
                  </div>
                )}

                <div className="form-group">
                  <label className="form-label-saas">
                    Display Label *
                  </label>
                  <input
                    id="create-display-name-input"
                    type="text"
                    className="form-input-saas"
                    placeholder="e.g. Memory Speed, VRAM Capacity, Socket Type"
                    value={createForm.displayName}
                    onChange={handleCreateDisplayNameChange}
                    required
                  />
                  {createErrors.displayName && (
                    <span className="field-error-text">
                      {createErrors.displayName}
                    </span>
                  )}
                </div>

                <div className="form-group">
                  <label className="form-label-saas">
                    System Filter Key *
                    <span style={{ fontSize: '0.75rem', fontWeight: 400, color: 'var(--text-muted)', marginLeft: '0.4rem' }}>
                      (auto-slugged, used in product specs & queries)
                    </span>
                  </label>
                  <input
                    id="create-filter-key-input"
                    type="text"
                    className="form-input-saas"
                    placeholder="e.g. memory_speed, vram, socket"
                    value={createForm.filterKey}
                    onChange={(e) => setCreateForm({ ...createForm, filterKey: slugify(e.target.value) })}
                    required
                    style={{ fontFamily: 'monospace' }}
                  />
                  {createErrors.filterKey && (
                    <span className="field-error-text">
                      {createErrors.filterKey}
                    </span>
                  )}
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label-saas">
                      UI Filter Type
                    </label>
                    <select
                      className="form-select-saas"
                      value={createForm.filterType}
                      onChange={(e) => setCreateForm({ ...createForm, filterType: e.target.value })}
                    >
                      <option value="multiselect">Multi-Select Checkboxes</option>
                      <option value="singleselect">Single-Select Radio</option>
                      <option value="range">Numeric Range (Slider / Min-Max)</option>
                      <option value="boolean">Boolean Switch (Yes / No)</option>
                    </select>
                  </div>

                  <div className="form-group">
                    <label className="form-label-saas">
                      Unit of Measure
                      <span style={{ fontSize: '0.75rem', fontWeight: 400, color: 'var(--text-muted)', marginLeft: '0.3rem' }}>
                        (Optional)
                      </span>
                    </label>
                    <input
                      type="text"
                      className="form-input-saas"
                      placeholder="e.g. GB, MHz, W, mm"
                      value={createForm.unit}
                      onChange={(e) => setCreateForm({ ...createForm, unit: e.target.value })}
                    />
                  </div>
                </div>

                {/* Predefined Options Chip Manager */}
                <div style={{ background: '#f8fafc', border: '1px solid var(--border)', borderRadius: 'var(--radius-lg)', padding: '1rem', marginTop: '0.5rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.35rem' }}>
                    <label style={{ margin: 0, fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-main)' }}>
                      Predefined Filter Options
                    </label>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                      {createForm.options.length} added
                    </span>
                  </div>
                  <p style={{ margin: '0 0 0.75rem', fontSize: '0.78rem', color: 'var(--text-muted)' }}>
                    Add selectable options/chips for customer mobile and web catalog filtering.
                  </p>

                  <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '0.5rem' }}>
                    <input
                      id="create-option-input"
                      type="text"
                      className="form-input-saas"
                      placeholder="e.g. 144Hz, AM5, 16GB"
                      value={createOptionInput}
                      onChange={(e) => setCreateOptionInput(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          e.preventDefault();
                          handleAddCreateOption(e);
                        }
                      }}
                    />
                    <button
                      type="button"
                      className="btn btn-secondary"
                      onClick={handleAddCreateOption}
                      style={{ padding: '0 1rem', whiteSpace: 'nowrap' }}
                    >
                      + Add
                    </button>
                  </div>

                  {createForm.unit && createForm.unit.trim() && (
                    <div style={{ fontSize: '0.76rem', color: 'var(--primary)', marginBottom: '0.5rem' }}>
                      Unit of measure <strong>{createForm.unit.trim()}</strong> will be automatically appended (e.g. 100 &rarr; 100{createForm.unit.trim()}).
                    </div>
                  )}

                  {createErrors.option && (
                    <div className="field-error-text" style={{ marginBottom: '0.5rem' }}>
                      {createErrors.option}
                    </div>
                  )}

                  {createForm.options.length > 0 ? (
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem', marginTop: '0.5rem' }}>
                      {createForm.options.map((opt, idx) => (
                        <span
                          key={idx}
                          className="filter-option-chip"
                        >
                          {opt}
                          <button
                            type="button"
                            className="filter-option-chip-remove"
                            onClick={() => handleRemoveCreateOption(idx)}
                            aria-label={`Remove option ${opt}`}
                          >
                            <CloseIcon size={12} />
                          </button>
                        </span>
                      ))}
                    </div>
                  ) : (
                    <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', fontStyle: 'italic' }}>
                      No options added yet. (Options can also be harvested from product specifications).
                    </div>
                  )}
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" onClick={handleCloseCreateModal} className="btn btn-secondary" disabled={createSubmitting}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={createSubmitting} id="save-filter-submit-btn">
                  {createSubmitting ? 'Saving...' : 'Save Filter to DB'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ==================================================== */}
      {/* EDIT FILTER MODAL */}
      {/* ==================================================== */}
      {isEditModalOpen && editingFilter && (
        <div className="modal-overlay" onClick={handleCloseEditModal}>
          <div className="modal-dialog" style={{ maxWidth: '600px' }} onClick={(e) => e.stopPropagation()} id="edit-filter-modal">
            <div className="modal-header">
              <div>
                <h3 className="modal-title">Edit Master Filter</h3>
                <span className="modal-subtitle">
                  Update metadata and options for <code style={{ fontWeight: 700 }}>{editingFilter.filterKey}</code>
                </span>
              </div>
              <button onClick={handleCloseEditModal} className="modal-close-btn" aria-label="Close modal">
                <CloseIcon size={16} />
              </button>
            </div>

            <form onSubmit={handleEditSubmit}>
              <div className="modal-body">
                {editErrors.general && (
                  <div className="alert alert-error">
                    {editErrors.general}
                  </div>
                )}

                <div className="form-group">
                  <label className="form-label-saas">
                    Display Label *
                  </label>
                  <input
                    type="text"
                    className="form-input-saas"
                    value={editForm.displayName}
                    onChange={(e) => setEditForm({ ...editForm, displayName: e.target.value })}
                    required
                  />
                  {editErrors.displayName && (
                    <span className="field-error-text">
                      {editErrors.displayName}
                    </span>
                  )}
                </div>

                <div className="form-group">
                  <label className="form-label-saas">
                    System Filter Key <span style={{ fontSize: '0.75rem', fontWeight: 400, color: 'var(--text-muted)' }}>(Immutable Key)</span>
                  </label>
                  <input
                    type="text"
                    className="form-input-saas"
                    value={editingFilter.filterKey}
                    disabled
                    style={{ background: '#f8fafc', color: 'var(--text-muted)', fontFamily: 'monospace' }}
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label-saas">
                      UI Filter Type
                    </label>
                    <select
                      className="form-select-saas"
                      value={editForm.filterType}
                      onChange={(e) => setEditForm({ ...editForm, filterType: e.target.value })}
                    >
                      <option value="multiselect">Multi-Select Checkboxes</option>
                      <option value="singleselect">Single-Select Radio</option>
                      <option value="range">Numeric Range (Slider / Min-Max)</option>
                      <option value="boolean">Boolean Switch (Yes / No)</option>
                    </select>
                  </div>

                  <div className="form-group">
                    <label className="form-label-saas">
                      Unit of Measure
                    </label>
                    <input
                      type="text"
                      className="form-input-saas"
                      placeholder="e.g. GB, MHz, W"
                      value={editForm.unit}
                      onChange={(e) => setEditForm({ ...editForm, unit: e.target.value })}
                    />
                  </div>
                </div>

                {/* Predefined Options Chip Manager */}
                <div style={{ background: '#f8fafc', border: '1px solid var(--border)', borderRadius: 'var(--radius-lg)', padding: '1rem', marginTop: '0.5rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.35rem' }}>
                    <label style={{ margin: 0, fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-main)' }}>
                      Predefined Filter Options
                    </label>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                      {editForm.options.length} options
                    </span>
                  </div>

                  <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '0.5rem' }}>
                    <input
                      type="text"
                      className="form-input-saas"
                      placeholder="e.g. 144Hz, AM5, 16GB"
                      value={editOptionInput}
                      onChange={(e) => setEditOptionInput(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          e.preventDefault();
                          handleAddEditOption(e);
                        }
                      }}
                    />
                    <button
                      type="button"
                      className="btn btn-secondary"
                      onClick={handleAddEditOption}
                      style={{ padding: '0 1rem', whiteSpace: 'nowrap' }}
                    >
                      + Add
                    </button>
                  </div>

                  {editForm.unit && editForm.unit.trim() && (
                    <div style={{ fontSize: '0.76rem', color: 'var(--primary)', marginBottom: '0.5rem' }}>
                      Unit of measure <strong>{editForm.unit.trim()}</strong> will be automatically appended (e.g. 100 &rarr; 100{editForm.unit.trim()}).
                    </div>
                  )}

                  {editErrors.option && (
                    <div className="field-error-text" style={{ marginBottom: '0.5rem' }}>
                      {editErrors.option}
                    </div>
                  )}

                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem', marginTop: '0.5rem' }}>
                    {editForm.options.map((opt, idx) => (
                      <span
                        key={idx}
                        className="filter-option-chip"
                      >
                        {opt}
                        <button
                          type="button"
                          className="filter-option-chip-remove"
                          onClick={() => handleRemoveEditOption(idx)}
                          aria-label={`Remove option ${opt}`}
                        >
                          <CloseIcon size={12} />
                        </button>
                      </span>
                    ))}
                  </div>
                </div>

                <div style={{ marginTop: '1rem', padding: '0.75rem', background: 'var(--primary-light)', border: '1px solid var(--primary-border)', borderRadius: 'var(--radius-md)', fontSize: '0.8rem', color: 'var(--primary-hover)', display: 'flex', alignItems: 'flex-start', gap: '0.5rem' }}>
                  <InfoIcon size={16} color="var(--primary)" style={{ flexShrink: 0, marginTop: '2px' }} />
                  <span>Changes to Display Name, Unit, and Type will automatically sync across categories assigned this filter.</span>
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" onClick={handleCloseEditModal} className="btn btn-secondary" disabled={editSubmitting}>
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={editSubmitting}>
                  {editSubmitting ? 'Updating...' : 'Update Filter'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ==================================================== */}
      {/* DELETE CONFIRMATION MODAL */}
      {/* ==================================================== */}
      {deleteCandidate && (
        <div className="modal-overlay" onClick={handleCloseDeleteModal}>
          <div className="modal-dialog" style={{ maxWidth: '480px' }} onClick={(e) => e.stopPropagation()} id="delete-filter-modal">
            <div className="modal-header">
              <h3 className="modal-title" style={{ color: 'var(--danger-text)' }}>Delete Filter</h3>
              <button onClick={handleCloseDeleteModal} className="modal-close-btn" aria-label="Close modal">
                <CloseIcon size={16} />
              </button>
            </div>

            <div className="modal-body">
              {deleteError && (
                <div className="alert alert-error">
                  {deleteError}
                </div>
              )}

              <p style={{ margin: '0 0 1rem', fontSize: '0.9rem', color: 'var(--text-main)' }}>
                Are you sure you want to permanently delete filter{' '}
                <strong>"{deleteCandidate.displayName}"</strong> (<code>{deleteCandidate.filterKey}</code>) from the database?
              </p>

              {deleteCandidate.assignedCategoriesCount > 0 ? (
                <div style={{ padding: '0.85rem', background: 'var(--danger-light)', border: '1px solid var(--danger-border)', borderRadius: 'var(--radius-md)', color: 'var(--danger-text)', fontSize: '0.825rem' }}>
                  <strong>Warning:</strong> This filter is currently assigned to {deleteCandidate.assignedCategoriesCount} category/categories:
                  <div style={{ marginTop: '0.4rem', fontWeight: 600 }}>
                    {deleteCandidate.assignedCategoryNames.join(', ')}
                  </div>
                  <div style={{ marginTop: '0.4rem' }}>
                    You must remove this filter from these categories before deleting it from the database.
                  </div>
                </div>
              ) : (
                <div style={{ fontSize: '0.825rem', color: 'var(--text-muted)' }}>
                  This filter is currently unassigned. Deleting it will remove it from the master filter catalog.
                </div>
              )}
            </div>

            <div className="modal-footer">
              <button type="button" onClick={handleCloseDeleteModal} className="btn btn-secondary" disabled={deleteSubmitting}>
                Cancel
              </button>
              <button
                type="button"
                className="btn btn-danger"
                onClick={handleConfirmDelete}
                disabled={deleteSubmitting || deleteCandidate.assignedCategoriesCount > 0}
              >
                {deleteSubmitting ? 'Deleting...' : 'Delete Filter'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default FilterManagement;
