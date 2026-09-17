import React, { useState, useEffect, useMemo } from 'react';
import { buildReviewService } from '../services/buildReviewService.js';
import { staffService } from '../services/staffService.js';
import { emailService } from '../services/emailService.js';
import { useAuth } from '../context/AuthContext.jsx';
import {
  BuildReviewStats,
  BuildReviewToolbar,
  BuildReviewTable,
  BuildWorkbenchModal,
} from '../components/builds';
import { ToolsIcon, RefreshCwIcon, CloseIcon } from '../components/icons';

export const BuildReviews = () => {
  const { user } = useAuth();

  const [builds, setBuilds] = useState([]);
  const [technicians, setTechnicians] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [staffFilter, setStaffFilter] = useState('all');

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(10);

  // Selected build for detailed inspection modal
  const [selectedBuild, setSelectedBuild] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);

  // Technician review form state
  const [technicianNotes, setTechnicianNotes] = useState('');
  const [validationError, setValidationError] = useState('');

  // Toast notification
  const [notification, setNotification] = useState(null);

  const showNotification = (message, type = 'success') => {
    setNotification({ message, type });
    setTimeout(() => {
      setNotification(null);
    }, 4500);
  };

  // Load builds & staff
  const loadData = async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);

    try {
      const [buildsResult, staffResult] = await Promise.allSettled([
        buildReviewService.fetchBuilds(),
        staffService.fetchStaffFromApi(),
      ]);

      if (buildsResult.status === 'fulfilled' && Array.isArray(buildsResult.value)) {
        setBuilds(buildsResult.value);
      } else if (buildsResult.status === 'rejected') {
        console.error('Failed to load builds:', buildsResult.reason);
        showNotification('Failed to fetch build reviews from backend.', 'error');
      }

      if (staffResult.status === 'fulfilled' && Array.isArray(staffResult.value)) {
        setTechnicians(staffResult.value);
      } else if (staffResult.status === 'rejected') {
        console.warn('Could not load technicians directory:', staffResult.reason);
      }
    } catch (err) {
      console.error('Error loading build review queue:', err);
      showNotification('Failed to fetch build reviews from backend.', 'error');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Reset pagination on filter change
  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, statusFilter, staffFilter]);

  // Filtered builds
  const filteredBuilds = useMemo(() => {
    const myStaff = technicians.find(
      (t) => String(t.userId) === String(user?.userId) || String(t.staffId) === String(user?.userId)
    );
    const myStaffId = myStaff?.staffId;
    const currentUserId = user?.userId;

    return builds.filter((b) => {
      // 1. Status Filter
      if (statusFilter !== 'all' && (b.status || '').toLowerCase() !== statusFilter.toLowerCase()) {
        return false;
      }

      // 2. Staff Filter
      if (staffFilter === 'unassigned' && b.assignedStaffId != null) {
        return false;
      }
      if (staffFilter === 'my') {
        const isAssignedToMe =
          (myStaffId != null && String(b.assignedStaffId) === String(myStaffId)) ||
          (currentUserId != null && String(b.assignedStaffId) === String(currentUserId));
        if (!isAssignedToMe) {
          return false;
        }
      }
      if (staffFilter !== 'all' && staffFilter !== 'unassigned' && staffFilter !== 'my') {
        if (String(b.assignedStaffId) !== String(staffFilter)) return false;
      }

      // 3. Search query
      if (searchQuery.trim()) {
        const q = searchQuery.trim().toLowerCase();
        const cleanId = q.replace(/^#/, '');
        const matchId = String(b.buildId).includes(cleanId);
        const matchName = (b.buildName || '').toLowerCase().includes(q);
        const matchCustomer = (b.customerName || '').toLowerCase().includes(q);
        const matchEmail = (b.customerEmail || '').toLowerCase().includes(q);
        const matchNotes = (b.customerNotes || '').toLowerCase().includes(q);
        if (!matchId && !matchName && !matchCustomer && !matchEmail && !matchNotes) {
          return false;
        }
      }

      return true;
    });
  }, [builds, statusFilter, staffFilter, searchQuery, user, technicians]);

  const totalPages = Math.max(1, Math.ceil(filteredBuilds.length / pageSize));
  const paginatedBuilds = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredBuilds.slice(start, start + pageSize);
  }, [filteredBuilds, currentPage, pageSize]);

  // Summary Metrics
  const metrics = useMemo(() => {
    const total = builds.length;
    const pending = builds.filter((b) => b.status === 'Pending Staff Review').length;
    const inReview = builds.filter((b) => b.status === 'In Review by Staff').length;
    const approved = builds.filter((b) => b.status === 'Approved by Staff').length;
    const changesRequested = builds.filter((b) => b.status === 'Changes Requested').length;

    return { total, pending, inReview, approved, changesRequested };
  }, [builds]);

  // Open inspection modal
  const handleOpenInspection = async (build) => {
    setSelectedBuild(build);
    setTechnicianNotes(build.staffNotes || '');
    setValidationError('');

    // Fetch freshest detail if available
    try {
      const detailed = await buildReviewService.getBuildById(build.buildId);
      if (detailed) {
        setSelectedBuild(detailed);
        setTechnicianNotes(detailed.staffNotes || '');
      }
    } catch (err) {
      console.warn('Using cached build details:', err);
    }
  };

  const handleCloseModal = () => {
    setSelectedBuild(null);
    setTechnicianNotes('');
    setValidationError('');
  };

  // Review actions
  const handleAssignToMe = async () => {
    if (!selectedBuild) return;
    setActionLoading(true);
    try {
      const myStaff = technicians.find(
        (t) => String(t.userId) === String(user?.userId) || String(t.staffId) === String(user?.userId)
      );
      const myStaffId = myStaff?.staffId || user?.userId || 1;

      const updated = await buildReviewService.updateBuildReview(selectedBuild.buildId, {
        status: selectedBuild.status === 'Pending Staff Review' ? 'In Review by Staff' : selectedBuild.status,
        assignedStaffId: myStaffId,
        staffNotes: technicianNotes,
      });
      setSelectedBuild(updated);
      await loadData();
      showNotification(`Build #${selectedBuild.buildId} assigned to your workbench.`);
    } catch (err) {
      showNotification(`Failed to assign build: ${err?.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleStatusTransition = async (newStatus) => {
    if (!selectedBuild) return;

    if (newStatus === 'Changes Requested' && !technicianNotes.trim()) {
      setValidationError('Please provide technical feedback explaining what components need modification.');
      return;
    }

    setActionLoading(true);
    setValidationError('');

    try {
      const notesToSave = technicianNotes.trim() || 
        (newStatus === 'Approved by Staff' 
          ? 'Hardware clearances verified on workbench. Automated checks passed. Cleared for assembly.' 
          : selectedBuild.staffNotes);

      const updated = await buildReviewService.updateBuildReview(selectedBuild.buildId, {
        status: newStatus,
        staffNotes: notesToSave,
        assignedStaffId: selectedBuild.assignedStaffId || user?.userId || 1,
      });

      setSelectedBuild(updated);
      await loadData();
      showNotification(`Build #${selectedBuild.buildId} marked as "${newStatus}".`);

      // Send EmailJS notification to customer when build is approved or changes requested
      if (newStatus === 'Approved by Staff' || newStatus === 'Changes Requested') {
        const customerEmail = selectedBuild.customerEmail || updated?.customerEmail;
        if (customerEmail) {
          try {
            const emailRes = await emailService.sendBuildReviewNotification({
              customerName: selectedBuild.customerName || updated?.customerName || 'Valued Customer',
              customerEmail: customerEmail,
              buildId: selectedBuild.buildId,
              buildName: selectedBuild.buildName || updated?.buildName || 'Custom PC Build',
              newStatus: newStatus,
              technicianNotes: notesToSave,
              totalPrice: selectedBuild.totalPrice || updated?.totalPrice,
            });

            if (emailRes.success && !emailRes.simulated) {
              showNotification(`Notification email successfully sent to ${customerEmail}.`);
            } else if (emailRes.simulated) {
              console.info(`[EmailJS] Customer notification simulated for ${customerEmail}. Set EmailJS keys in web/.env for live dispatch.`);
            }
          } catch (emailErr) {
            console.warn('[EmailJS] Notification sending encountered error:', emailErr);
          }
        }
        handleCloseModal();
      }
    } catch (err) {
      showNotification(`Failed to update review status: ${err?.message}`, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleResetFilters = () => {
    setSearchQuery('');
    setStatusFilter('all');
    setStaffFilter('all');
    setCurrentPage(1);
  };

  return (
    <div className="page-container" id="build-reviews-page">
      {/* Header */}
      <div className="dashboard-header">
        <div>
          <h1 style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.4rem' }}>
              <ToolsIcon size={24} /> Custom PC Build Reviews
            </span>
            <span className="badge badge-staff" style={{ fontSize: '0.75rem' }}>Staff & Admin Hub</span>
          </h1>
          <p className="subtitle">
            Automated hardware clearance audit, PSU transient headroom validation, and manual technician assembly sign-off.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
          <button
            type="button"
            onClick={() => loadData(true)}
            className="btn btn-outline"
            id="refresh-build-queue-btn"
            disabled={refreshing}
          >
            {refreshing ? (
              'Refreshing...'
            ) : (
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}>
                <RefreshCwIcon size={14} /> Refresh Queue
              </span>
            )}
          </button>
        </div>
      </div>

      {/* Notification Toast */}
      {notification && (
        <div
          className={`notification-banner ${
            notification.type === 'error' ? 'alert-error' : 'alert-success'
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

      {/* KPI Stats Row */}
      <BuildReviewStats metrics={metrics} />

      {/* Toolbar & Filter Card */}
      <BuildReviewToolbar
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
        onClearSearch={() => setSearchQuery('')}
        statusFilter={statusFilter}
        onStatusFilterChange={setStatusFilter}
        staffFilter={staffFilter}
        onStaffFilterChange={setStaffFilter}
        technicians={technicians}
        metrics={metrics}
        onResetFilters={handleResetFilters}
      />

      {/* Main Review Queue Table */}
      <BuildReviewTable
        builds={filteredBuilds}
        paginatedBuilds={paginatedBuilds}
        totalCount={metrics.total}
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
        onInspect={handleOpenInspection}
      />

      {/* Modal: Full Inspection & Clearance Workbench */}
      <BuildWorkbenchModal
        build={selectedBuild}
        onClose={handleCloseModal}
        technicianNotes={technicianNotes}
        onNotesChange={setTechnicianNotes}
        validationError={validationError}
        actionLoading={actionLoading}
        onAssignToMe={handleAssignToMe}
        onStatusTransition={handleStatusTransition}
      />
    </div>
  );
};

export default BuildReviews;
