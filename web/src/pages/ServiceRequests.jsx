import React, { useState, useMemo, useEffect } from 'react';
import { serviceRequestService } from '../services/serviceRequestService.js';
import { useAuth } from '../context/AuthContext.jsx';
import { Pagination } from '../components/common/Pagination.jsx';
import { TableSkeleton } from '../components/common/TableSkeleton.jsx';
import { SearchIcon, RefreshCwIcon, CloseIcon } from '../components/icons/index.js';

export const ServiceRequests = () => {
  const { role } = useAuth();

  // Master state
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);

  // Filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [startDateFilter, setStartDateFilter] = useState('');
  const [endDateFilter, setEndDateFilter] = useState('');

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // Selected Service Request for detailed inspection
  const [activeSrId, setActiveSrId] = useState(null);

  // Create Service Request modal state
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [createData, setCreateData] = useState({
    title: '',
    description: '',
    preferredDate: '',
    preferredTime: '10:00 AM',
  });
  const [creatingRequest, setCreatingRequest] = useState(false);
  const [dateAvailability, setDateAvailability] = useState(null);
  const [checkingAvailability, setCheckingAvailability] = useState(false);

  // Notification toast
  const [notification, setNotification] = useState(null);

  const showNotification = (type, message) => {
    setNotification({ type, message });
    setTimeout(() => {
      setNotification(null);
    }, 4500);
  };

  const loadData = async () => {
    setLoading(true);
    try {
      const srList = await serviceRequestService.fetchServiceRequests();
      setRequests(Array.isArray(srList) ? srList : []);
    } catch {
      showNotification('error', 'Failed to load service requests from server.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Compute live stats
  const stats = useMemo(() => serviceRequestService.getStats(requests), [requests]);

  // Selected request
  const selectedRequest = useMemo(() => {
    if (!activeSrId) return null;
    return (
      requests.find(
        (r) => r.serviceRequestId === activeSrId || r.serviceRequestNumber === activeSrId
      ) || null
    );
  }, [requests, activeSrId]);

  // Filter pipeline
  const filteredRequests = useMemo(() => {
    return requests.filter((r) => {
      // 1. Status Filter
      if (statusFilter !== 'all') {
        const target = statusFilter.toLowerCase().replace(/_/g, ' ');
        const current = (r.status || '').toLowerCase().replace(/_/g, ' ');
        if (target === 'in progress') {
          if (
            current !== 'in progress' &&
            current !== 'in service' &&
            current !== 'under review' &&
            current !== 'scheduled'
          )
            return false;
        } else if (target === 'completed') {
          if (current !== 'completed' && current !== 'resolved') return false;
        } else if (target === 'cancelled') {
          if (current !== 'cancelled' && current !== 'canceled') return false;
        } else if (target === 'no show') {
          if (current !== 'no show' && current !== 'noshow') return false;
        } else if (current !== target) {
          return false;
        }
      }

      // 2. Date Range Filter
      if (startDateFilter) {
        const itemDate = r.preferredDate || r.createdAt?.split('T')[0];
        if (itemDate && itemDate < startDateFilter) return false;
      }
      if (endDateFilter) {
        const itemDate = r.preferredDate || r.createdAt?.split('T')[0];
        if (itemDate && itemDate > endDateFilter) return false;
      }

      // 3. Search Query
      if (searchQuery.trim()) {
        const q = searchQuery.trim().toLowerCase();
        const matchNumber = (r.serviceRequestNumber || '').toLowerCase().includes(q);
        const matchTitle = (r.title || '').toLowerCase().includes(q);
        const matchDesc = (r.description || '').toLowerCase().includes(q);
        const matchCustomer = (r.customerName || '').toLowerCase().includes(q);
        const matchEmail = (r.customerEmail || '').toLowerCase().includes(q);
        if (!matchNumber && !matchTitle && !matchDesc && !matchCustomer && !matchEmail) {
          return false;
        }
      }

      return true;
    });
  }, [requests, statusFilter, startDateFilter, endDateFilter, searchQuery]);

  // Pagination calculation
  const totalPages = Math.max(1, Math.ceil(filteredRequests.length / pageSize));
  const paginatedRequests = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredRequests.slice(start, start + pageSize);
  }, [filteredRequests, currentPage, pageSize]);

  // Handle status update
  const handleUpdateStatus = async (srId, newStatus) => {
    try {
      const updated = await serviceRequestService.updateServiceRequestStatus(srId, newStatus);
      setRequests((prev) =>
        prev.map((r) =>
          r.serviceRequestId === srId || r.serviceRequestNumber === srId
            ? { ...r, status: updated.status }
            : r
        )
      );
      showNotification('success', `Status updated to ${newStatus}.`);
    } catch (err) {
      showNotification('error', err.message || 'Failed to update status.');
    }
  };

  // Check date capacity
  const handleDateChange = async (dateStr) => {
    setCreateData((prev) => ({ ...prev, preferredDate: dateStr }));
    if (!dateStr) {
      setDateAvailability(null);
      return;
    }
    setCheckingAvailability(true);
    try {
      const info = await serviceRequestService.checkAvailability(dateStr);
      setDateAvailability(info);
    } catch {
      setDateAvailability(null);
    } finally {
      setCheckingAvailability(false);
    }
  };

  // Handle manual Service Request creation (Simple & optional)
  const handleCreateSubmit = async (e) => {
    e.preventDefault();

    if (dateAvailability && !dateAvailability.isAvailable) {
      showNotification(
        'error',
        'The selected date has reached its maximum capacity of 10 service appointments. Please choose another date.'
      );
      return;
    }

    setCreatingRequest(true);
    try {
      const created = await serviceRequestService.createServiceRequest({
        title: createData.title || null,
        description: createData.description || null,
        preferredDate: createData.preferredDate || null,
        preferredTime: createData.preferredTime || null,
      });
      setRequests((prev) => [created, ...prev]);
      setIsCreateModalOpen(false);
      setCreateData({
        title: '',
        description: '',
        preferredDate: '',
        preferredTime: '10:00 AM',
      });
      setDateAvailability(null);
      showNotification('success', `Service Request ${created.serviceRequestNumber} created successfully.`);
    } catch (err) {
      showNotification('error', err.message || 'Failed to create service request.');
    } finally {
      setCreatingRequest(false);
    }
  };

  const getStatusBadge = (status) => {
    const s = (status || '').toUpperCase().replace(/_/g, ' ');
    switch (s) {
      case 'PENDING':
        return <span className="badge badge-warning">Pending</span>;
      case 'IN PROGRESS':
      case 'IN SERVICE':
      case 'UNDER REVIEW':
      case 'SCHEDULED':
        return (
          <span className="badge badge-secondary" style={{ backgroundColor: '#6366f1', color: '#fff' }}>
            In Progress
          </span>
        );
      case 'COMPLETED':
      case 'RESOLVED':
        return <span className="badge badge-success">Completed</span>;
      case 'NO SHOW':
        return (
          <span className="badge badge-neutral" style={{ backgroundColor: '#f97316', color: '#fff' }}>
            No Show
          </span>
        );
      case 'CANCELLED':
      case 'CANCELED':
        return <span className="badge badge-error">Cancelled</span>;
      default:
        return <span className="badge badge-neutral">{status}</span>;
    }
  };

  return (
    <div className="page-container">
      {/* Page Header */}
      <div className="dashboard-header">
        <div>
          <h1>Service Requests</h1>
          <p className="subtitle">
            After-sales customer repair, diagnostics, and appointment queue.
          </p>
        </div>
        <div className="header-actions" style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <span className="badge badge-lg badge-admin">
            {role === 'Admin' ? 'ADMIN OVERSIGHT' : 'STAFF WORKBENCH'}
          </span>
          <button
            onClick={() => setIsCreateModalOpen(true)}
            className="btn btn-primary"
            id="add-service-request-btn"
          >
            + New Service Request
          </button>
        </div>
      </div>

      {/* Notification Toast */}
      {notification && (
        <div
          className={`notification-banner ${
            notification.type === 'error'
              ? 'alert-error'
              : notification.type === 'info'
              ? 'alert-warning'
              : 'alert-success'
          }`}
        >
          <span>{notification.message}</span>
          <button
            type="button"
            onClick={() => setNotification(null)}
            style={{
              background: 'none',
              border: 'none',
              color: 'inherit',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
            }}
            title="Dismiss"
          >
            <CloseIcon size={14} />
          </button>
        </div>
      )}

      {/* KPI Stats Cards */}
      <div className="stats-grid">
        <div className="stat-card stat-card-total">
          <span className="stat-label">Total Requests</span>
          <span className="stat-value">{stats.total}</span>
          <span className="stat-subtext">All recorded requests</span>
        </div>
        <div className="stat-card stat-card-inactive">
          <span className="stat-label">Pending</span>
          <span className="stat-value" style={{ color: '#fbbf24' }}>
            {stats.pending}
          </span>
          <span className="stat-subtext">Awaiting intake / drop-off</span>
        </div>
        <div className="stat-card stat-card-tech">
          <span className="stat-label">In Progress</span>
          <span className="stat-value" style={{ color: '#6366f1' }}>
            {stats.inProgress}
          </span>
          <span className="stat-subtext">Under diagnostic or repair</span>
        </div>
        <div className="stat-card stat-card-active">
          <span className="stat-label">Completed</span>
          <span className="stat-value" style={{ color: '#10b981' }}>
            {stats.completed}
          </span>
          <span className="stat-subtext">Successfully resolved</span>
        </div>
        <div className="stat-card stat-card-inactive">
          <span className="stat-label">Cancelled</span>
          <span className="stat-value" style={{ color: '#ef4444' }}>
            {stats.cancelled}
          </span>
          <span className="stat-subtext">Cancelled requests</span>
        </div>
      </div>

      {/* Unified Search & Filter Toolbar */}
      <div className="toolbar-card">
        <div className="search-filter-row">
          {/* Search Box */}
          <div className="search-input-wrapper">
            <span className="search-icon">
              <SearchIcon size={16} />
            </span>
            <input
              type="text"
              placeholder="Search by Title, Description, SR#, or Customer..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              id="service-request-search-input"
            />
            {searchQuery && (
              <button
                type="button"
                className="clear-search-btn"
                onClick={() => setSearchQuery('')}
                title="Clear search"
              >
                <CloseIcon size={14} />
              </button>
            )}
          </div>

          {/* Status Filter */}
          <div className="filter-item">
            <label htmlFor="sr-filter-status">Status:</label>
            <select
              id="sr-filter-status"
              className="filter-select"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="all">All Statuses ({stats.total})</option>
              <option value="Pending">Pending ({stats.pending})</option>
              <option value="In Progress">In Progress ({stats.inProgress})</option>
              <option value="Completed">Completed ({stats.completed})</option>
              <option value="No Show">No Show ({stats.noShow})</option>
              <option value="Cancelled">Cancelled ({stats.cancelled})</option>
            </select>
          </div>

          {/* Date Range Filters */}
          <div className="filter-item">
            <label htmlFor="sr-filter-start-date">From Date:</label>
            <input
              type="date"
              id="sr-filter-start-date"
              className="filter-select"
              value={startDateFilter}
              onChange={(e) => setStartDateFilter(e.target.value)}
            />
          </div>

          <div className="filter-item">
            <label htmlFor="sr-filter-end-date">To Date:</label>
            <input
              type="date"
              id="sr-filter-end-date"
              className="filter-select"
              value={endDateFilter}
              onChange={(e) => setEndDateFilter(e.target.value)}
            />
          </div>

          {/* Reset Filters */}
          {(searchQuery || statusFilter !== 'all' || startDateFilter || endDateFilter) && (
            <button
              type="button"
              onClick={() => {
                setSearchQuery('');
                setStatusFilter('all');
                setStartDateFilter('');
                setEndDateFilter('');
                setCurrentPage(1);
              }}
              className="btn btn-outline-sm"
              id="reset-sr-filters-btn"
            >
              Reset Filters
            </button>
          )}

          <button
            type="button"
            onClick={loadData}
            className="btn btn-outline-sm"
            title="Refresh Service Requests"
            id="refresh-sr-btn"
            style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
          >
            <RefreshCwIcon size={14} /> Refresh
          </button>
        </div>
      </div>

      {/* Main Table */}
      <div className="data-table-card">
        <div className="table-header-banner">
          <h3>Service Requests ({filteredRequests.length})</h3>
          <span className="table-header-subtitle">
            Showing {paginatedRequests.length} of {requests.length} service requests
          </span>
        </div>
        <div className="table-responsive">
          <table className="data-table" id="service-requests-table">
            <thead>
              <tr>
                <th>SR Number</th>
                <th>Title & Description</th>
                <th>Customer</th>
                <th>Appointment</th>
                <th>Status</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            {loading ? (
              <TableSkeleton rows={pageSize} columns={6} />
            ) : paginatedRequests.length === 0 ? (
              <tbody>
                <tr>
                  <td colSpan={6} style={{ padding: 0 }}>
                    <div className="empty-state">
                      <div className="empty-state-icon">
                        <svg
                          width="36"
                          height="36"
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          strokeWidth="1.5"
                        >
                          <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z" />
                        </svg>
                      </div>
                      <h4>No service requests found</h4>
                      <p>No service requests match your search or filter criteria.</p>
                      <button
                        type="button"
                        className="btn btn-outline-sm"
                        onClick={() => {
                          setSearchQuery('');
                          setStatusFilter('all');
                          setStartDateFilter('');
                          setEndDateFilter('');
                          setCurrentPage(1);
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
                {paginatedRequests.map((r) => (
                  <tr
                    key={r.serviceRequestId}
                    style={{
                      backgroundColor: activeSrId === r.serviceRequestId ? 'var(--primary-light)' : undefined,
                    }}
                  >
                    <td style={{ fontWeight: 700, color: 'var(--primary)' }}>
                      {r.serviceRequestNumber}
                    </td>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>
                        {r.title || 'Service Request'}
                      </div>
                      {r.description && (
                        <div
                          style={{
                            fontSize: '0.75rem',
                            color: 'var(--text-muted)',
                            maxWidth: '320px',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                          }}
                        >
                          {r.description}
                        </div>
                      )}
                    </td>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>
                        {r.customerName || `Customer #${r.userId}`}
                      </div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                        {r.customerEmail}
                      </div>
                    </td>
                    <td>
                      {r.preferredDate ? (
                        <div>
                          <div style={{ fontWeight: 500 }}>
                            {typeof r.preferredDate === 'string'
                              ? r.preferredDate.split('T')[0]
                              : r.preferredDate}
                          </div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                            {r.preferredTime || '10:00 AM'}
                          </div>
                        </div>
                      ) : (
                        <span style={{ color: 'var(--text-muted)', fontSize: '0.8rem' }}>Flexible</span>
                      )}
                    </td>
                    <td>{getStatusBadge(r.status)}</td>
                    <td style={{ textAlign: 'right' }}>
                      <button
                        onClick={() => setActiveSrId(r.serviceRequestId)}
                        className="btn btn-outline-sm"
                      >
                        View Details →
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            )}
          </table>
        </div>

        {!loading && filteredRequests.length > 0 && (
          <Pagination
            currentPage={currentPage}
            totalPages={totalPages}
            totalItems={filteredRequests.length}
            pageSize={pageSize}
            pageSizeOptions={[10, 25, 50]}
            onPageChange={setCurrentPage}
            onPageSizeChange={(newSize) => {
              setPageSize(newSize);
              setCurrentPage(1);
            }}
            itemLabel="service requests"
          />
        )}
      </div>

      {/* INSPECTION / DETAIL MODAL */}
      {selectedRequest && (
        <div className="modal-backdrop" onClick={() => setActiveSrId(null)}>
          <div
            className="modal-dialog"
            style={{ maxWidth: '750px' }}
            onClick={(e) => e.stopPropagation()}
            id="service-request-detail-modal"
          >
            {/* Modal Header */}
            <div className="modal-header">
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
                  <h3 className="modal-title" style={{ margin: 0 }}>
                    Service Request {selectedRequest.serviceRequestNumber}
                  </h3>
                  {getStatusBadge(selectedRequest.status)}
                </div>
                <p className="modal-subtitle">
                  Created on {new Date(selectedRequest.createdAt).toLocaleString()}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setActiveSrId(null)}
                className="modal-close-btn"
                title="Close modal"
              >
                <CloseIcon size={16} />
              </button>
            </div>

            {/* Modal Body */}
            <div className="modal-body" style={{ maxHeight: 'calc(85vh - 70px)', overflowY: 'auto' }}>
              {/* Quick Status Transition Bar */}
              <div
                style={{
                  padding: '0.85rem 1.15rem',
                  backgroundColor: 'var(--bg-subtle)',
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--radius-lg)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  flexWrap: 'wrap',
                  gap: '0.75rem',
                }}
              >
                <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)' }}>
                  Change Status:
                </span>
                <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                  <button
                    type="button"
                    onClick={() => handleUpdateStatus(selectedRequest.serviceRequestId, 'Pending')}
                    className="btn btn-outline-sm"
                    style={{ borderColor: '#f59e0b', color: '#b45309' }}
                  >
                    Pending
                  </button>
                  <button
                    type="button"
                    onClick={() => handleUpdateStatus(selectedRequest.serviceRequestId, 'In Progress')}
                    className="btn btn-outline-sm"
                    style={{
                      backgroundColor: '#e0e7ff',
                      borderColor: '#6366f1',
                      color: '#4338ca',
                      fontWeight: 600,
                    }}
                  >
                    In Progress
                  </button>
                  <button
                    type="button"
                    onClick={() => handleUpdateStatus(selectedRequest.serviceRequestId, 'Completed')}
                    className="btn btn-primary"
                    style={{ fontSize: '0.8rem', padding: '0.35rem 0.75rem' }}
                  >
                    Completed
                  </button>
                  <button
                    type="button"
                    onClick={() => handleUpdateStatus(selectedRequest.serviceRequestId, 'Cancelled')}
                    className="btn btn-outline-sm"
                    style={{ color: 'var(--danger-text)', borderColor: 'var(--danger-border)' }}
                  >
                    Cancel
                  </button>
                </div>
              </div>

              {/* Title & Description */}
              <div
                style={{
                  padding: '1.25rem',
                  backgroundColor: 'var(--bg-card)',
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--radius-lg)',
                }}
              >
                <div style={{ fontSize: '0.8rem', textTransform: 'uppercase', color: 'var(--text-muted)', fontWeight: 600, letterSpacing: '0.05em', marginBottom: '0.35rem' }}>
                  Request Title
                </div>
                <h3 style={{ margin: '0 0 1rem 0', color: 'var(--text-main)', fontSize: '1.15rem', fontWeight: 700 }}>
                  {selectedRequest.title || 'Service Request'}
                </h3>
                <div style={{ fontSize: '0.8rem', textTransform: 'uppercase', color: 'var(--text-muted)', fontWeight: 600, letterSpacing: '0.05em', marginBottom: '0.35rem' }}>
                  Problem Description
                </div>
                <p
                  style={{
                    margin: 0,
                    color: 'var(--text-main)',
                    fontSize: '0.925rem',
                    lineHeight: 1.6,
                    whiteSpace: 'pre-wrap',
                  }}
                >
                  {selectedRequest.description || 'No additional description provided.'}
                </p>
              </div>

              {/* Info Cards Grid */}
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
                  gap: '1rem',
                }}
              >
                {/* Customer Card */}
                <div
                  style={{
                    padding: '1rem',
                    backgroundColor: 'var(--bg-card)',
                    border: '1px solid var(--border)',
                    borderRadius: 'var(--radius-lg)',
                  }}
                >
                  <h4
                    style={{
                      margin: '0 0 0.5rem 0',
                      color: 'var(--primary)',
                      fontSize: '0.875rem',
                      fontWeight: 600,
                    }}
                  >
                    Customer Details
                  </h4>
                  <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>
                    {selectedRequest.customerName || `User #${selectedRequest.userId}`}
                  </div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>
                    {selectedRequest.customerEmail || 'No email on record'}
                  </div>
                </div>

                {/* Appointment Card */}
                <div
                  style={{
                    padding: '1rem',
                    backgroundColor: 'var(--bg-card)',
                    border: '1px solid var(--border)',
                    borderRadius: 'var(--radius-lg)',
                  }}
                >
                  <h4
                    style={{
                      margin: '0 0 0.5rem 0',
                      color: 'var(--primary)',
                      fontSize: '0.875rem',
                      fontWeight: 600,
                    }}
                  >
                    Appointment Slot
                  </h4>
                  <div style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--text-main)' }}>
                    {selectedRequest.preferredDate
                      ? `${typeof selectedRequest.preferredDate === 'string' ? selectedRequest.preferredDate.split('T')[0] : selectedRequest.preferredDate} (${selectedRequest.preferredTime || '10:00 AM'})`
                      : 'Flexible / Unscheduled'}
                  </div>
                  <div style={{ marginTop: '0.35rem', fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                    Store hours: 9:00 AM - 6:00 PM
                  </div>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '1rem' }}>
                <button
                  type="button"
                  onClick={() => setActiveSrId(null)}
                  className="btn btn-outline"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* CREATE SERVICE REQUEST MODAL (Simple & Optional Form) */}
      {isCreateModalOpen && (
        <div className="modal-backdrop" onClick={() => setIsCreateModalOpen(false)}>
          <div
            className="modal-dialog"
            style={{ maxWidth: '580px' }}
            onClick={(e) => e.stopPropagation()}
            id="create-service-request-modal"
          >
            <div className="modal-header">
              <div>
                <h3 className="modal-title" style={{ margin: 0 }}>
                  Create Service Request
                </h3>
                <p className="modal-subtitle">
                  Simple form — fill what you know, leave the rest optional.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsCreateModalOpen(false)}
                className="modal-close-btn"
                title="Close modal"
              >
                <CloseIcon size={16} />
              </button>
            </div>

            <div className="modal-body">
              {/* Friendly helper banner */}
              <div
                style={{
                  padding: '0.75rem 1rem',
                  backgroundColor: 'var(--bg-subtle)',
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--radius-md)',
                  marginBottom: '1rem',
                  fontSize: '0.85rem',
                  color: 'var(--text-muted)',
                  lineHeight: 1.5,
                }}
              >
                💡 <strong>Non-technical friendly:</strong> You don't need to know PC specifications. Just describe what is happening and our staff will handle the rest.
              </div>

              <form onSubmit={handleCreateSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                <div>
                  <label
                    style={{
                      display: 'block',
                      fontSize: '0.85rem',
                      fontWeight: 600,
                      color: 'var(--text-main)',
                      marginBottom: '0.35rem',
                    }}
                  >
                    Title (Optional):
                  </label>
                  <input
                    type="text"
                    className="filter-select"
                    style={{ width: '100%', backgroundImage: 'none', padding: '0.55rem 0.85rem' }}
                    placeholder="e.g. Computer won't start, Loud noise, Screen flickering"
                    value={createData.title}
                    onChange={(e) => setCreateData({ ...createData, title: e.target.value })}
                  />
                </div>

                <div>
                  <label
                    style={{
                      display: 'block',
                      fontSize: '0.85rem',
                      fontWeight: 600,
                      color: 'var(--text-main)',
                      marginBottom: '0.35rem',
                    }}
                  >
                    Description (Optional):
                  </label>
                  <textarea
                    rows={4}
                    className="filter-select"
                    style={{
                      width: '100%',
                      backgroundImage: 'none',
                      padding: '0.65rem 0.85rem',
                      resize: 'vertical',
                      fontFamily: 'inherit',
                    }}
                    placeholder="Describe what happened or what problem you are seeing..."
                    value={createData.description}
                    onChange={(e) => setCreateData({ ...createData, description: e.target.value })}
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                  <div>
                    <label
                      style={{
                        display: 'block',
                        fontSize: '0.85rem',
                        fontWeight: 600,
                        color: 'var(--text-main)',
                        marginBottom: '0.35rem',
                      }}
                    >
                      Preferred Date (Optional):
                    </label>
                    <input
                      type="date"
                      className="filter-select"
                      style={{ width: '100%', backgroundImage: 'none', padding: '0.55rem 0.85rem' }}
                      value={createData.preferredDate}
                      onChange={(e) => handleDateChange(e.target.value)}
                    />
                    {checkingAvailability && (
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                        Checking capacity...
                      </span>
                    )}
                    {dateAvailability && (
                      <div
                        style={{
                          marginTop: '0.25rem',
                          fontSize: '0.75rem',
                          fontWeight: 600,
                          color: dateAvailability.isAvailable ? '#059669' : '#dc2626',
                        }}
                      >
                        {dateAvailability.isAvailable
                          ? `Available (${dateAvailability.remainingSlots} slots remaining)`
                          : `Date full (Max 10 per day)`}
                      </div>
                    )}
                  </div>
                  <div>
                    <label
                      style={{
                        display: 'block',
                        fontSize: '0.85rem',
                        fontWeight: 600,
                        color: 'var(--text-main)',
                        marginBottom: '0.35rem',
                      }}
                    >
                      Time Slot (Optional):
                    </label>
                    <select
                      className="filter-select"
                      style={{ width: '100%' }}
                      value={createData.preferredTime}
                      onChange={(e) => setCreateData({ ...createData, preferredTime: e.target.value })}
                    >
                      <option value="09:00 AM">09:00 AM</option>
                      <option value="10:00 AM">10:00 AM</option>
                      <option value="11:00 AM">11:00 AM</option>
                      <option value="12:00 PM">12:00 PM</option>
                      <option value="01:00 PM">01:00 PM</option>
                      <option value="02:00 PM">02:00 PM</option>
                      <option value="03:00 PM">03:00 PM</option>
                      <option value="04:00 PM">04:00 PM</option>
                      <option value="05:00 PM">05:00 PM</option>
                      <option value="06:00 PM">06:00 PM</option>
                    </select>
                  </div>
                </div>

                <div
                  className="modal-footer"
                  style={{
                    margin: '0.5rem -1.5rem -1.5rem',
                    borderRadius: '0 0 var(--radius-xl) var(--radius-xl)',
                  }}
                >
                  <button
                    type="button"
                    onClick={() => setIsCreateModalOpen(false)}
                    className="btn btn-outline"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={creatingRequest || (dateAvailability && !dateAvailability.isAvailable)}
                    className="btn btn-primary"
                  >
                    {creatingRequest ? 'Submitting...' : 'Submit Service Request'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ServiceRequests;
