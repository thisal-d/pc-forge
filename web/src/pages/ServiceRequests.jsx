import React, { useState, useMemo, useEffect, useCallback } from 'react';
import { serviceRequestService } from '../services/serviceRequestService.js';
import { useAuth } from '../context/AuthContext.jsx';
import { Pagination } from '../components/common/Pagination.jsx';
import { TableSkeleton } from '../components/common/TableSkeleton.jsx';
import { SearchIcon, RefreshCwIcon, CloseIcon, ClipboardListIcon, ClockIcon, CalendarIcon, SettingsIcon } from '../components/icons/index.js';
import '../styles/pages/service-requests.css';

export const ServiceRequests = () => {
  const { role } = useAuth();
  const isStaffOrAdmin = role === 'Admin' || role === 'Staff';

  // Navigation tab for Admin/Staff ('queue' | 'slots')
  const [activeTab, setActiveTab] = useState('queue');

  // Master Service Requests state
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

  const getTomorrowStr = () => {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return d.toISOString().split('T')[0];
  };

  const getTodayStr = () => {
    return new Date().toISOString().split('T')[0];
  };

  const formatDate = (dateStr) => {
    if (!dateStr) return '—';
    try {
      const d = new Date(dateStr);
      if (isNaN(d.getTime())) return dateStr;
      return d.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
      });
    } catch {
      return dateStr;
    }
  };

  // Pre-calculated standard 30-min time increments (06:00 to 22:00) for seamless 1-click time picking
  const STANDARD_TIME_OPTIONS = useMemo(() => {
    const options = [];
    for (let h = 6; h <= 22; h++) {
      for (let m = 0; m < 60; m += 30) {
        const hh = String(h).padStart(2, '0');
        const mm = String(m).padStart(2, '0');
        const val = `${hh}:${mm}`;
        const period = h >= 12 ? 'PM' : 'AM';
        const h12 = h % 12 === 0 ? 12 : h % 12;
        const label12 = `${String(h12).padStart(2, '0')}:${mm} ${period}`;
        options.push({ value: val, display: `${label12} (${val})` });
      }
    }
    return options;
  }, []);

  const formatTime12Hour = (val24) => {
    if (!val24 || typeof val24 !== 'string') return '';
    const parts = val24.split(':');
    if (parts.length < 2) return val24;
    const h = parseInt(parts[0], 10);
    const m = parts[1];
    if (isNaN(h)) return val24;
    const period = h >= 12 ? 'PM' : 'AM';
    const h12 = h % 12 === 0 ? 12 : h % 12;
    return `${String(h12).padStart(2, '0')}:${m} ${period}`;
  };

  const getDefaultSlotLabel = (start24, end24) => {
    if (!start24 || !end24) return '';
    return `${formatTime12Hour(start24)} - ${formatTime12Hour(end24)}`;
  };

  const COMMON_SLOT_PRESETS = [
    { start: '09:00', end: '11:00', label: '09:00 AM - 11:00 AM (Morning)' },
    { start: '11:00', end: '13:00', label: '11:00 AM - 01:00 PM (Midday)' },
    { start: '14:00', end: '16:00', label: '02:00 PM - 04:00 PM (Afternoon)' },
    { start: '16:00', end: '18:00', label: '04:00 PM - 06:00 PM (Evening)' },
  ];

  // Create Service Request modal state
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [createData, setCreateData] = useState({
    title: '',
    description: '',
    preferredDate: '',
    slotId: null,
    preferredTime: '',
  });
  const [creatingRequest, setCreatingRequest] = useState(false);
  const [modalSlots, setModalSlots] = useState([]);
  const [loadingModalSlots, setLoadingModalSlots] = useState(false);

  // Notification toast
  const [notification, setNotification] = useState(null);

  // Time Slot Management states (Admin/Staff)
  const [adminSlots, setAdminSlots] = useState([]);
  const [loadingAdminSlots, setLoadingAdminSlots] = useState(false);
  const [selectedScheduleDate, setSelectedScheduleDate] = useState(getTomorrowStr());
  const [scheduleSlots, setScheduleSlots] = useState([]);
  const [loadingScheduleSlots, setLoadingScheduleSlots] = useState(false);

  // Master slot modal (Add / Edit)
  const [isSlotModalOpen, setIsSlotModalOpen] = useState(false);
  const [editingSlot, setEditingSlot] = useState(null);
  const [slotFormData, setSlotFormData] = useState({
    startTime: '09:00',
    endTime: '11:00',
    label: '09:00 AM - 11:00 AM',
    defaultCapacity: 5,
    isActive: true,
  });
  const [savingSlot, setSavingSlot] = useState(false);

  // Date closure modal / actions
  const [isOverrideModalOpen, setIsOverrideModalOpen] = useState(false);
  const [overrideTargetSlot, setOverrideTargetSlot] = useState(null);
  const [savingOverride, setSavingOverride] = useState(false);

  const showNotification = (type, message) => {
    setNotification({ type, message });
    setTimeout(() => {
      setNotification(null);
    }, 5000);
  };

  // Load Service Requests Queue
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

  // Load Master Slots for Admin (sorted chronologically by Start Time)
  const loadAdminSlots = useCallback(async () => {
    if (!isStaffOrAdmin) return;
    setLoadingAdminSlots(true);
    try {
      const slots = await serviceRequestService.fetchAdminSlots();
      const sorted = (Array.isArray(slots) ? slots : []).sort((a, b) =>
        (a.startTime || '').localeCompare(b.startTime || '')
      );
      setAdminSlots(sorted);
    } catch (err) {
      showNotification('error', err.message || 'Failed to load time slots.');
    } finally {
      setLoadingAdminSlots(false);
    }
  }, [isStaffOrAdmin]);

  // Load daily schedule capacity for selected date
  const loadScheduleSlots = useCallback(async (dateStr) => {
    if (!isStaffOrAdmin || !dateStr) return;
    setLoadingScheduleSlots(true);
    try {
      const slots = await serviceRequestService.fetchTimeSlotsForDate(dateStr);
      setScheduleSlots(slots);
    } catch (err) {
      showNotification('error', err.message || 'Failed to load daily schedule.');
    } finally {
      setLoadingScheduleSlots(false);
    }
  }, [isStaffOrAdmin]);

  useEffect(() => {
    loadData();
  }, []);

  useEffect(() => {
    if (activeTab === 'slots' && isStaffOrAdmin) {
      loadAdminSlots();
      loadScheduleSlots(selectedScheduleDate);
    }
  }, [activeTab, isStaffOrAdmin, loadAdminSlots, loadScheduleSlots, selectedScheduleDate]);

  // Compute live stats
  const stats = useMemo(() => serviceRequestService.getStats(requests), [requests]);

  // Status options for filter pills with live counts
  const STATUS_OPTIONS = useMemo(
    () => [
      { label: 'All Requests', value: 'all', count: requests.length },
      { label: 'Booked', value: 'booked', count: (stats.booked ?? stats.pending) || 0 },
      { label: 'In Progress', value: 'in progress', count: stats.inProgress || 0 },
      { label: 'Completed', value: 'completed', count: stats.completed || 0 },
      {
        label: 'No Show',
        value: 'no show',
        count: requests.filter((r) => (r.status || '').toLowerCase() === 'no show').length,
      },
      {
        label: 'Cancelled',
        value: 'cancelled',
        count: requests.filter((r) => {
          const s = (r.status || '').toLowerCase();
          return s === 'cancelled' || s === 'canceled';
        }).length,
      },
    ],
    [requests, stats]
  );

  // Selected request for details modal
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
        } else if (target === 'no show') {
          if (current !== 'no show') return false;
        } else if (target === 'cancelled') {
          if (current !== 'cancelled' && current !== 'canceled') return false;
        } else if (target === 'booked' || target === 'pending') {
          if (current !== 'booked' && current !== 'pending') return false;
        } else if (current !== target) {
          return false;
        }
      }

      if (startDateFilter) {
        const itemDate = r.preferredDate || r.createdAt;
        if (!itemDate || itemDate.substring(0, 10) < startDateFilter) return false;
      }

      if (endDateFilter) {
        const itemDate = r.preferredDate || r.createdAt;
        if (!itemDate || itemDate.substring(0, 10) > endDateFilter) return false;
      }

      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase().trim();
        const num = (r.serviceRequestNumber || '').toLowerCase();
        const title = (r.title || '').toLowerCase();
        const desc = (r.description || '').toLowerCase();
        const cust = (r.customerName || '').toLowerCase();
        const email = (r.customerEmail || '').toLowerCase();
        if (
          !num.includes(q) &&
          !title.includes(q) &&
          !desc.includes(q) &&
          !cust.includes(q) &&
          !email.includes(q)
        ) {
          return false;
        }
      }

      return true;
    });
  }, [requests, statusFilter, startDateFilter, endDateFilter, searchQuery]);

  const totalPages = Math.ceil(filteredRequests.length / pageSize) || 1;
  const paginatedRequests = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredRequests.slice(start, start + pageSize);
  }, [filteredRequests, currentPage, pageSize]);

  // Fetch slot availability for creation modal
  const handleModalDateChange = async (dateStr) => {
    setCreateData((prev) => ({ ...prev, preferredDate: dateStr, slotId: null, preferredTime: '' }));
    if (!dateStr) {
      setModalSlots([]);
      return;
    }
    setLoadingModalSlots(true);
    try {
      const slots = await serviceRequestService.fetchTimeSlotsForDate(dateStr);
      setModalSlots(slots);
      // Auto-select first available slot if any
      const firstAvail = slots.find((s) => s.isAvailable);
      if (firstAvail) {
        setCreateData((prev) => ({
          ...prev,
          preferredDate: dateStr,
          slotId: firstAvail.slotId,
          preferredTime: firstAvail.label,
        }));
      }
    } catch {
      setModalSlots([]);
    } finally {
      setLoadingModalSlots(false);
    }
  };

  const handleOpenCreateModal = () => {
    const tomorrow = getTomorrowStr();
    setCreateData({
      title: '',
      description: '',
      preferredDate: tomorrow,
      slotId: null,
      preferredTime: '',
    });
    handleModalDateChange(tomorrow);
    setIsCreateModalOpen(true);
  };

  // Submit new Service Request with chosen time slot
  const handleCreateSubmit = async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    if (!createData.title || !createData.title.trim()) {
      showNotification('error', 'Issue title is required.');
      return;
    }
    if (createData.title.trim().length < 3) {
      showNotification('error', 'Issue title must be at least 3 characters.');
      return;
    }
    if (!createData.description || !createData.description.trim()) {
      showNotification('error', 'Problem description is required.');
      return;
    }
    if (createData.description.trim().length < 10) {
      showNotification('error', 'Please provide a more detailed problem description (at least 10 characters).');
      return;
    }
    if (!createData.preferredDate || !createData.preferredDate.trim()) {
      showNotification('error', 'Appointment date is required. Please select a date.');
      return;
    }
    if (!createData.slotId) {
      showNotification('error', 'Time slot is required. Please select an available time slot.');
      return;
    }

    setCreatingRequest(true);
    try {
      const created = await serviceRequestService.createServiceRequest({
        title: createData.title.trim(),
        description: createData.description.trim(),
        slotId: createData.slotId,
        preferredDate: createData.preferredDate,
        preferredTime: createData.preferredTime,
      });
      setRequests((prev) => [created, ...prev]);
      setIsCreateModalOpen(false);
      showNotification('success', `Service Request ${created.serviceRequestNumber} booked successfully!`);
    } catch (err) {
      showNotification('error', err.message || 'Failed to create service request.');
    } finally {
      setCreatingRequest(false);
    }
  };

  // Cancel a service request
  const handleCancelRequest = async (srId) => {
    if (!window.confirm('Are you sure you want to cancel this service request? This will free up the slot.')) {
      return;
    }
    try {
      const cancelled = await serviceRequestService.cancelServiceRequest(srId);
      setRequests((prev) =>
        prev.map((r) =>
          r.serviceRequestId === srId || r.serviceRequestNumber === srId
            ? { ...r, status: cancelled.status }
            : r
        )
      );
      if (activeSrId === srId) {
        setActiveSrId(null);
      }
      showNotification('success', `Service Request ${srId} has been cancelled.`);
      if (activeTab === 'slots') {
        loadScheduleSlots(selectedScheduleDate);
      }
    } catch (err) {
      showNotification('error', err.message || 'Failed to cancel service request.');
    }
  };

  // Update status (Staff/Admin)
  const handleStatusChange = async (srId, newStatus) => {
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

  // --- ADMIN TIME SLOT ACTIONS ---

  const handleOpenAddSlotModal = () => {
    setEditingSlot(null);
    setSlotFormData({
      startTime: '09:00',
      endTime: '11:00',
      label: '09:00 AM - 11:00 AM',
      defaultCapacity: 5,
      isActive: true,
    });
    setIsSlotModalOpen(true);
  };

  const handleOpenEditSlotModal = (slot) => {
    setEditingSlot(slot);
    setSlotFormData({
      startTime: slot.startTime,
      endTime: slot.endTime,
      label: slot.label,
      defaultCapacity: slot.defaultCapacity,
      isActive: slot.isActive,
    });
    setIsSlotModalOpen(true);
  };

  const handleSaveSlot = async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    if (!slotFormData.startTime || !slotFormData.endTime) {
      showNotification('error', 'Start and end time are required.');
      return;
    }
    if (slotFormData.startTime >= slotFormData.endTime) {
      showNotification('error', 'End time must be later than start time.');
      return;
    }
    if (Number(slotFormData.defaultCapacity) <= 0) {
      showNotification('error', 'Capacity must be at least 1.');
      return;
    }

    const resolvedLabel = slotFormData.label && slotFormData.label.trim() !== ''
      ? slotFormData.label.trim()
      : getDefaultSlotLabel(slotFormData.startTime, slotFormData.endTime);

    setSavingSlot(true);
    try {
      if (editingSlot) {
        await serviceRequestService.updateSlot(editingSlot.slotId, {
          startTime: slotFormData.startTime,
          endTime: slotFormData.endTime,
          label: resolvedLabel,
          defaultCapacity: Number(slotFormData.defaultCapacity),
          isActive: slotFormData.isActive,
        });
        showNotification('success', 'Time slot updated successfully.');
      } else {
        await serviceRequestService.createSlot({
          startTime: slotFormData.startTime,
          endTime: slotFormData.endTime,
          label: resolvedLabel,
          defaultCapacity: Number(slotFormData.defaultCapacity),
          isActive: slotFormData.isActive,
        });
        showNotification('success', 'New time slot created successfully.');
      }
      setIsSlotModalOpen(false);
      loadAdminSlots();
      loadScheduleSlots(selectedScheduleDate);
    } catch (err) {
      showNotification('error', err.message || 'Failed to save time slot.');
    } finally {
      setSavingSlot(false);
    }
  };

  const handleToggleSlotActive = async (slotId) => {
    try {
      const target = adminSlots.find((s) => s.slotId === slotId);
      const willBeActive = target ? !target.isActive : true;
      await serviceRequestService.toggleSlotActive(slotId);
      loadAdminSlots();
      loadScheduleSlots(selectedScheduleDate);
      showNotification(
        'success',
        willBeActive ? 'Time slot enabled for bookings.' : 'Time slot disabled.'
      );
    } catch (err) {
      showNotification('error', err.message || 'Failed to toggle slot status.');
    }
  };

  const handleDeleteSlot = async (slotId) => {
    if (!window.confirm('Are you sure you want to delete this time slot? (Slots with bookings cannot be deleted and must be deactivated).')) {
      return;
    }
    try {
      await serviceRequestService.deleteSlot(slotId);
      showNotification('success', 'Time slot deleted.');
      loadAdminSlots();
      loadScheduleSlots(selectedScheduleDate);
    } catch (err) {
      showNotification('error', err.message || 'Cannot delete slot. Please deactivate it instead.');
    }
  };

  // Close / Reopen slot for selected date
  const handleOpenCloseSlotModal = (slot) => {
    setOverrideTargetSlot(slot);
    setIsOverrideModalOpen(true);
  };

  const handleConfirmCloseSlot = async () => {
    if (!overrideTargetSlot) return;
    setSavingOverride(true);
    try {
      await serviceRequestService.setSlotOverride(overrideTargetSlot.slotId, {
        date: selectedScheduleDate,
        isClosed: true,
      });
      showNotification('success', `Time slot closed for ${selectedScheduleDate}.`);
      setIsOverrideModalOpen(false);
      loadScheduleSlots(selectedScheduleDate);
    } catch (err) {
      showNotification('error', err.message || 'Failed to close time slot.');
    } finally {
      setSavingOverride(false);
    }
  };

  const handleReopenSlot = async (slot) => {
    try {
      await serviceRequestService.removeSlotOverride(slot.slotId, selectedScheduleDate);
      showNotification('success', `Time slot reopened for ${selectedScheduleDate}.`);
      loadScheduleSlots(selectedScheduleDate);
    } catch (err) {
      showNotification('error', err.message || 'Failed to reopen time slot.');
    }
  };

  const getStatusBadge = (status) => {
    const s = (status || '').toUpperCase().replace(/_/g, ' ');
    switch (s) {
      case 'BOOKED':
      case 'PENDING':
        return <span className="badge badge-warning">Booked</span>;
      case 'IN PROGRESS':
      case 'IN SERVICE':
      case 'UNDER REVIEW':
      case 'SCHEDULED':
        return (
          <span className="badge" style={{ backgroundColor: '#e0e7ff', color: '#4338ca', border: '1px solid #c7d2fe' }}>
            In Progress
          </span>
        );
      case 'COMPLETED':
      case 'RESOLVED':
        return <span className="badge badge-success">Completed</span>;
      case 'NO SHOW':
        return (
          <span className="badge" style={{ backgroundColor: '#fff7ed', color: '#c2410c', border: '1px solid #ffedd5' }}>
            No Show
          </span>
        );
      case 'CANCELLED':
      case 'CANCELED':
      case 'REJECTED':
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
            After-sales customer repair, diagnostics, and appointment capacity management.
          </p>
        </div>
        <div className="header-actions" style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
          <span className="badge badge-lg badge-admin">
            {role === 'Admin' ? 'ADMIN OVERSIGHT' : 'STAFF WORKBENCH'}
          </span>
          <button
            onClick={handleOpenCreateModal}
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

      {/* Tab Navigation for Staff/Admin */}
      {isStaffOrAdmin && (
        <div
          style={{
            display: 'flex',
            gap: '0.75rem',
            borderBottom: '1px solid var(--border)',
            paddingBottom: '0.5rem',
            marginBottom: '1.5rem',
          }}
        >
          <button
            type="button"
            onClick={() => setActiveTab('queue')}
            className={`btn ${activeTab === 'queue' ? 'btn-primary' : 'btn-outline'}`}
            style={{ padding: '0.5rem 1.25rem', borderRadius: 'var(--radius-lg)', display: 'inline-flex', alignItems: 'center', gap: '0.45rem' }}
          >
            <ClipboardListIcon size={16} />
            <span>Requests Queue ({requests.length})</span>
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('slots')}
            className={`btn ${activeTab === 'slots' ? 'btn-primary' : 'btn-outline'}`}
            style={{ padding: '0.5rem 1.25rem', borderRadius: 'var(--radius-lg)', display: 'inline-flex', alignItems: 'center', gap: '0.45rem' }}
          >
            <ClockIcon size={16} />
            <span>Time Slot Management</span>
          </button>
        </div>
      )}

      {/* ========================================================= */}
      {/* TAB 1: SERVICE REQUESTS QUEUE                             */}
      {/* ========================================================= */}
      {activeTab === 'queue' && (
        <>
          {/* KPI Stats Cards */}
          <div className="stats-grid">
            <div className="stat-card stat-card-total">
              <span className="stat-label">Total Requests</span>
              <span className="stat-value">{stats.total}</span>
              <span className="stat-subtext">All recorded requests</span>
            </div>
            <div className="stat-card stat-card-inactive">
              <span className="stat-label">Booked</span>
              <span className="stat-value" style={{ color: 'var(--warning-text)' }}>
                {stats.booked ?? stats.pending}
              </span>
              <span className="stat-subtext">Awaiting intake / drop-off</span>
            </div>
            <div className="stat-card stat-card-tech">
              <span className="stat-label">In Progress</span>
              <span className="stat-value" style={{ color: 'var(--accent-purple)' }}>
                {stats.inProgress}
              </span>
              <span className="stat-subtext">Under diagnostic or repair</span>
            </div>
            <div className="stat-card stat-card-active">
              <span className="stat-label">Completed</span>
              <span className="stat-value" style={{ color: 'var(--success-text)' }}>
                {stats.completed}
              </span>
              <span className="stat-subtext">Repaired and collected</span>
            </div>
          </div>

          {/* Service Requests Filter Toolbar */}
          <div className="service-requests-toolbar" style={{ marginTop: '1.5rem' }}>
            <div className="sr-toolbar-top-row">
              <div className="sr-search-box">
                <span className="sr-search-icon">
                  <SearchIcon size={16} />
                </span>
                <input
                  type="text"
                  placeholder="Search SR-number, customer, or issue..."
                  value={searchQuery}
                  onChange={(e) => {
                    setSearchQuery(e.target.value);
                    setCurrentPage(1);
                  }}
                  className="sr-search-input"
                />
              </div>

              <div className="sr-filters-group">
                <div className="sr-date-filter-group" title="Filter by date range">
                  <span className="sr-date-filter-label">From</span>
                  <input
                    type="date"
                    value={startDateFilter}
                    onChange={(e) => {
                      setStartDateFilter(e.target.value);
                      setCurrentPage(1);
                    }}
                    className="sr-date-input"
                  />
                  <span className="sr-date-filter-label" style={{ marginLeft: '0.25rem' }}>To</span>
                  <input
                    type="date"
                    value={endDateFilter}
                    onChange={(e) => {
                      setEndDateFilter(e.target.value);
                      setCurrentPage(1);
                    }}
                    className="sr-date-input"
                  />
                </div>

                <button
                  type="button"
                  onClick={loadData}
                  className="btn btn-outline-sm"
                  title="Refresh requests"
                  style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}
                >
                  <RefreshCwIcon size={14} /> Refresh
                </button>

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
                    title="Clear all active filters"
                  >
                    Clear Filters
                  </button>
                )}
              </div>
            </div>

            {/* Status Pills Row with Live Counts */}
            <div className="sr-status-pills-row">
              {STATUS_OPTIONS.map((opt) => (
                <button
                  key={opt.value}
                  type="button"
                  className={`sr-status-pill ${statusFilter === opt.value ? 'active' : ''}`}
                  onClick={() => {
                    setStatusFilter(opt.value);
                    setCurrentPage(1);
                  }}
                >
                  {opt.label}
                  <span className="sr-pill-count">{opt.count}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Service Requests Table Card */}
          <div className="data-table-card">
            <div className="table-header-banner">
              <div>
                <h3>Service Requests Directory ({filteredRequests.length})</h3>
                <span className="table-header-subtitle">
                  Showing {paginatedRequests.length} of {requests.length} total scheduled bookings
                </span>
              </div>
              <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                <button
                  type="button"
                  className="btn btn-primary-sm"
                  onClick={() => {
                    setCreateData({
                      title: '',
                      description: '',
                      preferredDate: getTomorrowStr(),
                      preferredTime: '',
                      slotId: null,
                    });
                    setIsCreateModalOpen(true);
                  }}
                  id="book-service-request-btn"
                >
                  + Book Service Request
                </button>
              </div>
            </div>

            <div className="table-responsive">
              <table className="data-table" id="service-requests-table">
                <thead>
                  <tr>
                    <th style={{ width: '130px' }}>Request #</th>
                    <th>Customer</th>
                    <th>Issue Title</th>
                    <th>Appointment Date</th>
                    <th>Time Slot</th>
                    <th>Status</th>
                    <th style={{ textAlign: 'right', minWidth: '180px' }}>Actions</th>
                  </tr>
                </thead>
                {loading ? (
                  <TableSkeleton columns={7} rows={6} />
                ) : paginatedRequests.length === 0 ? (
                  <tbody>
                    <tr>
                      <td colSpan="7" style={{ padding: 0 }}>
                        <div className="empty-state">
                          <div className="empty-state-icon">
                            <svg
                              width="40"
                              height="40"
                              viewBox="0 0 24 24"
                              fill="none"
                              stroke="currentColor"
                              strokeWidth="1.5"
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              style={{ color: 'var(--text-muted)' }}
                            >
                              <rect x="2" y="7" width="20" height="14" rx="2" ry="2" />
                              <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16" />
                            </svg>
                          </div>
                          <h4>No service requests found</h4>
                          <p>No service requests match your search query or filter criteria.</p>
                          {(searchQuery || statusFilter !== 'all' || startDateFilter || endDateFilter) && (
                            <button
                              type="button"
                              className="btn btn-outline-sm"
                              style={{ marginTop: '0.75rem' }}
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
                          )}
                        </div>
                      </td>
                    </tr>
                  </tbody>
                ) : (
                  <tbody>
                    {paginatedRequests.map((req) => {
                      const isCompleted = (req.status || '').toLowerCase() === 'completed';
                      const isCancelled =
                        (req.status || '').toLowerCase() === 'cancelled' ||
                        (req.status || '').toLowerCase() === 'canceled';
                      const isNoShow = (req.status || '').toLowerCase() === 'no show';
                      const isTerminal = isCompleted || isCancelled || isNoShow;

                      return (
                        <tr
                          key={req.serviceRequestId || req.serviceRequestNumber}
                          id={`sr-row-${req.serviceRequestId}`}
                        >
                          <td>
                            <button
                              type="button"
                              onClick={() => setActiveSrId(req.serviceRequestId)}
                              className="sr-id-btn"
                              title="Click to view full request details"
                            >
                              {req.serviceRequestNumber}
                            </button>
                          </td>
                          <td>
                            <div className="customer-cell-wrapper">
                              <span className="customer-name">
                                {req.customerName || 'Customer'}
                              </span>
                              <span className="customer-email">
                                {req.customerEmail || 'No email provided'}
                              </span>
                            </div>
                          </td>
                          <td>
                            <div
                              style={{
                                maxWidth: '240px',
                                whiteSpace: 'nowrap',
                                overflow: 'hidden',
                                textOverflow: 'ellipsis',
                              }}
                            >
                              <span style={{ fontWeight: 600, color: 'var(--text-main)' }}>
                                {req.title || 'General PC Service Request'}
                              </span>
                            </div>
                          </td>
                          <td>
                            <div className="sr-date-cell">
                              <svg
                                className="sr-date-icon"
                                width="14"
                                height="14"
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth="2"
                                strokeLinecap="round"
                                strokeLinejoin="round"
                              >
                                <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                                <line x1="16" y1="2" x2="16" y2="6" />
                                <line x1="8" y1="2" x2="8" y2="6" />
                                <line x1="3" y1="10" x2="21" y2="10" />
                              </svg>
                              <span>{formatDate(req.preferredDate || req.createdAt)}</span>
                            </div>
                          </td>
                          <td>
                            <span
                              className="badge"
                              style={{
                                backgroundColor: '#f1f5f9',
                                color: '#334155',
                                border: '1px solid #e2e8f0',
                                fontSize: '0.75rem',
                                fontWeight: 600,
                              }}
                            >
                              {req.timeSlotLabel || req.preferredTime || 'Standard'}
                            </span>
                          </td>
                          <td>{getStatusBadge(req.status)}</td>
                          <td style={{ textAlign: 'right' }}>
                            <div
                              className="action-btn-group"
                              style={{
                                justifyContent: 'flex-end',
                                display: 'flex',
                                gap: '0.4rem',
                                alignItems: 'center',
                              }}
                            >
                              <button
                                type="button"
                                className="btn btn-outline-sm"
                                onClick={() => setActiveSrId(req.serviceRequestId)}
                                title="View Request Details"
                              >
                                View Details
                              </button>
                              {isStaffOrAdmin && !isTerminal && (
                                <select
                                  value={req.status}
                                  onChange={(e) =>
                                    handleStatusChange(req.serviceRequestId, e.target.value)
                                  }
                                  className="sr-status-select"
                                  title="Quick status change"
                                >
                                  <option value="Booked">Booked</option>
                                  {req.status === 'Pending' && <option value="Pending">Pending</option>}
                                  <option value="In Progress">In Progress</option>
                                  <option value="Completed">Completed</option>
                                  <option value="No Show">No Show</option>
                                  <option value="Cancelled">Cancelled</option>
                                </select>
                              )}
                              {!isTerminal && (
                                <button
                                  type="button"
                                  onClick={() => handleCancelRequest(req.serviceRequestId)}
                                  className="btn btn-danger-sm"
                                  title="Cancel Request"
                                >
                                  Cancel
                                </button>
                              )}
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                )}
              </table>
            </div>

            {!loading && filteredRequests.length > 0 && (
              <Pagination
                currentPage={currentPage}
                totalPages={totalPages}
                onPageChange={setCurrentPage}
                pageSize={pageSize}
                pageSizeOptions={[10, 25, 50]}
                onPageSizeChange={(sz) => {
                  setPageSize(sz);
                  setCurrentPage(1);
                }}
                totalItems={filteredRequests.length}
                itemLabel="requests"
              />
            )}
          </div>
        </>
      )}

      {/* ========================================================= */}
      {/* TAB 2: TIME SLOT MANAGEMENT (Admin / Staff)              */}
      {/* ========================================================= */}
      {activeTab === 'slots' && isStaffOrAdmin && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
          {/* SECTION A: Daily Slot Schedule & Capacity Overview */}
          <div
            style={{
              padding: '1.5rem',
              backgroundColor: 'var(--bg-card, #fff)',
              border: '1px solid var(--border)',
              borderRadius: 'var(--radius-xl)',
              boxShadow: 'var(--shadow-sm)',
            }}
          >
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                flexWrap: 'wrap',
                gap: '1rem',
                marginBottom: '1.25rem',
              }}
            >
              <div>
                <h2 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <CalendarIcon size={20} color="var(--primary)" />
                  <span>Daily Slot Schedule & Capacity Inspector</span>
                </h2>
                <p style={{ margin: '0.25rem 0 0', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                  View booked appointments vs capacity per time slot on any given date, or apply date overrides.
                </p>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <label style={{ fontSize: '0.85rem', fontWeight: 600 }}>Inspect Date:</label>
                <input
                  type="date"
                  value={selectedScheduleDate}
                  onChange={(e) => setSelectedScheduleDate(e.target.value)}
                  className="filter-select"
                  style={{ padding: '0.45rem 0.75rem', fontWeight: 600 }}
                />
                <button
                  type="button"
                  onClick={() => loadScheduleSlots(selectedScheduleDate)}
                  className="btn btn-outline"
                  title="Refresh schedule"
                >
                  <RefreshCwIcon size={14} />
                </button>
              </div>
            </div>

            {loadingScheduleSlots ? (
              <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                Loading date schedule...
              </div>
            ) : scheduleSlots.length === 0 ? (
              <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                No active time slots configured for {selectedScheduleDate}.
              </div>
            ) : (
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))',
                  gap: '1.25rem',
                }}
              >
                {scheduleSlots.map((slot) => {
                  const utilizationPercent =
                    slot.maxCapacity > 0
                      ? Math.min(100, Math.round((slot.bookedCount / slot.maxCapacity) * 100))
                      : 100;
                  const isFull = slot.remainingSlots === 0;

                  return (
                    <div
                      key={slot.slotId}
                      style={{
                        padding: '1.25rem',
                        border: `1px solid ${
                          slot.isClosed
                            ? '#fca5a5'
                            : isFull
                            ? '#fdba74'
                            : 'var(--border)'
                        }`,
                        backgroundColor: slot.isClosed
                          ? '#fef2f2'
                          : isFull
                          ? '#fff7ed'
                          : 'var(--bg-subtle, #f8fafc)',
                        borderRadius: 'var(--radius-lg)',
                        display: 'flex',
                        flexDirection: 'column',
                        justifyContent: 'space-between',
                      }}
                    >
                      <div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                          <div>
                            <span style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-main)' }}>
                              {slot.label}
                            </span>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.15rem' }}>
                              Time: {slot.startTime} – {slot.endTime}
                            </div>
                          </div>
                          <div>
                            {slot.isClosed ? (
                              <span className="badge badge-error">Closed</span>
                            ) : isFull ? (
                              <span className="badge badge-error" style={{ backgroundColor: '#ef4444' }}>Full</span>
                            ) : (
                              <span className="badge badge-success">Available</span>
                            )}
                          </div>
                        </div>

                        {/* Capacity Details & Utilization Bar */}
                        <div style={{ marginTop: '1rem' }}>
                          <div
                            style={{
                              display: 'flex',
                              justifyContent: 'space-between',
                              fontSize: '0.85rem',
                              fontWeight: 600,
                              marginBottom: '0.35rem',
                            }}
                          >
                            <span>
                              {slot.isClosed
                                ? 'Status: Closed for this Date'
                                : `Booked: ${slot.bookedCount} / ${slot.defaultCapacity}`}
                            </span>
                            {!slot.isClosed && (
                              <span style={{ color: slot.remainingSlots > 0 ? '#10b981' : '#ef4444' }}>
                                {slot.remainingSlots} left
                              </span>
                            )}
                          </div>

                          <div
                            style={{
                              width: '100%',
                              height: '8px',
                              backgroundColor: 'rgba(0,0,0,0.08)',
                              borderRadius: '4px',
                              overflow: 'hidden',
                            }}
                          >
                            <div
                              style={{
                                width: slot.isClosed ? '100%' : `${utilizationPercent}%`,
                                height: '100%',
                                backgroundColor: slot.isClosed
                                  ? '#ef4444'
                                  : isFull
                                  ? '#f97316'
                                  : utilizationPercent > 60
                                  ? '#eab308'
                                  : '#10b981',
                                transition: 'width 0.3s ease',
                              }}
                            />
                          </div>

                          <div
                            style={{
                              display: 'flex',
                              justifyContent: 'space-between',
                              marginTop: '0.5rem',
                              fontSize: '0.75rem',
                              color: 'var(--text-muted)',
                            }}
                          >
                            <span>Capacity: {slot.defaultCapacity} per day</span>
                            <span style={{ fontWeight: 600, color: slot.isClosed ? '#ef4444' : '#10b981' }}>
                              {slot.isClosed ? 'Closed' : 'Open'}
                            </span>
                          </div>
                        </div>
                      </div>

                      {/* Override Actions */}
                      <div
                        style={{
                          marginTop: '1.25rem',
                          paddingTop: '0.75rem',
                          borderTop: '1px dashed var(--border)',
                          display: 'flex',
                          gap: '0.5rem',
                          justifyContent: 'flex-end',
                        }}
                      >
                        {slot.isClosed ? (
                          <button
                            type="button"
                            onClick={() => handleReopenSlot(slot)}
                            className="btn btn-sm btn-primary"
                            style={{ fontSize: '0.8rem', padding: '0.35rem 0.75rem' }}
                            title={`Reopen this slot on ${selectedScheduleDate}`}
                          >
                            Reopen Slot
                          </button>
                        ) : (
                          <button
                            type="button"
                            onClick={() => handleOpenCloseSlotModal(slot)}
                            className="btn btn-sm btn-outline"
                            style={{ fontSize: '0.8rem', padding: '0.35rem 0.75rem', color: '#dc2626', borderColor: '#fca5a5' }}
                            title={`Close this slot on ${selectedScheduleDate}`}
                          >
                            Close for this Date
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* SECTION B: Master Time Slot Configuration Table */}
          <div
            style={{
              padding: '1.5rem',
              backgroundColor: 'var(--bg-card, #fff)',
              border: '1px solid var(--border)',
              borderRadius: 'var(--radius-xl)',
              boxShadow: 'var(--shadow-sm)',
            }}
          >
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '1.25rem',
              }}
            >
              <div>
                <h2 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <SettingsIcon size={20} color="var(--primary)" />
                  <span>Configured Master Time Slots</span>
                </h2>
                <p style={{ margin: '0.25rem 0 0', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                  Define recurring appointment windows, default daily capacities, and active/inactive status.
                </p>
              </div>

              <button
                type="button"
                onClick={handleOpenAddSlotModal}
                className="btn btn-primary"
                id="add-time-slot-btn"
              >
                + New Time Slot
              </button>
            </div>

            {loadingAdminSlots ? (
              <TableSkeleton columns={6} rows={4} />
            ) : adminSlots.length === 0 ? (
              <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
                No time slots configured. Click "+ New Time Slot" to define one.
              </div>
            ) : (
              <div className="table-responsive">
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Time Window</th>
                      <th>Slot Label</th>
                      <th>Daily Capacity</th>
                      <th>Status</th>
                      <th style={{ textAlign: 'right' }}>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {adminSlots.map((s) => (
                      <tr key={s.slotId} style={{ opacity: s.isActive ? 1 : 0.65 }}>
                        <td>
                          <span style={{ fontWeight: 700, fontFamily: 'monospace', fontSize: '0.9rem' }}>
                            {s.startTime} - {s.endTime}
                          </span>
                        </td>
                        <td style={{ fontWeight: 600 }}>{s.label}</td>
                        <td>
                          <span className="badge badge-neutral" style={{ fontWeight: 700 }}>
                            {s.defaultCapacity} per day
                          </span>
                        </td>
                        <td>
                          <button
                            type="button"
                            onClick={() => handleToggleSlotActive(s.slotId)}
                            className="slot-toggle-pill"
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '0.45rem',
                              padding: '0.35rem 0.75rem',
                              borderRadius: '9999px',
                              fontSize: '0.8rem',
                              fontWeight: 600,
                              cursor: 'pointer',
                              border: s.isActive
                                ? '1px solid rgba(16, 185, 129, 0.4)'
                                : '1px solid rgba(156, 163, 175, 0.4)',
                              background: s.isActive
                                ? 'rgba(16, 185, 129, 0.12)'
                                : 'rgba(156, 163, 175, 0.12)',
                              color: s.isActive ? '#059669' : '#6b7280',
                              transition: 'all 0.15s ease-in-out',
                            }}
                            title={s.isActive ? 'Click to Disable Time Slot' : 'Click to Enable Time Slot'}
                          >
                            <span
                              style={{
                                width: '8px',
                                height: '8px',
                                borderRadius: '50%',
                                backgroundColor: s.isActive ? '#10b981' : '#9ca3af',
                                display: 'inline-block',
                                boxShadow: s.isActive ? '0 0 6px rgba(16, 185, 129, 0.7)' : 'none',
                              }}
                            />
                            {s.isActive ? 'Enabled' : 'Disabled'}
                          </button>
                        </td>
                        <td style={{ textAlign: 'right' }}>
                          <div style={{ display: 'inline-flex', gap: '0.5rem', alignItems: 'center' }}>
                            <button
                              type="button"
                              onClick={() => handleToggleSlotActive(s.slotId)}
                              className={`btn btn-sm ${s.isActive ? 'btn-outline' : 'btn-primary'}`}
                              style={{
                                minWidth: '78px',
                                borderColor: s.isActive ? '#f59e0b' : undefined,
                                color: s.isActive ? '#d97706' : undefined,
                              }}
                              title={
                                s.isActive
                                  ? 'Disable this time slot from taking new bookings'
                                  : 'Enable this time slot for bookings'
                              }
                            >
                              {s.isActive ? 'Disable' : 'Enable'}
                            </button>
                            <button
                              type="button"
                              onClick={() => handleOpenEditSlotModal(s)}
                              className="btn btn-sm btn-outline"
                            >
                              Edit
                            </button>
                            <button
                              type="button"
                              onClick={() => handleDeleteSlot(s.slotId)}
                              className="btn btn-sm btn-outline"
                              style={{ color: '#ef4444', borderColor: '#ef4444' }}
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
          </div>
        </div>
      )}

      {/* ========================================================= */}
      {/* MODAL: ADD / EDIT TIME SLOT (Master Config)                */}
      {/* ========================================================= */}
      {isSlotModalOpen && (
        <div className="modal-backdrop" onClick={() => setIsSlotModalOpen(false)}>
          <div
            className="modal-dialog"
            style={{ maxWidth: '500px' }}
            onClick={(e) => e.stopPropagation()}
            id="slot-editor-modal"
          >
            <div className="modal-header">
              <div>
                <h3 className="modal-title" style={{ margin: 0 }}>
                  {editingSlot ? `Edit Time Slot #${editingSlot.slotId}` : 'Add New Time Slot'}
                </h3>
                <p className="modal-subtitle">
                  Configure recurring start/end time and default customer appointment capacity.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsSlotModalOpen(false)}
                className="modal-close-btn"
                title="Close modal"
              >
                <CloseIcon size={16} />
              </button>
            </div>

            <form onSubmit={handleSaveSlot}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                {/* Quick Presets */}
                <div>
                  <label style={{ display: 'block', fontSize: '0.78rem', fontWeight: 600, color: 'var(--text-muted)', marginBottom: '0.35rem' }}>
                    Quick Presets:
                  </label>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4rem' }}>
                    {COMMON_SLOT_PRESETS.map((preset) => (
                      <button
                        key={preset.start}
                        type="button"
                        onClick={() => {
                          setSlotFormData({
                            ...slotFormData,
                            startTime: preset.start,
                            endTime: preset.end,
                            label: preset.label,
                          });
                        }}
                        className="btn btn-sm btn-outline"
                        style={{ fontSize: '0.78rem', padding: '0.25rem 0.55rem' }}
                      >
                        {preset.start} - {preset.end}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Start & End Time Dropdowns */}
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                      Start Time <span style={{ color: '#ef4444' }}>*</span>:
                    </label>
                    <select
                      value={slotFormData.startTime}
                      onChange={(e) => {
                        const newStart = e.target.value;
                        let newEnd = slotFormData.endTime;
                        if (newEnd <= newStart) {
                          const startIdx = STANDARD_TIME_OPTIONS.findIndex((o) => o.value === newStart);
                          const nextIdx = Math.min(STANDARD_TIME_OPTIONS.length - 1, startIdx + 4);
                          newEnd = STANDARD_TIME_OPTIONS[nextIdx]?.value || newStart;
                        }
                        const autoLabel = getDefaultSlotLabel(newStart, newEnd);
                        setSlotFormData({
                          ...slotFormData,
                          startTime: newStart,
                          endTime: newEnd,
                          label: autoLabel,
                        });
                      }}
                      className="filter-select"
                      style={{ width: '100%' }}
                    >
                      {!STANDARD_TIME_OPTIONS.some((o) => o.value === slotFormData.startTime) && slotFormData.startTime && (
                        <option value={slotFormData.startTime}>{formatTime12Hour(slotFormData.startTime)} ({slotFormData.startTime})</option>
                      )}
                      {STANDARD_TIME_OPTIONS.map((opt) => (
                        <option key={opt.value} value={opt.value}>
                          {opt.display}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                      End Time <span style={{ color: '#ef4444' }}>*</span>:
                    </label>
                    <select
                      value={slotFormData.endTime}
                      onChange={(e) => {
                        const newEnd = e.target.value;
                        const autoLabel = getDefaultSlotLabel(slotFormData.startTime, newEnd);
                        setSlotFormData({
                          ...slotFormData,
                          endTime: newEnd,
                          label: autoLabel,
                        });
                      }}
                      className="filter-select"
                      style={{ width: '100%' }}
                    >
                      {!STANDARD_TIME_OPTIONS.some((o) => o.value === slotFormData.endTime) && slotFormData.endTime && (
                        <option value={slotFormData.endTime}>{formatTime12Hour(slotFormData.endTime)} ({slotFormData.endTime})</option>
                      )}
                      {STANDARD_TIME_OPTIONS.map((opt) => (
                        <option key={opt.value} value={opt.value}>
                          {opt.display}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                {/* Slot Label (Auto-generated or custom) */}
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                    Label (Optional):
                  </label>
                  <input
                    type="text"
                    placeholder={getDefaultSlotLabel(slotFormData.startTime, slotFormData.endTime) || 'e.g. 09:00 AM - 11:00 AM'}
                    value={slotFormData.label}
                    onChange={(e) => setSlotFormData({ ...slotFormData, label: e.target.value })}
                    className="filter-select"
                    style={{ width: '100%', backgroundImage: 'none' }}
                  />
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.2rem' }}>
                    Auto-generated from start & end time. Custom titles (e.g. "Morning Express") are also allowed.
                  </div>
                </div>

                {/* Default Capacity (Display Order removed!) */}
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '0.35rem' }}>
                    Default Daily Capacity <span style={{ color: '#ef4444' }}>*</span>:
                  </label>
                  <input
                    type="number"
                    min={1}
                    max={200}
                    required
                    value={slotFormData.defaultCapacity}
                    onChange={(e) => setSlotFormData({ ...slotFormData, defaultCapacity: e.target.value })}
                    className="filter-select"
                    style={{ width: '100%', backgroundImage: 'none' }}
                  />
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.2rem' }}>
                    Maximum customer appointments allowed for this slot per day (can be overridden per date).
                  </div>
                </div>

                {/* Active Checkbox */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginTop: '0.25rem' }}>
                  <input
                    type="checkbox"
                    id="slot-active-check"
                    checked={slotFormData.isActive}
                    onChange={(e) => setSlotFormData({ ...slotFormData, isActive: e.target.checked })}
                    style={{ cursor: 'pointer', width: '18px', height: '18px' }}
                  />
                  <label htmlFor="slot-active-check" style={{ fontSize: '0.9rem', fontWeight: 600, cursor: 'pointer' }}>
                    Time Slot is Active and Available for Bookings
                  </label>
                </div>
              </div>

              <div
                className="modal-footer"
                style={{
                  padding: '1rem 1.5rem',
                  borderTop: '1px solid var(--border)',
                  display: 'flex',
                  justifyContent: 'flex-end',
                  gap: '0.75rem',
                }}
              >
                <button type="button" onClick={() => setIsSlotModalOpen(false)} className="btn btn-outline">
                  Cancel
                </button>
                <button type="submit" disabled={savingSlot} className="btn btn-primary">
                  {savingSlot ? 'Saving...' : editingSlot ? 'Update Time Slot' : 'Create Time Slot'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================= */}
      {/* MODAL: CLOSE TIME SLOT FOR SPECIFIC DATE                  */}
      {/* ========================================================= */}
      {isOverrideModalOpen && overrideTargetSlot && (
        <div className="modal-backdrop" onClick={() => setIsOverrideModalOpen(false)}>
          <div
            className="modal-dialog"
            style={{ maxWidth: '440px' }}
            onClick={(e) => e.stopPropagation()}
            id="slot-override-modal"
          >
            <div className="modal-header">
              <div>
                <h3 className="modal-title" style={{ margin: 0 }}>
                  Close Time Slot
                </h3>
                <p className="modal-subtitle">
                  Prevent new bookings on <strong>{selectedScheduleDate}</strong>
                </p>
              </div>
              <button
                type="button"
                onClick={() => setIsOverrideModalOpen(false)}
                className="modal-close-btn"
                title="Close modal"
              >
                <CloseIcon size={16} />
              </button>
            </div>

            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div
                style={{
                  padding: '1rem',
                  backgroundColor: 'var(--bg-subtle, #f8fafc)',
                  border: '1px solid var(--border)',
                  borderRadius: 'var(--radius-md)',
                  fontSize: '0.9rem',
                }}
              >
                <div style={{ fontWeight: 700, marginBottom: '0.35rem', color: 'var(--text-main)' }}>
                  {overrideTargetSlot.label}
                </div>
                <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>
                  Date: <strong>{selectedScheduleDate}</strong>
                </div>
                <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginTop: '0.2rem' }}>
                  Current Bookings: <strong>{overrideTargetSlot.bookedCount}</strong> | Default Capacity: <strong>{overrideTargetSlot.defaultCapacity}</strong>
                </div>
              </div>

              <p style={{ margin: 0, fontSize: '0.9rem', color: 'var(--text-main)', lineHeight: 1.5 }}>
                Are you sure you want to close this time slot on <strong>{selectedScheduleDate}</strong>? Customers will not be able to select or book this time slot on this date.
              </p>
            </div>

            <div
              className="modal-footer"
              style={{
                padding: '1rem 1.5rem',
                borderTop: '1px solid var(--border)',
                display: 'flex',
                justifyContent: 'flex-end',
                gap: '0.75rem',
              }}
            >
              <button type="button" onClick={() => setIsOverrideModalOpen(false)} className="btn btn-outline">
                Cancel
              </button>
              <button
                type="button"
                disabled={savingOverride}
                onClick={handleConfirmCloseSlot}
                className="btn btn-primary"
                style={{ backgroundColor: '#dc2626', borderColor: '#dc2626' }}
              >
                {savingOverride ? 'Closing...' : 'Close Slot on this Date'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================= */}
      {/* MODAL: DETAIL INSPECTION OF SINGLE SERVICE REQUEST        */}
      {/* ========================================================= */}
      {selectedRequest && (
        <div className="modal-backdrop" onClick={() => setActiveSrId(null)}>
          <div
            className="modal-dialog"
            style={{ maxWidth: '640px' }}
            onClick={(e) => e.stopPropagation()}
            id="service-request-detail-modal"
          >
            <div className="modal-header">
              <div>
                <h3 className="modal-title" style={{ margin: 0 }}>
                  Service Request: {selectedRequest.serviceRequestNumber}
                </h3>
                <p className="modal-subtitle">
                  Logged on {formatDate(selectedRequest.createdAt)}
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

            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>Status:</span>
                <div>{getStatusBadge(selectedRequest.status)}</div>
              </div>

              <div>
                <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Customer:</span>
                <div style={{ fontWeight: 600, fontSize: '0.95rem' }}>
                  {selectedRequest.customerName || 'Customer'}
                </div>
                {selectedRequest.customerEmail && (
                  <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                    {selectedRequest.customerEmail}
                  </div>
                )}
              </div>

              <div>
                <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Issue Title:</span>
                <div style={{ fontWeight: 600, fontSize: '1rem' }}>
                  {selectedRequest.title || 'General Service Request'}
                </div>
              </div>

              <div>
                <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Problem Description:</span>
                <div
                  style={{
                    marginTop: '0.35rem',
                    padding: '0.75rem',
                    backgroundColor: 'var(--bg-subtle)',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--border)',
                    fontSize: '0.9rem',
                    lineHeight: 1.5,
                  }}
                >
                  {selectedRequest.description || 'No detailed description provided.'}
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
                <div>
                  <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Appointment Date:</span>
                  <div style={{ fontWeight: 600 }}>
                    {formatDate(selectedRequest.preferredDate || selectedRequest.createdAt)}
                  </div>
                </div>
                <div>
                  <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Booked Time Slot:</span>
                  <div style={{ fontWeight: 600 }}>
                    {selectedRequest.timeSlotLabel || selectedRequest.preferredTime || 'Standard'}
                  </div>
                </div>
              </div>

              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  marginTop: '1.25rem',
                  paddingTop: '1rem',
                  borderTop: '1px solid var(--border)',
                }}
              >
                <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                  {isStaffOrAdmin &&
                    selectedRequest.status !== 'Completed' &&
                    selectedRequest.status !== 'Cancelled' && (
                      <select
                        value={selectedRequest.status}
                        onChange={(e) =>
                          handleStatusChange(selectedRequest.serviceRequestId, e.target.value)
                        }
                        className="sr-status-select"
                        title="Update status"
                      >
                        <option value="Booked">Booked</option>
                        {selectedRequest.status === 'Pending' && <option value="Pending">Pending</option>}
                        <option value="In Progress">In Progress</option>
                        <option value="Completed">Completed</option>
                        <option value="No Show">No Show</option>
                        <option value="Cancelled">Cancelled</option>
                      </select>
                    )}
                  {selectedRequest.status !== 'Completed' &&
                    selectedRequest.status !== 'Cancelled' &&
                    selectedRequest.status !== 'No Show' && (
                      <button
                        type="button"
                        onClick={() => {
                          handleCancelRequest(selectedRequest.serviceRequestId);
                          setActiveSrId(null);
                        }}
                        className="btn btn-danger-sm"
                      >
                        Cancel Request
                      </button>
                    )}
                </div>
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

      {/* ========================================================= */}
      {/* MODAL: CREATE SERVICE REQUEST WITH TIME SLOT PICKER       */}
      {/* ========================================================= */}
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
                <h3 className="modal-title" style={{ margin: 0 }}>
                  Book Service Request
                </h3>
                <p className="modal-subtitle">
                  Select an appointment date and an available time slot.
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

            <form onSubmit={handleCreateSubmit}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
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
                    Title <span style={{ color: '#ef4444' }}>*</span>:
                  </label>
                  <input
                    type="text"
                    required
                    className="filter-select"
                    style={{ width: '100%', backgroundImage: 'none', padding: '0.55rem 0.85rem' }}
                    placeholder="e.g. Computer won't start, Loud fan noise, Screen flickering"
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
                    Problem Description <span style={{ color: '#ef4444' }}>*</span>:
                  </label>
                  <textarea
                    rows={3}
                    required
                    className="filter-select"
                    style={{
                      width: '100%',
                      backgroundImage: 'none',
                      padding: '0.65rem 0.85rem',
                      resize: 'vertical',
                      fontFamily: 'inherit',
                    }}
                    placeholder="Describe what happened or what symptoms you are observing..."
                    value={createData.description}
                    onChange={(e) => setCreateData({ ...createData, description: e.target.value })}
                  />
                </div>

                {/* Date Picker */}
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
                    Appointment Date <span style={{ color: '#ef4444' }}>*</span>:
                  </label>
                  <input
                    type="date"
                    required
                    min={getTodayStr()}
                    className="filter-select"
                    style={{ width: '100%', backgroundImage: 'none', padding: '0.55rem 0.85rem' }}
                    value={createData.preferredDate}
                    onChange={(e) => handleModalDateChange(e.target.value)}
                  />
                </div>

                {/* Time Slots Availability Selector */}
                <div>
                  <div
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      marginBottom: '0.45rem',
                    }}
                  >
                    <label style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-main)' }}>
                      Available Time Slots <span style={{ color: '#ef4444' }}>*</span>:
                    </label>
                    {loadingModalSlots && (
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                        Checking slot capacities...
                      </span>
                    )}
                  </div>

                  {modalSlots.length === 0 && !loadingModalSlots ? (
                    <div
                      style={{
                        padding: '1rem',
                        backgroundColor: 'var(--bg-subtle)',
                        borderRadius: 'var(--radius-md)',
                        fontSize: '0.85rem',
                        color: 'var(--text-muted)',
                        textAlign: 'center',
                      }}
                    >
                      No time slots available for this date. Please pick another date.
                    </div>
                  ) : (
                    <div
                      style={{
                        display: 'grid',
                        gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))',
                        gap: '0.65rem',
                      }}
                    >
                      {modalSlots.map((slot) => {
                        const isSelected = createData.slotId === slot.slotId;
                        const isAvailable = slot.isAvailable;
                        const isClosed = slot.isClosed;

                        return (
                          <button
                            key={slot.slotId}
                            type="button"
                            disabled={!isAvailable}
                            onClick={() => {
                              if (isAvailable) {
                                setCreateData({
                                  ...createData,
                                  slotId: slot.slotId,
                                  preferredTime: slot.label,
                                });
                              }
                            }}
                            style={{
                              padding: '0.75rem 0.85rem',
                              border: `2px solid ${
                                isSelected
                                  ? 'var(--primary, #3b82f6)'
                                  : isAvailable
                                  ? 'var(--border)'
                                  : '#e2e8f0'
                              }`,
                              borderRadius: 'var(--radius-md)',
                              backgroundColor: isSelected
                                ? 'rgba(59, 130, 246, 0.08)'
                                : !isAvailable
                                ? '#f1f5f9'
                                : '#ffffff',
                              cursor: isAvailable ? 'pointer' : 'not-allowed',
                              textAlign: 'left',
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center',
                              opacity: isAvailable ? 1 : 0.65,
                              transition: 'all 0.15s ease',
                            }}
                          >
                            <div>
                              <div
                                style={{
                                  fontSize: '0.85rem',
                                  fontWeight: isSelected ? 700 : 600,
                                  color: isSelected
                                    ? 'var(--primary, #3b82f6)'
                                    : !isAvailable
                                    ? 'var(--text-muted)'
                                    : 'var(--text-main)',
                                }}
                              >
                                {slot.label}
                              </div>
                            </div>

                            <div>
                              {isClosed ? (
                                <span
                                  className="badge badge-error"
                                  style={{ fontSize: '0.7rem', padding: '0.15rem 0.45rem' }}
                                >
                                  Closed
                                </span>
                              ) : !isAvailable ? (
                                <span
                                  className="badge badge-error"
                                  style={{
                                    fontSize: '0.7rem',
                                    padding: '0.15rem 0.45rem',
                                    backgroundColor: '#ef4444',
                                  }}
                                >
                                  Full
                                </span>
                              ) : (
                                <span
                                  className="badge badge-success"
                                  style={{ fontSize: '0.7rem', padding: '0.15rem 0.45rem' }}
                                >
                                  {slot.remainingSlots} of {slot.maxCapacity} available
                                </span>
                              )}
                            </div>
                          </button>
                        );
                      })}
                    </div>
                  )}
                </div>

                <div
                  className="modal-footer"
                  style={{
                    margin: '0.5rem -1.5rem -1.5rem',
                    borderRadius: '0 0 var(--radius-xl) var(--radius-xl)',
                    padding: '1rem 1.5rem',
                    borderTop: '1px solid var(--border)',
                    display: 'flex',
                    justifyContent: 'flex-end',
                    gap: '0.75rem',
                  }}
                >
                  <button type="button" onClick={() => setIsCreateModalOpen(false)} className="btn btn-outline">
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={creatingRequest || !createData.slotId}
                    className="btn btn-primary"
                  >
                    {creatingRequest ? 'Submitting...' : 'Confirm Appointment'}
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default ServiceRequests;
