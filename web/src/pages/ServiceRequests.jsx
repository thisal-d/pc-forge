import React, { useState, useMemo, useEffect } from 'react';
import { serviceRequestService } from '../services/serviceRequestService.js';
import { staffService } from '../services/staffService.js';
import { useAuth } from '../context/AuthContext.jsx';
import { Pagination } from '../components/common/Pagination.jsx';
import { TableSkeleton } from '../components/common/TableSkeleton.jsx';
import { SearchIcon, RefreshCwIcon, CloseIcon } from '../components/icons/index.js';

export const ServiceRequests = () => {
  const { user, role } = useAuth();

  // Master state
  const [requests, setRequests] = useState([]);
  const [technicians, setTechnicians] = useState([]);
  const [loading, setLoading] = useState(true);

  // Filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [priorityFilter, setPriorityFilter] = useState('all');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [technicianFilter, setTechnicianFilter] = useState('all');
  const [warrantyFilter, setWarrantyFilter] = useState('all');
  const [startDateFilter, setStartDateFilter] = useState('');
  const [endDateFilter, setEndDateFilter] = useState('');

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // Selected Service Request for detailed inspection
  const [activeSrId, setActiveSrId] = useState(null);

  // Staff confidential internal notes form
  const [internalNotesText, setInternalNotesText] = useState('');
  const [savingNotes, setSavingNotes] = useState(false);

  // Create Service Request modal state
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [createData, setCreateData] = useState({
    title: '',
    description: '',
    orderId: '',
    productId: '',
    problemDescription: '',
    problemCategory: 'General',
    warrantyStatus: 'Active',
    preferredDate: '',
    preferredTime: '10:00 AM',
    priority: 'Normal',
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
      const [srList, staffList] = await Promise.all([
        serviceRequestService.fetchServiceRequests(),
        staffService.fetchStaffFromApi().catch(() => []),
      ]);
      setRequests(Array.isArray(srList) ? srList : []);
      setTechnicians(Array.isArray(staffList) ? staffList : []);
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
    return requests.find(
      (r) => r.serviceRequestId === activeSrId || r.serviceRequestNumber === activeSrId
    ) || null;
  }, [requests, activeSrId]);

  // Sync selected request internal notes to form
  useEffect(() => {
    if (selectedRequest) {
      setInternalNotesText(selectedRequest.internalNotes || '');
    } else {
      setInternalNotesText('');
    }
  }, [selectedRequest]);

  // Filtered requests
  const filteredRequests = useMemo(() => {
    return requests.filter((r) => {
      // Status
      if (statusFilter !== 'all') {
        const norm = (s) => (s || '').toUpperCase().replace(/_/g, ' ');
        const fNorm = statusFilter.toUpperCase().replace(/_/g, ' ');
        const rNorm = norm(r.status);
        if (fNorm === 'IN PROGRESS') {
          if (rNorm !== 'IN PROGRESS' && rNorm !== 'IN SERVICE' && rNorm !== 'UNDER REVIEW' && rNorm !== 'SCHEDULED') return false;
        } else if (fNorm === 'COMPLETED') {
          if (rNorm !== 'COMPLETED' && rNorm !== 'RESOLVED') return false;
        } else if (fNorm === 'NO SHOW') {
          if (rNorm !== 'NO SHOW') return false;
        } else if (fNorm === 'CANCELLED') {
          if (rNorm !== 'CANCELLED' && rNorm !== 'CANCELED') return false;
        } else if (rNorm !== fNorm) {
          return false;
        }
      }
      // Priority
      if (priorityFilter !== 'all' && r.priority?.toLowerCase() !== priorityFilter.toLowerCase()) {
        return false;
      }
      // Category
      if (categoryFilter !== 'all' && r.problemCategory?.toLowerCase() !== categoryFilter.toLowerCase()) {
        return false;
      }
      // Technician
      if (technicianFilter !== 'all') {
        if (technicianFilter === 'unassigned') {
          if (r.assignedStaffId) return false;
        } else if (Number(r.assignedStaffId) !== Number(technicianFilter)) {
          return false;
        }
      }
      // Warranty Status
      if (warrantyFilter !== 'all' && (r.warrantyStatus || '').toLowerCase() !== warrantyFilter.toLowerCase()) {
        return false;
      }
      // Date Range Filter (Preferred Appointment Date or CreatedAt)
      if (startDateFilter) {
        const sDate = new Date(startDateFilter);
        const rDate = r.preferredDate ? new Date(r.preferredDate) : new Date(r.createdAt);
        if (rDate < sDate) return false;
      }
      if (endDateFilter) {
        const eDate = new Date(endDateFilter);
        eDate.setHours(23, 59, 59, 999);
        const rDate = r.preferredDate ? new Date(r.preferredDate) : new Date(r.createdAt);
        if (rDate > eDate) return false;
      }
      // Search
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const num = (r.serviceRequestNumber || '').toLowerCase();
        const title = (r.title || '').toLowerCase();
        const desc = (r.problemDescription || r.description || '').toLowerCase();
        const cust = (r.customerName || '').toLowerCase();
        const email = (r.customerEmail || '').toLowerCase();
        const prod = (r.productName || '').toLowerCase();
        return num.includes(q) || title.includes(q) || desc.includes(q) || cust.includes(q) || email.includes(q) || prod.includes(q);
      }
      return true;
    });
  }, [requests, statusFilter, priorityFilter, categoryFilter, technicianFilter, warrantyFilter, startDateFilter, endDateFilter, searchQuery]);

  // Reset pagination on filter or search change
  useEffect(() => {
    setCurrentPage(1);
  }, [statusFilter, priorityFilter, categoryFilter, technicianFilter, warrantyFilter, startDateFilter, endDateFilter, searchQuery]);

  const totalPages = Math.max(1, Math.ceil(filteredRequests.length / pageSize));
  const paginatedRequests = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredRequests.slice(start, start + pageSize);
  }, [filteredRequests, currentPage, pageSize]);

  // Handle status update
  const handleUpdateStatus = async (id, newStatus) => {
    try {
      const updated = await serviceRequestService.updateServiceRequestStatus(
        id,
        newStatus,
        undefined,
        undefined,
        internalNotesText || undefined
      );
      setRequests((prev) =>
        prev.map((r) => (r.serviceRequestId === id ? { ...r, ...updated } : r))
      );
      showNotification('success', `Service Request #${updated.serviceRequestNumber} marked as ${newStatus}.`);
    } catch (err) {
      showNotification('error', err.message || 'Failed to update status.');
    }
  };

  // Handle saving staff internal notes
  const handleSaveNotes = async (e) => {
    e.preventDefault();
    if (!selectedRequest) return;
    setSavingNotes(true);
    try {
      const updated = await serviceRequestService.updateServiceRequestStatus(
        selectedRequest.serviceRequestId,
        selectedRequest.status,
        undefined,
        undefined,
        internalNotesText
      );
      setRequests((prev) =>
        prev.map((r) => (r.serviceRequestId === selectedRequest.serviceRequestId ? { ...r, ...updated } : r))
      );
      showNotification('success', 'Internal notes saved successfully.');
    } catch (err) {
      showNotification('error', err.message || 'Failed to save notes.');
    } finally {
      setSavingNotes(false);
    }
  };

  // Handle technician assignment
  const handleAssignTechnician = async (srId, staffId) => {
    try {
      const updated = await serviceRequestService.assignTechnician(srId, staffId);
      setRequests((prev) =>
        prev.map((r) => (r.serviceRequestId === srId ? { ...r, ...updated } : r))
      );
      showNotification('success', `Technician assigned to ${updated.serviceRequestNumber}.`);
    } catch (err) {
      showNotification('error', err.message || 'Failed to assign technician.');
    }
  };

  // Handle priority update
  const handleUpdatePriority = async (srId, newPriority) => {
    try {
      const updated = await serviceRequestService.updatePriority(srId, newPriority);
      setRequests((prev) =>
        prev.map((r) => (r.serviceRequestId === srId ? { ...r, ...updated } : r))
      );
      showNotification('success', `Priority updated to ${newPriority}.`);
    } catch (err) {
      showNotification('error', err.message || 'Failed to update priority.');
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

  // Handle manual Service Request creation
  const handleCreateSubmit = async (e) => {
    e.preventDefault();
    const title = (createData.title || '').trim();
    if (!title) {
      showNotification('error', 'Title is required for service request.');
      return;
    }

    if (dateAvailability && !dateAvailability.isAvailable) {
      showNotification('error', 'The selected date has reached its maximum capacity of 10 service appointments. Please choose another date.');
      return;
    }

    setCreatingRequest(true);
    try {
      const created = await serviceRequestService.createServiceRequest({
        ...createData,
        title: title,
        problemDescription: createData.description || title,
        description: createData.description || null,
      });
      setRequests((prev) => [created, ...prev]);
      setIsCreateModalOpen(false);
      setCreateData({
        title: '',
        description: '',
        orderId: '',
        productId: '',
        problemDescription: '',
        problemCategory: 'General',
        warrantyStatus: 'Active',
        preferredDate: '',
        preferredTime: '10:00 AM',
        priority: 'Normal',
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
        return <span className="badge badge-secondary" style={{ backgroundColor: '#6366f1', color: '#fff' }}>In Progress</span>;
      case 'COMPLETED':
      case 'RESOLVED':
        return <span className="badge badge-success">Completed</span>;
      case 'NO SHOW':
        return <span className="badge badge-neutral" style={{ backgroundColor: '#f97316', color: '#fff' }}>No Show</span>;
      case 'CANCELLED':
      case 'CANCELED':
        return <span className="badge badge-error">Cancelled</span>;
      default:
        return <span className="badge badge-neutral">{status}</span>;
    }
  };

  const getPriorityBadge = (p) => {
    switch ((p || '').toLowerCase()) {
      case 'urgent':
        return <span className="badge badge-error">Urgent</span>;
      case 'high':
        return <span className="badge badge-warning">High</span>;
      case 'normal':
        return <span className="badge badge-info">Normal</span>;
      case 'low':
        return <span className="badge badge-neutral">Low</span>;
      default:
        return <span className="badge badge-neutral">{p}</span>;
    }
  };

  return (
    <div className="page-container">
      {/* Page Header */}
      <div className="dashboard-header">
        <div>
          <h1>After-Sales Service Requests</h1>
          <p className="subtitle">
            Technician inspection workbench, service request details, and appointment lifecycle.
          </p>
        </div>
        <div className="header-actions" style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <span className="badge badge-lg badge-admin">
            {role === 'Admin' ? 'ADMIN OVERSIGHT' : 'TECHNICIAN WORKBENCH'}
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
            style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', display: 'flex', alignItems: 'center' }}
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
          <span className="stat-label">Pending Intake</span>
          <span className="stat-value" style={{ color: '#fbbf24' }}>{stats.pending}</span>
          <span className="stat-subtext">Awaiting PC drop-off</span>
        </div>
        <div className="stat-card stat-card-tech">
          <span className="stat-label">In Progress</span>
          <span className="stat-value" style={{ color: '#6366f1' }}>{stats.inProgress}</span>
          <span className="stat-subtext">PC at store / On bench</span>
        </div>
        <div className="stat-card stat-card-active">
          <span className="stat-label">Completed</span>
          <span className="stat-value" style={{ color: '#10b981' }}>{stats.completed}</span>
          <span className="stat-subtext">Requests completed</span>
        </div>
        <div className="stat-card stat-card-inactive">
          <span className="stat-label">No Show</span>
          <span className="stat-value" style={{ color: '#f97316' }}>{stats.noShow}</span>
          <span className="stat-subtext">Missed appointment</span>
        </div>
        <div className="stat-card stat-card-inactive">
          <span className="stat-label">Cancelled</span>
          <span className="stat-value" style={{ color: '#ef4444' }}>{stats.cancelled}</span>
          <span className="stat-subtext">Customer / staff cancelled</span>
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
              placeholder="Search by Title, SR#, Customer, or Order..."
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

          {/* Technician Filter */}
          <div className="filter-item">
            <label htmlFor="sr-filter-technician">Technician:</label>
            <select
              id="sr-filter-technician"
              className="filter-select"
              value={technicianFilter}
              onChange={(e) => setTechnicianFilter(e.target.value)}
            >
              <option value="all">All Technicians</option>
              <option value="unassigned">Unassigned Only</option>
              {technicians.map((t) => (
                <option key={t.staffId || t.id || t.userId} value={t.staffId || t.userId}>
                  {t.firstName ? `${t.firstName} ${t.lastName}` : (t.user ? `${t.user.firstName} ${t.user.lastName}` : `Technician #${t.staffId}`)}
                </option>
              ))}
            </select>
          </div>

          {/* Action buttons */}
          {(searchQuery || statusFilter !== 'all' || priorityFilter !== 'all' || categoryFilter !== 'all' || technicianFilter !== 'all' || warrantyFilter !== 'all' || startDateFilter || endDateFilter) && (
            <button
              type="button"
              onClick={() => {
                setSearchQuery('');
                setStatusFilter('all');
                setPriorityFilter('all');
                setCategoryFilter('all');
                setTechnicianFilter('all');
                setWarrantyFilter('all');
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
                <th>Request Title & Issue</th>
                <th>Customer</th>
                <th>Hardware / Order</th>
                <th>Appointment</th>
                <th>Status</th>
                <th>Assigned Tech</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            {loading ? (
              <TableSkeleton rows={pageSize} columns={8} />
            ) : paginatedRequests.length === 0 ? (
              <tbody>
                <tr>
                  <td colSpan={8} style={{ padding: 0 }}>
                    <div className="empty-state">
                      <div className="empty-state-icon">
                        <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
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
                          setPriorityFilter('all');
                          setCategoryFilter('all');
                          setTechnicianFilter('all');
                          setWarrantyFilter('all');
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
                      <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>{r.title || r.problemDescription}</div>
                      {r.description && r.title && (
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', maxWidth: '280px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {r.description}
                        </div>
                      )}
                    </td>
                    <td>
                      <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>{r.customerName || `Customer #${r.userId}`}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{r.customerEmail}</div>
                    </td>
                    <td>
                      <div style={{ color: 'var(--text-main)', fontWeight: 500 }}>{r.productName || 'Hardware Component'}</div>
                      {r.orderId && (
                        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Order #ORD-{r.orderId}</span>
                      )}
                    </td>
                    <td>
                      {r.preferredDate ? (
                        <div>
                          <div style={{ fontWeight: 500 }}>{r.preferredDate}</div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{r.preferredTime || '10:00 AM'}</div>
                        </div>
                      ) : (
                        <span style={{ color: 'var(--text-muted)', fontSize: '0.8rem' }}>Unscheduled</span>
                      )}
                    </td>
                    <td>{getStatusBadge(r.status)}</td>
                    <td>
                      <select
                        className="filter-select"
                        style={{ fontSize: '0.8rem', padding: '0.35rem 0.6rem', width: '150px' }}
                        value={r.assignedStaffId || ''}
                        onChange={(e) => handleAssignTechnician(r.serviceRequestId, e.target.value || null)}
                      >
                        <option value="">Unassigned</option>
                        {technicians.map((t) => (
                          <option key={t.staffId || t.id || t.userId} value={t.staffId || t.userId}>
                            {t.firstName ? `${t.firstName} ${t.lastName}` : (t.user ? `${t.user.firstName} ${t.user.lastName}` : `Tech #${t.staffId}`)}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <button
                        onClick={() => setActiveSrId(r.serviceRequestId)}
                        className="btn btn-outline-sm"
                      >
                        Inspect & Diagnose →
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

      {/* INSPECTION MODAL */}
      {selectedRequest && (
        <div className="modal-backdrop" onClick={() => setActiveSrId(null)}>
          <div
            className="modal-dialog"
            style={{ maxWidth: '900px' }}
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
                  {getPriorityBadge(selectedRequest.priority)}
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
              <div style={{ padding: '0.85rem 1.15rem', backgroundColor: 'var(--bg-subtle)', border: '1px solid var(--border)', borderRadius: 'var(--radius-lg)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '0.75rem' }}>
                <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)' }}>Update Lifecycle Status:</span>
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
                    style={{ backgroundColor: '#e0e7ff', borderColor: '#6366f1', color: '#4338ca', fontWeight: 600 }}
                  >
                    In Progress (PC Received)
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
                    onClick={() => handleUpdateStatus(selectedRequest.serviceRequestId, 'No Show')}
                    className="btn btn-outline-sm"
                    style={{ borderColor: '#ea580c', color: '#c2410c' }}
                  >
                    No Show
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

              {/* Title & Description Banner */}
              <div style={{ padding: '1rem', backgroundColor: '#f8fafc', border: '1px solid var(--border)', borderRadius: 'var(--radius-lg)' }}>
                <h4 style={{ margin: '0 0 0.35rem 0', color: 'var(--primary)', fontSize: '1rem', fontWeight: 700 }}>
                  {selectedRequest.title || 'Untitled Request'}
                </h4>
                <p style={{ margin: 0, color: 'var(--text-main)', fontSize: '0.875rem', lineHeight: 1.5 }}>
                  {selectedRequest.description || selectedRequest.problemDescription || 'No description provided.'}
                </p>
              </div>

              {/* Info Cards Grid */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '1rem' }}>
                {/* Customer Card */}
                <div style={{ padding: '1rem', backgroundColor: '#ffffff', border: '1px solid var(--border)', borderRadius: 'var(--radius-lg)' }}>
                  <h4 style={{ margin: '0 0 0.5rem 0', color: 'var(--primary)', fontSize: '0.875rem', fontWeight: 600 }}>Customer Information</h4>
                  <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>{selectedRequest.customerName || `User #${selectedRequest.userId}`}</div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>{selectedRequest.customerEmail || 'No email on record'}</div>
                  {selectedRequest.customerPhone && (
                    <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>{selectedRequest.customerPhone}</div>
                  )}
                </div>

                {/* Order & Product Card */}
                <div style={{ padding: '1rem', backgroundColor: '#ffffff', border: '1px solid var(--border)', borderRadius: 'var(--radius-lg)' }}>
                  <h4 style={{ margin: '0 0 0.5rem 0', color: 'var(--primary)', fontSize: '0.875rem', fontWeight: 600 }}>Hardware & Linked Order</h4>
                  <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>{selectedRequest.productName || 'Hardware Component'}</div>
                  {selectedRequest.orderId ? (
                    <div style={{ color: 'var(--primary)', fontWeight: 600, fontSize: '0.85rem' }}>
                      Linked Order: #{selectedRequest.orderId}
                      {selectedRequest.orderNumber && ` (${selectedRequest.orderNumber})`}
                    </div>
                  ) : (
                    <div style={{ color: 'var(--text-subtle)', fontSize: '0.85rem' }}>Direct / External Hardware</div>
                  )}
                </div>

                {/* Warranty & Appointment Card */}
                <div style={{ padding: '1rem', backgroundColor: '#ffffff', border: '1px solid var(--border)', borderRadius: 'var(--radius-lg)' }}>
                  <h4 style={{ margin: '0 0 0.5rem 0', color: 'var(--primary)', fontSize: '0.875rem', fontWeight: 600 }}>Service Slot & Warranty</h4>
                  <div style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--text-main)' }}>
                    {selectedRequest.preferredDate || 'Date Not Set'}{' '}
                    {selectedRequest.preferredTime && `(${selectedRequest.preferredTime})`}
                  </div>
                  <div style={{ marginTop: '0.35rem' }}>
                    <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Store hours: 9:00 AM - 6:00 PM</span>
                  </div>
                </div>
              </div>

              {/* Internal Notes & Diagnostics Editor */}
              <form onSubmit={handleSaveNotes} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                {/* Internal Notes - Hidden from Customer */}
                <div style={{ padding: '1rem', backgroundColor: '#fef3c7', border: '1px solid #fde68a', borderRadius: 'var(--radius-lg)', display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
                  <label style={{ fontSize: '0.875rem', fontWeight: 700, color: '#92400e', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                    Staff / Admin Internal Notes (Confidential):
                  </label>
                  <textarea
                    rows={3}
                    className="filter-select"
                    style={{ width: '100%', fontFamily: 'inherit', resize: 'vertical', backgroundImage: 'none', padding: '0.65rem 0.85rem', backgroundColor: '#fff', borderColor: '#f59e0b' }}
                    placeholder="Enter confidential notes, preliminary diagnosis, customer interaction history, or internal remarks..."
                    value={internalNotesText}
                    onChange={(e) => setInternalNotesText(e.target.value)}
                  />
                </div>

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem', marginTop: '0.25rem' }}>
                  <button
                    type="button"
                    onClick={() => setActiveSrId(null)}
                    className="btn btn-outline"
                  >
                    Close
                  </button>
                  <button
                    type="submit"
                    disabled={savingNotes}
                    className="btn btn-primary"
                  >
                    {savingNotes ? 'Saving...' : 'Save Internal Notes'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* CREATE SERVICE REQUEST MODAL */}
      {isCreateModalOpen && (
        <div className="modal-backdrop" onClick={() => setIsCreateModalOpen(false)}>
          <div
            className="modal-dialog"
            style={{ maxWidth: '600px' }}
            onClick={(e) => e.stopPropagation()}
            id="create-service-request-modal"
          >
            <div className="modal-header">
              <div>
                <h3 className="modal-title" style={{ margin: 0 }}>Create New Service Request</h3>
                <p className="modal-subtitle">Submit customer ticket (Hours: 9:00 AM - 6:00 PM, Max 10 per day)</p>
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
              <form onSubmit={handleCreateSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.35rem' }}>
                    Title * :
                  </label>
                  <input
                    type="text"
                    required
                    className="filter-select"
                    style={{ width: '100%', backgroundImage: 'none', padding: '0.55rem 0.85rem' }}
                    placeholder="e.g. PC won't boot / GPU display issue"
                    value={createData.title}
                    onChange={(e) => setCreateData({ ...createData, title: e.target.value })}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.35rem' }}>
                    Description (Optional):
                  </label>
                  <textarea
                    rows={3}
                    className="filter-select"
                    style={{ width: '100%', backgroundImage: 'none', padding: '0.65rem 0.85rem', resize: 'vertical', fontFamily: 'inherit' }}
                    placeholder="Provide any additional details or symptoms..."
                    value={createData.description}
                    onChange={(e) => setCreateData({ ...createData, description: e.target.value })}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.35rem' }}>
                    Linked Order ID (Optional - if bought from this store):
                  </label>
                  <input
                    type="number"
                    className="filter-select"
                    style={{ width: '100%', backgroundImage: 'none', padding: '0.55rem 0.85rem' }}
                    placeholder="e.g. 101"
                    value={createData.orderId}
                    onChange={(e) => setCreateData({ ...createData, orderId: e.target.value })}
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.35rem' }}>
                      Preferred Date *:
                    </label>
                    <input
                      type="date"
                      required
                      className="filter-select"
                      style={{ width: '100%', backgroundImage: 'none', padding: '0.55rem 0.85rem' }}
                      value={createData.preferredDate}
                      onChange={(e) => handleDateChange(e.target.value)}
                    />
                    {checkingAvailability && (
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Checking capacity...</span>
                    )}
                    {dateAvailability && (
                      <div style={{ marginTop: '0.25rem', fontSize: '0.75rem', fontWeight: 600, color: dateAvailability.isAvailable ? '#059669' : '#dc2626' }}>
                        {dateAvailability.isAvailable
                          ? `Available (${dateAvailability.remainingSlots} of 10 slots left)`
                          : `Fully booked (${dateAvailability.bookedCount} of 10 slots used)`}
                      </div>
                    )}
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.35rem' }}>
                      Preferred Time Slot (9 AM - 6 PM) *:
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

                <div className="modal-footer" style={{ margin: '0.5rem -1.5rem -1.5rem', borderRadius: '0 0 var(--radius-xl) var(--radius-xl)' }}>
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
                    {creatingRequest ? 'Creating...' : 'Create Service Request'}
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
