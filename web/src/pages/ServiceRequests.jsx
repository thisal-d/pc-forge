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

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // Selected Service Request for detailed inspection
  const [activeSrId, setActiveSrId] = useState(null);

  // Technician notes & diagnosis form
  const [technicianNotes, setTechnicianNotes] = useState('');
  const [resolutionText, setResolutionText] = useState('');
  const [savingNotes, setSavingNotes] = useState(false);

  // Create Service Request modal state
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [createData, setCreateData] = useState({
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

  // Sync selected request fields to form
  useEffect(() => {
    if (selectedRequest) {
      setTechnicianNotes(selectedRequest.technicianNotes || '');
      setResolutionText(selectedRequest.resolution || '');
    } else {
      setTechnicianNotes('');
      setResolutionText('');
    }
  }, [selectedRequest]);

  // Filtered requests
  const filteredRequests = useMemo(() => {
    return requests.filter((r) => {
      // Status
      if (statusFilter !== 'all' && r.status?.toUpperCase() !== statusFilter.toUpperCase()) {
        return false;
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
      // Search
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const num = (r.serviceRequestNumber || '').toLowerCase();
        const desc = (r.problemDescription || '').toLowerCase();
        const cust = (r.customerName || '').toLowerCase();
        const email = (r.customerEmail || '').toLowerCase();
        const prod = (r.productName || '').toLowerCase();
        return num.includes(q) || desc.includes(q) || cust.includes(q) || email.includes(q) || prod.includes(q);
      }
      return true;
    });
  }, [requests, statusFilter, priorityFilter, categoryFilter, technicianFilter, warrantyFilter, searchQuery]);

  // Reset pagination on filter or search change
  useEffect(() => {
    setCurrentPage(1);
  }, [statusFilter, priorityFilter, categoryFilter, technicianFilter, warrantyFilter, searchQuery]);

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
        technicianNotes || undefined,
        resolutionText || undefined
      );
      setRequests((prev) =>
        prev.map((r) => (r.serviceRequestId === id ? { ...r, ...updated } : r))
      );
      showNotification('success', `Service Request #${updated.serviceRequestNumber} marked as ${newStatus}.`);
    } catch (err) {
      showNotification('error', err.message || 'Failed to update status.');
    }
  };

  // Handle saving technician notes
  const handleSaveNotes = async (e) => {
    e.preventDefault();
    if (!selectedRequest) return;
    setSavingNotes(true);
    try {
      const updated = await serviceRequestService.updateServiceRequestStatus(
        selectedRequest.serviceRequestId,
        selectedRequest.status,
        technicianNotes,
        resolutionText
      );
      setRequests((prev) =>
        prev.map((r) => (r.serviceRequestId === selectedRequest.serviceRequestId ? { ...r, ...updated } : r))
      );
      showNotification('success', 'Technician diagnosis and notes saved successfully.');
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

  // Handle manual Service Request creation
  const handleCreateSubmit = async (e) => {
    e.preventDefault();
    if (!createData.problemDescription.trim()) {
      showNotification('error', 'Problem description is required.');
      return;
    }

    setCreatingRequest(true);
    try {
      const created = await serviceRequestService.createServiceRequest(createData);
      setRequests((prev) => [created, ...prev]);
      setIsCreateModalOpen(false);
      setCreateData({
        orderId: '',
        productId: '',
        problemDescription: '',
        problemCategory: 'General',
        warrantyStatus: 'Active',
        preferredDate: '',
        preferredTime: '10:00 AM',
        priority: 'Normal',
      });
      showNotification('success', `Service Request ${created.serviceRequestNumber} created successfully.`);
    } catch (err) {
      showNotification('error', err.message || 'Failed to create service request.');
    } finally {
      setCreatingRequest(false);
    }
  };

  const getStatusBadge = (status) => {
    switch ((status || '').toUpperCase()) {
      case 'PENDING':
        return <span className="badge badge-warning">PENDING</span>;
      case 'UNDER_REVIEW':
        return <span className="badge badge-info">UNDER REVIEW</span>;
      case 'WAITING_FOR_CUSTOMER':
        return <span className="badge badge-neutral">WAITING CUSTOMER</span>;
      case 'SCHEDULED':
        return <span className="badge badge-primary">SCHEDULED</span>;
      case 'IN_SERVICE':
        return <span className="badge badge-secondary" style={{ backgroundColor: '#8b5cf6', color: '#fff' }}>IN SERVICE</span>;
      case 'RESOLVED':
        return <span className="badge badge-success">RESOLVED</span>;
      case 'CANCELLED':
        return <span className="badge badge-error">CANCELLED</span>;
      default:
        return <span className="badge badge-neutral">{status}</span>;
    }
  };

  const getPriorityBadge = (p) => {
    switch ((p || '').toLowerCase()) {
      case 'urgent':
        return <span className="badge badge-error">🔥 Urgent</span>;
      case 'high':
        return <span className="badge badge-warning">⚡ High</span>;
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
            Technician inspection workbench, AI troubleshooting history, warranty verification, and repair diagnostics.
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
          <span className="stat-subtext">All recorded claims</span>
        </div>
        <div className="stat-card stat-card-inactive">
          <span className="stat-label">Pending Intake</span>
          <span className="stat-value" style={{ color: '#fbbf24' }}>{stats.pending}</span>
          <span className="stat-subtext">Awaiting technician intake</span>
        </div>
        <div className="stat-card stat-card-tech">
          <span className="stat-label">Under Review</span>
          <span className="stat-value" style={{ color: '#60a5fa' }}>{stats.underReview}</span>
          <span className="stat-subtext">Diagnostics in progress</span>
        </div>
        <div className="stat-card stat-card-active">
          <span className="stat-label">Scheduled</span>
          <span className="stat-value" style={{ color: '#34d399' }}>{stats.scheduled}</span>
          <span className="stat-subtext">Appointments confirmed</span>
        </div>
        <div className="stat-card stat-card-tech">
          <span className="stat-label">In Service / Bench</span>
          <span className="stat-value" style={{ color: '#a78bfa' }}>{stats.inService}</span>
          <span className="stat-subtext">On technician bench</span>
        </div>
        <div className="stat-card stat-card-active">
          <span className="stat-label">Resolved</span>
          <span className="stat-value" style={{ color: '#34d399' }}>{stats.resolved}</span>
          <span className="stat-subtext">Completed repairs</span>
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
              placeholder="Search by SR Number, Customer, Problem, or Product..."
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
              <option value="PENDING">Pending Intake ({stats.pending})</option>
              <option value="UNDER_REVIEW">Under Review ({stats.underReview})</option>
              <option value="WAITING_FOR_CUSTOMER">Waiting Customer</option>
              <option value="SCHEDULED">Scheduled ({stats.scheduled})</option>
              <option value="IN_SERVICE">In Service ({stats.inService})</option>
              <option value="RESOLVED">Resolved ({stats.resolved})</option>
              <option value="CANCELLED">Cancelled</option>
            </select>
          </div>

          {/* Priority Filter */}
          <div className="filter-item">
            <label htmlFor="sr-filter-priority">Priority:</label>
            <select
              id="sr-filter-priority"
              className="filter-select"
              value={priorityFilter}
              onChange={(e) => setPriorityFilter(e.target.value)}
            >
              <option value="all">All Priorities</option>
              <option value="Urgent">🔥 Urgent</option>
              <option value="High">⚡ High</option>
              <option value="Normal">Normal</option>
              <option value="Low">Low</option>
            </select>
          </div>

          {/* Category Filter */}
          <div className="filter-item">
            <label htmlFor="sr-filter-category">Category:</label>
            <select
              id="sr-filter-category"
              className="filter-select"
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
            >
              <option value="all">All Categories</option>
              <option value="General">General Diagnosis</option>
              <option value="Hardware Failure">Hardware Failure</option>
              <option value="Thermal / Cooling">Thermal / Cooling</option>
              <option value="Power Issue">Power Issue</option>
              <option value="Software / BIOS">Software / BIOS</option>
            </select>
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

          {/* Warranty Filter */}
          <div className="filter-item">
            <label htmlFor="sr-filter-warranty">Warranty:</label>
            <select
              id="sr-filter-warranty"
              className="filter-select"
              value={warrantyFilter}
              onChange={(e) => setWarrantyFilter(e.target.value)}
            >
              <option value="all">All Warranties</option>
              <option value="Active">Active Warranty</option>
              <option value="Expired">Expired Warranty</option>
            </select>
          </div>

          {/* Action buttons */}
          {(searchQuery || statusFilter !== 'all' || priorityFilter !== 'all' || categoryFilter !== 'all' || technicianFilter !== 'all' || warrantyFilter !== 'all') && (
            <button
              type="button"
              onClick={() => {
                setSearchQuery('');
                setStatusFilter('all');
                setPriorityFilter('all');
                setCategoryFilter('all');
                setTechnicianFilter('all');
                setWarrantyFilter('all');
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
                <th>Customer</th>
                <th>Hardware / Order</th>
                <th>Problem Category</th>
                <th>Warranty</th>
                <th>Appointment</th>
                <th>Status</th>
                <th>Priority</th>
                <th>Assigned Tech</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            {loading ? (
              <TableSkeleton rows={pageSize} columns={10} />
            ) : paginatedRequests.length === 0 ? (
              <tbody>
                <tr>
                  <td colSpan={10} style={{ padding: 0 }}>
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
                      <span className="badge badge-neutral">{r.problemCategory || 'General'}</span>
                    </td>
                    <td>
                      {r.warrantyStatus === 'Active' ? (
                        <span className="badge badge-success">Active</span>
                      ) : (
                        <span className="badge badge-error">Expired</span>
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
                    <td>{getPriorityBadge(r.priority)}</td>
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
                    onClick={() => handleUpdateStatus(selectedRequest.serviceRequestId, 'UNDER_REVIEW')}
                    className="btn btn-outline-sm"
                  >
                    Under Review
                  </button>
                  <button
                    type="button"
                    onClick={() => handleUpdateStatus(selectedRequest.serviceRequestId, 'SCHEDULED')}
                    className="btn btn-outline-sm"
                  >
                    Schedule Appointment
                  </button>
                  <button
                    type="button"
                    onClick={() => handleUpdateStatus(selectedRequest.serviceRequestId, 'IN_SERVICE')}
                    className="btn btn-outline-sm"
                    style={{ color: '#8b5cf6', borderColor: '#c4b5fd' }}
                  >
                    Bench In-Service
                  </button>
                  <button
                    type="button"
                    onClick={() => handleUpdateStatus(selectedRequest.serviceRequestId, 'RESOLVED')}
                    className="btn btn-primary"
                    style={{ fontSize: '0.8rem', padding: '0.35rem 0.75rem' }}
                  >
                    ✓ Mark Resolved
                  </button>
                  <button
                    type="button"
                    onClick={() => handleUpdateStatus(selectedRequest.serviceRequestId, 'CANCELLED')}
                    className="btn btn-outline-sm"
                    style={{ color: 'var(--danger-text)', borderColor: 'var(--danger-border)' }}
                  >
                    Cancel
                  </button>
                </div>
              </div>

              {/* Info Cards Grid */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '1rem' }}>
                {/* Customer Card */}
                <div style={{ padding: '1rem', backgroundColor: '#ffffff', border: '1px solid var(--border)', borderRadius: 'var(--radius-lg)' }}>
                  <h4 style={{ margin: '0 0 0.5rem 0', color: 'var(--primary)', fontSize: '0.875rem', fontWeight: 600 }}>👤 Customer Info</h4>
                  <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>{selectedRequest.customerName || `User #${selectedRequest.userId}`}</div>
                  <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>{selectedRequest.customerEmail || 'No email on record'}</div>
                  {selectedRequest.customerPhone && (
                    <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>{selectedRequest.customerPhone}</div>
                  )}
                </div>

                {/* Order & Product Card */}
                <div style={{ padding: '1rem', backgroundColor: '#ffffff', border: '1px solid var(--border)', borderRadius: 'var(--radius-lg)' }}>
                  <h4 style={{ margin: '0 0 0.5rem 0', color: 'var(--primary)', fontSize: '0.875rem', fontWeight: 600 }}>📦 Hardware & Order</h4>
                  <div style={{ fontWeight: 600, color: 'var(--text-main)' }}>{selectedRequest.productName || 'Hardware Component'}</div>
                  {selectedRequest.orderId ? (
                    <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>Order #{selectedRequest.orderId}</div>
                  ) : (
                    <div style={{ color: 'var(--text-subtle)', fontSize: '0.85rem' }}>Direct Component Request</div>
                  )}
                </div>

                {/* Warranty & Appointment Card */}
                <div style={{ padding: '1rem', backgroundColor: '#ffffff', border: '1px solid var(--border)', borderRadius: 'var(--radius-lg)' }}>
                  <h4 style={{ margin: '0 0 0.5rem 0', color: 'var(--primary)', fontSize: '0.875rem', fontWeight: 600 }}>🛡️ Warranty & Service Slot</h4>
                  <div>
                    <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Status: </span>
                    {selectedRequest.warrantyStatus === 'Active' ? (
                      <span className="badge badge-success">Active Coverage</span>
                    ) : (
                      <span className="badge badge-error">Expired Coverage</span>
                    )}
                  </div>
                  {selectedRequest.warrantyExpiryDate && (
                    <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>
                      Expires: {new Date(selectedRequest.warrantyExpiryDate).toLocaleDateString()}
                    </div>
                  )}
                  <div style={{ marginTop: '0.5rem', fontSize: '0.85rem', color: 'var(--text-main)' }}>
                    📅 Appointment: {selectedRequest.preferredDate || 'Not specified'}{' '}
                    {selectedRequest.preferredTime && `at ${selectedRequest.preferredTime}`}
                  </div>
                </div>
              </div>

              {/* Problem Description */}
              <div style={{ padding: '1rem', backgroundColor: 'var(--bg-subtle)', border: '1px solid var(--border)', borderRadius: 'var(--radius-lg)' }}>
                <h4 style={{ margin: '0 0 0.4rem 0', color: 'var(--text-main)', fontSize: '0.9rem', fontWeight: 600 }}>
                  Customer Reported Symptom ({selectedRequest.problemCategory})
                </h4>
                <p style={{ margin: 0, color: 'var(--text-muted)', lineHeight: 1.5, fontSize: '0.875rem' }}>
                  {selectedRequest.problemDescription}
                </p>
              </div>

              {/* AI Troubleshooting Summary Card */}
              <div style={{ padding: '1rem', backgroundColor: 'var(--primary-light)', border: '1px solid var(--primary-border)', borderRadius: 'var(--radius-lg)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.4rem' }}>
                  <span style={{ fontSize: '1.1rem' }}>🤖</span>
                  <h4 style={{ margin: 0, color: 'var(--primary-hover)', fontSize: '0.9rem', fontWeight: 600 }}>
                    AI Troubleshooting Summary & Attempt Counter ({selectedRequest.attemptCount || 0} Attempts)
                  </h4>
                </div>
                <div style={{ color: 'var(--text-main)', fontSize: '0.875rem', lineHeight: 1.6, whiteSpace: 'pre-wrap' }}>
                  {selectedRequest.troubleshootingSummary || 'No preliminary AI troubleshooting steps recorded for this request.'}
                </div>
              </div>

              {/* Technician Notes & Diagnosis Editor */}
              <form onSubmit={handleSaveNotes} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                <h4 style={{ margin: 0, color: 'var(--text-main)', fontSize: '0.95rem', fontWeight: 600 }}>
                  🛠️ Technician Bench Diagnosis & Resolution Notes
                </h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
                  <label style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)' }}>
                    Technician Diagnostics & Internal Bench Notes:
                  </label>
                  <textarea
                    rows={3}
                    className="filter-select"
                    style={{ width: '100%', fontFamily: 'inherit', resize: 'vertical', backgroundImage: 'none', padding: '0.65rem 0.85rem' }}
                    placeholder="Record hardware bench findings, component swap notes, or technician remarks..."
                    value={technicianNotes}
                    onChange={(e) => setTechnicianNotes(e.target.value)}
                  />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
                  <label style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)' }}>
                    Final Customer Resolution & Repair Confirmation:
                  </label>
                  <textarea
                    rows={2}
                    className="filter-select"
                    style={{ width: '100%', fontFamily: 'inherit', resize: 'vertical', backgroundImage: 'none', padding: '0.65rem 0.85rem' }}
                    placeholder="Record resolution summary for the customer (e.g. Component replaced under manufacturer warranty, thermal paste reapplied)..."
                    value={resolutionText}
                    onChange={(e) => setResolutionText(e.target.value)}
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
                    {savingNotes ? 'Saving...' : 'Save Diagnosis & Notes'}
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
                <p className="modal-subtitle">Submit manual customer ticket for bench repair & diagnostics</p>
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
                    Linked Order ID (Optional):
                  </label>
                  <input
                    type="number"
                    className="filter-select"
                    style={{ width: '100%', backgroundImage: 'none', padding: '0.55rem 0.85rem' }}
                    placeholder="e.g. 1 or 1001"
                    value={createData.orderId}
                    onChange={(e) => setCreateData({ ...createData, orderId: e.target.value })}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.35rem' }}>
                    Problem Category:
                  </label>
                  <select
                    className="filter-select"
                    style={{ width: '100%' }}
                    value={createData.problemCategory}
                    onChange={(e) => setCreateData({ ...createData, problemCategory: e.target.value })}
                  >
                    <option value="Power / Boot Failure">Power / Boot Failure</option>
                    <option value="Display / Black Screen">Display / Black Screen</option>
                    <option value="Shutdowns / Restarts">Shutdowns / Restarts</option>
                    <option value="Performance / Slowness">Performance / Slowness</option>
                    <option value="Audio / Strange Noise">Audio / Strange Noise</option>
                    <option value="GPU / Graphics Fault">GPU / Graphics Fault</option>
                    <option value="General">General Hardware Defect</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.35rem' }}>
                    Problem Description * :
                  </label>
                  <textarea
                    rows={3}
                    required
                    className="filter-select"
                    style={{ width: '100%', backgroundImage: 'none', padding: '0.65rem 0.85rem', resize: 'vertical', fontFamily: 'inherit' }}
                    placeholder="Describe the issue reported by the customer..."
                    value={createData.problemDescription}
                    onChange={(e) => setCreateData({ ...createData, problemDescription: e.target.value })}
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.35rem' }}>
                      Preferred Date:
                    </label>
                    <input
                      type="date"
                      className="filter-select"
                      style={{ width: '100%', backgroundImage: 'none', padding: '0.55rem 0.85rem' }}
                      value={createData.preferredDate}
                      onChange={(e) => setCreateData({ ...createData, preferredDate: e.target.value })}
                    />
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)', marginBottom: '0.35rem' }}>
                      Preferred Time Slot:
                    </label>
                    <select
                      className="filter-select"
                      style={{ width: '100%' }}
                      value={createData.preferredTime}
                      onChange={(e) => setCreateData({ ...createData, preferredTime: e.target.value })}
                    >
                      <option value="10:00 AM">10:00 AM</option>
                      <option value="11:30 AM">11:30 AM</option>
                      <option value="02:00 PM">02:00 PM</option>
                      <option value="03:30 PM">03:30 PM</option>
                      <option value="05:00 PM">05:00 PM</option>
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
                    disabled={creatingRequest}
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
