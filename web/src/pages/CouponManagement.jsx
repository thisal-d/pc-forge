import React, { useState, useEffect, useMemo } from 'react';
import { couponService } from '../services/couponService.js';
import { Pagination } from '../components/common/Pagination.jsx';
import { TableSkeleton } from '../components/common/TableSkeleton.jsx';
import { CloseIcon } from '../components/icons/index.js';
import '../styles/pages/coupons.css';

export const CouponManagement = () => {
  const [coupons, setCoupons] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  // Filters & Sorting
  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [sortBy, setSortBy] = useState('code-asc');

  // Pagination
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // Modals
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [currentCoupon, setCurrentCoupon] = useState(null);
  const [deleteCandidate, setDeleteCandidate] = useState(null);

  // Form State
  const [formData, setFormData] = useState({
    code: '',
    description: '',
    discountType: 'PERCENTAGE',
    discountValue: '',
    minSubtotal: '',
    maxDiscount: '',
    isActive: true,
  });
  const [formSubmitting, setFormSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  // Notification & Load Error State
  const [notification, setNotification] = useState(null);
  const [loadError, setLoadError] = useState(null);

  const showNotification = (arg1, arg2 = 'success') => {
    let type = 'success';
    let message = '';
    if (['success', 'error', 'info', 'warning'].includes(arg1)) {
      type = arg1;
      message = arg2;
    } else if (['success', 'error', 'info', 'warning'].includes(arg2)) {
      type = arg2;
      message = arg1;
    } else {
      message = arg1 || 'Notification';
    }
    setNotification({ type, message });
    setTimeout(() => setNotification(null), 4500);
  };
  const showToast = showNotification;

  // Load coupons from backend
  const loadCoupons = async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);
    setLoadError(null);

    try {
      const data = await couponService.getCoupons({
        search: searchQuery,
      });
      setCoupons(Array.isArray(data) ? data : []);
      if (isRefresh) {
        showNotification('success', 'Coupons refreshed successfully.');
      }
    } catch (err) {
      console.error('Failed to load coupons:', err);
      const errMsg = err?.response?.data?.message || err?.message || 'Failed to load coupons from backend.';
      setLoadError(errMsg);
      showNotification('error', `Failed to load coupons from backend: ${errMsg}`);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    loadCoupons();
  }, []);

  // Reset pagination on filter changes
  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, typeFilter, statusFilter, sortBy]);

  // Filtered and sorted coupons
  const filteredCoupons = useMemo(() => {
    const list = coupons.filter((c) => {
      if (!c) return false;
      const cType = (c.discountType || 'PERCENTAGE').toUpperCase();
      // Type filter
      if (typeFilter !== 'all' && cType !== typeFilter.toUpperCase()) {
        return false;
      }
      // Status filter
      if (statusFilter === 'active' && !c.isActive) return false;
      if (statusFilter === 'inactive' && c.isActive) return false;

      // Search query (client filter for instant reactivity)
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const codeMatch = (c.code || '').toLowerCase().includes(q);
        const descMatch = (c.description || '').toLowerCase().includes(q);
        if (!codeMatch && !descMatch) return false;
      }

      return true;
    });

    return [...list].sort((a, b) => {
      if (sortBy === 'code-asc') return (a.code || '').localeCompare(b.code || '');
      if (sortBy === 'code-desc') return (b.code || '').localeCompare(a.code || '');
      if (sortBy === 'discount-desc') return (Number(b.discountValue) || 0) - (Number(a.discountValue) || 0);
      if (sortBy === 'discount-asc') return (Number(a.discountValue) || 0) - (Number(b.discountValue) || 0);
      return 0;
    });
  }, [coupons, typeFilter, statusFilter, searchQuery, sortBy]);

  const totalPages = Math.ceil(filteredCoupons.length / pageSize) || 1;
  const paginatedCoupons = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredCoupons.slice(start, start + pageSize);
  }, [filteredCoupons, currentPage, pageSize]);

  // KPIs
  const kpis = useMemo(() => {
    const total = coupons.length;
    const active = coupons.filter((c) => Boolean(c?.isActive)).length;
    const inactive = total - active;
    const percentageCount = coupons.filter((c) => (c?.discountType || '').toUpperCase() === 'PERCENTAGE').length;
    return { total, active, inactive, percentageCount };
  }, [coupons]);

  // Open Create Modal
  const handleOpenCreate = () => {
    setIsEditing(false);
    setCurrentCoupon(null);
    setFormData({
      code: '',
      description: '',
      discountType: 'PERCENTAGE',
      discountValue: '10',
      minSubtotal: '50000',
      maxDiscount: '15000',
      isActive: true,
    });
    setFormError('');
    setIsModalOpen(true);
  };

  // Open Edit Modal
  const handleOpenEdit = (coupon) => {
    setIsEditing(true);
    setCurrentCoupon(coupon);
    setFormData({
      code: coupon.code,
      description: coupon.description,
      discountType: coupon.discountType,
      discountValue: coupon.discountValue.toString(),
      minSubtotal: coupon.minSubtotal ? coupon.minSubtotal.toString() : '0',
      maxDiscount: coupon.maxDiscount ? coupon.maxDiscount.toString() : '',
      isActive: coupon.isActive,
    });
    setFormError('');
    setIsModalOpen(true);
  };

  // Submit Form (Create or Edit)
  const handleFormSubmit = async (e) => {
    e.preventDefault();
    setFormError('');

    const codeClean = formData.code.trim().toUpperCase();
    if (!codeClean) {
      setFormError('Coupon code is required.');
      return;
    }
    if (codeClean.length < 3) {
      setFormError('Coupon code must be at least 3 characters long.');
      return;
    }
    if (!/^[A-Z0-9_-]+$/.test(codeClean)) {
      setFormError('Coupon code can only contain uppercase letters, numbers, hyphens, and underscores.');
      return;
    }
    if (!formData.description.trim()) {
      setFormError('Campaign description is required.');
      return;
    }
    const val = parseFloat(formData.discountValue);
    if (isNaN(val) || val <= 0) {
      setFormError('Discount value must be greater than 0.');
      return;
    }
    if (formData.discountType === 'PERCENTAGE' && val > 100) {
      setFormError('Percentage discount cannot exceed 100%.');
      return;
    }
    if (formData.minSubtotal && parseFloat(formData.minSubtotal) < 0) {
      setFormError('Minimum subtotal cannot be negative.');
      return;
    }
    if (formData.maxDiscount && parseFloat(formData.maxDiscount) <= 0) {
      setFormError('Maximum discount cap must be greater than 0.');
      return;
    }

    setFormSubmitting(true);

    try {
      const payload = {
        code: formData.code.trim().toUpperCase(),
        description: formData.description.trim(),
        discountType: formData.discountType,
        discountValue: val,
        minSubtotal: formData.minSubtotal ? parseFloat(formData.minSubtotal) : 0,
        maxDiscount: formData.maxDiscount ? parseFloat(formData.maxDiscount) : null,
        isActive: formData.isActive,
      };

      if (isEditing && currentCoupon) {
        await couponService.updateCoupon(currentCoupon.couponId, payload);
        showNotification('success', `Coupon "${payload.code}" updated successfully.`);
      } else {
        await couponService.createCoupon(payload);
        showNotification('success', `Coupon "${payload.code}" created successfully.`);
      }

      setIsModalOpen(false);
      loadCoupons(true);
    } catch (err) {
      setFormError(err.message || 'Operation failed.');
    } finally {
      setFormSubmitting(false);
    }
  };

  // Toggle active/inactive
  const handleToggleStatus = async (coupon) => {
    try {
      const updated = await couponService.toggleStatus(coupon.couponId);
      setCoupons((prev) =>
        prev.map((c) => (c.couponId === coupon.couponId ? { ...c, isActive: updated.isActive } : c))
      );
      showNotification(
        'success',
        `Coupon "${coupon.code}" status set to ${updated.isActive ? 'Active' : 'Inactive'}.`
      );
    } catch (err) {
      showNotification('error', err.message || 'Failed to toggle coupon status.');
    }
  };

  // Delete Coupon
  const handleDeleteConfirm = async () => {
    if (!deleteCandidate) return;

    try {
      await couponService.deleteCoupon(deleteCandidate.couponId);
      setCoupons((prev) => prev.filter((c) => c.couponId !== deleteCandidate.couponId));
      showNotification('success', `Coupon "${deleteCandidate.code}" deleted successfully.`);
      setDeleteCandidate(null);
    } catch (err) {
      showNotification('error', err.message || 'Failed to delete coupon.');
    }
  };

  return (
    <div className="page-container">
      {/* Header */}
      <div className="dashboard-header">
        <div>
          <h1>Promotions & Coupons</h1>
          <p className="subtitle">
            Configure store vouchers, discount rates, and spend thresholds. Synced live with PostgreSQL and the AI Order Planning Agent.
          </p>
        </div>
        <div className="header-actions">
          <button
            type="button"
            className="btn btn-outline"
            onClick={() => loadCoupons(true)}
            disabled={refreshing}
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67" />
            </svg>
            <span>{refreshing ? 'Refreshing...' : 'Refresh'}</span>
          </button>
          <button type="button" className="btn btn-primary" onClick={handleOpenCreate}>
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="12" y1="5" x2="12" y2="19" />
              <line x1="5" y1="12" x2="19" y2="12" />
            </svg>
            <span>Create Coupon</span>
          </button>
        </div>
      </div>

      {/* Standard Notification Banner */}
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

      {/* KPI Stats Cards */}
      <div className="stats-grid">
        <div className="stat-card stat-card-total">
          <div className="metric-card-top">
            <div className="metric-icon-circle icon-circle-blue">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" />
                <line x1="7" y1="7" x2="7.01" y2="7" />
              </svg>
            </div>
            <div className="metric-details">
              <span className="stat-label">Total Coupons</span>
              <span className="stat-value">{kpis.total}</span>
              <span className="stat-subtext">Configured vouchers</span>
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
              <span className="stat-label">Active Campaigns</span>
              <span className="stat-value">{kpis.active}</span>
              <span className="stat-subtext">Usable at checkout</span>
            </div>
          </div>
        </div>

        <div className="stat-card stat-card-inactive">
          <div className="metric-card-top">
            <div className="metric-icon-circle icon-circle-amber">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <line x1="10" y1="15" x2="10" y2="9" />
                <line x1="14" y1="15" x2="14" y2="9" />
              </svg>
            </div>
            <div className="metric-details">
              <span className="stat-label">Paused / Inactive</span>
              <span className="stat-value">{kpis.inactive}</span>
              <span className="stat-subtext">Temporarily inactive</span>
            </div>
          </div>
        </div>

        <div className="stat-card stat-card-tech">
          <div className="metric-card-top">
            <div className="metric-icon-circle icon-circle-purple">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
                <line x1="8" y1="21" x2="16" y2="21" />
                <line x1="12" y1="17" x2="12" y2="21" />
              </svg>
            </div>
            <div className="metric-details">
              <span className="stat-label">AI Agent Integration</span>
              <span className="stat-value" style={{ fontSize: '1.25rem', color: 'var(--accent-purple)' }}>
                Order Agent
              </span>
              <span className="stat-subtext">LangGraph live sync</span>
            </div>
          </div>
        </div>
      </div>

      {/* Toolbar & Filters */}
      <div className="toolbar-card">
        <div className="search-filter-row">
          <div className="toolbar-search-wrapper">
            <span className="toolbar-search-icon">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="11" cy="11" r="8" />
                <line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
            </span>
            <input
              type="text"
              className="toolbar-search-input"
              placeholder="Search coupon code or description..."
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
                className="toolbar-select"
                value={typeFilter}
                onChange={(e) => setTypeFilter(e.target.value)}
              >
                <option value="all">All Discount Types</option>
                <option value="PERCENTAGE">Percentage (%)</option>
                <option value="FLAT">Flat Amount (Rs.)</option>
              </select>
            </div>

            <div className="toolbar-select-item">
              <select
                className="toolbar-select"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
              >
                <option value="all">All Statuses</option>
                <option value="active">Active Only</option>
                <option value="inactive">Inactive Only</option>
              </select>
            </div>

            <div className="toolbar-select-item">
              <select
                className="toolbar-select"
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
              >
                <option value="code-asc">Sort: Code (A-Z)</option>
                <option value="code-desc">Sort: Code (Z-A)</option>
                <option value="discount-desc">Sort: Discount (High-Low)</option>
                <option value="discount-asc">Sort: Discount (Low-High)</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      {/* Table */}
      <div className="data-table-card">
        <div className="table-header-banner">
          <h3>Promotional Vouchers ({filteredCoupons.length})</h3>
          <span className="table-header-subtitle">
            Showing {paginatedCoupons.length} of {coupons.length} configured vouchers
          </span>
        </div>
        <div className="table-responsive">
          <table className="data-table coupons-table" id="coupons-table">
            <thead>
              <tr>
                <th>Coupon Code</th>
                <th>Description</th>
                <th>Discount Rate</th>
                <th>Min Subtotal</th>
                <th>Max Cap</th>
                <th>Status</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            {loading ? (
              <TableSkeleton rows={pageSize} columns={7} />
            ) : filteredCoupons.length === 0 ? (
              <tbody>
                <tr>
                  <td colSpan="7" style={{ padding: 0 }}>
                    {loadError ? (
                      <div className="empty-state error-state" style={{ padding: '40px 24px', textAlign: 'center' }}>
                        <div className="empty-state-icon" style={{ color: 'var(--danger)', marginBottom: '12px' }}>
                          <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <circle cx="12" cy="12" r="10" />
                            <line x1="12" y1="8" x2="12" y2="12" />
                            <line x1="12" y1="16" x2="12.01" y2="16" />
                          </svg>
                        </div>
                        <h4 style={{ color: 'var(--danger-text)', marginBottom: '6px' }}>Failed to load coupons from backend</h4>
                        <p style={{ color: 'var(--text-muted)', maxWidth: '440px', margin: '0 auto 16px', fontSize: '13px' }}>
                          {loadError}. Please verify that the backend API server is running on port 5000 and try again.
                        </p>
                        <button
                          type="button"
                          className="btn btn-primary"
                          onClick={() => loadCoupons(true)}
                          disabled={refreshing}
                        >
                          {refreshing ? 'Retrying...' : 'Retry Connection'}
                        </button>
                      </div>
                    ) : (
                      <div className="empty-state">
                        <div className="empty-state-icon">
                          <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
                            <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" />
                            <line x1="7" y1="7" x2="7.01" y2="7" />
                          </svg>
                        </div>
                        <h4>No coupons found</h4>
                        <p>Try clearing your filters or create a new coupon.</p>
                        <button
                          type="button"
                          className="btn btn-outline-sm"
                          onClick={() => {
                            setSearchQuery('');
                            setTypeFilter('all');
                            setStatusFilter('all');
                            setSortBy('code-asc');
                          }}
                        >
                          Clear Filters
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              </tbody>
            ) : (
              <tbody>
                {paginatedCoupons.map((coupon) => (
                  <tr key={coupon.couponId}>
                    <td>
                      <span className="coupon-code-badge">
                        {coupon.code}
                      </span>
                    </td>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>{coupon.description}</div>
                    </td>
                    <td>
                      {(coupon.discountType || 'PERCENTAGE').toUpperCase() === 'PERCENTAGE' ? (
                        <span className="discount-rate-badge percentage">
                          {coupon.discountValue}% OFF
                        </span>
                      ) : (
                        <span className="discount-rate-badge flat">
                          Rs. {Number(coupon.discountValue).toLocaleString()} FLAT
                        </span>
                      )}
                    </td>
                    <td>
                      {coupon.minSubtotal && Number(coupon.minSubtotal) > 0
                        ? `Rs. ${Number(coupon.minSubtotal).toLocaleString()}`
                        : 'None (Rs. 0)'}
                    </td>
                    <td>
                      {coupon.maxDiscount && Number(coupon.maxDiscount) > 0
                        ? `Rs. ${Number(coupon.maxDiscount).toLocaleString()}`
                        : 'No Limit'}
                    </td>
                    <td>
                      <button
                        className={`status-pill ${coupon.isActive ? 'status-pill-in' : 'status-pill-low'}`}
                        style={{ border: 'none', cursor: 'pointer' }}
                        onClick={() => handleToggleStatus(coupon)}
                        title="Click to toggle status"
                      >
                        <span className="status-dot"></span>
                        <span>{coupon.isActive ? 'Active' : 'Inactive'}</span>
                      </button>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <div className="coupon-actions" style={{ justifyContent: 'flex-end' }}>
                        <button
                          className="btn btn-outline-sm"
                          title="Edit Coupon"
                          onClick={() => handleOpenEdit(coupon)}
                        >
                          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                            <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                          </svg>
                        </button>
                        <button
                          className="btn btn-danger-sm"
                          title="Delete Coupon"
                          onClick={() => setDeleteCandidate(coupon)}
                        >
                          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <polyline points="3 6 5 6 21 6" />
                            <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
                          </svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            )}
          </table>
        </div>
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          totalItems={filteredCoupons.length}
          pageSize={pageSize}
          onPageChange={setCurrentPage}
          onPageSizeChange={(newSize) => {
            setPageSize(newSize);
            setCurrentPage(1);
          }}
          itemLabel="coupons"
        />
      </div>

      {/* Create / Edit Modal */}
      {isModalOpen && (
        <div className="modal-overlay" onClick={() => setIsModalOpen(false)}>
          <div className="modal-dialog" style={{ maxWidth: '580px' }} onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <div>
                <h3 className="modal-title">
                  {isEditing ? `Edit Coupon: ${currentCoupon?.code}` : 'Create New Promotional Coupon'}
                </h3>
                <span className="modal-subtitle">Configure discount parameters and checkout eligibility</span>
              </div>
              <button className="modal-close-btn" onClick={() => setIsModalOpen(false)} aria-label="Close modal">
                <CloseIcon size={16} />
              </button>
            </div>

            <form onSubmit={handleFormSubmit}>
              <div className="modal-body">
                {formError && (
                  <div className="alert alert-error" style={{ marginBottom: '1rem' }}>
                    {formError}
                  </div>
                )}

                <div className="form-group">
                  <label className="form-label-saas">Coupon Code (Uppercase) *</label>
                  <input
                    type="text"
                    className="form-input-saas"
                    placeholder="e.g. FORGE10"
                    value={formData.code}
                    disabled={isEditing}
                    onChange={(e) => setFormData({ ...formData, code: e.target.value.toUpperCase() })}
                    required
                  />
                  <div className="form-help-text">
                    Unique uppercase voucher code that customers apply in checkout.
                  </div>
                </div>

                <div className="form-group">
                  <label className="form-label-saas">Campaign Description *</label>
                  <input
                    type="text"
                    className="form-input-saas"
                    placeholder="e.g. 10% Custom Rig Hardware Discount"
                    value={formData.description}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                    required
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label-saas">Discount Type</label>
                    <select
                      className="form-select-saas"
                      value={formData.discountType}
                      onChange={(e) => setFormData({ ...formData, discountType: e.target.value })}
                    >
                      <option value="PERCENTAGE">Percentage (%)</option>
                      <option value="FLAT">Flat Amount (Rs.)</option>
                    </select>
                  </div>

                  <div className="form-group">
                    <label className="form-label-saas">
                      {formData.discountType === 'PERCENTAGE' ? 'Discount Percentage (%) *' : 'Discount Amount (Rs.) *'}
                    </label>
                    <input
                      type="number"
                      step="0.01"
                      className="form-input-saas"
                      placeholder={formData.discountType === 'PERCENTAGE' ? '10' : '10000'}
                      value={formData.discountValue}
                      onChange={(e) => setFormData({ ...formData, discountValue: e.target.value })}
                      required
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                  <div className="form-group">
                    <label className="form-label-saas">Min Subtotal (Rs.)</label>
                    <input
                      type="number"
                      step="1"
                      className="form-input-saas"
                      placeholder="e.g. 50000 (0 for no min)"
                      value={formData.minSubtotal}
                      onChange={(e) => setFormData({ ...formData, minSubtotal: e.target.value })}
                    />
                    <div className="form-help-text">Cart must reach this amount to qualify.</div>
                  </div>

                  <div className="form-group">
                    <label className="form-label-saas">Max Discount Cap (Rs.)</label>
                    <input
                      type="number"
                      step="1"
                      className="form-input-saas"
                      placeholder="e.g. 15000 (optional)"
                      value={formData.maxDiscount}
                      onChange={(e) => setFormData({ ...formData, maxDiscount: e.target.value })}
                    />
                    <div className="form-help-text">Ceiling on percentage deductions.</div>
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem', marginTop: '0.5rem' }}>
                  <input
                    type="checkbox"
                    id="isActiveCoupon"
                    checked={formData.isActive}
                    onChange={(e) => setFormData({ ...formData, isActive: e.target.checked })}
                    style={{ width: '16px', height: '16px', cursor: 'pointer', accentColor: 'var(--primary)' }}
                  />
                  <label htmlFor="isActiveCoupon" style={{ fontSize: '0.875rem', fontWeight: 600, color: 'var(--text-main)', cursor: 'pointer' }}>
                    Active and usable by customers immediately
                  </label>
                </div>

                {/* Real-time receipt simulation */}
                <div className="receipt-preview-card">
                  <div className="receipt-preview-title">Receipt Calculation Simulation</div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem', color: 'var(--text-body)' }}>
                    <span>Example Subtotal:</span>
                    <span>Rs. 150,000</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem', color: 'var(--success-text)', fontWeight: 700, marginTop: '0.25rem' }}>
                    <span>Discount ({formData.code || 'CODE'}):</span>
                    <span>
                      - Rs.{' '}
                      {formData.discountType === 'PERCENTAGE'
                        ? Math.min(
                            Math.round(150000 * ((parseFloat(formData.discountValue) || 0) / 100)),
                            parseFloat(formData.maxDiscount) || 999999
                          ).toLocaleString()
                        : (parseFloat(formData.discountValue) || 0).toLocaleString()}
                    </span>
                  </div>
                </div>
              </div>

              <div className="modal-footer">
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setIsModalOpen(false)}
                  disabled={formSubmitting}
                >
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={formSubmitting}>
                  {formSubmitting ? 'Saving...' : isEditing ? 'Update Coupon' : 'Create Coupon'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {deleteCandidate && (
        <div className="modal-overlay" onClick={() => setDeleteCandidate(null)}>
          <div className="modal-dialog" style={{ maxWidth: '440px' }} onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title" style={{ color: 'var(--danger-text)' }}>Delete Coupon?</h3>
              <button className="modal-close-btn" onClick={() => setDeleteCandidate(null)} aria-label="Close modal">
                <CloseIcon size={16} />
              </button>
            </div>
            <div className="modal-body">
              <p style={{ margin: 0, color: 'var(--text-body)', fontSize: '0.875rem', lineHeight: 1.5 }}>
                Are you sure you want to permanently delete coupon <strong>"{deleteCandidate.code}"</strong>? Customers will no longer be able to use it in checkout proposals.
              </p>
            </div>
            <div className="modal-footer">
              <button type="button" className="btn btn-secondary" onClick={() => setDeleteCandidate(null)}>
                Cancel
              </button>
              <button
                type="button"
                className="btn btn-danger"
                onClick={handleDeleteConfirm}
              >
                Delete Coupon
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default CouponManagement;

