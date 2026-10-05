import React, { useState, useMemo, useEffect } from 'react';
import { filterService } from '../services/filterService.js';
import { CloseIcon, AlertTriangleIcon, CheckCircleIcon } from '../components/icons/index.js';

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

  // Derived Stats
  const stats = useMemo(() => {
    return filterService.calculateStats(filters);
  }, [filters]);

  // Slug generator
  const slugify = (text) => {
    return (text || '')
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '');
  };

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
    e.preventDefault();
    const opt = (createOptionInput || '').trim();
    if (!opt) return;

    if (createForm.options.some((o) => o.toLowerCase() === opt.toLowerCase())) {
      setCreateErrors((prev) => ({ ...prev, option: `Option "${opt}" is already added.` }));
      return;
    }

    setCreateForm((prev) => ({
      ...prev,
      options: [...prev.options, opt],
    }));
    setCreateOptionInput('');
    setCreateErrors((prev) => ({ ...prev, option: '' }));
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
      options: Array.isArray(filter.options) ? filter.options.map((o) => o.value) : [],
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
    e.preventDefault();
    const opt = (editOptionInput || '').trim();
    if (!opt) return;

    if (editForm.options.some((o) => o.toLowerCase() === opt.toLowerCase())) {
      setEditErrors((prev) => ({ ...prev, option: `Option "${opt}" is already added.` }));
      return;
    }

    setEditForm((prev) => ({
      ...prev,
      options: [...prev.options, opt],
    }));
    setEditOptionInput('');
    setEditErrors((prev) => ({ ...prev, option: '' }));
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
    if (t === 'multiselect') {
      return (
        <span
          style={{
            padding: '3px 8px',
            borderRadius: '12px',
            fontSize: '0.75rem',
            fontWeight: 600,
            background: '#eff6ff',
            color: '#1d4ed8',
            border: '1px solid #bfdbfe',
          }}
        >
          Multi-Select
        </span>
      );
    }
    if (t === 'singleselect') {
      return (
        <span
          style={{
            padding: '3px 8px',
            borderRadius: '12px',
            fontSize: '0.75rem',
            fontWeight: 600,
            background: '#faf5ff',
            color: '#7e22ce',
            border: '1px solid #e9d5ff',
          }}
        >
          Single-Select
        </span>
      );
    }
    if (t === 'range') {
      return (
        <span
          style={{
            padding: '3px 8px',
            borderRadius: '12px',
            fontSize: '0.75rem',
            fontWeight: 600,
            background: '#fffbeb',
            color: '#b45309',
            border: '1px solid #fde68a',
          }}
        >
          Numeric Range
        </span>
      );
    }
    if (t === 'boolean') {
      return (
        <span
          style={{
            padding: '3px 8px',
            borderRadius: '12px',
            fontSize: '0.75rem',
            fontWeight: 600,
            background: '#ecfdf5',
            color: '#047857',
            border: '1px solid #a7f3d0',
          }}
        >
          Boolean Switch
        </span>
      );
    }
    return <span className="badge badge-secondary">{type}</span>;
  };

  return (
    <div className="page-container" style={{ padding: '1.5rem 2rem' }}>
      {/* Toast Notification */}
      {notification && (
        <div
          className={`alert ${notification.type === 'error' ? 'alert-error' : 'alert-success'}`}
          style={{
            position: 'fixed',
            top: '20px',
            right: '20px',
            zIndex: 9999,
            minWidth: '320px',
            boxShadow: '0 8px 24px rgba(0,0,0,0.15)',
            display: 'flex',
            alignItems: 'center',
            gap: '0.75rem',
          }}
        >
          {notification.type === 'error' ? <AlertTriangleIcon size={18} /> : <CheckCircleIcon size={18} />}
          <div style={{ flex: 1 }}>{notification.message}</div>
          <button
            onClick={() => setNotification(null)}
            style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: 'inherit' }}
          >
            <CloseIcon size={14} />
          </button>
        </div>
      )}

      {/* Header Banner */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1.5rem', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '1.65rem', fontWeight: 800, color: 'var(--text-main)', letterSpacing: '-0.02em' }}>
            Filter Management
          </h2>
          <p style={{ margin: '0.3rem 0 0', fontSize: '0.875rem', color: 'var(--text-muted)' }}>
            Manage master hardware specifications and dynamic filter options stored in the database.
          </p>
        </div>
        <button
          id="create-filter-btn"
          className="btn btn-primary"
          onClick={handleOpenCreateModal}
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: '0.5rem',
            padding: '0.65rem 1.25rem',
            fontWeight: 600,
            borderRadius: '8px',
            boxShadow: '0 2px 8px rgba(37, 99, 235, 0.25)',
          }}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <line x1="12" y1="5" x2="12" y2="19"></line>
            <line x1="5" y1="12" x2="19" y2="12"></line>
          </svg>
          Create Filter
        </button>
      </div>

      {/* KPI Stats Cards */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))',
          gap: '1rem',
          marginBottom: '1.5rem',
        }}
      >
        <div style={{ background: '#ffffff', border: '1px solid var(--border)', borderRadius: '10px', padding: '1.15rem 1.25rem', boxShadow: '0 1px 3px rgba(0,0,0,0.04)' }}>
          <span style={{ fontSize: '0.78rem', fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Total Database Filters
          </span>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: 'var(--text-main)', marginTop: '0.35rem' }}>
            {stats.total}
          </div>
        </div>

        <div style={{ background: '#ffffff', border: '1px solid var(--border)', borderRadius: '10px', padding: '1.15rem 1.25rem', boxShadow: '0 1px 3px rgba(0,0,0,0.04)' }}>
          <span style={{ fontSize: '0.78rem', fontWeight: 600, color: '#1d4ed8', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Multi-Select Filters
          </span>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: '#1d4ed8', marginTop: '0.35rem' }}>
            {stats.multiselect}
          </div>
        </div>

        <div style={{ background: '#ffffff', border: '1px solid var(--border)', borderRadius: '10px', padding: '1.15rem 1.25rem', boxShadow: '0 1px 3px rgba(0,0,0,0.04)' }}>
          <span style={{ fontSize: '0.78rem', fontWeight: 600, color: '#7e22ce', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Single-Select Filters
          </span>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: '#7e22ce', marginTop: '0.35rem' }}>
            {stats.singleselect}
          </div>
        </div>

        <div style={{ background: '#ffffff', border: '1px solid var(--border)', borderRadius: '10px', padding: '1.15rem 1.25rem', boxShadow: '0 1px 3px rgba(0,0,0,0.04)' }}>
          <span style={{ fontSize: '0.78rem', fontWeight: 600, color: '#047857', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
            Predefined Option Values
          </span>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, color: '#047857', marginTop: '0.35rem' }}>
            {stats.totalOptions}
          </div>
        </div>
      </div>

      {/* Search & Filter Toolbar */}
      <div
        style={{
          background: '#ffffff',
          border: '1px solid var(--border)',
          borderRadius: '10px',
          padding: '1rem 1.25rem',
          marginBottom: '1.25rem',
          display: 'flex',
          alignItems: 'center',
          gap: '1rem',
          flexWrap: 'wrap',
          boxShadow: '0 1px 3px rgba(0,0,0,0.03)',
        }}
      >
        <div style={{ flex: '1 1 280px', position: 'relative' }}>
          <input
            id="filter-search-input"
            type="text"
            className="form-control"
            placeholder="Search by filter name, key (e.g. cuda_cores), or unit..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={{
              paddingLeft: '2.4rem',
              borderRadius: '8px',
              border: '1px solid var(--border)',
              height: '40px',
              fontSize: '0.875rem',
              width: '100%',
            }}
          />
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            style={{ position: 'absolute', left: '12px', top: '12px', color: 'var(--text-muted)' }}
          >
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
        </div>

        <div style={{ minWidth: '180px' }}>
          <select
            id="filter-type-select"
            className="form-control"
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
            style={{
              borderRadius: '8px',
              border: '1px solid var(--border)',
              height: '40px',
              fontSize: '0.875rem',
            }}
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
            onClick={() => {
              setSearchQuery('');
              setTypeFilter('all');
            }}
            className="btn btn-secondary-sm"
            style={{ height: '40px', borderRadius: '8px', padding: '0 1rem' }}
          >
            Reset Filters
          </button>
        )}
      </div>

      {/* Main Table */}
      <div style={{ background: '#ffffff', border: '1px solid var(--border)', borderRadius: '10px', overflow: 'hidden', boxShadow: '0 1px 4px rgba(0,0,0,0.04)' }}>
        {loading ? (
          <div style={{ padding: '3rem', textAlign: 'center', color: 'var(--text-muted)' }}>
            <div className="spinner" style={{ margin: '0 auto 1rem' }}></div>
            Loading database filters...
          </div>
        ) : filteredFilters.length === 0 ? (
          <div style={{ padding: '3.5rem 2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
            <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" style={{ margin: '0 auto 1rem', opacity: 0.5 }}>
              <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"></polygon>
            </svg>
            <h4 style={{ margin: '0 0 0.5rem', color: 'var(--text-main)', fontSize: '1.05rem' }}>No Filters Found</h4>
            <p style={{ margin: 0, fontSize: '0.875rem' }}>
              {searchQuery || typeFilter !== 'all'
                ? 'No filters matched your search criteria.'
                : 'No master filters have been created yet. Click "Create Filter" to add one.'}
            </p>
          </div>
        ) : (
          <table className="table" style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
            <thead>
              <tr style={{ background: '#f8fafc', borderBottom: '1px solid var(--border)' }}>
                <th style={{ padding: '0.85rem 1.25rem', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
                  Filter Name & Key
                </th>
                <th style={{ padding: '0.85rem 1rem', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
                  UI Type
                </th>
                <th style={{ padding: '0.85rem 1rem', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
                  Unit
                </th>
                <th style={{ padding: '0.85rem 1rem', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
                  Predefined Options
                </th>
                <th style={{ padding: '0.85rem 1rem', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
                  Assigned Categories
                </th>
                <th style={{ padding: '0.85rem 1.25rem', fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', textAlign: 'right' }}>
                  Actions
                </th>
              </tr>
            </thead>
            <tbody>
              {filteredFilters.map((f) => (
                <tr key={f.filterId} style={{ borderBottom: '1px solid var(--border)', transition: 'background 0.15s ease' }}>
                  <td style={{ padding: '1rem 1.25rem' }}>
                    <div style={{ fontWeight: 700, fontSize: '0.925rem', color: 'var(--text-main)' }}>
                      {f.displayName}
                    </div>
                    <code
                      style={{
                        display: 'inline-block',
                        background: '#f1f5f9',
                        padding: '2px 6px',
                        borderRadius: '4px',
                        fontSize: '0.75rem',
                        color: '#475569',
                        marginTop: '0.2rem',
                        fontFamily: 'monospace',
                      }}
                    >
                      {f.filterKey}
                    </code>
                  </td>

                  <td style={{ padding: '1rem 1rem' }}>{getTypeBadge(f.filterType)}</td>

                  <td style={{ padding: '1rem 1rem' }}>
                    {f.unit ? (
                      <span
                        style={{
                          background: '#f8fafc',
                          border: '1px solid #cbd5e1',
                          padding: '2px 7px',
                          borderRadius: '6px',
                          fontSize: '0.78rem',
                          fontWeight: 600,
                          color: '#334155',
                        }}
                      >
                        {f.unit}
                      </span>
                    ) : (
                      <span style={{ color: '#94a3b8', fontSize: '0.85rem' }}>—</span>
                    )}
                  </td>

                  <td style={{ padding: '1rem 1rem' }}>
                    {f.options && f.options.length > 0 ? (
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.35rem', maxWidth: '320px' }}>
                        {f.options.slice(0, 4).map((opt) => (
                          <span
                            key={opt.optionId || opt.value}
                            style={{
                              background: '#f1f5f9',
                              border: '1px solid #e2e8f0',
                              padding: '2px 8px',
                              borderRadius: '12px',
                              fontSize: '0.75rem',
                              color: '#334155',
                              fontWeight: 500,
                            }}
                          >
                            {opt.value}
                          </span>
                        ))}
                        {f.options.length > 4 && (
                          <span
                            style={{
                              background: '#e2e8f0',
                              padding: '2px 6px',
                              borderRadius: '12px',
                              fontSize: '0.72rem',
                              fontWeight: 600,
                              color: '#475569',
                            }}
                          >
                            +{f.options.length - 4} more
                          </span>
                        )}
                      </div>
                    ) : (
                      <span style={{ fontSize: '0.8rem', color: '#94a3b8', fontStyle: 'italic' }}>
                        (Harvested from products)
                      </span>
                    )}
                  </td>

                  <td style={{ padding: '1rem 1rem' }}>
                    {f.assignedCategoryNames && f.assignedCategoryNames.length > 0 ? (
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.35rem' }}>
                        {f.assignedCategoryNames.map((catName) => (
                          <span
                            key={catName}
                            style={{
                              background: '#e0f2fe',
                              border: '1px solid #bae6fd',
                              color: '#0369a1',
                              padding: '2px 8px',
                              borderRadius: '12px',
                              fontSize: '0.75rem',
                              fontWeight: 600,
                            }}
                          >
                            {catName}
                          </span>
                        ))}
                      </div>
                    ) : (
                      <span style={{ fontSize: '0.78rem', color: '#94a3b8', background: '#f8fafc', padding: '2px 8px', borderRadius: '10px' }}>
                        Not assigned
                      </span>
                    )}
                  </td>

                  <td style={{ padding: '1rem 1.25rem', textAlign: 'right' }}>
                    <div style={{ display: 'inline-flex', gap: '0.5rem' }}>
                      <button
                        className="btn btn-secondary-sm"
                        onClick={() => handleOpenEditModal(f)}
                        style={{ fontSize: '0.8rem', padding: '0.35rem 0.75rem', borderRadius: '6px' }}
                      >
                        Edit
                      </button>
                      <button
                        className="btn btn-danger-sm"
                        onClick={() => handleOpenDeleteModal(f)}
                        style={{ fontSize: '0.8rem', padding: '0.35rem 0.75rem', borderRadius: '6px' }}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* ==================================================== */}
      {/* CREATE FILTER MODAL */}
      {/* ==================================================== */}
      {isCreateModalOpen && (
        <div className="modal-backdrop" onClick={handleCloseCreateModal}>
          <div className="modal-dialog" style={{ maxWidth: '600px' }} onClick={(e) => e.stopPropagation()} id="create-filter-modal">
            <div className="modal-header">
              <div>
                <h3 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800 }}>Create Master Filter</h3>
                <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                  New technical specification attribute stored in the database
                </span>
              </div>
              <button onClick={handleCloseCreateModal} className="modal-close-btn">
                <CloseIcon size={16} />
              </button>
            </div>

            <form onSubmit={handleCreateSubmit}>
              <div className="modal-body" style={{ maxHeight: '70vh', overflowY: 'auto' }}>
                {createErrors.general && (
                  <div className="alert alert-error" style={{ marginBottom: '1rem', padding: '0.65rem 0.85rem' }}>
                    {createErrors.general}
                  </div>
                )}

                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                    Display Label <span style={{ color: '#ef4444' }}>*</span>
                  </label>
                  <input
                    id="create-display-name-input"
                    type="text"
                    className="form-control"
                    placeholder="e.g. Memory Speed, VRAM Capacity, Socket Type"
                    value={createForm.displayName}
                    onChange={handleCreateDisplayNameChange}
                    required
                  />
                  {createErrors.displayName && (
                    <span style={{ fontSize: '0.78rem', color: '#ef4444', marginTop: '0.25rem', display: 'block' }}>
                      {createErrors.displayName}
                    </span>
                  )}
                </div>

                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                    System Filter Key <span style={{ color: '#ef4444' }}>*</span>
                    <span style={{ fontSize: '0.75rem', fontWeight: 400, color: 'var(--text-muted)', marginLeft: '0.4rem' }}>
                      (auto-slugged, used in product specs & queries)
                    </span>
                  </label>
                  <input
                    id="create-filter-key-input"
                    type="text"
                    className="form-control"
                    placeholder="e.g. memory_speed, vram, socket"
                    value={createForm.filterKey}
                    onChange={(e) => setCreateForm({ ...createForm, filterKey: slugify(e.target.value) })}
                    required
                    style={{ fontFamily: 'monospace' }}
                  />
                  {createErrors.filterKey && (
                    <span style={{ fontSize: '0.78rem', color: '#ef4444', marginTop: '0.25rem', display: 'block' }}>
                      {createErrors.filterKey}
                    </span>
                  )}
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1rem' }}>
                  <div className="form-group">
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                      UI Filter Type
                    </label>
                    <select
                      className="form-control"
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
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                      Unit of Measure
                      <span style={{ fontSize: '0.75rem', fontWeight: 400, color: 'var(--text-muted)', marginLeft: '0.3rem' }}>
                        (Optional)
                      </span>
                    </label>
                    <input
                      type="text"
                      className="form-control"
                      placeholder="e.g. GB, MHz, W, mm"
                      value={createForm.unit}
                      onChange={(e) => setCreateForm({ ...createForm, unit: e.target.value })}
                    />
                  </div>
                </div>

                {/* Predefined Options Chip Manager */}
                <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: '8px', padding: '1rem', marginTop: '1.25rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
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

                  <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '0.75rem' }}>
                    <input
                      id="create-option-input"
                      type="text"
                      className="form-control"
                      placeholder="e.g. 144Hz, AM5, 16GB"
                      value={createOptionInput}
                      onChange={(e) => setCreateOptionInput(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          e.preventDefault();
                          handleAddCreateOption(e);
                        }
                      }}
                      style={{ fontSize: '0.85rem' }}
                    />
                    <button
                      type="button"
                      className="btn btn-secondary-sm"
                      onClick={handleAddCreateOption}
                      style={{ padding: '0 1.15rem', fontWeight: 600, borderRadius: '6px' }}
                    >
                      + Add
                    </button>
                  </div>

                  {createErrors.option && (
                    <div style={{ fontSize: '0.78rem', color: '#ef4444', marginBottom: '0.5rem' }}>
                      {createErrors.option}
                    </div>
                  )}

                  {createForm.options.length > 0 ? (
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem', marginTop: '0.5rem' }}>
                      {createForm.options.map((opt, idx) => (
                        <span
                          key={idx}
                          style={{
                            background: '#ffffff',
                            border: '1px solid #cbd5e1',
                            borderRadius: '16px',
                            padding: '4px 10px',
                            fontSize: '0.8rem',
                            fontWeight: 600,
                            color: '#1e293b',
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '0.35rem',
                          }}
                        >
                          {opt}
                          <button
                            type="button"
                            onClick={() => handleRemoveCreateOption(idx)}
                            style={{
                              background: 'none',
                              border: 'none',
                              cursor: 'pointer',
                              padding: 0,
                              color: '#94a3b8',
                              display: 'inline-flex',
                              alignItems: 'center',
                            }}
                          >
                            <CloseIcon size={12} />
                          </button>
                        </span>
                      ))}
                    </div>
                  ) : (
                    <div style={{ fontSize: '0.78rem', color: '#94a3b8', fontStyle: 'italic' }}>
                      No options added yet. (Options can also be harvested from product specifications).
                    </div>
                  )}
                </div>
              </div>

              <div className="modal-footer" style={{ borderTop: '1px solid var(--border)', background: '#f8fafc', padding: '0.85rem 1.5rem', display: 'flex', justifyContent: 'flex-end', gap: '0.75rem' }}>
                <button type="button" onClick={handleCloseCreateModal} className="btn btn-secondary-sm" disabled={createSubmitting}>
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
        <div className="modal-backdrop" onClick={handleCloseEditModal}>
          <div className="modal-dialog" style={{ maxWidth: '600px' }} onClick={(e) => e.stopPropagation()} id="edit-filter-modal">
            <div className="modal-header">
              <div>
                <h3 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800 }}>Edit Master Filter</h3>
                <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                  Update metadata and options for <code style={{ fontWeight: 700 }}>{editingFilter.filterKey}</code>
                </span>
              </div>
              <button onClick={handleCloseEditModal} className="modal-close-btn">
                <CloseIcon size={16} />
              </button>
            </div>

            <form onSubmit={handleEditSubmit}>
              <div className="modal-body" style={{ maxHeight: '70vh', overflowY: 'auto' }}>
                {editErrors.general && (
                  <div className="alert alert-error" style={{ marginBottom: '1rem', padding: '0.65rem 0.85rem' }}>
                    {editErrors.general}
                  </div>
                )}

                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                    Display Label <span style={{ color: '#ef4444' }}>*</span>
                  </label>
                  <input
                    type="text"
                    className="form-control"
                    value={editForm.displayName}
                    onChange={(e) => setEditForm({ ...editForm, displayName: e.target.value })}
                    required
                  />
                  {editErrors.displayName && (
                    <span style={{ fontSize: '0.78rem', color: '#ef4444', marginTop: '0.25rem', display: 'block' }}>
                      {editErrors.displayName}
                    </span>
                  )}
                </div>

                <div className="form-group" style={{ marginBottom: '1rem' }}>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                    System Filter Key <span style={{ fontSize: '0.75rem', fontWeight: 400, color: 'var(--text-muted)' }}>(Immutable Key)</span>
                  </label>
                  <input
                    type="text"
                    className="form-control"
                    value={editingFilter.filterKey}
                    disabled
                    style={{ background: '#f8fafc', color: '#64748b', fontFamily: 'monospace' }}
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1rem' }}>
                  <div className="form-group">
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                      UI Filter Type
                    </label>
                    <select
                      className="form-control"
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
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                      Unit of Measure
                    </label>
                    <input
                      type="text"
                      className="form-control"
                      placeholder="e.g. GB, MHz, W"
                      value={editForm.unit}
                      onChange={(e) => setEditForm({ ...editForm, unit: e.target.value })}
                    />
                  </div>
                </div>

                {/* Predefined Options Chip Manager */}
                <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: '8px', padding: '1rem', marginTop: '1.25rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.5rem' }}>
                    <label style={{ margin: 0, fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-main)' }}>
                      Predefined Filter Options
                    </label>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                      {editForm.options.length} options
                    </span>
                  </div>

                  <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '0.75rem' }}>
                    <input
                      type="text"
                      className="form-control"
                      placeholder="e.g. 144Hz, AM5, 16GB"
                      value={editOptionInput}
                      onChange={(e) => setEditOptionInput(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          e.preventDefault();
                          handleAddEditOption(e);
                        }
                      }}
                      style={{ fontSize: '0.85rem' }}
                    />
                    <button
                      type="button"
                      className="btn btn-secondary-sm"
                      onClick={handleAddEditOption}
                      style={{ padding: '0 1.15rem', fontWeight: 600, borderRadius: '6px' }}
                    >
                      + Add
                    </button>
                  </div>

                  {editErrors.option && (
                    <div style={{ fontSize: '0.78rem', color: '#ef4444', marginBottom: '0.5rem' }}>
                      {editErrors.option}
                    </div>
                  )}

                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem', marginTop: '0.5rem' }}>
                    {editForm.options.map((opt, idx) => (
                      <span
                        key={idx}
                        style={{
                          background: '#ffffff',
                          border: '1px solid #cbd5e1',
                          borderRadius: '16px',
                          padding: '4px 10px',
                          fontSize: '0.8rem',
                          fontWeight: 600,
                          color: '#1e293b',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '0.35rem',
                        }}
                      >
                        {opt}
                        <button
                          type="button"
                          onClick={() => handleRemoveEditOption(idx)}
                          style={{
                            background: 'none',
                            border: 'none',
                            cursor: 'pointer',
                            padding: 0,
                            color: '#94a3b8',
                            display: 'inline-flex',
                            alignItems: 'center',
                          }}
                        >
                          <CloseIcon size={12} />
                        </button>
                      </span>
                    ))}
                  </div>
                </div>

                <div style={{ marginTop: '1rem', padding: '0.75rem', background: '#eff6ff', borderRadius: '6px', fontSize: '0.8rem', color: '#1e40af' }}>
                  ℹ️ Changes to Display Name, Unit, and Type will automatically sync across categories assigned this filter.
                </div>
              </div>

              <div className="modal-footer" style={{ borderTop: '1px solid var(--border)', background: '#f8fafc', padding: '0.85rem 1.5rem', display: 'flex', justifyContent: 'flex-end', gap: '0.75rem' }}>
                <button type="button" onClick={handleCloseEditModal} className="btn btn-secondary-sm" disabled={editSubmitting}>
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
        <div className="modal-backdrop" onClick={handleCloseDeleteModal}>
          <div className="modal-dialog" style={{ maxWidth: '480px' }} onClick={(e) => e.stopPropagation()} id="delete-filter-modal">
            <div className="modal-header">
              <h3 style={{ margin: 0, fontSize: '1.15rem', color: '#dc2626' }}>Delete Filter</h3>
              <button onClick={handleCloseDeleteModal} className="modal-close-btn">
                <CloseIcon size={16} />
              </button>
            </div>

            <div className="modal-body">
              {deleteError && (
                <div className="alert alert-error" style={{ marginBottom: '1rem', padding: '0.65rem 0.85rem' }}>
                  {deleteError}
                </div>
              )}

              <p style={{ margin: '0 0 1rem', fontSize: '0.9rem', color: 'var(--text-main)' }}>
                Are you sure you want to permanently delete filter{' '}
                <strong>"{deleteCandidate.displayName}"</strong> (<code>{deleteCandidate.filterKey}</code>) from the database?
              </p>

              {deleteCandidate.assignedCategoriesCount > 0 ? (
                <div style={{ padding: '0.85rem', background: '#fff1f2', border: '1px solid #fecdd3', borderRadius: '8px', color: '#9f1239', fontSize: '0.825rem' }}>
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

            <div className="modal-footer" style={{ borderTop: '1px solid var(--border)', background: '#f8fafc', padding: '0.85rem 1.5rem', display: 'flex', justifyContent: 'flex-end', gap: '0.75rem' }}>
              <button type="button" onClick={handleCloseDeleteModal} className="btn btn-secondary-sm" disabled={deleteSubmitting}>
                Cancel
              </button>
              <button
                type="button"
                className="btn btn-danger-sm"
                onClick={handleConfirmDelete}
                disabled={deleteSubmitting || deleteCandidate.assignedCategoriesCount > 0}
                style={{ padding: '0.5rem 1.15rem', fontWeight: 600 }}
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
