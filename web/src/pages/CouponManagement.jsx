import React, { useState, useEffect, useMemo } from 'react';
import { couponService } from '../services/couponService.js';
import { Pagination } from '../components/common/Pagination.jsx';
import { TableSkeleton } from '../components/common/TableSkeleton.jsx';
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

  // Toast
  const [toast, setToast] = useState(null);

  const showToast = (message, type = 'success') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 4000);
  };

  // Load coupons from backend
  const loadCoupons = async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);

    try {
      const data = await couponService.getCoupons({
        search: searchQuery,
      });
      setCoupons(data);
    } catch (err) {
      console.error('Failed to load coupons:', err);
      showToast('Failed to load coupons from backend.', 'error');
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
      // Type filter
      if (typeFilter !== 'all' && c.discountType.toUpperCase() !== typeFilter.toUpperCase()) {
        return false;
      }
      // Status filter
      if (statusFilter === 'active' && !c.isActive) return false;
      if (statusFilter === 'inactive' && c.isActive) return false;

      // Search query (client filter for instant reactivity)
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const codeMatch = c.code.toLowerCase().includes(q);
        const descMatch = c.description.toLowerCase().includes(q);
        if (!codeMatch && !descMatch) return false;
      }

      return true;
    });

    return [...list].sort((a, b) => {
      if (sortBy === 'code-asc') return a.code.localeCompare(b.code);
      if (sortBy === 'code-desc') return b.code.localeCompare(a.code);
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
    const active = coupons.filter((c) => c.isActive).length;
    const inactive = total - active;
    const percentageCount = coupons.filter((c) => c.discountType.toUpperCase() === 'PERCENTAGE').length;
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

    if (!formData.code.trim()) {
      setFormError('Coupon code is required.');
      return;
    }
    if (!formData.description.trim()) {
      setFormError('Description is required.');
      return;
    }
    const val = parseFloat(formData.discountValue);
    if (isNaN(val) || val <= 0) {
      setFormError('Discount value must be greater than 0.');
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
        showToast(`Coupon "${payload.code}" updated successfully!`);
      } else {
        await couponService.createCoupon(payload);
        showToast(`Coupon "${payload.code}" created and live in PostgreSQL!`);
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
      showToast(
        `Coupon "${coupon.code}" is now ${updated.isActive ? 'Active' : 'Inactive'}.`
      );
    } catch (err) {
      showToast(err.message || 'Failed to toggle coupon status.', 'error');
    }
  };

  // Delete Coupon
  const handleDeleteConfirm = async () => {
    if (!deleteCandidate) return;

    try {
      await couponService.deleteCoupon(deleteCandidate.couponId);
      setCoupons((prev) => prev.filter((c) => c.couponId !== deleteCandidate.couponId));
      showToast(`Coupon "${deleteCandidate.code}" deleted.`);
      setDeleteCandidate(null);
    } catch (err) {
      showToast(err.message || 'Failed to delete coupon.', 'error');
    }
  };

  return (
    <div className="coupons-page">
      {/* Toast Notification */}
      {toast && (
        <div className={`coupons-toast ${toast.type}`}>
          <span>{toast.message}</span>
        </div>
      )}

      {/* Header */}
      <div className="coupons-header">
        <div>
          <h1 className="coupons-header-title">Promotions & Coupons</h1>
          <p className="coupons-header-subtitle">
            Configure store vouchers, discount rates, and spend thresholds. Synced live with PostgreSQL and the AI Order Planning Agent.
          </p>
        </div>
        <div className="coupons-header-actions">
          <button
            className="btn-secondary"
            onClick={() => loadCoupons(true)}
            disabled={refreshing}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67" />
            </svg>
            {refreshing ? 'Refreshing...' : 'Refresh'}
          </button>
          <button className="btn-primary" onClick={handleOpenCreate}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="12" y1="5" x2="12" y2="19" />
              <line x1="5" y1="12" x2="19" y2="12" />
            </svg>
            Create Coupon
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="coupons-kpi-grid">
        <div className="coupons-kpi-card">
          <div className="coupons-kpi-icon indigo">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" />
              <line x1="7" y1="7" x2="7.01" y2="7" />
            </svg>
          </div>
          <div className="coupons-kpi-content">
            <div className="coupons-kpi-label">Total Coupons</div>
            <div className="coupons-kpi-value">{kpis.total}</div>
            <div className="coupons-kpi-subtext">Configured store vouchers</div>
          </div>
        </div>

        <div className="coupons-kpi-card">
          <div className="coupons-kpi-icon green">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <polyline points="20 6 9 17 4 12" />
            </svg>
          </div>
          <div className="coupons-kpi-content">
            <div className="coupons-kpi-label">Active Campaigns</div>
            <div className="coupons-kpi-value">{kpis.active}</div>
            <div className="coupons-kpi-subtext">Currently usable at checkout</div>
          </div>
        </div>

        <div className="coupons-kpi-card">
          <div className="coupons-kpi-icon amber">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" />
              <line x1="10" y1="15" x2="10" y2="9" />
              <line x1="14" y1="15" x2="14" y2="9" />
            </svg>
          </div>
          <div className="coupons-kpi-content">
            <div className="coupons-kpi-label">Paused / Inactive</div>
            <div className="coupons-kpi-value">{kpis.inactive}</div>
            <div className="coupons-kpi-subtext">Temporarily deactivated</div>
          </div>
        </div>

        <div className="coupons-kpi-card">
          <div className="coupons-kpi-icon purple">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
              <line x1="8" y1="21" x2="16" y2="21" />
              <line x1="12" y1="17" x2="12" y2="21" />
            </svg>
          </div>
          <div className="coupons-kpi-content">
            <div className="coupons-kpi-label">AI Agent Integration</div>
            <div className="coupons-kpi-value" style={{ fontSize: '18px', color: '#7c3aed' }}>
              Order Planning Agent
            </div>
            <div className="coupons-kpi-subtext">Live queries via LangGraph</div>
          </div>
        </div>
      </div>

      {/* Toolbar & Filters */}
      <div className="coupons-toolbar">
        <div className="coupons-search-box">
          <svg className="coupons-search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <input
            type="text"
            className="coupons-search-input"
            placeholder="Search coupon code or description..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>

        <div className="coupons-filter-group">
          <select
            className="coupons-select"
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
          >
            <option value="all">All Discount Types</option>
            <option value="PERCENTAGE">Percentage (%)</option>
            <option value="FLAT">Flat Amount (LKR)</option>
          </select>

          <select
            className="coupons-select"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="all">All Statuses</option>
            <option value="active">Active Only</option>
            <option value="inactive">Inactive Only</option>
          </select>

          <select
            className="coupons-select"
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
                      <div style={{ fontWeight: 600, color: '#0f172a' }}>{coupon.description}</div>
                    </td>
                    <td>
                      {coupon.discountType.toUpperCase() === 'PERCENTAGE' ? (
                        <span className="discount-rate-badge percentage">
                          {coupon.discountValue}% OFF
                        </span>
                      ) : (
                        <span className="discount-rate-badge flat">
                          LKR {Number(coupon.discountValue).toLocaleString()} FLAT
                        </span>
                      )}
                    </td>
                    <td>
                      {coupon.minSubtotal && Number(coupon.minSubtotal) > 0
                        ? `LKR ${Number(coupon.minSubtotal).toLocaleString()}`
                        : 'None (LKR 0)'}
                    </td>
                    <td>
                      {coupon.maxDiscount && Number(coupon.maxDiscount) > 0
                        ? `LKR ${Number(coupon.maxDiscount).toLocaleString()}`
                        : 'No Limit'}
                    </td>
                    <td>
                      <button
                        className={`status-pill ${coupon.isActive ? 'active' : 'inactive'}`}
                        onClick={() => handleToggleStatus(coupon)}
                        title="Click to toggle status"
                      >
                        <span className="status-dot"></span>
                        <span>{coupon.isActive ? 'Active' : 'Inactive'}</span>
                      </button>
                    </td>
                    <td>
                      <div className="coupon-actions">
                        <button
                          className="action-btn"
                          title="Edit Coupon"
                          onClick={() => handleOpenEdit(coupon)}
                        >
                          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                            <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                            <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                          </svg>
                        </button>
                        <button
                          className="action-btn delete"
                          title="Delete Coupon"
                          onClick={() => setDeleteCandidate(coupon)}
                        >
                          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
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
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2 className="modal-title">
                {isEditing ? `Edit Coupon: ${currentCoupon?.code}` : 'Create New Promotional Coupon'}
              </h2>
              <button className="modal-close-btn" onClick={() => setIsModalOpen(false)}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </button>
            </div>

            <form onSubmit={handleFormSubmit}>
              <div className="modal-body">
                {formError && (
                  <div style={{ background: '#fee2e2', color: '#b91c1c', padding: '10px 14px', borderRadius: '8px', marginBottom: '16px', fontSize: '13px', fontWeight: 600 }}>
                    {formError}
                  </div>
                )}

                <div className="form-group">
                  <label className="form-label">Coupon Code (Uppercase)</label>
                  <input
                    type="text"
                    className="form-input"
                    placeholder="e.g. FORGE10"
                    value={formData.code}
                    disabled={isEditing} // code cannot be changed once created to preserve order history integrity
                    onChange={(e) => setFormData({ ...formData, code: e.target.value.toUpperCase() })}
                    required
                  />
                  <div className="form-hint">
                    Unique uppercase voucher code that customers type in mobile (e.g. Screen UI 4).
                  </div>
                </div>

                <div className="form-group">
                  <label className="form-label">Campaign Description</label>
                  <input
                    type="text"
                    className="form-input"
                    placeholder="e.g. 10% Custom Rig Hardware Discount"
                    value={formData.description}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                    required
                  />
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Discount Type</label>
                    <select
                      className="form-select"
                      value={formData.discountType}
                      onChange={(e) => setFormData({ ...formData, discountType: e.target.value })}
                    >
                      <option value="PERCENTAGE">Percentage (%)</option>
                      <option value="FLAT">Flat Amount (LKR)</option>
                    </select>
                  </div>

                  <div className="form-group">
                    <label className="form-label">
                      {formData.discountType === 'PERCENTAGE' ? 'Discount Percentage (%)' : 'Discount Amount (LKR)'}
                    </label>
                    <input
                      type="number"
                      step="0.01"
                      className="form-input"
                      placeholder={formData.discountType === 'PERCENTAGE' ? '10' : '10000'}
                      value={formData.discountValue}
                      onChange={(e) => setFormData({ ...formData, discountValue: e.target.value })}
                      required
                    />
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Min Subtotal (LKR)</label>
                    <input
                      type="number"
                      step="1"
                      className="form-input"
                      placeholder="e.g. 50000 (0 for no min)"
                      value={formData.minSubtotal}
                      onChange={(e) => setFormData({ ...formData, minSubtotal: e.target.value })}
                    />
                    <div className="form-hint">Cart must reach this amount to qualify.</div>
                  </div>

                  <div className="form-group">
                    <label className="form-label">Max Discount Cap (LKR)</label>
                    <input
                      type="number"
                      step="1"
                      className="form-input"
                      placeholder="e.g. 15000 (optional)"
                      value={formData.maxDiscount}
                      onChange={(e) => setFormData({ ...formData, maxDiscount: e.target.value })}
                    />
                    <div className="form-hint">Ceiling on percentage deductions.</div>
                  </div>
                </div>

                <div className="form-group" style={{ display: 'flex', alignItems: 'center', gap: '10px', marginTop: '12px' }}>
                  <input
                    type="checkbox"
                    id="isActiveCoupon"
                    checked={formData.isActive}
                    onChange={(e) => setFormData({ ...formData, isActive: e.target.checked })}
                    style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                  />
                  <label htmlFor="isActiveCoupon" style={{ fontSize: '14px', fontWeight: 600, color: '#1e293b', cursor: 'pointer' }}>
                    Active and usable by customers immediately
                  </label>
                </div>

                {/* Real-time receipt simulation */}
                <div className="receipt-preview-card">
                  <div className="receipt-preview-title">Receipt Preview (UI 4 Simulation)</div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', color: '#475569' }}>
                    <span>Subtotal (example):</span>
                    <span>LKR 150,000</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', color: '#059669', fontWeight: 700, marginTop: '4px' }}>
                    <span>Discount ({formData.code || 'CODE'}):</span>
                    <span>
                      - LKR{' '}
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
                  className="btn-secondary"
                  onClick={() => setIsModalOpen(false)}
                  disabled={formSubmitting}
                >
                  Cancel
                </button>
                <button type="submit" className="btn-primary" disabled={formSubmitting}>
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
          <div className="modal-content" style={{ maxWidth: '420px' }} onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title" style={{ color: '#dc2626' }}>Delete Coupon?</h3>
              <button className="modal-close-btn" onClick={() => setDeleteCandidate(null)}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <line x1="18" y1="6" x2="6" y2="18" />
                  <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
              </button>
            </div>
            <div className="modal-body">
              <p style={{ margin: 0, color: '#334155', fontSize: '14px', lineHeight: 1.5 }}>
                Are you sure you want to permanently delete coupon <strong>"{deleteCandidate.code}"</strong>? Customers will no longer be able to use it in checkout proposals.
              </p>
            </div>
            <div className="modal-footer">
              <button className="btn-secondary" onClick={() => setDeleteCandidate(null)}>
                Cancel
              </button>
              <button
                className="btn-primary"
                style={{ background: '#dc2626' }}
                onClick={handleDeleteConfirm}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default CouponManagement;
